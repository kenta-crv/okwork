# config/routes.rb
Rails.application.routes.draw do
  # ================================================================
  # 1. 共通基盤設定
  # ================================================================
  
  # 管理者認証 (admins)
  devise_for :admins, controllers: {
    sessions: 'admins/sessions',
    registrations: 'admins/registrations'
  }

  # Sidekiq 管理画面
  require 'sidekiq/web'
  authenticate :admin do 
    mount Sidekiq::Web, at: "/sidekiq"
  end

  # コラム基本管理機能
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
  # 2. j-work.jp 向け簡易ルーティング（Host constraints を削除）
  # ================================================================
  
  # トップページ
  root to: 'pages#index'

  # 各ページ
  get 'cleaning',      to: 'pages#cleaning'
  get 'daily',         to: 'pages#daily'
  get 'housekeeping',  to: 'pages#housekeeping'
  get 'cargo',         to: 'pages#cargo'
  get 'logistics',     to: 'pages#logistics'
  get 'event',         to: 'pages#event'

  # columns ページ
  scope ':genre/columns', constraints: { genre: /cargo|cleaning|logistics|event|housekeeping|babysitter/ } do
    get '/',    to: 'columns#index', as: :columns_index
    get '/:id', to: 'columns#show',  as: :columns_show
  end

  # ユーザー関連ページなど
  get 'users', to: 'users#index'

  # ================================================================
  # 3. okey.work や他ドメイン固有ページもシンプルに
  # ================================================================
  
  # マスタードメイン (okey.work)
  get 'construction', to: 'pages#construction'
  get 'security',     to: 'pages#security'
  get 'short',        to: 'pages#short'
  get 'vender',       to: 'pages#vender'
  get 'recruit',      to: 'pages#recruit'
  get 'bpo',          to: 'pages#bpo'
  get 'pest',         to: 'pages#pest'
  get 'ads',          to: 'pages#ads'

  get ':genre/columns',     to: 'columns#index', as: :nested_columns
  get ':genre/columns/:id', to: 'columns#show',  as: :nested_column

  # ri-plus.jp 用ページ
  get 'app', to: 'pages#app', as: :app_root

  # 自販機.net 用ページ
  get 'vender', to: 'pages#vender', as: :vender_root

  # ================================================================
  # 4. 共通の付随機能
  # ================================================================
  get 'draft/progress', to: 'draft#progress', as: :draft_progress
  resources :contracts
end