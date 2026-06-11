class Admin::BuyersController < Admin::BaseController
  before_action :set_buyer, only: %i[approve decline]

  def index
    @buyers = User.buyer.order(created_at: :desc)
  end

  def approve
    @buyer.update(approval_status: "approved")
    redirect_to admin_buyers_path, notice: "#{@buyer.email_address} approved."
  end

  def decline
    @buyer.update(approval_status: "declined")
    redirect_to admin_buyers_path, notice: "Buyer declined."
  end

  private

  def set_buyer
    @buyer = User.buyer.find(params[:id])
  end
end
