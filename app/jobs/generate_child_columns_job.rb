class GenerateChildColumnsJob < ApplicationJob
  queue_as :default

  def perform(pillar_id, batch_count)
    # Controllerでやっていた処理をここに移動
    GeminiColumnGenerator.generate_columns(batch_count: batch_count, pillar_id: pillar_id)
  end
end