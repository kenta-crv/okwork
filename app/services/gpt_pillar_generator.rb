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
    "営業代行" => ["営業代行", "テレアポ", "インサイドセールス", "コールセンター"],
    "建設"     => ["建設", "現場", "工務店", "リフォーム", "土木"]
  }.freeze

  def self.generate_full_from_existing_column!(column)
    raise "タイトルが空です" if column.title.blank?
    
    target_category = detect_category(column)
    genre_code = GENRE_MAP[target_category] || "other"

    puts "▶ 統合生成開始: #{column.title}"

    # 1. meta情報生成 (ここだけJSONモード)
    meta_data = generate_meta_info(column, target_category)
    raise "Meta情報の生成に失敗しました" if meta_data.nil?
    
    clean_code = meta_data["code"].to_s.downcase
                  .gsub(/[^a-z0-9\s\-]/, '')
                  .strip
                  .gsub(/[\s_]+/, '-')
                  .gsub(/-+/, '-')
                  .gsub(/\A-|-\z/, '')

    clean_code = "article-#{column.id.to_s.split('-').first}" if clean_code.blank?

    # 2. 記事構成生成 (ここもJSONモード)
    structure_data = generate_structure(column, target_category)
    raise "記事構成の生成に失敗しました" if structure_data.nil? || structure_data["structure"].nil?

    # DB中間保存
    column.update!(
      code: clean_code,
      description: meta_data["description"],
      keyword: meta_data["keyword"],
      choice: target_category,
      genre: genre_code,
      status: "creating",
      article_type: "pillar"
    )

    # 3. 本文生成 (ここは通常のテキストモード)
    body_content = ""
    # 導入文
    body_content += call_section(introduction_prompt(column, target_category)) + "\n\n"

    # 各見出し
    structure_data["structure"].each do |section|
      body_content += "## #{section["h2_title"]}\n\n"
      body_content += call_section(h2_content_prompt(column, target_category, section)) + "\n\n"
      sleep(1)
    end

    # まとめ
    body_content += call_section(conclusion_prompt(column, target_category))
    body_content += "\n\n{::options auto_ids=\"false\" /}"

    # 4. 最終保存
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
      以下の条件でSEOメタ情報を生成し「JSON」形式で出力してください。
      【重要】本文や説明は「日本語」で、スラッグ(code)のみ「英語」にしてください。

      タイトル: #{column.title}
      業種: #{category}

      出力形式:
      {
        "code": "english-slug-only",
        "description": "日本語による120文字程度の説明文",
        "keyword": "キーワード1, キーワード2"
      }
    PROMPT
    res = call_gpt_api(prompt, json_mode: true)
    res ? JSON.parse(res.dig("choices", 0, "message", "content")) : nil
  end

  def self.generate_structure(column, category)
    child_columns = Column.where(parent_id: column.id, article_type: "child")
    child_titles = child_columns.map(&:title).join("\n- ")
    prompt = <<~PROMPT
      記事「#{column.title}」の構成（日本語のH2見出し6〜8個）を「JSON」形式で作成してください。
      出力形式: { "structure": [ { "h2_title": "日本語の見出し" } ] }
    PROMPT
    res = call_gpt_api(prompt, json_mode: true)
    res ? JSON.parse(res.dig("choices", 0, "message", "content")) : nil
  end

  def self.call_section(prompt)
    # 本文生成は json_mode: false で呼び出す
    response = call_gpt_api(prompt, json_mode: false)
    content = response&.dig("choices", 0, "message", "content") || "（生成エラー）"
    # 万が一JSONっぽく出力された場合のガード（"{ " 始まりならパースを試みる等）はせず、
    # プロンプト側で「プレーンテキストで」と指定する
    content.strip
  end

  def self.call_gpt_api(prompt, json_mode: false)
    uri = URI(GPT_API_URL)
    req = Net::HTTP::Post.new(uri)
    req["Content-Type"] = "application/json"
    req["Authorization"] = "Bearer #{ENV['GPT_API_KEY']}"

    payload = {
      model: MODEL_NAME,
      messages: [
        { role: "system", content: "あなたは特定の業界知識に深いSEOライターです。回答は必ず「日本語」で行ってください（スラッグ指定がある場合を除く）。" },
        { role: "user", content: prompt }
      ],
      temperature: 0.3
    }
    payload[:response_format] = { type: "json_object" } if json_mode
    req.body = payload.to_json

    begin
      res = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true, read_timeout: 180) { |http| http.request(req) }
      res.is_a?(Net::HTTPSuccess) ? JSON.parse(res.body) : nil
    rescue => e
      nil
    end
  end

  def self.introduction_prompt(column, category)
    <<~PROMPT
      記事「#{column.title}」の導入文を執筆してください。
      【ルール】
      ・必ず「日本語」で執筆すること。
      ・JSON形式ではなく、そのまま読める「プレーンテキスト」で出力してください。
      ・600文字以上。
    PROMPT
  end

  def self.h2_content_prompt(column, category, section)
    <<~PROMPT
      見出し「#{section["h2_title"]}」の本文を執筆してください。
      【ルール】
      ・必ず「日本語」で執筆すること。
      ・JSON形式は厳禁。そのまま本文として使える「テキスト」のみ出力してください。
      ・文字数1000文字程度。
    PROMPT
  end

  def self.conclusion_prompt(column, category)
    "記事「#{column.title}」のまとめを「## まとめ」から始めて「日本語のプレーンテキスト」で執筆してください。"
  end
end