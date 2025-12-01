# app/services/gemini_column_generator.rb
class GeminiColumnGenerator
  require "net/http"
  require "json"
  require "openssl"

  GEMINI_API_KEY = ENV["GEMINI_API_KEY"]
  GEMINI_API_URL = "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent"

  def self.generate_columns(batch_count: 100)
    # カテゴリの制限リストを設定
    category_list = ["物流トレンド", "コスト削減・効率化", "法令・安全対策", "顧客獲得・サービス向上", "新規事業・技術導入"]

    batch_count.times do
      # 軽貨物事業者の経営層・担当者が新規取引を検討したくなるようなテーマを要求
      # カテゴリの選択肢もプロンプトに含めて、AIの回答を誘導
      prompt = <<~EOS
        軽貨物配送サービスに関するブログ記事のテーマ、記事概要、SEOキーワード、およびカテゴリを日本語で生成してください。
        ターゲット読者は軽貨物事業者の経営層・担当者で、彼らが新規の取引や業務提携を検討したくなるような、事業の課題解決や収益向上につながる汎用性のあるテーマを抽出してください。
        テーマは常に多様性を保ってください。求職者に向けた発信ではありません。

        カテゴリは以下のリストから必ず1つ選択してください: #{category_list.join(", ")}
      EOS
      
      response_json_string = post_to_gemini(prompt, category_list) # category_listを引数に追加
      next unless response_json_string

      begin
        data = JSON.parse(response_json_string)
        
        # モデルに合わせて choice の代わりに category に変更することを推奨します。
        # 現在のDBカラム名に合わせて choice のままにしますが、内容的には「category」です。
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


  # category_listを引数に追加し、スキーマに enum として制約を追加
  def self.post_to_gemini(prompt, category_list = nil)
    uri = URI(GEMINI_API_URL)
    uri.query = URI.encode_www_form(key: GEMINI_API_KEY)

    req = Net::HTTP::Post.new(uri, "Content-Type" => "application/json")

    # responseSchemaの choice の名前を category に変更し、enum で選択肢を制限
    category_schema = { "type": "string" }
    category_schema["enum"] = category_list if category_list.present? # enum制約を追加

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
            "category":    category_schema # choice から category に変更
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