# app/models/lp_definition.rb
module LpDefinition
  MAP = {
    'cargo'        => '軽貨物',
    'security'     => '警備業',
    'construction' => '建設業',
    'cleaning'     => '清掃業',
    'daily'        => '日常清掃',
    'daily_cleaning' => '日常清掃',
    'mansion_patrol_cleaning' => 'マンション巡回清掃',
    'hospital_cleaning' => '病院清掃',
    'hotel_cleaning' => 'ホテル清掃',
    'office_cleaning' => 'オフィス清掃',
    'care_cleaning' => '介護清掃',
    'building_cleaning' => 'ビルクリーニング',
    'columns'      => 'お役立ち記事',
    'event'        => 'イベント',
    'logistics'    => '物流業',
    'app'          => 'テレアポ代行',
    'ads'          => '広告CPA改善',
    'staffing'     => '人材サービス'
  }.freeze

  CLEANING_LP_ACTIONS = %w[
    daily_cleaning
    mansion_patrol_cleaning
    hospital_cleaning
    hotel_cleaning
    office_cleaning
    care_cleaning
    building_cleaning
  ].freeze

  CLEANING_LP_PATHS = %w[
    /daily-cleaning
    /daily
    /mansion
    /hospital
    /hotel
    /office
    /care
    /building
  ].freeze

  # LINE相談URL（ENVがあれば優先）
  LINE_CONSULT_URL = ENV['OKWORK_LINE_URL'].presence || 'https://lin.ee/XJMSNq9'

  def self.label(key)
    MAP[key]
  end

  def self.cleaning_lp_action?(action_name)
    CLEANING_LP_ACTIONS.include?(action_name.to_s)
  end

  def self.cleaning_lp_path?(path)
    CLEANING_LP_PATHS.include?(path.to_s.split('?').first)
  end

  def self.line_consult_url
    LINE_CONSULT_URL
  end
end
