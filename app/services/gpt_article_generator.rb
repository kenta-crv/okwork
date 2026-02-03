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
    category = detect_category(column.keyword)
    # 追加プロンプト（user_instruction）を取得
    user_instruction = column.respond_to?(:prompt) ? column.prompt : nil

    Rails.logger.info("判定カテゴリ: #{category}")

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
          sleep(0.5) 
        end
      else
        prompt = section_content_prompt(column, h2["h2_title"], "H2", category, user_instruction)
        full_article += generate_section_content(h2["h2_title"], prompt, column, heading_level: "") + "\n\n"
      end

      sleep(0.5) 
    end

    # まとめセクションの生成
    full_article += generate_section_content(
      "まとめ",
      simple_conclusion_prompt(column, category, user_instruction),
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
    when "自販機"
      <<~TEXT
        サービス名: 自動販売機の設置なら『自販機ねっと』
        強み: メーカー自動販売機の一括見積サイト及び自動販売機が設置できない企業・個人向けに誰でも設置できる自動販売機の提供
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
  # プロンプト群（重複・空見出し対策版）
  # ==============================
  def self.structure_generation_prompt(column, category, user_instruction)
    service = service_profile(category)
    instruction = user_instruction.present? ? "### 個別指示（最優先事項）\n#{user_instruction}\n" : ""
    <<~PROMPT
      あなたはプロのWebライターです。読者の疑問を解消する論理的な構成を作成してください。

      # 記事情報
      - タイトル: #{column.title}
      - 概要: #{column.description}
      - 業種カテゴリ: #{category}
      - サービス背景: #{service}

      #{instruction}

      # 構成指示（厳守）
      - 各H2・H3の見出しで扱う内容が**絶対に重複しない**ように分けてください。
      - 例：H2(1)で費用相場、H2(2)で負担者の条件、H2(3)でトラブル対策、など役割を分担。
      - 本文を300文字以上書ける、具体的で深掘り可能な見出しにしてください。
      - 見出しだけの空セクションを作らないよう、各項目の粒度を揃えてください。

      # 出力形式（JSONのみ）
      { "structure": [ { "h2_title": "...", "h3_sub_sections": ["...", "..."] } ] }
    PROMPT
  end

  def self.introduction_prompt(column, category, user_instruction)
    service = service_profile(category)
    instruction = user_instruction.present? ? "### 個別指示（反映必須）\n#{user_instruction}\n" : ""
    <<~PROMPT
      タイトル「#{column.title}」の記事の導入文（リード文）を書いてください。

      - 役割：読者の悩みへ共感し、この記事を読めば解決できることを伝えます。
      - 注意：具体的な「400〜600本」の基準や解決策の詳細は、後の見出しで詳しく書くため、ここでは**結論の概要のみ**に留めてください。
      #{instruction}
      - 文字数：**必ず#{TARGET_CHARS_PER_SECTION}〜#{MAX_CHARS_PER_SECTION}文字で書いてください。**
      - 見出しは出力しないでください。本文のみを出力してください。
    PROMPT
  end

  def self.section_content_prompt(column, headline, level, category, user_instruction, parent_h2: nil)
    parent = parent_h2 ? "（親テーマ: #{parent_h2}）" : ""
    service = service_profile(category)
    instruction = user_instruction.present? ? "### 個別指示（反映必須）\n#{user_instruction}\n" : ""
    heading_instruction = level == "H3" ? "### #{headline} から書き始めてください。" : "本文のみを書いてください。"

    <<~PROMPT
      以下のセクションの本文を執筆してください。見出しだけ出力して本文を書かないことは**絶対に禁止**です。

      - 執筆対象の見出し: #{headline} #{parent}
      - 記事タイトル: #{column.title}
      - 専門背景: #{service}

      #{instruction}

      # 執筆ルール（大問題解決のため厳守）
      1. **重複の徹底回避**: 他の見出しで説明済みの内容（例：400本基準の繰り返し等）は避け、この見出し独自の専門的な詳細を深掘りしてください。
      2. **文字数ノルマ**: **必ず#{TARGET_CHARS_PER_SECTION}文字以上、#{MAX_CHARS_PER_SECTION}文字以内で執筆してください。**
      3. **具体性の確保**: 抽象的な表現で濁さず、実務上の注意点、法的根拠、具体的な手順、または独自のノウハウを必ず含めてください。
      4. スタイル: です・ます調、箇条書き、太字（**）を使い、読みやすくしてください。

      #{heading_instruction}
    PROMPT
  end

  def self.simple_conclusion_prompt(column, category, user_instruction)
    service = service_profile(category)
    instruction = user_instruction.present? ? "### 個別指示（反映必須）\n#{user_instruction}\n" : ""
    <<~PROMPT
      記事全体の「まとめ」を執筆してください。

      - 「## まとめ」という見出しから開始してください。
      - 記事で伝えた重要なポイントを要約し、読者が次に取るべきアクション（相見積もり等）を促してください。
      #{instruction}
      - 専門背景: #{service}
      - 文字数：**必ず#{TARGET_CHARS_PER_SECTION}〜#{MAX_CHARS_PER_SECTION}文字を維持してください。**
    PROMPT
  end

  # ==============================
  # GPT呼び出し（システム指示を強化）
  # ==============================
  def self.generate_section_content(name, prompt, column, heading_level: "##")
    response = call_gpt_api(prompt)
    response&.dig("choices", 0, "message", "content") || "（#{name}の本文生成に失敗しました。再生成してください。）"
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
        { role: "system", content: "あなたはプロの業界特化ライターです。各セクションで必ず300文字以上の具体的かつ重複のない本文を執筆する義務があります。見出しだけを出力して本文を省略することは決して許されません。" },
        { role: "user", content: prompt }
      ],
      temperature: 0.4 # 少し下げて確実性を向上
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