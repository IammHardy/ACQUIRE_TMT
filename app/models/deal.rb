# An anonymized TMT business for sale, shown to buyers in their curated feed.
# Seeded with sample listings (db/seeds.rb) and managed by admins.
class Deal < ApplicationRecord
  STATUSES = %w[active under_offer sold].freeze

  has_many :deal_accesses, dependent: :destroy

  validates :reference, :title, :industry, presence: true
  validates :reference, uniqueness: true
  validates :status, inclusion: { in: STATUSES }

  scope :active, -> { where(status: "active") }

  # Active deals matching a buyer's mandate (industries + revenue range),
  # newest first. An empty mandate matches everything.
  def self.for_buyer(user)
    scope = active
    scope = scope.where(industry: user.mandate_industries) if user.mandate_industries.present?
    scope = scope.where("revenue >= ?", user.mandate_min_revenue) if user.mandate_min_revenue.present?
    scope = scope.where("revenue <= ?", user.mandate_max_revenue) if user.mandate_max_revenue.present?
    scope.order(created_at: :desc)
  end

  def industry_name
    ValuationData.sector(industry)["name"]
  end

  def status_label
    status.tr("_", " ")
  end
end
