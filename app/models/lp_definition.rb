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

  # LINE相談URL（ENVがあれば優先）
  LINE_CONSULT_URL = ENV['OKWORK_LINE_URL'].presence || 'https://lin.ee/XJMSNq9'

  def self.label(key)
    MAP[key]
  end

  def self.line_consult_url
    LINE_CONSULT_URL
  end
end
