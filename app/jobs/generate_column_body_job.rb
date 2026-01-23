# app/jobs/generate_column_body_job.rb

class GenerateColumnBodyJob < ApplicationJob
  queue_as :article_generation

  def perform(column_id)
    column = Column.find_by(id: column_id)
    return unless column

    begin
      # ここを generate_full_from_existing_column! に差し替え
      if column.article_type == "pillar"
        GptPillarGenerator.generate_full_from_existing_column!(column)
      else
        # 通常記事（子記事）の場合の処理
        body = GptArticleGenerator.generate_body(column)
        column.update!(body: body, status: "completed")
      end
    rescue => e
      Rails.logger.error "生成失敗: #{e.message}"
      column.update(status: "error")
      raise e
    end
  end
end