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
      { title: "日常清掃の外注判断・費用相場完全ガイド", path: "/columns/daily-cleaning-outsourcing-cost-complete-guide" },
      { title: "日常清掃でどこまで業者に任せるべきか？委託範囲の決め方と失敗パターン", path: "/columns/how-much-to-outsource-daily-cleaning" },
      { title: "日常清掃の料金相場と見積もり内訳｜高くなる原因と適正価格の見極め方", path: "/columns/nichijouseisou-ryoukin-souba-mitsumori" },
      { title: "日常清掃で起こりがちなトラブルと防止策｜契約前・契約後の注意点", path: "/columns/nichijouseisou-toraburu-boushisaku" },
      { title: "社員の快適な環境を作る日常清掃｜業者利用のメリットと費用", path: "/columns/daily-cleaning-cost" }
    ],
    mansion: [
      { title: "マンション清掃・管理の基本とは？管理組合・オーナー向け業者選びと清掃品質の見極め方", path: "/columns/basic-cleaning-management-mansion" },
      { title: "マンション清掃、委託業者の変更でコスト削減は可能？相場と注意点", path: "/columns/mansion-cleaning-cost-reduction-a16f0373-822a-4430-9ed5-782bf15d2a92" },
      { title: "マンション清掃のコスト削減術：見積もりから契約まで、賢い選択で費用対効果を最大化", path: "/columns/condo-cleaning-cost-ca61f423-20d6-482f-9053-74502684dd32" },
      { title: "マンション清掃業者の見積もり徹底比較：隠れたコストを見抜く３つのポイント", path: "/columns/cleaning-cost-comparison-243ea1c9-1a98-4ca7-93ae-17643ce75ee1" },
      { title: "マンション清掃の委託費用相場と内訳｜見積書で必ず確認すべきポイント", path: "/columns/mansion-cleaning-costs" }
    ],
    hospital: [
      { title: "医療・病院清掃完全ガイド｜感染対策・清掃基準・専門業者の選び方を徹底解説", path: "/columns/medical-hospital-cleaning-guide" },
      { title: "病院清掃における感染対策の基本｜ゾーニング・動線・清掃手順", path: "/columns/byouin-seisou-kansen-taisaku" },
      { title: "医療施設で清掃不備が招く感染リスクとは？実例から学ぶ注意点", path: "/columns/irregularities-in-medical-facility-cleaning-infection-risk" },
      { title: "病院清掃で使う洗剤・消毒剤の正しい選び方｜次亜塩素酸・アルコールの使い分け", path: "/columns/byouin-seisou-senzai-shidou" },
      { title: "医療機関に求められる清掃頻度と範囲｜病棟・外来・手術室の違い", path: "/columns/iryoukikan-seisou-hindo-han" },
      { title: "病院清掃は内製と外注どちらが適切か？コスト・感染対策・管理負担で比較", path: "/columns/byouin-seisou-naisei-gai-chuu-hikaku" },
      { title: "病院清掃を外注すべきタイミングとは？人員不足・品質低下の判断基準", path: "/columns/byouin-seisou-outsourcing-timing" },
      { title: "医療・病院清掃業者の選び方｜感染対策で必ず確認すべきチェックポイント", path: "/columns/iryou-byouin-seisou-sagasu" },
      { title: "病院清掃の見積もり比較で見るべきポイント｜価格差と業務範囲の違い", path: "/columns/byouin-seisou-mitsumori-hikaku" },
      { title: "病院清掃業者と契約する際の注意点｜責任範囲・教育体制・緊急対応", path: "/columns/byouin-seisou-gyousha-chuui" },
      { title: "病院・クリニック・診療所で異なる清掃要件とは？施設規模別の考え方", path: "/columns/byouin-kurinikku-shinryousho-seisou-youken" }
    ],
    care: [
      { title: "介護施設の清掃業者選び完全ガイド｜感染対策・衛生管理・料金相場まで徹底解説", path: "/columns/complete-guide-to-cleaning-service-selection-for-nursing-facilities" },
      { title: "介護施設の日常清掃、自社 vs 外注？コストと品質で徹底比較", path: "/columns/facility-cleaning-cost" },
      { title: "介護施設向け清掃業者選びの落とし穴｜契約前に確認すべき３つのポイント", path: "/columns/nursing-home-cleaning-checklist" },
      { title: "介護施設における清掃チェックリスト：感染症リスク低減と衛生管理の徹底", path: "/columns/elderly-care-cleaning-checklist" },
      { title: "特別養護老人ホームの清掃業者選び｜重度介護環境で求められる衛生管理とは", path: "/columns/tokubetsuyougo-roujinhome-seisougyousha-erabi" },
      { title: "介護老人保健施設（老健）の清掃管理とは？医療寄り施設に必要な感染対策", path: "/columns/kaigo-rouken-seisou-kanri" },
      { title: "老健の清掃委託で重要なポイント｜病院清掃との違いと注意点", path: "/columns/rouken-seisou-itaku" },
      { title: "老健における清掃業者選定基準｜リハビリ・医療動線を考慮した清掃設計", path: "/columns/rouken-seisou-gyousha-senteikijun" },
      { title: "介護施設の種類別に見る清掃委託の違い｜特養・老健・有料老人ホーム比較", path: "/columns/kaigo-seisou-ittaku-chigai" },
      { title: "介護施設清掃の見積もり比較で見るべきポイント｜価格差と業務範囲の違い", path: "/columns/care-facility-cleaning-estimate-comparison" },
      { title: "介護施設の清掃業者と契約する際の注意点｜責任範囲・教育体制・緊急対応", path: "/columns/care-facility-cleaning-contract-notes" },
      { title: "介護施設清掃を外注すべきタイミングとは？人員不足・品質低下の判断基準", path: "/columns/care-facility-cleaning-outsourcing-timing" },
      { title: "介護施設に求められる清掃頻度と範囲｜居室・共用部・浴室・厨房の違い", path: "/columns/care-facility-cleaning-frequency-and-scope" }
    ],
    office: [
      { title: "オフィス清掃完全ガイド｜業務内容・費用相場・業者選びを徹底解説", path: "/columns/office-cleaning-guide" },
      { title: "オフィス清掃で生産性向上？ OK清掃が教える、清掃頻度と集中力の意外な関係", path: "/columns/office-cleaning-productivity-863ea15f-aca8-488c-a613-028e300ef3e8" },
      { title: "オフィス清掃の業務内容一覧｜日常清掃・定期清掃・特別清掃の違い", path: "/columns/office-cleaning-services" },
      { title: "オフィス清掃で対応できる範囲・できない範囲｜契約前の注意点", path: "/columns/office-cleaning-scope" },
      { title: "オフィス清掃の費用相場｜坪単価・月額料金・作業別料金を解説", path: "/columns/office-cleaning-cost-8f231229-5d93-437d-9d98-e94e9d367105" }
    ],
    hotel: [
      { title: "ホテル清掃完全ガイド｜客室清掃・費用相場・業者選びを徹底解説", path: "/columns/hotel-room-cleaning-complete-guide-cost-and-outsourcing" },
      { title: "ホテル客室清掃の基本手順｜チェックアウト後の流れと所要時間", path: "/columns/hotel-room-cleaning-procedure-checkout" },
      { title: "客室清掃の不備が招くクレームと口コミ低下｜実例から学ぶ注意点", path: "/columns/hotel-room-cleaning-complaints-and-reviews-prevention" },
      { title: "客室で使う洗剤・消毒剤の選び方｜リネン・水回り・アメニティの使い分け", path: "/columns/hotel-room-cleaning-detergent-disinfectant-selection" },
      { title: "ホテル清掃の頻度と範囲｜客室・ロビー・宴会場・大浴場の違い", path: "/columns/hotel-room-and-facility-cleaning-frequency-and-scope" }
    ],
    building: [
      { title: "ビルクリーニング完全ガイド｜日常清掃・共用部・費用相場・業者選びを徹底解説", path: "/columns/building-cleaning-complete-guide-daily-cleaning-common-area-cost-and-provider-se" },
      { title: "ビルクリーニングの業務内容一覧｜日常清掃・定期清掃・特別清掃の違い", path: "/columns/building-cleaning-work-details-daily-regular-special" },
      { title: "ビル共用部で対応できる範囲・できない範囲｜契約前の注意点", path: "/columns/building-common-area-cleaning-scope-and-limits-contract-prechecks" },
      { title: "ビルクリーニングの費用相場｜坪単価・月額料金・作業別料金を解説", path: "/columns/building-cleaning-costs-market-price" },
      { title: "ビル清掃は内製と外注どちらが正解か？コスト・品質・管理負担で比較", path: "/columns/building-cleaning-inhouse-vs-outsourcing-cost-quality-management" }
    ]
  }.freeze

  FEATURED_COLUMNS_MORE = {
    daily: "/columns/daily-cleaning-outsourcing-cost-complete-guide",
    mansion: "/columns/basic-cleaning-management-mansion",
    hospital: "/columns/medical-hospital-cleaning-guide",
    care: "/columns/complete-guide-to-cleaning-service-selection-for-nursing-facilities",
    office: "/columns/office-cleaning-guide",
    hotel: "/columns/hotel-room-cleaning-complete-guide-cost-and-outsourcing",
    building: "/columns/building-cleaning-complete-guide-daily-cleaning-common-area-cost-and-provider-se"
  }.freeze

  def featured_columns_for(page_key = :top)
    FEATURED_COLUMNS[page_key.to_sym] || FEATURED_COLUMNS[:top]
  end

  def featured_columns_more_path(page_key = :top)
    FEATURED_COLUMNS_MORE[page_key.to_sym] || "/columns"
  end

  # pages#index のFAQと同一内容（JSON-LD用）
  def lp_faqs
    [
      { q: "対応エリアはどこまでですか？", a: "全国対応可能です。地域や業種により条件が異なりますのでご相談ください。" },
      { q: "複数事業をまとめて依頼できますか？", a: "はい、複数業種を一括でご依頼いただけます。" }
    ]
  end
end
