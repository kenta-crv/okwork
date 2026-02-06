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

  # ==========================================================
  # メイン生成ロジック
  # ==========================================================
  def self.generate_full_from_existing_column!(column)
    raise "タイトルが空です" if column.title.blank?
    
    target_category = detect_category(column)
    genre_code = GENRE_MAP[target_category] || "other"

    puts "▶ 統合生成開始: #{column.title} (判定: #{target_category})"

    # 1. meta情報生成 (JSONモード)
    meta_data = generate_meta_info(column, target_category)
    raise "Meta情報の生成に失敗しました" if meta_data.nil?
    
    # スラッグのクレンジング
    clean_code = meta_data["code"].to_s.downcase
                  .gsub(/[^a-z0-9\s\-]/, '')
                  .strip
                  .gsub(/[\s_]+/, '-')
                  .gsub(/-+/, '-')
                  .gsub(/\A-|-\z/, '')

    clean_code = "article-#{column.id.to_s.split('-').first}" if clean_code.blank?

    # 2. 記事構成生成 (JSONモード)
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

    # 3. 本文生成 (ここからはプレーンテキストモード)
    body_content = ""
    
    # 導入文
    body_content += call_text_section(introduction_prompt(column, target_category)) + "\n\n"

    # 各見出し
    structure_data["structure"].each do |section|
      body_content += "## #{section["h2_title"]}\n\n"
      body_content += call_text_section(h2_content_prompt(column, target_category, section)) + "\n\n"
      sleep(1.5) # レート制限対策
    end

    # まとめ
    body_content += call_text_section(conclusion_prompt(column, target_category))
    body_content += "\n\n{::options auto_ids=\"false\" /}"

    # 4. 最終保存
    column.update!(
      body: body_content,
      status: "completed" 
    )

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

  # JSONモード用：Meta情報
  def self.generate_meta_info(column, category)
    prompt = <<~PROMPT
      以下の条件でSEOメタ情報を「JSON」形式で生成してください。
      【重要】説明文(description)は必ず日本語、スラッグ(code)のみ英語にしてください。
      
      タイトル: #{column.title}
      業種: #{category}
      出力形式: { "code": "english-slug", "description": "日本語の説明文", "keyword": "キーワード" }
    PROMPT
    res = call_gpt_api(prompt, json_mode: true)
    res ? JSON.parse(res.dig("choices", 0, "message", "content")) : nil
  end

  # JSONモード用：記事構成
  def self.generate_structure(column, category)
    child_columns = Column.where(parent_id: column.id, article_type: "child")
    child_titles = child_columns.map(&:title).join("\n- ")
    prompt = <<~PROMPT
      記事「#{column.title}」の構成（日本語のH2見出し6〜8個）を「JSON」形式で作成してください。
      業種: #{category}
      子記事リスト: #{child_titles}
      出力形式: { "structure": [ { "h2_title": "日本語の見出し名" } ] }
    PROMPT
    res = call_gpt_api(prompt, json_mode: true)
    res ? JSON.parse(res.dig("choices", 0, "message", "content")) : nil
  end

  # テキストモード用：各セクション執筆
  def self.call_text_section(prompt)
    response = call_gpt_api(prompt, json_mode: false)
    content = response&.dig("choices", 0, "message", "content")
    return "（生成エラー）" if content.blank?
    
    # JSONとして出力されてしまった場合の簡易除去
    content.gsub!(/\A\{.*"content":\s*"/m, '')
    content.gsub!(/"\s*\}\z/m, '')
    content.strip
  end

  # 共通API呼び出し
  def self.call_gpt_api(prompt, json_mode: false)
    uri = URI(GPT_API_URL)
    req = Net::HTTP::Post.new(uri)
    req["Content-Type"] = "application/json"
    req["Authorization"] = "Bearer #{ENV['GPT_API_KEY']}"

    # システムプロンプトで日本語を強制
    system_content = "あなたはSEO専門ライターです。回答は【必ず日本語】で行ってください。"
    system_content += " 出力はJSON形式で行ってください。" if json_mode
    system_content += " JSONは禁止です。そのまま本文として使えるプレーンテキストのみ出力してください。" unless json_mode

    payload = {
      model: MODEL_NAME,
      messages: [
        { role: "system", content: system_content },
        { role: "user", content: prompt }
      ],
      temperature: 0.3
    }
    payload[:response_format] = { type: "json_object" } if json_mode
    req.body = payload.to_json

    begin
      # タイムアウトを長めに設定（240秒）
      res = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true, read_timeout: 240) { |http| http.request(req) }
      
      if res.is_a?(Net::HTTPSuccess)
        JSON.parse(res.body)
      else
        Rails.logger.error "❌ OpenAI Error: #{res.code} #{res.body}"
        nil
      end
    rescue => e
      Rails.logger.error "❌ Connection Error: #{e.message}"
      nil
    end
  end

  def self.introduction_prompt(column, category)
    "記事「#{column.title}」の導入文を日本語で600文字以上執筆してください。JSON形式は厳禁です。"
  end

  def self.h2_content_prompt(column, category, section)
    "見出し「#{section["h2_title"]}」の本文を日本語で1000文字程度執筆してください。業種「#{category}」に関連させ、JSONは使わずテキストのみ出力してください。"
  end

  def self.conclusion_prompt(column, category)
    "記事「#{column.title}」のまとめを日本語で執筆してください。必ず「## まとめ」から開始し、JSONは使わないでください。"
  end
end