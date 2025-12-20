# config/routes.rb

Rails.application.routes.draw do
  # Deviseの管理者認証
  devise_for :admins, controllers: {
    sessions: 'admins/sessions',
    registrations: 'admins/registrations'
  }
  
  root to: 'tops#index'

  # --- 各ジャンルLPの定義 ---
  get 'cargo', to: 'tops#cargo'
  get 'security', to: 'tops#security'
  get 'construction', to: 'tops#construction'
  get 'cleaning', to: 'tops#cleaning'
  get 'event', to: 'tops#event'
  get 'logistics', to: 'tops#logistics'
  get 'recruit', to: 'tops#recruit'
  get 'app', to: 'tops#app'

  # --- SEO用: ジャンル別コラム階層 (/genre/columns と /genre/columns/:id) ---
  # index（一覧）と show（詳細）の両方を許可します
  scope ':genre', constraints: { genre: /cargo|security|cleaning|app|construction/ } do
    resources :columns, only: [:index, :show], as: :nested_columns
  end

  get 'draft/progress', to: 'draft#progress'

  # --- 管理機能・汎用リソースとしてのコラム ---
  resources :columns do
    collection do
      get :draft            # ドラフト一覧
      post :generate_gemini # Gemini生成ボタンのPOST
      match 'bulk_update_drafts', via: [:post, :patch]
    end
    member do
      patch :approve
    end
  end

  # --- Sidekiq Web UI ---
  require 'sidekiq/web'
  authenticate :admin do 
    mount Sidekiq::Web, at: "/sidekiq"
  end
end