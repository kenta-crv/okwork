require "net/http"
require "json"
require "openssl"

class GptPillarGenerator
  MODEL_NAME = "gpt-4o-mini"
  GPT_API_URL = "https://api.openai.com/v1/chat/completions"

  GENRE_MAP = {
    "軽貨物"   => "cargo",
    "清掃業"   => "cleaning",
    "警備業"   => "security",
    "営業代行" => "app",
    "自販機"   => "vender",
    "建設"     => "construction"
  }.freeze

  CATEGORY_KEYWORDS = {
    "警備業"   => ["警備", "セキュリティー", "施設警備", "交通整理"],
    "軽貨物"   => ["軽貨物", "配送", "運送", "ドライバー", "宅配"],
    "清掃業"   => ["清掃", "クリーニング", "ハウスクリーニング", "ビル清掃"],
    "自販機"   => ["自動販売機設置", "自販機設置", "自販機経営"],
    "営業代行" => ["営業代行", "テレアポ代行", "インサイドセールス", "法人リスト制作","フォーム営業", "商談代行"],
    "建設"     => ["建設", "現場", "工務店", "リフォーム", "土木"]
  }.freeze

  def self.generate_full_from_existing_column!(column)
    raise "タイトルが空です" if column.title.blank?
    
    target_category = detect_category(column)
    genre_code = GENRE_MAP[target_category] || "other"

    puts "▶ 統合生成開始: #{column.title} (判定: #{target_category})"

    # 1. meta情報生成
    meta_data = generate_meta_info(column, target_category)
    raise "Meta情報の生成に失敗しました" if meta_data.nil?
    
    clean_code = meta_data["code"].to_s.downcase.gsub(/[^a-z0-9\s\-]/, '').strip.gsub(/[\s_]+/, '-').gsub(/-+/, '-').gsub(/\A-|-\z/, '')
    clean_code = "article-#{column.id.to_s.split('-').first}" if clean_code.blank?

    # 2. 記事構成生成
    structure_data = generate_structure(column, target_category)
    raise "記事構成の生成に失敗しました" if structure_data.nil? || structure_data["structure"].nil?

    column.update!(
      code: clean_code,
      description: meta_data["description"],
      keyword: meta_data["keyword"],
      choice: target_category,
      genre: genre_code,
      status: "creating",
      article_type: "pillar"
    )

    # --- 本文生成（連携強化Ver） ---
    h2_titles = structure_data["structure"].map { |s| s["h2_title"] }
    body_content = ""
    
    # 3. 導入文
    body_content += call_text_section(introduction_prompt(column, target_category, h2_titles)) + "\n\n"

    # 4. 各見出し（前後の文脈を意識させる）
    structure_data["structure"].each_with_index do |section, index|
      prev_h2 = index > 0 ? h2_titles[index - 1] : nil
      next_h2 = h2_titles[index + 1]
      
      body_content += "## #{section["h2_title"]}\n\n"
      body_content += call_text_section(h2_content_prompt(column, target_category, section, prev_h2, next_h2)) + "\n\n"
      sleep(1.0) 
    end

    # 5. まとめ
    body_content += call_text_section(conclusion_prompt(column, target_category))
    body_content += "\n\n{::options auto_ids=\"false\" /}"

    column.update!(body: body_content, status: "completed")
    puts "✅ 生成完了: #{clean_code}"
    true
  end

  private

  def self.detect_category(column)
    search_text = "#{column.title} #{column.keyword} #{column.genre} #{column.choice}"
    CATEGORY_KEYWORDS.each do |category, words|
      return category if words.any? { |w| search_text.include?(w) }
    end
    "その他"
  end

  def self.generate_meta_info(column, category)
    prompt = <<~PROMPT
      以下の条件でSEOメタ情報をJSONで生成してください。
      タイトル: #{column.title}
      業種: #{category}
      形式: { "code": "slug", "description": "日本語説明", "keyword": "キーワード" }
    PROMPT
    res = call_gpt_api(prompt, json_mode: true)
    res ? JSON.parse(res.dig("choices", 0, "message", "content")) : nil
  end

  def self.generate_structure(column, category)
    child_columns = Column.where(parent_id: column.id, article_type: "child")
    child_titles = child_columns.map(&:title).join(", ")
    prompt = <<~PROMPT
      記事「#{column.title}」の構成案を作成してください。
      読者がこの一記事で運用を完結できるよう、導入・準備・実行・検証・改善のサイクルを含めたH2見出しを6〜8個構成してください。
      業種: #{category}
      参考子記事: #{child_titles}
      出力形式: { "structure": [ { "h2_title": "見出し名" } ] }
    PROMPT
    res = call_gpt_api(prompt, json_mode: true)
    res ? JSON.parse(res.dig("choices", 0, "message", "content")) : nil
  end

  def self.call_text_section(prompt)
    response = call_gpt_api(prompt, json_mode: false)
    content = response&.dig("choices", 0, "message", "content")
    return "（生成エラー）" if content.blank?
    content.strip
  end

  def self.call_gpt_api(prompt, json_mode: false)
    uri = URI(GPT_API_URL)
    req = Net::HTTP::Post.new(uri)
    req["Content-Type"] = "application/json"
    req["Authorization"] = "Bearer #{ENV['GPT_API_KEY']}"

    system_content = "あなたはプロのSEOライターです。読者が実務で使える具体的かつ論理的な記事を執筆してください。"
    system_content += " 出力はJSON形式のみ。" if json_mode
    system_content += " JSONは厳禁。Markdown形式の本文テキストのみを直接出力してください。「見出し」「まとめ」といった言葉を文頭に付けず、内容から始めてください。" unless json_mode

    payload = {
      model: MODEL_NAME,
      messages: [
        { role: "system", content: system_content },
        { role: "user", content: prompt }
      ],
      temperature: 0.5 # 少し上げることで自然な繋がりを許容
    }
    payload[:response_format] = { type: "json_object" } if json_mode
    req.body = payload.to_json

    begin
      res = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true, read_timeout: 240) { |http| http.request(req) }
      JSON.parse(res.body) if res.is_a?(Net::HTTPSuccess)
    rescue => e
      nil
    end
  end

  # --- プロンプト修正ポイント：文脈の注入 ---

  def self.introduction_prompt(column, category, h2_titles)
    <<~PROMPT
      記事「#{column.title}」の導入文を600文字以上で執筆してください。
      業種: #{category}
      この記事では以下の流れで解説することを読者に伝えてください: #{h2_titles.join('→')}。
      「勘に頼らず、検証と改善を繰り返す重要性」に触れ、読者の期待感を高めてください。
    PROMPT
  end

  def self.h2_content_prompt(column, category, section, prev_h2, next_h2)
    context = ""
    context += "前のセクション「#{prev_h2}」の内容を受けて、自然な接続で始めてください。" if prev_h2
    context += "次に「#{next_h2}」の解説に繋がるように文章を締めてください。" if next_h2

    <<~PROMPT
      見出し「#{section["h2_title"]}」の内容を1000文字程度で執筆してください。
      業種: #{category}
      【指示】:
      - 単なる説明で終わらず、具体的な手順や数値、検証方法（PDCA）を含めてください。
      - #{context}
      - 箇条書きや表、実例を用いて、読みやすく実践的な内容にしてください。
    PROMPT
  end

  def self.conclusion_prompt(column, category)
    <<~PROMPT
      記事「#{column.title}」の総括を執筆してください。
      必ず「## まとめ」という見出しから開始してください。
      「検証とフィードバックが成功の鍵である」というメッセージで締めくくってください。
    PROMPT
  end
end