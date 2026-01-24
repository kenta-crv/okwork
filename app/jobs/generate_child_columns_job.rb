class GenerateChildColumnsJob < ApplicationJob
  queue_as :default

  # pillar_id: 親記事のID, batch_count: 生成する件数(25)
  def perform(pillar_id, batch_count)
    # ここで GeminiColumnGenerator を呼び出す
    # (※Geminiの方は、以前のGeneratorが正しく動いている前提です)
    GeminiColumnGenerator.generate_columns(batch_count: batch_count, pillar_id: pillar_id)
  rescue => e
    Rails.logger.error "❌ 子記事生成失敗 (PillarID: #{pillar_id}): #{e.message}"
    raise e # エラー時はJobをリトライさせるためにraise
  end
end