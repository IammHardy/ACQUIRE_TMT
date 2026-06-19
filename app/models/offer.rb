# A buyer's offer on a seller's deal (shown in the seller dashboard's Offers tab).
class Offer < ApplicationRecord
  belongs_to :deal

  validates :buyer_name, presence: true

  def structure_label
    if equity_rollover_pct.to_i.positive?
      ["#{upfront_cash_pct}% upfront", "#{equity_rollover_pct}% equity rollover"]
    else
      ["#{upfront_cash_pct}% upfront", "#{seller_note_pct}% seller note"]
    end
  end
end
