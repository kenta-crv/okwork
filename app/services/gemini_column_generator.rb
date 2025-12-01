# app/services/gemini_column_generator.rb
class GeminiColumnGenerator
  require "net/http"
  # ... (require, 定数定義は省略) ...

  GEMINI_API_KEY = ENV["GEMINI_API_KEY"]
  GEMINI_API_URL = "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent"

  def self.generate_columns(batch_count: 100)
    # カテゴリは「取引検討者（荷主など）」の関心事に合わせたものに変更
    category_list = ["軽貨物パートナー選定", "物流DX・技術連携", "発注リスクと法令遵守", "市場トレンドと展望", "コスト最適化・事例"]

    batch_count.times do
      # 🚨 プロンプトを根本的に修正：ターゲットを「取引したい企業」に限定
      prompt = <<~EOS
        軽貨物配送サービスに関するブログ記事のテーマ、記事概要、SEOキーワード、およびカテゴリを日本語で生成してください。
        
        ターゲット読者は**軽貨物事業者との取引や協業を検討している企業の担当者または経営層（荷主企業やITベンダーなど）**です。
        テーマは、彼らが発注や提携の意思決定に役立つ、軽貨物事業者の選定基準、メリット、市場動向、リスク管理に関する内容とし、常に多様性を保ってください。
        
        求職者および軽貨物事業者自身に向けた発信ではありません。
        カテゴリは以下のリストから必ず1つ選択してください: #{category_list.join(", ")}
      EOS
      
      response_json_string = post_to_gemini(prompt, category_list)
      next unless response_json_string

      begin
        data = JSON.parse(response_json_string)

        Column.create!(
          title:       data["title"],
          description: data["description"],
          keyword:     data["keyword"],
          choice:      data["category"], # スキーマ名を category に変更したため、ここも変更
          status:      "draft"
        )

      rescue JSON::ParserError => e
        Rails.logger.error("JSONパースエラー: #{e.message} - Response: #{response_json_string}")
        next
      rescue => e
        Rails.logger.error("データベース保存エラー: #{e.message}")
        next
      end
    end
  end


  # post_to_gemini メソッドは、category_listを引数に受け取り、スキーマのenumに設定する点で、前回の修正版（2.post_to_gemini(prompt, category_list)の箇所）をそのまま利用します。
  def self.post_to_gemini(prompt, category_list = nil)
    uri = URI(GEMINI_API_URL)
    uri.query = URI.encode_www_form(key: GEMINI_API_KEY)

    req = Net::HTTP::Post.new(uri, "Content-Type" => "application/json")

    category_schema = { "type": "string" }
    category_schema["enum"] = category_list if category_list.present?

    req.body = {
      contents: [ { parts: [ { text: prompt } ] } ],
      generationConfig: {
        "responseMimeType": "application/json",
        "responseSchema": {
          "type": "object",
          "properties": {
            "title":       { "type": "string" },
            "description": { "type": "string" },
            "keyword":     { "type": "string" },
            "category":    category_schema 
          },
          "required": ["title", "description", "keyword", "category"]
        }
      }
    }.to_json

    res = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true, verify_mode: OpenSSL::SSL::VERIFY_NONE) do |http|
      http.request(req)
    end

    if res.is_a?(Net::HTTPSuccess)
      api_response = JSON.parse(res.body)
      api_response.dig("candidates", 0, "content", "parts", 0, "text")
    else
      Rails.logger.error("Gemini API error (Status: #{res.code}): #{res.body}")
      nil
    end
  end
end