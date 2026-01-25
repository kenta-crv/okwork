class GenerateColumnBodyJob < ApplicationJob
  queue_as :article_generation

  # OpenAIのレスポンス待ちで失敗した場合のリトライ設定
  retry_on Net::ReadTimeout, wait: :exponentially_longer, attempts: 3

  def perform(column_id)
    column = Column.find_by(id: column_id)
    return unless column
    
    # 二重実行防止
    return if column.status == "completed" && column.body.present?

    # ジョブが開始されたことをDBに刻む（生存確認用）
    column.update_columns(status: "creating")

    begin
      if column.article_type == "pillar"
        GptPillarGenerator.generate_full_from_existing_column!(column)
      else
        body = GptArticleGenerator.generate_body(column)
        
        if body.present? && !body.include?("生成失敗")
          column.update!(body: body, status: "completed")
        else
          raise "本文の生成に失敗しました（空またはエラー）"
        end
      end
    rescue => e
      # 詳細なエラーをログに残す
      Rails.logger.error "❌ [ID:#{column_id}] 生成失敗: #{e.message}"
      column.update(status: "error")
      raise e 
    end
  end
end