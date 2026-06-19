# An upcoming meeting with a buyer on a seller's deal.
class Meeting < ApplicationRecord
  belongs_to :deal

  validates :buyer_name, presence: true

  scope :upcoming, -> { where("scheduled_at IS NULL OR scheduled_at >= ?", Time.current).order(:scheduled_at) }
end
