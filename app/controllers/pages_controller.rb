class PagesController < ApplicationController
  before_action :set_breadcrumbs, except: [:index]
  before_action :initialize_contract

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
  def columns; end
  def short; end

  private

  def initialize_contract
    @contract = Contract.new
  rescue StandardError => e
    Rails.logger.error "Failed to initialize contract: #{e.message}"
    @contract = Contract.new
  end

  def set_breadcrumbs
    add_breadcrumb "トップ", root_path
    label = LpDefinition.label(action_name)
    add_breadcrumb label, request.path if label
  end
end
