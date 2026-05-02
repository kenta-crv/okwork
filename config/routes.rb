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



  # ================================================================
  # 2. ルート構造（ここが重要）
  # ================================================================

  # トップ
  root to: 'pages#index'


  # ================================================================
  # 3. 固定ページ
  # ================================================================

  #get 'construction', to: 'pages#construction'
  #get 'security',     to: 'pages#security'
  #get 'short',        to: 'pages#short'
  #get 'vender',       to: 'pages#vender'
  #get 'recruit',      to: 'pages#recruit'
  #get 'bpo',          to: 'pages#bpo'
  #get 'pest',         to: 'pages#pest'
  get 'daily',          to: 'pages#daily'

  # ================================================================
  # 4. 共通機能
  # ================================================================

  get 'draft/progress', to: 'draft#progress', as: :draft_progress
  resources :contracts
end