class Admin::MeetingsController < Admin::BaseController
  before_action :set_deal

  def create
    if @deal.meetings.create(meeting_params).persisted?
      redirect_to edit_admin_deal_path(@deal), notice: "Meeting added."
    else
      redirect_to edit_admin_deal_path(@deal), alert: "Couldn't add meeting (buyer name required)."
    end
  end

  def destroy
    @deal.meetings.find(params[:id]).destroy
    redirect_to edit_admin_deal_path(@deal), notice: "Meeting removed."
  end

  private

  def set_deal
    @deal = Deal.find(params[:deal_id])
  end

  def meeting_params
    params.require(:meeting).permit(:buyer_name, :scheduled_at, :note, :status)
  end
end
