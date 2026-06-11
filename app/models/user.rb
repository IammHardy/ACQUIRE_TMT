class User < ApplicationRecord
  has_secure_password
  has_many :sessions, dependent: :destroy
  has_many :tool_runs, dependent: :nullify
  has_many :leads, dependent: :nullify
  has_many :deal_accesses, dependent: :destroy

  # A signup picks a role: sellers track their tool runs; buyers get a curated
  # deal feed matching their acquisition mandate.
  ROLES = %w[seller buyer].freeze

  enum :role, { seller: "seller", buyer: "buyer" }, default: "seller"

  normalizes :email_address, with: ->(e) { e.strip.downcase }

  validates :email_address, presence: true, uniqueness: true,
            format: { with: URI::MailTo::EMAIL_REGEXP, message: "is not a valid email" }
  validates :name, presence: true
  validates :role, inclusion: { in: ROLES }

  # Buyers whose (set) mandate matches a deal — for new-listing alerts. Buyers
  # who haven't set a mandate aren't alerted (they've expressed no interest).
  scope :matching_deal, ->(deal) {
    buyer
      .where("array_length(mandate_industries, 1) > 0")
      .where("? = ANY (mandate_industries)", deal.industry)
      .where("mandate_min_revenue IS NULL OR mandate_min_revenue <= ?", deal.revenue.to_i)
      .where("mandate_max_revenue IS NULL OR mandate_max_revenue >= ?", deal.revenue.to_i)
  }

  def display_name
    name.presence || email_address.split("@").first
  end

  # A buyer has set their acquisition criteria once they've picked a sector.
  def mandate_set?
    mandate_industries.present?
  end
end
