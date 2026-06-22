class Column < ApplicationRecord
  extend FriendlyId
  friendly_id :code, use: :slugs

  belongs_to :parent, class_name: 'Column', optional: true
  has_many :children, class_name: 'Column', foreign_key: 'parent_id'

  validates :title, presence: true
  validates :code, presence: true, uniqueness: true
  validates :service_type, presence: true
  validates :article_type, presence: true

  scope :published, -> { where(status: 'published') }
  scope :by_genre, ->(genre) { where(genre: genre) }
  scope :by_service_type, ->(service_type) { where(service_type: service_type) }
  scope :recent, -> { order(created_at: :desc) }

  def self.ransackable_attributes(auth_object = nil)
    %w[title keyword description status service_type genre code article_type created_at updated_at]
  end

  def self.ransackable_associations(auth_object = nil)
    %w[parent children]
  end
end
