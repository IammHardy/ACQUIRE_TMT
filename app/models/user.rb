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

  # Buyer onboarding option sets (mirrors OffDeal's wizard).
  BUYER_TYPES = ["Individual", "Search Fund", "PE Firm", "Strategic Acquirer"].freeze

  # Personal email providers — these may only register as "Individual"; the
  # institutional buyer types require a work email (OffDeal behavior).
  PERSONAL_EMAIL_DOMAINS = %w[
    gmail.com googlemail.com yahoo.com yahoo.co.uk ymail.com outlook.com hotmail.com
    live.com msn.com icloud.com me.com mac.com aol.com proton.me protonmail.com pm.me
    gmx.com gmx.net mail.com zoho.com yandex.com
  ].freeze
  EXPERIENCE_LEVELS = [
    "First-time buyer",
    "I've bought or sold a business before",
    "Professional investor / operator"
  ].freeze
  FUNDING_SOURCES = ["Personal Funds", "Family and Friends", "Committed Capital", "SBA", "Bank Loans", "Other"].freeze
  LIQUIDITY_LEVELS = ["Under $250K", "$250K – $1M", "$1M – $5M", "$5M – $25M", "$25M+"].freeze
  GEOGRAPHIES = ["Global", "US East Coast", "US Midwest", "US Mountain", "US Southeast", "US West Coast"].freeze

  # Buyer accounts are reviewed before they get full deal access (OffDeal flow):
  # incomplete (just signed up) -> pending (submitted profile) -> approved/declined.
  APPROVAL_STATUSES = %w[incomplete pending approved declined].freeze

  normalizes :email_address, with: ->(e) { e.strip.downcase }

  validates :email_address, presence: true, uniqueness: true,
            format: { with: URI::MailTo::EMAIL_REGEXP, message: "is not a valid email" }
  validates :name, presence: true
  validates :role, inclusion: { in: ROLES }

  # Approved buyers whose mandate (sector + enterprise-value range) matches a
  # deal — for new-listing alerts. Buyers with no industries aren't alerted.
  scope :matching_deal, ->(deal) {
    buyer.where(approval_status: "approved")
      .where("array_length(mandate_industries, 1) > 0")
      .where("? = ANY (mandate_industries)", deal.industry)
      .where("ev_min IS NULL OR ev_min <= ?", deal.asking_price.to_i)
      .where("ev_max IS NULL OR ev_max >= ?", deal.asking_price.to_i)
  }

  # Find or create a user from a Google OmniAuth callback. New OAuth users land
  # as buyers (the Google flow is the Buyer Network) and go through onboarding.
  def self.from_omniauth(auth)
    return nil unless auth&.info&.email.present?

    user = find_by(provider: auth.provider, uid: auth.uid) || find_by(email_address: auth.info.email) || new(role: "buyer")
    user.provider = auth.provider
    user.uid = auth.uid
    user.email_address = auth.info.email if user.email_address.blank?
    user.name = auth.info.name if user.name.blank?
    user.password = SecureRandom.alphanumeric(24) if user.new_record?
    user.save
    user
  end

  def display_name
    name.presence || email_address.split("@").first
  end

  # A buyer has set their acquisition criteria once they've picked a sector.
  def mandate_set?
    mandate_industries.present?
  end

  def email_domain
    email_address.to_s.split("@").last.to_s.downcase
  end

  def personal_email?
    PERSONAL_EMAIL_DOMAINS.include?(email_domain)
  end

  # Personal-email buyers can only be Individuals; work emails unlock all types.
  def available_buyer_types
    personal_email? ? ["Individual"] : BUYER_TYPES
  end

  def onboarded?
    approval_status != "incomplete"
  end

  def approved?
    approval_status == "approved"
  end
end
