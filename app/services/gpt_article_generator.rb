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
    "自販機"   => ["自販機"],
    "建設"     => ["建設", "現場"]
  }

  def self.generate_body(column)
    unless GPT_API_KEY.present?
      Rails.logger.error("OPENAI_API_KEY が設定されていません")
      return nil
    end

    original_body = column.body
    category = detect_category(column.keyword.presence || column.title)
    # 追加：フォームからの個別指示を取得
    user_instruction = column.respond_to?(:prompt) ? column.prompt : nil

    Rails.logger.info("判定カテゴリ: #{category}")

    # ==============================
    # 1. Meta情報生成（Pillarと同様のフローを追加）
    # ==============================
    meta_data = generate_meta_info(column, category, user_instruction)
    if meta_data
      clean_code = meta_data["code"].to_s.downcase.gsub(/[^a-z0-9\s\-]/, '').strip.gsub(/[\s_]+/, '-').gsub(/-+/, '-').gsub(/\A-|-\z/, '')
      clean_code = "article-#{column.id}" if clean_code.blank?

      # 本文生成前に、Meta情報を先に更新・保存する
      column.update!(
        code: clean_code,
        description: meta_data["description"],
        keyword: meta_data["keyword"],
        status: "creating"
      )
    end

    # ==============================
    # STEP 1: 構成生成
    # ==============================
    structure_prompt = structure_generation_prompt(column, category, user_instruction)
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
      introduction_prompt(column, category, user_instruction),
      column,
      heading_level: ""
    ) + "\n\n"

    structure.each do |h2|
      full_article += "## #{h2['h2_title']}\n\n"

      if h2["h3_sub_sections"].present?
        h2["h3_sub_sections"].each do |h3|
          prompt = section_content_prompt(column, h3, "H3", category, user_instruction, parent_h2: h2["h2_title"])
          full_article += generate_section_content(h3, prompt, column, heading_level: "###") + "\n\n"
          sleep(0.5) # レート制限対策
        end
      else
        prompt = section_content_prompt(column, h2["h2_title"], "H2", category, user_instruction)
        full_article += generate_section_content(h2["h2_title"], prompt, column, heading_level: "") + "\n\n"
      end

      sleep(0.5) # レート制限対策
    end

    # まとめセクションの生成
    full_article += generate_section_content(
      "まとめ",
      simple_conclusion_prompt(column, category, user_instruction),
      column,
      heading_level: ""
    )

    # 最終保存
    column.update!(body: full_article, status: "completed")
    full_article
  end

  # ==============================
  # Meta情報生成（Pillarのロジックを移植）
  # ==============================
  def self.generate_meta_info(column, category, user_instruction)
    prompt = <<~PROMPT
      以下の条件でSEOメタ情報をJSONで生成してください。
      タイトル: #{column.title}
      業種: #{category}
      個別指示: #{user_instruction}
      形式: { "code": "英字スラッグ", "description": "120文字程度の日本語説明文", "keyword": "カンマ区切りのキーワード" }
    PROMPT
    res = call_gpt_api(prompt, response_format: { type: "json_object" })
    return nil if res.nil?
    begin
      content = res.dig("choices", 0, "message", "content").gsub(/```json|```/, '').strip
      JSON.parse(content)
    rescue
      nil
    end
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
        サービス名: 第一号警備業務（施設警備）
        強み: 常駐警備、出入管理、巡回警備、防災センター業務。有資格者による確実な監視と防犯体制の構築。
      TEXT
    when "建設"
      <<~TEXT
        サービス名: 建設現場支援
        強み: 現場の人手不足解消、熟練工から手元作業員まで幅広くマッチング。
      TEXT
    when "自販機"
      <<~TEXT
        サービス名: 自動販売機の設置なら『自販機ねっと』
        強み: メーカー自販機一括見積及び自動販売機が設置できない企業・個人向けに誰でも設置できる自動販売機の提供
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
  # プロンプト群（空見出し・重複・文字数不足を厳格に封殺）
  # ==============================
  def self.structure_generation_prompt(column, category, user_instruction)
    service = service_profile(category)
    instruction = user_instruction.present? ? "### 個別指示（最優先事項）\n#{user_instruction}\n" : ""
    <<~PROMPT
      あなたはプロの業界特化ライターです。読者の疑問を段階的に解消する論理的な構成をJSONで作成してください。

      # 記事情報
      - タイトル: #{column.title}
      - 業種カテゴリ: #{category}
      - サービス背景: #{service}
      #{instruction}

      # 構成指示（厳守）
      - 各セクションの内容が絶対に重複しないよう役割を分担してください。
      - 300文字以上の「本文」を執筆できる深掘り可能な見出しを設定してください。
      - 本文を書く内容がないような薄い見出しは作成しないでください。

      # 出力形式
      { "structure": [ { "h2_title": "...", "h3_sub_sections": ["..."] } ] }
    PROMPT
  end

  def self.introduction_prompt(column, category, user_instruction)
    service = service_profile(category)
    instruction = user_instruction.present? ? "### 個別指示（反映必須）\n#{user_instruction}\n" : ""
    <<~PROMPT
      タイトル「#{column.title}」の導入文を書いてください。
      - 役割：読者の悩み（費用負担等）への共感と、記事を読むメリット。
      - 注意：具体的な結論（400本基準等）は後の見出しで詳述するため、ここでは書かず重複を避けてください。
      #{instruction}
      - 文字数：必ず#{TARGET_CHARS_PER_SECTION}文字以上を維持してください。
      - 見出しは含めず本文のみ出力してください。
    PROMPT
  end

  def self.section_content_prompt(column, headline, level, category, user_instruction, parent_h2: nil)
    parent = parent_h2 ? "（親テーマ: #{parent_h2}）" : ""
    service = service_profile(category)
    instruction = user_instruction.present? ? "### 個別指示（最優先事項）\n#{user_instruction}\n" : ""
    heading_instr = level == "H3" ? "### #{headline} から書き始めてください。" : "本文のみ書いてください。"

    <<~PROMPT
      以下のセクションを執筆してください。見出しだけ出力して本文を省略することは「絶対に禁止」です。

      - 見出し: #{headline} #{parent}
      - タイトル: #{column.title}
      - 専門背景: #{service}
      #{instruction}

      # 執筆の絶対ルール
      1. **本文執筆の義務**: 必ず300文字〜500文字の本文を生成してください。
      2. **重複の徹底排除**: 他の見出しで書いた内容（例：400本基準の繰り返し）を避け、この見出し独自の専門知識を深掘りしてください。
      3. **具体性**: 読者が実行できる具体的なアクション、実務上の注意点、法的根拠、または独自のノウハウを必ず盛り込んでください。
      
      #{heading_instr}
    PROMPT
  end

  def self.simple_conclusion_prompt(column, category, user_instruction)
    service = service_profile(category)
    instruction = user_instruction.present? ? "### 個別指示（反映必須）\n#{user_instruction}\n" : ""
    <<~PROMPT
      記事の「まとめ」を執筆してください。
      - 「## まとめ」から開始。
      - 重複を避け、読者が次に取るべき具体的なアクションを力強く後押ししてください。
      #{instruction}
      - 文字数：必ず300〜500文字を維持してください。
    PROMPT
  end

  # ==============================
  # GPT呼び出し（システム指示で本文省略を封殺）
  # ==============================
  def self.generate_section_content(name, prompt, column, heading_level: "##")
    response = call_gpt_api(prompt)
    content = response&.dig("choices", 0, "message", "content")
    content.presence || "（#{name}の本文生成に失敗しました。再生成してください。）"
  end

  def self.call_gpt_api(prompt, response_format: nil)
    uri = URI(GPT_API_URL)
    req = Net::HTTP::Post.new(uri, { "Content-Type" => "application/json", "Authorization" => "Bearer #{GPT_API_KEY}" })

    payload = {
      model: MODEL_NAME,
      messages: [
        { role: "system", content: "あなたはプロの業界ライターです。見出しを出力した際は、必ずセットで300文字以上の具体的かつ重複のない本文を執筆します。本文の省略や見出しのみの出力は絶対にしません。" },
        { role: "user", content: prompt }
      ],
      temperature: 0.4
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