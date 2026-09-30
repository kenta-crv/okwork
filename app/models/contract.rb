class Contract < ApplicationRecord
  CORPORATE_NAME_PATTERN = /(株式会社|合同会社|有限会社|合資会社|合名会社|一般社団法人|一般財団法人|NPO法人|医療法人|社会福祉法人|学校法人|宗教法人|特定非営利活動法人)/.freeze

  validates :company, presence: true
  validate :company_must_include_kaisha

  private

  def company_must_include_kaisha
    return if company.blank?

    unless company.match?(CORPORATE_NAME_PATTERN)
      errors.add(:company, 'には「株式会社」などの法人格を含める必要があります')
    end
  end
end