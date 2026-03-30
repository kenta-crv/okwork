Rails.application.routes.draw do
  # ================================================================
  # 1. 共通基盤設定 (既存の構成・パスを1行ずつ完全維持)
  # ================================================================
  
  # 管理者認証 (admins)
  devise_for :admins, controllers: {
    sessions: 'admins/sessions',
    registrations: 'admins/registrations'
  }

  # Sidekiq 管理画面 (以前の通り維持)
  require 'sidekiq/web'
  authenticate :admin do 
    mount Sidekiq::Web, at: "/sidekiq"
  end

  # コラム基本管理機能 (全ドメインで共通認識させるための基本パス)
  post 'columns/generate_from_selected', to: 'columns#generate_from_selected', as: :generate_from_selected_columns_fix
  post 'columns/bulk_update_drafts', to: 'columns#bulk_update_drafts', as: :bulk_update_drafts_columns_fix

  resources :columns do
    collection do
      get :draft
      post :generate_gemini
      post :generate_pillar
      post :generate_from_selected
      match 'bulk_update_drafts', via: [:post, :patch]
    end
    member do
      post :generate_from_pillar
      patch :approve
    end
  end

  # ================================================================
  # 2. j-work.jp（最優先・完全一致）
  # ================================================================
  constraints(lambda { |req| req.host == 'j-work.jp' }) do
    root to: 'tops#index', as: :j_work_root
    
    get 'cleaning',      to: 'tops#cleaning'
    get 'daily',         to: 'tops#daily'
    get 'housekeeping',  to: 'tops#housekeeping'
    get 'cargo',         to: 'tops#cargo'
    get 'logistics',     to: 'tops#logistics'
    get 'event',         to: 'tops#event'

    scope ':genre/columns', constraints: { genre: /cargo|cleaning|logistics|event|housekeeping|babysitter/ } do
      get 'columns/',    to: 'columns#index'
      get 'columns/:id', to: 'columns#show'
    end
  end

  # ================================================================
  # 3. マスタードメイン (okey.work)
  # ================================================================
  constraints(lambda { |req| req.host == 'okey.work' }) do
    root to: 'columns#index', as: :master_root

    get 'construction', to: 'tops#construction'
    get 'security',     to: 'tops#security'
    get 'short',        to: 'tops#short'
    get 'vender',       to: 'tops#vender'
    get 'recruit',      to: 'tops#recruit'
    get 'bpo',          to: 'tops#bpo'
    get 'pest',         to: 'tops#pest'
    get 'ads',          to: 'tops#ads'

    get ':genre/columns',     to: 'columns#index', as: :nested_columns
    get ':genre/columns/:id', to: 'columns#show',  as: :nested_column
  end

  # ================================================================
  # 4. ri-plus.jp (app のみ)
  # ================================================================
  constraints(lambda { |req| req.host == 'ri-plus.jp' }) do
    root to: 'tops#app', as: :ri_plus_root

    scope ':genre/columns', constraints: { genre: /app/ } do
      get '/',    to: 'columns#index'
      get '/:id', to: 'columns#show'
    end
  end

  # 開発環境限定
  if Rails.env.development?
    get '/app', to: 'tops#app', as: :app_root
  end

  # ================================================================
  # 5. 自販機.net (vender のみ)
  # ================================================================
  constraints(lambda { |req| req.host == '自販機.net' }) do
    root to: 'tops#vender', as: :vender_root

    scope ':genre/columns', constraints: { genre: /vender/ } do
      get '/',    to: 'columns#index'
      get '/:id', to: 'columns#show'
    end
  end

  # ================================================================
  # 6. 付随機能 (Payment / Plans / その他共通)
  # ================================================================
  get 'draft/progress', to: 'draft#progress', as: :draft_progress
  resources :contracts

end