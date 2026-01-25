require "net/http"
require "json"
require "openssl"
require "openai"

class GptArticleGenerator
  TARGET_CHARS_PER_SECTION = 300
  MAX_CHARS_PER_SECTION = 500
  MODEL_NAME = "gpt-4o-mini"

  GPT_API_KEY = ENV["GPT_API_KEY"]
  GPT_API_URL = "https://api.openai.com/v1/chat/completions"

  # ==============================
  # 業種カテゴリ定義（部分一致）
  # ==============================
  CATEGORY_KEYWORDS = {
    "警備"     => ["警備"],
    "軽貨物"   => ["軽貨物", "配送"],
    "清掃"     => ["清掃"],
    "営業代行" => ["営業代行", "テレアポ"],
    "ブログ"   => ["ブログ"],
    "建設"     => ["建設", "現場"]
  }

  def self.generate_body(column)
    unless GPT_API_KEY.present?
      Rails.logger.error("OPENAI_API_KEY が設定されていません")
      return nil
    end

    original_body = column.body
    category = detect_category(column.keyword)

    Rails.logger.info("判定カテゴリ: #{category}")

    # ==============================
    # STEP 1: 構成生成
    # ==============================
    structure_prompt = structure_generation_prompt(column, category)
    structure_response = call_gpt_api(structure_prompt, response_format: { type: "json_object" })

    return original_body if structure_response.nil?

    begin
      json_str = structure_response.dig("choices", 0, "message", "content")
      structure_data = JSON.parse(json_str)
      structure = structure_data["structure"] || []

      return original_body if structure.length < 3
    rescue => e
      Rails.logger.error("構成生成エラー: #{e.message}")
      return original_body
    end

    # ==============================
    # STEP 2: 本文生成
    # ==============================
    full_article = ""

    full_article += generate_section_content(
      "導入",
      introduction_prompt(column, category),
      column,
      heading_level: ""
    ) + "\n\n"

    structure.each do |h2|
      full_article += "## #{h2['h2_title']}\n\n"

      if h2["h3_sub_sections"].present?
        h2["h3_sub_sections"].each do |h3|
          prompt = section_content_prompt(column, h3, "H3", category, parent_h2: h2["h2_title"])
          full_article += generate_section_content(h3, prompt, column, heading_level: "###") + "\n\n"
          sleep(0.5) # レート制限対策
        end
      else
        prompt = section_content_prompt(column, h2["h2_title"], "H2", category)
        full_article += generate_section_content(h2["h2_title"], prompt, column, heading_level: "") + "\n\n"
      end

      sleep(0.5) # レート制限対策
    end

    # まとめセクションの生成（全業種共通のプロンプトを使用）
    full_article += generate_section_content(
      "まとめ",
      simple_conclusion_prompt(column, category),
      column,
      heading_level: ""
    )

    full_article
  end

  # ==============================
  # カテゴリ判定
  # ==============================
  def self.detect_category(keyword)
    return "その他" if keyword.blank?

    CATEGORY_KEYWORDS.each do |category, words|
      return category if words.any? { |w| keyword.include?(w) }
    end

    "その他"
  end

  # ==============================
  # 業種別のサービス情報明確化
  # ==============================
  def self.service_profile(category)
    case category
    when "軽貨物"
      <<~TEXT
        サービス名: OK配送
        強み: 全国対応の軽貨物ネットワーク、企業・個人配送対応、ドライバーの迅速な確保。
      TEXT
    when "清掃"
      <<~TEXT
        サービス名: 専門清掃ソリューション
        強み: オフィス・店舗・常駐清掃に対応。徹底した品質管理と教育されたスタッフによる施工。
      TEXT
    when "警備"
      <<~TEXT
        サービス名: サービス区分: 第一号警備業務（施設警備）
        内容: 事務所、住宅、興行場、駐車場、遊園地等における盗難、火災等の事故発生の警戒・防止。
        強み: 常駐警備、出入管理、巡回警備、防災センター業務。有資格者による確実な監視と防犯体制の構築。
      TEXT
    when "建設"
      <<~TEXT
        サービス名: 建設現場支援
        強み: 現場の人手不足解消、熟練工から手元作業員まで幅広くマッチング。
      TEXT
    when "営業代行"
      <<~TEXT
        サービス名: セールスパートナー
        強み: ターゲット選定からテレアポ、商談設定まで一気通貫。高い成約率を誇るノウハウ。
      TEXT
    else
      "各業界の専門知識に基づいた最適なソリューションを提供。"
    end
  end

  # ==============================
  # プロンプト群
  # ==============================
  def self.structure_generation_prompt(column, category)
    service = service_profile(category)
    <<~PROMPT
      あなたはプロのWebライターです。

      # 記事情報
      - タイトル: #{column.title}
      - 概要: #{column.description}
      - キーワード: #{column.keyword}
      - 業種カテゴリ: #{category}
      - サービス背景: #{service}

      # 指示
      - H2は最大4つ
      - H3は各H2につき最大3つ
      - 導入・まとめは含めない
      - 論理的で一貫した構成にする

      # 出力形式（JSONのみ）
      {
        "structure": [
          {
            "h2_title": "H2見出し",
            "h3_sub_sections": ["H3見出し"]
          }
        ]
      }
    PROMPT
  end

  def self.introduction_prompt(column, category)
    service = service_profile(category)
    <<~PROMPT
      タイトル「#{column.title}」の記事の導入文を書いてください。

      - 対象業種: #{category}
      - コンセプト: #{service} に基づいた専門家としての視点
      - 文字数: #{TARGET_CHARS_PER_SECTION}文字程度（最大#{MAX_CHARS_PER_SECTION}文字）
      - 見出しは含めない
      - 段落・太字・箇条書きを活用
    PROMPT
  end

  def self.section_content_prompt(column, headline, level, category, parent_h2: nil)
    parent = parent_h2 ? "（親H2: #{parent_h2}）" : ""
    service = service_profile(category)
    heading_instruction = level == "H3" ? "### #{headline} から書き始めてください。" : "本文のみを書いてください。"

    <<~PROMPT
      以下のセクション本文を書いてください。

      - 業種カテゴリ: #{category}
      - 専門背景: #{service}
      - タイトル: #{column.title}
      - 見出し: #{headline} #{parent}

      # 制約
      - 文字数: #{TARGET_CHARS_PER_SECTION}文字程度（最大#{MAX_CHARS_PER_SECTION}文字）
      - 特定の社名を出した過度な宣伝・CTAは禁止（あくまで専門知識の提供に徹する）
      - 段落・太字・箇条書きを使用
      - H4（####）使用可
      - です・ます調

      #{heading_instruction}
    PROMPT
  end

  def self.simple_conclusion_prompt(column, category)
    service = service_profile(category)
    <<~PROMPT
      記事のまとめを書いてください。

      - 文字数: #{TARGET_CHARS_PER_SECTION}文字程度（最大#{MAX_CHARS_PER_SECTION}文字）
      - 「## まとめ」から開始
      - 記事内容を簡潔に要約
      - 背景知識として「#{service}」の視点を踏まえるが、直接的な営業文や「お問い合わせはこちら」といったCTAは含めない。
      - 読者に寄り添った締めくくりにしてください。
    PROMPT
  end

  # ==============================
  # GPT呼び出し
  # ==============================
  def self.generate_section_content(name, prompt, column, heading_level: "##")
    response = call_gpt_api(prompt)
    response&.dig("choices", 0, "message", "content") || "（#{name}生成失敗）"
  end

  def self.call_gpt_api(prompt, response_format: nil)
    uri = URI(GPT_API_URL)
    req = Net::HTTP::Post.new(uri, {
      "Content-Type" => "application/json",
      "Authorization" => "Bearer #{GPT_API_KEY}"
    })

    payload = {
      model: MODEL_NAME,
      messages: [
        { role: "system", content: "あなたはプロの業界特化ライターです。 #{MODEL_NAME} として、専門的かつ客観的な情報提供を行います。" },
        { role: "user", content: prompt }
      ],
      temperature: 0.5
    }

    payload[:response_format] = response_format if response_format.present?
    req.body = payload.to_json

    begin
      res = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true, read_timeout: 240) do |http|
        http.request(req)
      end

      res.is_a?(Net::HTTPSuccess) ? JSON.parse(res.body) : nil
    rescue => e
      Rails.logger.error("GPT API通信エラー: #{e.message}")
      nil
    end
  end
end