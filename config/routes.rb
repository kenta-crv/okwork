Rails.application.routes.draw do
  # ================================================================
  # 1. 共通基盤設定
  # ================================================================

  devise_for :admins, controllers: {
    sessions: 'admins/sessions',
    registrations: 'admins/registrations'
  }

  require 'sidekiq/web'
  authenticate :admin do 
    mount Sidekiq::Web, at: "/sidekiq"
  end

  # コラム管理
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
  # 2. ルート構造（ここが重要）
  # ================================================================

  # トップ
  root to: 'columns#index'

  # ★ columns直叩きを禁止（重要）
  get '/columns', to: ->(env) { [404, {}, ['Not Found']] }

  # ★ 正規ルート（制約あり）
  scope ':genre/columns', constraints: { genre: /cargo|cleaning|logistics|event|housekeeping|babysitter|app|vender/ } do
    get '/',    to: 'columns#index', as: :columns_index
    get '/:id', to: 'columns#show',  as: :columns_show
  end

  # ================================================================
  # 3. 固定ページ
  # ================================================================

  get 'construction', to: 'pages#construction'
  get 'security',     to: 'pages#security'
  get 'short',        to: 'pages#short'
  get 'vender',       to: 'pages#vender'
  get 'recruit',      to: 'pages#recruit'
  get 'bpo',          to: 'pages#bpo'
  get 'pest',         to: 'pages#pest'
  get 'ads',          to: 'pages#ads'

  # ================================================================
  # 4. 共通機能
  # ================================================================

  get 'draft/progress', to: 'draft#progress', as: :draft_progress
  resources :contracts
end