class GeminiColumnGenerator
  require "net/http"
  require "json"
  require "openssl"

  GEMINI_API_KEY = ENV["GEMINI_API_KEY"]
  GEMINI_API_URL = "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent"
  MAX_RETRIES = 3

  GENRE_CONFIG = {
    cargo: {
      service_name:  "軽貨物配送サービス",
      service_brand: "OK配送",
      service_path:  "/cargo",
      target: "軽貨物事業者との取引や協業を検討している企業の担当者または経営層",
      categories: ["課題解決", "選定・比較", "業界理解", "活用イメージ", "不安解消"],
      exclude: "軽貨物事業者自身に向けた発信",
      hints: "配送ルート最適化, 誤配送対策, 貨物保険, 車両メンテナンス, 繁忙期対応, 納品書管理"
    },
    security: {
      service_name:  "警備業務",
      service_brand: "OK警備",
      service_path:  "/security",
      target: "警備業務の外注や切替を検討している企業・施設管理者",
      categories: ["課題解決", "選定・比較", "業界理解", "活用イメージ", "不安解消"],
      exclude: "警備員の発注を検討している企業に向けた発信",
      hints: "防犯カメラ連携, 巡回ルート設定, 緊急連絡体制, 入退館管理, 夜間警備リスク, 警備報告書"
    },
    cleaning: {
      service_name:  "清掃業務",
      service_brand: "OK清掃",
      service_path:  "/cleaning",
      target: "清掃業務の外注を検討している法人・施設管理者",
      categories: ["課題解決", "選定・比較", "業界理解", "活用イメージ", "不安解消"],
      exclude: "清掃の業務を外注しようとしている企業に向けた発信",
      hints: "床ワックス頻度, エアコン洗浄時期, 感染症対策清掃, 定期清掃コスト, 洗剤の安全性, トイレ衛生管理"
    },
    app: {
      service_name:  "営業代行",
      service_brand: "アポ匠",
      service_path:  "/app",
      target: "ターゲット選定・法人リスト制作・テレアポ代行・フォーム営業・商談代行・インサイドセールスと一括パッケージで新規商談獲得を外注したいBtoB企業の責任者",
      categories: ["課題解決", "選定・比較", "業界理解", "活用イメージ", "不安解消"],
      exclude: "営業一括アウトソーシング・営業代行・営業総合支援の訴求",
      hints: "リスト精度向上, スクリプトABテスト, 架電時間帯の分析, 失注理由の資産化, KPI設計, フォーム営業コツ"
    },
    ai: {
      service_name:  "AI活用型ブログ・SEO支援",
      service_brand: "AI生成BLOG",
      service_path:  "/ai",
      target: "SEO集客を効率化・内製化したい企業",
      categories: ["課題解決", "導入検討", "業界理解", "活用イメージ", "不安解消"],
      exclude: "個人ブロガー向けの発信",
      hints: "生成AIプロンプト, 記事のリライト手法, カニバリズム対策, E-E-A-T強化, キーワード選定, AI校正"
    },
    vender: {
      service_name:  "メーカー自動販売機の設置サービス",
      service_brand: "自販機ねっと",
      service_path:  "/vender",
      target: "メーカー自動販売機を設置・運営する立場の企業担当者",
      categories: ["自動販売機", "自販機", "設置", "運営", "契約"],
      exclude: "メーカー設置が前提で、仕組みや責任範囲を理解しようとしない浅い内容",
      hints: "契約形態, 電気代負担, 商品補充の仕組み, 管理責任の分界点, 社内説明, 撤去・入替の考え方"
    },
    construction: {
      service_name:  "建設現場労務支援サービス",
      service_brand: "OK建設",
      service_path:  "/construction",
      target: "建設現場の人手不足に悩む元請・施工会社",
      categories: ["課題解決", "選定・比較", "業界理解", "活用イメージ", "不安解消"],
      exclude: "作業員の求人を目的とした発信",
      hints: "労務安全書類, 出欠管理デジタル化, 現場待機時間, 多能工育成, 外国人労働者対応, 工期遅延対策"
    }
  }.freeze

  def self.generate_columns(genre: nil, batch_count: 10, pillar_id: nil)
    success_count = 0
    target_pillar = pillar_id ? Column.find_by(id: pillar_id) : nil
    
    genre_list = if target_pillar
                   [target_pillar.genre.to_sym]
                 elsif genre
                   [genre.to_sym]
                 else
                   GENRE_CONFIG.keys.shuffle
                 end

    processed = 0
    while processed < batch_count
      genre_list.each do |g|
        break if processed >= batch_count
        target_category = GENRE_CONFIG[g][:categories].sample
        success_count += 1 if execute_generation(g, target_category, pillar_id: target_pillar&.id)
        processed += 1
        sleep 2
      end
      genre_list.shuffle! unless target_pillar
    end

    puts "\n✅ 完了: #{success_count} / #{batch_count} 件の子記事を保存しました。"
    success_count
  end

  def self.execute_generation(original_genre, target_category, pillar_id: nil)
    pillar = pillar_id ? Column.find_by(id: pillar_id) : PillarSelector.select_available_pillar(original_genre)
    
    if pillar.nil?
      puts "❌ 親記事(ID: #{pillar_id})が見つかりません"
      return false
    end

    actual_genre = pillar.genre.to_sym
    config = GENRE_CONFIG[actual_genre]

    # 【改善点】既存の子記事タイトルを取得して、AIに「これ以外を作れ」と命じる
    existing_titles = Column.where(parent_id: pillar.id).pluck(:title).join("\n- ")

    prompt = <<~PROMPT
      以下の親記事に紐づく、独自視点の「子記事」のメタ情報を1つ作成してください。
      出力は必ず「1つのJSONオブジェクト」とし、余計な文章や配列は含めないでください。

      【重要：重複回避】
      以下のタイトルは既に存在します。これらと内容やキーワードが重複しないように、全く別の切り口で作成してください。
      既存記事リスト:
      - #{existing_titles.presence || "なし"}

      【親記事情報】
      タイトル: #{pillar.title}
      概要: #{pillar.description}

      【記事設定】
      サービス名: #{config[:service_name]} (#{config[:service_brand]})
      ターゲット: #{config[:target]}
      カテゴリー: #{target_category}
      除外事項: #{config[:exclude]}
      
      【執筆のヒント（これらに関連させて具体化してください）】
      #{config[:hints]}

      【指示】
      - 「従業員満足度」や「最適な選び方」のような抽象的で量産型のタイトルは禁止です。
      - 「冬から春への商品入替タイミング」や「ゴミ箱の悪臭対策」のように、現場の実務・運用に即した具体的な課題解決をテーマにしてください。
      - 親記事が「運用・管理マニュアル」であることを踏まえ、読者が次に知るべき実務的な1点に絞ってください。

      【出力JSON形式】
      {
        "title": "具体例や数値を含み、既存と被らない専門的なタイトル",
        "code": "3〜4単語の短いURLスラッグ（例: trash-can-maintenance）",
        "description": "120文字程度の要約。具体的なメリットを記述",
        "keyword": "キーワード1, キーワード2"
      }
    PROMPT

    retries = 0
    loop do
      response_text = post_to_gemini(prompt)
      return false if response_text.nil?

      json_match = response_text.match(/(\{.*\}|\[.*\])/m)
      json_text = json_match ? json_match[0] : nil

      if json_text.nil?
        retries += 1
        break if retries >= MAX_RETRIES
        next
      end

      begin
        parsed_data = JSON.parse(json_text)
        data = parsed_data.is_a?(Array) ? parsed_data.first : parsed_data

        required_keys = %w[title code description keyword]
        missing = required_keys.select { |k| data[k].to_s.strip.empty? }

        if missing.empty?
          safe_code = data["code"].to_s.downcase.strip.gsub(/[^a-z0-9\-_]+/, '-')[0..50]

          Column.create!(
            title:       data["title"],
            code:        safe_code,
            description: data["description"],
            keyword:     data["keyword"],
            choice:      target_category,
            genre:       actual_genre.to_s,
            status:      "draft",
            article_type: "child",
            parent_id:   pillar.id
          )
          puts "✅ 保存成功: #{data["title"]} (code: #{safe_code})"
          return true
        end
      rescue JSON::ParserError => e
        puts "❌ パースエラー: #{e.message}"
      end

      retries += 1
      break if retries >= MAX_RETRIES
    end
    false
  end

  def self.post_to_gemini(prompt)
    uri = URI(GEMINI_API_URL)
    uri.query = URI.encode_www_form(key: GEMINI_API_KEY)
    req = Net::HTTP::Post.new(uri, "Content-Type" => "application/json")
    req.body = {
      contents: [{ parts: [{ text: prompt }] }],
      generationConfig: { response_mime_type: "application/json" }
    }.to_json

    res = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) { |http| http.request(req) }
    return nil unless res.is_a?(Net::HTTPSuccess)
    
    body = JSON.parse(res.body)
    body.dig("candidates", 0, "content", "parts", 0, "text")
  end
end