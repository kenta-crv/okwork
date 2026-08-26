# app/models/lp_definition.rb
module LpDefinition
  MAP = {
    'cargo'        => '軽貨物',
    'security'     => '警備業',
    'construction' => '建設業',
    'cleaning'     => '清掃業',
    'daily'        => '日常清掃',
    'daily_cleaning' => '日常清掃',
    'columns'      => 'お役立ち記事',
    'event'        => 'イベント',
    'logistics'    => '物流業',
    'app'          => 'テレアポ代行',
    'ads'          => '広告CPA改善',
    'staffing'     => '人材サービス'
  }.freeze

  # 日常清掃LPのLINE相談URL。公式アカウントの https://lin.ee/xxxx を入れてください。
  LINE_CONSULT_URL = ENV['OKWORK_LINE_URL'].presence

  def self.label(key)
    MAP[key]
  end

  def self.line_consult_url
    LINE_CONSULT_URL
  end
end
