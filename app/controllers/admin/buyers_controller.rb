class Admin::BuyersController < Admin::BaseController
  before_action :set_buyer, only: %i[approve decline]

  def index
    @buyers = User.buyer.order(created_at: :desc)
  end

  def approve
    was_approved = @buyer.approved?
    @buyer.update(approval_status: "approved")
    notify_approved(@buyer) unless was_approved
    redirect_to admin_buyers_path, notice: "#{@buyer.email_address} approved."
  end

  def decline
    @buyer.update(approval_status: "declined")
    redirect_to admin_buyers_path, notice: "Buyer declined."
  end

  private

  # The approval must succeed even if the notification can't be sent, so a mail
  # backend hiccup never 500s the admin action.
  def notify_approved(buyer)
    BuyerMailer.with(user: buyer).approved.deliver_later
  rescue => e
    Rails.logger.error("[Admin::Buyers] approval email failed: #{e.class}: #{e.message}")
  end

  def set_buyer
    @buyer = User.buyer.find(params[:id])
  end
end
