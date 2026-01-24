class GenerateChildColumnsJob < ApplicationJob
  queue_as :default

  def perform(pillar_id, batch_count = 25)
    pillar = Column.find_by(id: pillar_id)
    return unless pillar

    begin
      # 1. まず子記事（タイトルだけのレコード）を Gemini で一括作成
      # generate_columns が作成された Column オブジェクトの配列を返すと想定
      child_columns = GeminiColumnGenerator.generate_columns(batch_count: batch_count, pillar_id: pillar_id)
      
      # 2. 生成された各子記事に対して、1件ずつ個別の「本文執筆Job」をキューに入れる
      # これにより、並列処理が可能になり、全体の完了が早まります
      child_columns.each do |child|
        GenerateColumnBodyJob.perform_later(child.id)
      end
      
      Rails.logger.info "✅ Pillar ID:#{pillar_id} から #{child_columns.size}件の子記事執筆Jobを投入しました。"
    rescue => e
      Rails.logger.error "❌ 子記事生成プロセスの開始に失敗 (PillarID: #{pillar_id}): #{e.message}"
      raise e
    end
  end
end