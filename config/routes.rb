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

  # ================================================================
  # 2. 管理系（衝突防止のため /admin 配下に隔離）
  # ================================================================

  namespace :admin do
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
  end

  # ================================================================
  # 3. 公開ルーティング（これがメイン）
  # ================================================================

  # トップ
  root to: 'columns#index'

  # /columns（ドメインごとにControllerで制御）
  get '/columns', to: 'columns#index'

  # ジャンル付きURL（正規）
  scope ':genre/columns', constraints: { genre: /cargo|cleaning|logistics|event|housekeeping|babysitter|app|vender/ } do
    get '/',    to: 'columns#index', as: :columns_index
    get '/:id', to: 'columns#show',  as: :columns_show
  end

  # ================================================================
  # 4. 固定ページ（okey.work等）
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
  # 5. 共通機能
  # ================================================================

  get 'draft/progress', to: 'draft#progress', as: :draft_progress
  resources :contracts
end