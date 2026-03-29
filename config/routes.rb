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
  # 2. マスタードメイン (okey.work)
  # 全ての管理・および j-work から外れた全ての LP を集約
  # ================================================================
  constraints host: 'okey.work' do
    root to: 'columns#index', as: :master_root

    # j-work から移設した各 LP アクションを1行ずつ明示的に記述
    get 'construction', to: 'tops#construction'
    get 'security',     to: 'tops#security'
    get 'short',        to: 'tops#short'
    get 'vender',       to: 'tops#vender'
    get 'recruit',      to: 'tops#recruit'
    get 'bpo',          to: 'tops#bpo'
    get 'pest',         to: 'tops#pest'
    get 'ads',          to: 'tops#ads'

    # 共通のエイリアス nested_columns を維持しつつ okey.work でも全ジャンル有効化
    get ':genre/columns', to: 'columns#index', as: :nested_columns
    get ':genre/columns/:id', to: 'columns#show', as: :nested_column
  end

  # ================================================================
  # 3. j-work.jp (厳格に 4ジャンル のみ)
  # ================================================================
  constraints ->(req) { req.host == 'j-work.jp' || Rails.env.development? } do
    root to: 'tops#index', as: :j_work_root
    
    # 許可された 4ジャンル の LP
    get 'cleaning',  to: 'tops#cleaning'
    get 'daily',  to: 'tops#daily'
    get 'housekeeping',  to: 'tops#housekeeping'
    get 'cargo',     to: 'tops#cargo'
    get 'logistics', to: 'tops#logistics'
    get 'event',     to: 'tops#event'

    # 構造: /:genre/columns (j-workでは cargo|cleaning|logistics|event に制限)
    scope ':genre/columns', constraints: { genre: /cargo|cleaning|logistics|event|housekeeping|babysitter/ } do
      get '/',    to: 'columns#index'
      get '/:id', to: 'columns#show'
    end
  end

  # ================================================================
  # 4. ri-plus.jp (app のみ)
  # ================================================================
  constraints ->(req) { req.host == 'ri-plus.jp' || Rails.env.development? } do
   root to: 'tops#app', as: :ri_plus_root
   scope ':genre/columns', constraints: { genre: /app/ } do
    get '/',    to: 'columns#index'
    get '/:id', to: 'columns#show'
   end
  end
    # 開発環境限定で localhost:3000/app にもアクセス可能
  if Rails.env.development?
    get '/app', to: 'tops#app', as: :app_root
  end

  # ================================================================
  # 5. 自販機.net (vender のみ)
  # ================================================================
  constraints host: '自販機.net' do
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