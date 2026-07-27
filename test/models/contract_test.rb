require "test_helper"

class ContractTest < ActiveSupport::TestCase
  test "company is required" do
    contract = Contract.new

    assert_not contract.valid?
    assert_includes contract.errors[:company], "を入力してください"
  end

  test "company must include a corporate suffix" do
    contract = Contract.new(company: "セールスプロ")

    assert_not contract.valid?
    assert_includes contract.errors[:company], "には「株式会社」などの法人格を含める必要があります"
  end

  test "company with a corporate suffix is valid" do
    contract = Contract.new(company: "株式会社セールスプロ")

    assert contract.valid?
  end
end
