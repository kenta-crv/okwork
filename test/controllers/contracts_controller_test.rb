require "test_helper"

class ContractsControllerTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  setup do
    ActionMailer::Base.deliveries.clear
    @params = {
      contract: {
        company: "テスト商事",
        name: "山田太郎",
        tel: "050-1234-5678",
        email: "test@example.com",
        address: "東京都港区",
        url: "https://example.com/",
        origin: "/daily-cleaning"
      }
    }
  end

  test "mail from daily cleaning notifies with html then returns sent" do
    perform_enqueued_jobs do
      assert_difference("Contract.count", 1) do
        post contracts_url, params: @params.merge(contact_via: "mail")
      end
    end
    assert_redirected_to "/daily-cleaning?sent=1"
    mail = ActionMailer::Base.deliveries.find { |m| m.to.include?("info@j-work.jp") }
    assert mail
    assert mail.html_part
    assert_includes mail.html_part.body.to_s, "送信が完了しました"
  end

  test "line from daily cleaning shows completion then continues to line" do
    perform_enqueued_jobs do
      assert_difference("Contract.count", 1) do
        post contracts_url, params: @params.merge(contact_via: "line")
      end
    end
    assert_redirected_to "/daily-cleaning?sent=1&via=line"
  end
end
