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
      exclude: "軽貨物事業者自身に向けた発信"
    },
    security: {
      service_name:  "警備業務",
      service_brand: "OK警備",
      service_path:  "/security",
      target: "警備業務の外注や切替を検討している企業・施設管理者",
      categories: ["課題解決", "選定・比較", "業界理解", "活用イメージ", "不安解消"],
      exclude: "警備員の発注を検討している企業に向けた発信"
    },
    cleaning: {
      service_name:  "清掃業務",
      service_brand: "OK清掃",
      service_path:  "/cleaning",
      target: "清掃業務の外注を検討している法人・施設管理者",
      categories: ["課題解決", "選定・比較", "業界理解", "活用イメージ", "不安解消"],
      exclude: "清掃の業務を外注しようとしている企業に向けた発信"
    },
    app: {
      service_name:  "テレアポ型営業代行",
      service_brand: "アポ匠",
      service_path:  "/app",
      target: "新規商談獲得を外注したいBtoB企業の責任者",
      categories: ["課題解決", "選定・比較", "業界理解", "活用イメージ", "不安解消"],
      exclude: "成果報酬型営業の訴求"
    },
    ai: {
      service_name:  "AI活用型ブログ・SEO支援",
      service_brand: "AI生成BLOG",
      service_path:  "/ai",
      target: "SEO集客を効率化・内製化したい企業",
      categories: ["課題解決", "導入検討", "業界理解", "活用イメージ", "不安解消"],
      exclude: "個人ブロガー向けの発信"
    },
    vender: {
      service_name:  "自動販売機の設置サービス",
      service_brand: "自販機ねっと",
      service_path:  "/vender",
      target: "自動販売機の設置を行いたい企業",
      categories: ["自動販売機", "自販機", "設置", "購入", "見積"],
      exclude: "自販機設置のニーズのある人向けの発信"
    },
    construction: {
      service_name:  "建設現場労務支援サービス",
      service_brand: "OK建設",
      service_path:  "/construction",
      target: "建設現場の人手不足に悩む元請・施工会社",
      categories: ["課題解決", "選定・比較", "業界理解", "活用イメージ", "不安解消"],
      exclude: "作業員の求人を目的とした発信"
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

    # プロンプトの改善：code（スラッグ）の長さを厳格に制限
    prompt = <<~PROMPT
      以下の親記事（ピラー記事）に紐づく、独自視点の「子記事」のメタ情報を1つ作成してください。
      出力は必ず「1つのJSONオブジェクト」とし、余計な文章や配列（[]）は含めないでください。

      【親記事情報】
      タイトル: #{pillar.title}
      概要: #{pillar.description}

      【記事設定】
      サービス名: #{config[:service_name]} (#{config[:service_brand]})
      ターゲット: #{config[:target]}
      カテゴリー: #{target_category}
      除外事項: #{config[:exclude]}

      【出力JSON形式】
      {
        "title": "親記事の内容と重複せず、読者の課題を解決するタイトル",
        "code": "3〜4単語の英単語をハイフンで繋いだ短いURLスラッグ（例: cost-reduction-tips）",
        "description": "120文字程度の要約",
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
          # プログラム側でもスラッグを短く制限（念のためのガード）
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