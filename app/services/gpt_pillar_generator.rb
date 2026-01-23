require "net/http"
require "json"
require "openssl"

class GptPillarGenerator
  MODEL_NAME = "gpt-4o-mini"
  GPT_API_KEY = ENV["GPT_API_KEY"]
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
    "営業代行" => ["営業代行", "テレアポ", "インサイドセールス", "コールセンター"],
    "建設"     => ["建設", "現場", "工務店", "リフォーム", "土木"]
  }.freeze

  # ==========================================================
  # 【統合メイン】Jobから呼び出し
  # ==========================================================
  def self.generate_full_from_existing_column!(column)
    raise "タイトルが空です" if column.title.blank?
    
    target_category = detect_category(column)
    genre_code = GENRE_MAP[target_category] || "other"

    puts "▶ 統合生成開始: #{column.title} (判定: #{target_category})"

    # 1. meta情報生成 (英語スラッグ生成を最優先に指示)
    meta_data = generate_meta_info(column, target_category)
    
    # --- 保存前の最終クレンジング (SEO観点で不正な文字を排除) ---
    # 日本語が含まれていようがいまいが、英数字とハイフン以外を消去して英単語化を強制
    clean_code = meta_data["code"].to_s.downcase
                  .gsub(/[^a-z0-9\s\-]/, '') # 英数字、スペース、ハイフン以外を削除
                  .strip
                  .gsub(/[\s_]+/, '-')       # スペースやアンダースコアをハイフンに
                  .gsub(/-+/, '-')           # 連続ハイフンを1つに
                  .gsub(/\A-|-\z/, '')       # 先頭と末尾のハイフンを削除

    # 万が一空になった場合のフォールバック
    clean_code = "article-#{column.id.to_s.split('-').first}" if clean_code.blank?

    # 2. DB中間保存
    column.update!(
      code: clean_code,
      description: meta_data["description"],
      keyword: meta_data["keyword"],
      choice: target_category,
      genre: genre_code,
      status: "creating",
      article_type: "pillar"
    )

    # 3. 本文生成
    child_columns = Column.where(parent_id: column.id, article_type: "child")
    body_content = generate_body_logic(column, target_category, child_columns)

    raise "本文生成失敗" if body_content.blank?

    # 4. 最終保存
    column.update!(
      body: body_content,
      status: "completed" 
    )

    puts "✅ スラッグ確定: #{clean_code}"
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
      以下の記事のSEO用メタ情報を生成してください。
      出力は必ず1つのJSONオブジェクトのみ。解説は不要です。

      【入力情報】
      タイトル: #{column.title}
      業種: #{category}

      【重要ルール: スラッグ(code)の生成】
      1. タイトルの意味を汲み取った「英語」で作成すること。
      2. 日本語（漢字・ひらがな・カタカナ）は絶対に含めない。
      3. 小文字の英数字とハイフンのみを使用すること。
      4. 3〜5単語程度で、SEOに適切なキーワードを含めること。
      5. 例: 「建設業の求人募集の書き方」 
            NG: kensetsu-kyujin-kakikata
            OK: construction-job-posting-guide

      【出力形式】
      {
        "code": "english-slug-here",
        "description": "120文字程度のディスクリプション",
        "keyword": "キーワード1, キーワード2"
      }
    PROMPT

    res = call_gpt_api(prompt, json_mode: true)
    JSON.parse(res.dig("choices", 0, "message", "content"))
  end

  def self.generate_body_logic(column, category, child_columns)
    structure_res = call_gpt_api(pillar_structure_prompt(column, category, child_columns), json_mode: true)
    structure = JSON.parse(structure_res.dig("choices", 0, "message", "content"))["structure"]

    article = ""
    article += call_section(introduction_prompt(column, category)) + "\n\n"

    structure.each do |section|
      article += "## #{section["h2_title"]}\n\n"
      article += call_section(h2_content_prompt(column, category, section, child_columns)) + "\n\n"
      sleep(1)
    end

    article += call_section(conclusion_prompt(column, category))
    article + "\n\n{::options auto_ids=\"false\" /}"
  end

  def self.call_section(prompt)
    response = call_gpt_api(prompt)
    response&.dig("choices", 0, "message", "content") || "（コンテンツ生成エラー）"
  end

  def self.call_gpt_api(prompt, json_mode: false)
    uri = URI(GPT_API_URL)
    req = Net::HTTP::Post.new(uri)
    req["Content-Type"] = "application/json"
    req["Authorization"] = "Bearer #{GPT_API_KEY}"

    payload = {
      model: MODEL_NAME,
      messages: [
        { role: "system", content: "あなたは特定の業界知識に深いSEO専門ライターです。スラッグは必ず英単語を使用します。" },
        { role: "user", content: prompt }
      ],
      temperature: 0.3
    }
    payload[:response_format] = { type: "json_object" } if json_mode
    req.body = payload.to_json

    res = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true, read_timeout: 150) { |http| http.request(req) }
    res.is_a?(Net::HTTPSuccess) ? JSON.parse(res.body) : nil
  end

  def self.pillar_structure_prompt(column, category, child_columns)
    child_titles = child_columns.map(&:title).join("\n- ")
    <<~PROMPT
      記事タイトル「#{column.title}」に基づき、体系的な記事構成（H2見出し）を6〜8個作成してください。
      業種: #{category}
      子記事リスト: #{child_titles}
      { "structure": [ { "h2_title": "見出し名" } ] }
    PROMPT
  end

  def self.introduction_prompt(column, category)
    <<~PROMPT
      記事「#{column.title}」の導入文を執筆してください。
      ターゲット業種: #{category}
      ・読者の悩みへの共感から始める
      ・600文字以上
    PROMPT
  end

  def self.h2_content_prompt(column, category, section, child_columns)
    child_titles = child_columns.map(&:title).join("、")
    <<~PROMPT
      見出し「#{section["h2_title"]}」に関する本文を執筆してください。
      全体タイトル: #{column.title}
      業種: #{category}
      ・## 記号は不要
      ・文字数1000文字程度
      ・子記事（#{child_titles}）があれば自然に言及する
    PROMPT
  end

  def self.conclusion_prompt(column, category)
    <<~PROMPT
      記事「#{column.title}」の締めくくり（まとめ）を執筆してください。
      ・無関係な話は書かず、「#{category}」の内容を要約する。
      ・必ず「## まとめ」から開始すること。
    PROMPT
  end
end