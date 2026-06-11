class User < ApplicationRecord
  has_secure_password
  has_many :sessions, dependent: :destroy

  # A signup picks a role: sellers track their tool runs; buyers get a curated
  # deal feed matching their acquisition mandate.
  ROLES = %w[seller buyer].freeze

  enum :role, { seller: "seller", buyer: "buyer" }, default: "seller"

  normalizes :email_address, with: ->(e) { e.strip.downcase }

  validates :email_address, presence: true, uniqueness: true,
            format: { with: URI::MailTo::EMAIL_REGEXP, message: "is not a valid email" }
  validates :name, presence: true
  validates :role, inclusion: { in: ROLES }

  def display_name
    name.presence || email_address.split("@").first
  end
end
