require "net/http"
require "json"
require "openssl"

class GptPillarGenerator
  MODEL_NAME = "gpt-4o-mini"
  GPT_API_URL = "https://api.openai.com/v1/chat/completions"

  # アポ匠の7つの工程
  APO_TAKUMI_FLOW = [
    "ターゲット選定",
    "AIを活用したリスト自動抽出",
    "問い合わせフォームの自動送信システム",
    "テレアポ代行",
    "商談代行",
    "顧客の追連絡",
    "契約締結"
  ].freeze

  def self.generate_full_from_existing_column!(column)
    raise "タイトルが空です" if column.title.blank?
    
    meta_data = generate_meta_info(column)
    raise "Meta情報の生成に失敗しました" if meta_data.nil?
    
    clean_code = meta_data["code"].to_s.downcase.gsub(/[^a-z0-9\-]/, '').strip
    clean_code = "article-#{column.id.to_s.split('-').first}" if clean_code.blank?

    structure_data = generate_structure(column)
    raise "記事構成の生成に失敗しました" if structure_data.nil? || structure_data["structure"].nil?

    column.update!(
      code: clean_code,
      description: meta_data["description"],
      keyword: meta_data["keyword"],
      choice: "営業代行",
      genre: "app",
      status: "creating",
      article_type: "pillar"
    )

    body_content = ""
    
    # 導入文
    body_content += call_text_section(introduction_prompt(column)) + "\n\n"

    # 各見出し
    structure_data["structure"].each do |section|
      # Ruby側でH2を挿入
      body_content += "## #{section["h2_title"]}\n\n"
      
      # GPTからの回答（見出しを重複させない処理済み）を追加
      body_content += call_text_section(h2_content_prompt(column, section)) + "\n\n"
      sleep(1.5)
    end

    # まとめ
    body_content += call_text_section(conclusion_prompt(column))
    body_content += "\n\n{::options auto_ids=\"false\" /}"

    column.update!(body: body_content, status: "completed")
    true
  end

  private

  # テキストセクションの取得と重複除去
  def self.call_text_section(prompt)
    response = call_gpt_api(prompt, json_mode: false)
    content = response&.dig("choices", 0, "message", "content")
    return "（生成エラー）" if content.blank?
    
    # 冒頭に「# 見出し」が紛れ込んだ場合に、その1行をまるごと削除する（重複防止）
    content.gsub!(/\A#+ .*\n?/, '')
    content.strip
  end

  def self.call_gpt_api(prompt, json_mode: false)
    uri = URI(GPT_API_URL)
    req = Net::HTTP::Post.new(uri)
    req["Content-Type"] = "application/json"
    req["Authorization"] = "Bearer #{ENV['GPT_API_KEY']}"

    system_content = "あなたは営業代行『アポ匠』の専任ライターです。回答は必ず日本語で行ってください。"
    system_content += " 出力はJSON形式で行ってください。" if json_mode
    # 強力に見出し出力を禁止
    system_content += " 本文のみを出力してください。見出し（# や ##）は絶対に出力に含めないでください。" unless json_mode

    payload = {
      model: MODEL_NAME,
      messages: [
        { role: "system", content: system_content },
        { role: "user", content: prompt }
      ],
      temperature: 0.4
    }
    payload[:response_format] = { type: "json_object" } if json_mode
    req.body = payload.to_json

    begin
      res = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true, read_timeout: 240) { |http| http.request(req) }
      res.is_a?(Net::HTTPSuccess) ? JSON.parse(res.body) : nil
    rescue => e
      nil
    end
  end

  # --- 各プロンプトの見出し出力を厳禁に設定 ---

  def self.generate_meta_info(column)
    prompt = "「アポ匠」のSEOメタ情報をJSONで生成。タイトル: #{column.title}。形式: { 'code': 'slug', 'description': '...', 'keyword': '...' }"
    res = call_gpt_api(prompt, json_mode: true)
    res ? JSON.parse(res.dig("choices", 0, "message", "content")) : nil
  end

  def self.generate_structure(column)
    prompt = <<~PROMPT
      記事「#{column.title}」のH2見出し6〜8個をJSONで作成。
      「アポ匠」の7工程（#{APO_TAKUMI_FLOW.join('、')}）を網羅したピラー構成にしてください。
      形式: { "structure": [ { "h2_title": "見出し名" } ] }
    PROMPT
    res = call_gpt_api(prompt, json_mode: true)
    res ? JSON.parse(res.dig("choices", 0, "message", "content")) : nil
  end

  def self.introduction_prompt(column)
    "記事「#{column.title}」の導入文（600文字以上）。見出しは含めず、本文のみ出力してください。"
  end

  def self.h2_content_prompt(column, section)
    "見出し「#{section["h2_title"]}」の本文（1000文字程度）。アポ匠の工程を具体的に解説。見出しそのものは出力に含めないでください。"
  end

  def self.conclusion_prompt(column)
    "記事「#{column.title}」のまとめ。「## まとめ」という文字列だけは冒頭に含めてください。それ以外の見出しは不要です。"
  end
end