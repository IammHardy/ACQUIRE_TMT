# An anonymized TMT business for sale, shown to buyers in their curated feed.
# Seeded with sample listings (db/seeds.rb) and managed by admins.
class Deal < ApplicationRecord
  STATUSES = %w[active under_offer sold].freeze

  has_many :deal_accesses, dependent: :destroy

  validates :reference, :title, :industry, presence: true
  validates :reference, uniqueness: true
  validates :status, inclusion: { in: STATUSES }

  scope :active, -> { where(status: "active") }

  # Active deals matching a buyer's mandate (industries + enterprise-value
  # range, using asking price as the EV proxy), newest first. An empty mandate
  # matches everything.
  def self.for_buyer(user)
    scope = active
    scope = scope.where(industry: user.mandate_industries) if user.mandate_industries.present?
    scope = scope.where("asking_price >= ?", user.ev_min) if user.ev_min.present?
    scope = scope.where("asking_price <= ?", user.ev_max) if user.ev_max.present?
    scope.order(created_at: :desc)
  end

  def industry_name
    ValuationData.sector(industry)["name"]
  end

  # OffDeal-style anonymized project label, e.g. "PROJECT EPSILON".
  def project_label
    "PROJECT #{(codename.presence || reference).upcase}"
  end

  def status_label
    status.tr("_", " ")
  end
end
