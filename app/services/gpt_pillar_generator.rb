require "net/http"
require "json"
require "openssl"

class GptPillarGenerator
  MODEL_NAME = "gpt-4o-mini"
  # API_KEYはメソッド内で直接 ENV から取得するように変更（安全策）
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

    # 1. meta情報生成
    meta_data = generate_meta_info(column, target_category)
    raise "Meta情報の生成に失敗しました (OpenAI response nil)" if meta_data.nil?
    
    # スラッグのクレンジング
    clean_code = meta_data["code"].to_s.downcase
                  .gsub(/[^a-z0-9\s\-]/, '') 
                  .strip
                  .gsub(/[\s_]+/, '-')       
                  .gsub(/-+/, '-')           
                  .gsub(/\A-|-\z/, '')       

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

    # 3. 本文構成(H2見出し)の生成
    structure_data = generate_structure(column, target_category)
    raise "記事構成の生成に失敗しました" if structure_data.nil? || structure_data["structure"].nil?

    # 4. 各セクションの本文生成
    body_content = ""
    body_content += call_section(introduction_prompt(column, target_category)) + "\n\n"

    structure_data["structure"].each do |section|
      body_content += "## #{section["h2_title"]}\n\n"
      body_content += call_section(h2_content_prompt(column, target_category, section)) + "\n\n"
      sleep(1) # API制限と負荷対策
    end

    body_content += call_section(conclusion_prompt(column, target_category))
    body_content += "\n\n{::options auto_ids=\"false\" /}"

    # 5. 最終保存
    column.update!(
      body: body_content,
      status: "completed" 
    )

    puts "✅ 全工程完了: #{column.title} (Slug: #{clean_code})"
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
      以下の記事のSEO用メタ情報を「JSON」形式で生成してください。
      出力は必ず1つのJSONオブジェクトのみ。解説は不要です。

      【入力情報】
      タイトル: #{column.title}
      業種: #{category}

      【重要ルール: スラッグ(code)の生成】
      1. タイトルの意味を汲み取った「英語」で作成すること。
      2. 日本語（漢字・ひらがな・カタカナ）は絶対に含めない。
      3. 小文字の英数字とハイフンのみを使用すること。
      {
        "code": "english-slug-here",
        "description": "...",
        "keyword": "..."
      }
    PROMPT

    res = call_gpt_api(prompt, json_mode: true)
    return nil if res.nil?
    JSON.parse(res.dig("choices", 0, "message", "content"))
  end

  def self.generate_structure(column, category)
    child_columns = Column.where(parent_id: column.id, article_type: "child")
    child_titles = child_columns.map(&:title).join("\n- ")
    
    prompt = <<~PROMPT
      記事「#{column.title}」の体系的な記事構成（H2見出し6〜8個）を「JSON」形式で作成してください。
      業種: #{category}
      子記事リスト: #{child_titles}
      出力フォーマット: { "structure": [ { "h2_title": "見出し名" } ] }
    PROMPT

    res = call_gpt_api(prompt, json_mode: true)
    return nil if res.nil?
    JSON.parse(res.dig("choices", 0, "message", "content"))
  end

  def self.call_section(prompt)
    response = call_gpt_api(prompt)
    response&.dig("choices", 0, "message", "content") || "（コンテンツ生成エラー）"
  end

  def self.call_gpt_api(prompt, json_mode: false)
    uri = URI(GPT_API_URL)
    req = Net::HTTP::Post.new(uri)
    req["Content-Type"] = "application/json"
    req["Authorization"] = "Bearer #{ENV['GPT_API_KEY']}" # ENVから直接取得

    payload = {
      model: MODEL_NAME,
      messages: [
        { role: "system", content: "あなたは特定の業界知識に深いSEO専門ライターです。指示されたフォーマット（JSONの場合はJSON）で回答してください。" },
        { role: "user", content: prompt }
      ],
      temperature: 0.3
    }
    payload[:response_format] = { type: "json_object" } if json_mode
    req.body = payload.to_json

    begin
      res = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true, read_timeout: 180) { |http| http.request(req) }
      if res.is_a?(Net::HTTPSuccess)
        JSON.parse(res.body)
      else
        Rails.logger.error "❌ OpenAI API Error: #{res.code} - #{res.body}"
        nil
      end
    rescue => e
      Rails.logger.error "❌ GPT API Connection Error: #{e.message}"
      nil
    end
  end

  def self.introduction_prompt(column, category)
    "記事「#{column.title}」の導入文を執筆してください。ターゲット業種: #{category}。読者の悩みへの共感から始め、600文字以上で執筆してください。"
  end

  def self.h2_content_prompt(column, category, section)
    "見出し「#{section["h2_title"]}」に関する本文を執筆してください。全体タイトル: #{column.title}、業種: #{category}。文字数1000文字程度で、## 記号は含めないでください。"
  end

  def self.conclusion_prompt(column, category)
    "記事「#{column.title}」のまとめを執筆してください。必ず「## まとめ」から開始し、業種「#{category}」の内容を要約してください。"
  end
end