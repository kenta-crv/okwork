class ContractMailer < ActionMailer::Base
  # 修正：必ずドメインを含む正しいアドレスを指定する
  default from: "info@j-work.jp" # 仮のドメインを入れています。実際の運用アドレスに

  def received_email(contract)
    @contract = contract
    options = {
      to: "info@j-work.jp",
      subject: '株式会社J Workにお問い合わせがありました'
    }
    options[:from] = @contract.email if @contract.email.present?
    mail(options)
  end

  def send_email(contract)
    return if contract.email.blank?

    @contract = contract
    mail(
      to: @contract.email,
      subject: 'お問い合わせ頂きありがとうございます。'
    )
  end
end