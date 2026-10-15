class ContractsController < ApplicationController
  LINE_CONSULT_URL = LpDefinition::LINE_CONSULT_URL

  protect_from_forgery with: :null_session, only: [:create]

  #before_action :authenticate_admin!, only: [:index, :destroy, :send_mail]
    def index
      @contracts = Contract.order(created_at: "DESC").page(params[:page])
    end
  
    def new
      @contract = Contract.new
    end

    def create
      @contract = Contract.new(contract_params)

      origin_url = if @contract.origin.to_s.start_with?('/')
        @contract.origin
      else
        request.referer || root_path
      end
      origin_path = origin_url.to_s.split('?').first
      daily_lp = LpDefinition.cleaning_lp_path?(origin_path)

      via = params[:contact_via].to_s
      if via == 'line' || via == 'mail'
        prefix = via == 'line' ? '依頼経路: LINE' : '依頼経路: メール'
        @contract.message = [prefix, @contract.message.presence].compact.join("\n")
      end

      if @contract.save
        if daily_lp
          ContractMailer.received_email(@contract, true).deliver_later
          ContractMailer.send_email(@contract, true).deliver_later if @contract.email.present?
        else
          ContractMailer.received_email(@contract).deliver_now
          ContractMailer.send_email(@contract).deliver_now if @contract.email.present?
        end

        if via == 'line' && !daily_lp
          redirect_to LINE_CONSULT_URL, allow_other_host: true
          return
        end

        separator = origin_url.include?('?') ? '&' : '?'
        sent_url = "#{origin_url}#{separator}sent=1"
        sent_url += '&via=line' if via == 'line' && daily_lp
        redirect_to sent_url
      else
        p @contract.errors.full_messages
        separator = origin_url.include?('?') ? '&' : '?'
        redirect_to "#{origin_url}#{separator}error=1"
      end
    end

    def show
      @contract = Contract.find(params[:id])
      #@comment = Comment.new
    end
  
    def edit
      @contract = Contract.find(params[:id])
    end

    def destroy
      @contract = Contract.find(params[:id])
      @contract.destroy
      redirect_to contracts_path, alert:"削除しました"
    end
  
    def update
      @contract = Contract.find(params[:id])
    
      if @contract.update(contract_params)
        redirect_to root_path
      else
        # 更新が失敗した場合の処理
        render :edit
      end
    end

    private
    def contract_params
      params.require(:contract).permit(
      :company, #会社名
      :name, #担当者
      :tel, #電話番号
      :email, #メールアドレス
      :address, #所在地
      :url,
      :period, #導入時期
      :message, #備考
      :origin,
      )
    end
end
