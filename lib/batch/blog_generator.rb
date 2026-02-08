module Batch
  class BlogGenerator
    # daily_count: 1日あたりの child 記事生成件数
    def self.run_daily(daily_count = 25)
      Rails.logger.info("=== Blog generation start: #{Time.current} ===")

      # pillar 記事を取得（status: approved のもの）
      pillar_columns = Column.where(article_type: "pillar").order(created_at: :asc)
      if pillar_columns.empty?
        Rails.logger.warn("pillar 記事なし。処理終了")
        return
      end

      daily_count.times do |i|
        Rails.logger.info("=== Processing #{i + 1}/#{daily_count} ===")

        # ランダムに parent_id を持つ child 記事を取得
        child = Column.where.not(parent_id: nil)
                      .where(article_type: [:child, :cluster], body: nil)
                      .order("RANDOM()")
                      .first

        unless child
          Rails.logger.warn("対象 child 記事なし。スキップ")
          next
        end

        # =====================
        # 本文生成
        # =====================
        begin
          GenerateColumnBodyJob.perform_now(child.id)
          Rails.logger.info("✅ Child 本文生成成功: #{child.id} (parent_id=#{child.parent_id})")
        rescue => e
          child.update!(status: "failed")
          Rails.logger.error("❌ Child 本文生成例外: #{child.id} - #{e.message}")
        end

        sleep(1) # API負荷対策
      end

      Rails.logger.info("=== Blog generation end: #{Time.current} ===")
    end
  end
end
