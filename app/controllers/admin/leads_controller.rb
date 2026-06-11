class Admin::LeadsController < Admin::BaseController
  def index
    @leads = Lead.order(created_at: :desc)
  end

  def show
    @lead = Lead.find(params[:id])
  end

  def update
    @lead = Lead.find(params[:id])

    if @lead.update(lead_params)
      redirect_to admin_lead_path(@lead), notice: "Lead updated."
    else
      redirect_to admin_lead_path(@lead), alert: @lead.errors.full_messages.to_sentence
    end
  end

  private

  def lead_params
    params.require(:lead).permit(:status)
  end
end
