class Admin::DealAccessesController < Admin::BaseController
  before_action :set_access, only: %i[approve decline]

  def index
    @accesses = DealAccess.includes(:user, :deal).order(created_at: :desc)
  end

  def approve
    @access.update(status: "approved")
    redirect_to admin_deal_accesses_path, notice: "Access approved for #{@access.user.email_address}."
  end

  def decline
    @access.update(status: "declined")
    redirect_to admin_deal_accesses_path, notice: "Access declined."
  end

  private

  def set_access
    @access = DealAccess.find(params[:id])
  end
end
