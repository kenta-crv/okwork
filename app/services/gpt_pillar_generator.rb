require "net/http"
require "json"
require "openssl"

class GptPillarGenerator
  MODEL_NAME = "gpt-4o-mini"
  GPT_API_URL = "https://api.openai.com/v1/chat/completions"

  GENRE_REVERSE_MAP = {
    "cargo"        => "軽貨物",
    "cleaning"     => "清掃業",
    "security"     => "警備業",
    "app"          => "営業代行",
    "vender"       => "自販機",
    "construction" => "建設"
  }.freeze

  GENRE_MAP = GENRE_REVERSE_MAP.invert.freeze

  CATEGORY_KEYWORDS = {
    "警備業"   => ["警備", "セキュリティー", "施設警備", "交通整理"],
    "軽貨物"   => ["軽貨物", "配送", "運送", "ドライバー", "宅配"],
    "清掃業"   => ["清掃", "クリーニング", "ハウスクリーニング", "ビル清掃"],
    "自販機"   => ["自動販売機設置", "自販機設置", "自販機経営"],
    "営業代行" => ["営業代行", "テレアポ代行", "インサイドセールス", "法人リスト制作","フォーム営業", "商談代行"],
    "建設"     => ["建設", "現場", "工務店", "リフォーム", "土木"]
  }.freeze

  # =================================================
  # メイン処理：親記事から6,000文字以上の記事を生成
  # =================================================
  def self.generate_full_from_existing_column!(column)
    raise "タイトルが空です" if column.title.blank?

    # --- 業種優先でカテゴリー決定 ---
    target_category = GENRE_REVERSE_MAP[column.genre] || detect_category(column)
    genre_code = GENRE_MAP[target_category] || "other"

    puts "▶ 統合生成開始: #{column.title} (判定: #{target_category})"

    # 1. meta情報生成
    meta_data = generate_meta_info(column, target_category)
    raise "Meta情報の生成に失敗しました" if meta_data.nil?

    clean_code = meta_data["code"].to_s.downcase.gsub(/[^a-z0-9\s\-]/, '')
                      .strip.gsub(/[\s_]+/, '-').gsub(/-+/, '-').gsub(/\A-|-\z/, '')
    clean_code = "article-#{column.id.to_s.split('-').first}" if clean_code.blank?

    # 2. 記事構成生成
    structure_data = generate_structure(column, target_category)
    raise "記事構成の生成に失敗しました" if structure_data.nil? || structure_data["structure"].nil?

    # 3. カラム情報更新
    column.update!(
      code: clean_code,
      description: meta_data["description"],
      keyword: meta_data["keyword"],
      genre: genre_code,
      status: "creating",
      article_type: "pillar"
    )

    # =================================================
    # 本文生成（長文対応版）
    # =================================================
    h2_titles = structure_data["structure"].map { |s| s["h2_title"] }
    body_content = ""

    # 導入文
    body_content += call_text_section(introduction_prompt(column, target_category, h2_titles), target_category) + "\n\n"

    # 各見出し本文
    structure_data["structure"].each_with_index do |section, index|
      prev_h2 = index > 0 ? h2_titles[index - 1] : nil
      next_h2 = h2_titles[index + 1]

      body_content += "## #{section["h2_title"]}\n\n"
      body_content += call_text_section(h2_content_prompt(column, target_category, section, prev_h2, next_h2), target_category) + "\n\n"

      sleep(1.0)
    end

    # まとめ
    body_content += call_text_section(conclusion_prompt(column, target_category), target_category)
    body_content += "\n\n{::options auto_ids=\"false\" /}"

    # 最終更新
    column.update!(body: body_content, status: "completed")
    puts "✅ 生成完了: #{clean_code}"
    true
  end

  # =================================================
  private
  # =================================================

  def self.detect_category(column)
    search_text = "#{column.title} #{column.keyword} #{column.genre} #{column.choice}"
    CATEGORY_KEYWORDS.each do |category, words|
      return category if words.any? { |w| search_text.include?(w) }
    end
    "ビジネス"
  end

  def self.generate_meta_info(column, category)
    prompt = <<~PROMPT
      以下の条件でSEOメタ情報をJSONで生成してください。
      タイトル: #{column.title}
      業種: #{category}
      形式: { "code": "slug", "description": "日本語説明", "keyword": "キーワード" }
    PROMPT
    res = call_gpt_api(prompt, category, json_mode: true)
    res ? JSON.parse(res.dig("choices", 0, "message", "content")) : nil
  end

  def self.generate_structure(column, category)
    child_columns = Column.where(parent_id: column.id, article_type: "child")
    child_titles = child_columns.map(&:title).join(", ")
    prompt = <<~PROMPT
      記事「#{column.title}」の構成案を作成してください。
      読者がこの一記事で「#{category}」に関連する業務やノウハウを実務レベルで体系的に理解できるよう、導入・現状の課題・具体的な手順（外注や導入準備）・運用のポイント・トラブル回避・まとめの流れでH2見出しを6〜8個作成してください。
      業種: #{category}
      参考情報: #{child_titles}
      出力形式: { "structure": [ { "h2_title": "見出し名" } ] }
    PROMPT
    res = call_gpt_api(prompt, category, json_mode: true)
    res ? JSON.parse(res.dig("choices", 0, "message", "content")) : nil
  end

  # =================================================
  # GPT呼び出し（汎用化）
  # =================================================
  def self.call_text_section(prompt, category)
    response = call_gpt_api(prompt, category, json_mode: false)
    content = response&.dig("choices", 0, "message", "content")
    return "（生成エラー）" if content.blank?
    content.strip
  end

  def self.call_gpt_api(prompt, category, json_mode: false)
    uri = URI(GPT_API_URL)
    req = Net::HTTP::Post.new(uri)
    req["Content-Type"] = "application/json"
    req["Authorization"] = "Bearer #{ENV['GPT_API_KEY']}"

    # システムメッセージを業種に合わせて動的に変更
    system_content = "あなたは#{category}業界に精通したプロのSEOライターです。読者が#{category}に関する実務を具体的に理解し、課題を解決できる専門性の高い記事を書いてください。"
    system_content += " 出力はJSON形式のみ。" if json_mode
    system_content += " Markdown形式の本文テキストのみを直接出力してください。" unless json_mode

    payload = {
      model: MODEL_NAME,
      messages: [
        { role: "system", content: system_content },
        { role: "user", content: prompt }
      ],
      temperature: 0.5
    }
    payload[:response_format] = { type: "json_object" } if json_mode
    req.body = payload.to_json

    begin
      res = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true, read_timeout: 300) { |http| http.request(req) }
      JSON.parse(res.body) if res.is_a?(Net::HTTPSuccess)
    rescue => e
      nil
    end
  end

  # =================================================
  # プロンプト定義
  # =================================================

  def self.introduction_prompt(column, category, h2_titles)
    <<~PROMPT
      記事「#{column.title}」の導入文を1,000文字前後で執筆してください。
      業種: #{category}
      読者が抱える課題（人手不足、効率化、コスト削減など）に共感し、この記事を読み終える頃にはどのような解決策が得られるかを伝えてください。
      H2見出しの順序: #{h2_titles.join(' → ')}
    PROMPT
  end

  def self.h2_content_prompt(column, category, section, prev_h2, next_h2)
    context = ""
    context += "前のセクション「#{prev_h2}」の内容を受けて自然な接続で始めてください。" if prev_h2
    context += " 次に「#{next_h2}」の解説に繋がるように締めてください。" if next_h2

    <<~PROMPT
      見出し「#{section["h2_title"]}」の本文を500〜1,000文字で執筆してください。
      対象業界: #{category}
      指示:
      - その業界ならではの専門用語や具体例、よくある成功パターンや失敗事例を交えてください。
      - 読者が即実践できる具体的なアクションプランを提示してください。
      - #{context}
      - 箇条書きや表を活用して読みやすく構成してください。
    PROMPT
  end

  def self.conclusion_prompt(column, category)
    <<~PROMPT
      記事「#{column.title}」のまとめを1,000文字前後で執筆してください。
      業種: #{category}
      記事全体の内容を要約し、読者が明日から取り組むべき一歩を明確にしてください。
      「#{category}に関する課題を解決し、事業を次のステージへ進めましょう」という前向きなメッセージで締めてください。
    PROMPT
  end
end