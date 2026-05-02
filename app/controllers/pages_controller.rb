class PagesController < ApplicationController
  #before_action :set_breadcrumbs
  # app, ads, short 以外はカラムを表示
  before_action :initialize_contract

  # 各アクション（中身は空で各viewを自動呼び出し）
  def index; end
  def cargo; end
  def security; end
  def construction; end
  def cleaning; end
  def daily; end
  def housekeeping; end
  def baby; end
  def babysitter; end
  def event; end
  def logistics; end
  def app; end
  def ads; end
  def short; end

  private

  def initialize_contract
    @contract = Contract.new
  end

  def set_breadcrumbs
    # 修正：ドメインに応じたルートパスを取得
    add_breadcrumb 'トップ', current_root_path
    
    label = LpDefinition.label(action_name)
    add_breadcrumb label, request.path if label
  end

end
