class GenerateColumnBodyJob < ApplicationJob
  # 専用キューを指定。なければ :default でも可
  queue_as :article_generation

  # OpenAI APIのタイムアウトやネットワークエラー時に3回まで自動リトライ
  retry_on Net::ReadTimeout, wait: :exponentially_longer, attempts: 3

  def perform(column_id)
    column = Column.find_by(id: column_id)
    return unless column
    
    # 既に完了している場合は二重実行防止のためスキップ
    return if column.status == "completed" && column.body.present?

    begin
      if column.article_type == "pillar"
        # 親記事(Pillar)の場合：既存のGeneratorを使用して構成から本文まで一括生成
        GptPillarGenerator.generate_full_from_existing_column!(column)
      else
        # 子記事(Child)の場合：GptArticleGeneratorを使用してセクションごとに生成
        body = GptArticleGenerator.generate_body(column)
        
        if body.present? && !body.include?("生成失敗")
          column.update!(body: body, status: "completed")
        else
          raise "本文の生成に失敗しました（内容が空、またはエラーメッセージが含まれています）"
        end
      end
    rescue => e
      Rails.logger.error "❌ [ID:#{column_id}] 生成失敗: #{e.message}"
      # 最終的な失敗としてステータスを更新（リトライ上限に達した際など）
      column.update(status: "error") if column.status != "completed"
      raise e # ActiveJobにエラーを投げ、リトライメカニズムを働かせる
    end
  end
end