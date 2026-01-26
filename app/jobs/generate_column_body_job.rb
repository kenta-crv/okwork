class GenerateColumnBodyJob < ApplicationJob
  queue_as :article_generation

  # OpenAI APIのタイムアウトやネットワークエラー時に3回まで自動リトライ
  retry_on Net::ReadTimeout, wait: :exponentially_longer, attempts: 3

  def perform(column_id)
    Rails.logger.error("=== BODY JOB START: column_id=#{column_id} ===")
    column = Column.find_by(id: column_id)
    return unless column
    
    # 二重実行防止
    return if column.status == "completed" && column.body.present?

    # 【証拠1】ジョブが開始されたことを即座に保存
    column.update_columns(status: "creating", body: "--- Job開始時刻: #{Time.current} ---")

    begin
      if column.article_type == "pillar"
        # 親記事(Pillar)の場合
        GptPillarGenerator.generate_full_from_existing_column!(column)
      else
        # 子記事(Child)の場合
        body = GptArticleGenerator.generate_body(column)
        
        if body.present? && !body.include?("生成失敗")
          column.update!(body: body, status: "completed")
        else
          raise "本文の生成に失敗しました（内容が空、またはエラーメッセージが含まれています）"
        end
      end
    rescue => e
      # 【証拠2】どこで落ちたかをDBに刻む（ログが消えてもDBで確認可能）
      error_info = "❌ 失敗: #{e.class} - #{e.message}\n場所: #{e.backtrace.first}"
      column.update_columns(status: "error", body: error_info)
      Rails.logger.error error_info
      raise e 
    end
  end
end