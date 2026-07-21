module PagesHelper
  FEATURED_COLUMNS = {
    top: [
      { title: "清掃業者の選び方: 品質を重視した判断基準", path: "/columns/how-to-choose-cleaning-service-7a0d021f-5b76-4eeb-a114-a88aa45b69e1" },
      { title: "失敗しない清掃業者の選び方: ケーススタディ", path: "/columns/cleaning-service-selection-bf7841c6-5c44-4746-bd8e-1e617507c62b" },
      { title: "日常清掃の業者選び：失敗しないためのガイド", path: "/columns/daily-cleaning-service-guide" },
      { title: "清掃業者選びにおける費用の透明性を確保する方法", path: "/columns/transparency-in-cleaning-service-costs" },
      { title: "日常清掃業者の選び方：信頼性と専門知識の重要性", path: "/columns/daily-cleaning-service-selection-b810974f-67c9-4117-aff7-4194bfee8785" }
    ],
    daily: [
      { title: "日常清掃の業者選び：失敗しないためのガイド", path: "/columns/daily-cleaning-service-guide" },
      { title: "日常清掃業者の選び方：信頼性と専門知識の重要性", path: "/columns/daily-cleaning-service-selection-b810974f-67c9-4117-aff7-4194bfee8785" },
      { title: "清掃業者の選び方: 品質を重視した判断基準", path: "/columns/how-to-choose-cleaning-service-7a0d021f-5b76-4eeb-a114-a88aa45b69e1" },
      { title: "清掃業者選びにおける費用の透明性を確保する方法", path: "/columns/transparency-in-cleaning-service-costs" },
      { title: "失敗しない清掃業者の選び方: ケーススタディ", path: "/columns/cleaning-service-selection-bf7841c6-5c44-4746-bd8e-1e617507c62b" }
    ]
  }.freeze

  def featured_columns_for(page_key = :top)
    FEATURED_COLUMNS[page_key.to_sym] || FEATURED_COLUMNS[:top]
  end
end
