# Read-only list of seller accounts (sellers don't require approval).
class Admin::SellersController < Admin::BaseController
  def index
    @sellers = User.seller.order(created_at: :desc)
  end
end
