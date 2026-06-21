class DashboardsController < ApplicationController
  layout "dashboard"
  before_action :require_authentication

  # Single entry point that renders the buyer or seller dashboard by role.
  def show
    @user = Current.user
    if @user.buyer?
      return redirect_to onboarding_path unless @user.onboarded?
      @deals = Deal.for_buyer(@user)
      render :buyer
    else
      @tool_runs = @user.tool_runs.where(status: "complete").order(created_at: :desc)
      @advisor_lead = @user.leads.order(created_at: :desc).first
      # Derive the seller's sector from their most recent tool run so we can show
      # the acquirers actively buying businesses like theirs.
      @sector = @tool_runs.map { |r| r.result["industry"].presence || r.analysis["industry"].presence }.compact.first
      @potential_buyers = potential_buyers_for(@sector)
      # If this seller has a live listing, surface its deal activity.
      @seller_deal = Deal.includes(:offers, :meetings, :deal_accesses).find_by(seller: @user)
      render :seller
    end
  end

  private

  # Uniform shape the seller "Potential buyers" view renders, so a live Apollo
  # company and a seeded Buyer record present identically.
  PotentialBuyer = Struct.new(:name, :category, :thesis, :acquisitions_count, :backed_by, keyword_init: true)

  # Live sourced companies when a provider (Consulti/Apollo) is configured (part
  # of the Find Buyers engine), otherwise the curated seeded acquirers.
  def potential_buyers_for(sector)
    return [] if sector.blank?

    if BuyerSourcer.live? && (sourced = BuyerSourcer.new(industry: sector, revenue: 0).call)
      Array(sourced["buyers"]).map do |b|
        PotentialBuyer.new(name: b["name"], category: "Corporate", thesis: b["rationale"], acquisitions_count: 0, backed_by: nil)
      end
    else
      Buyer.active.where("? = ANY (sectors)", sector).order(acquisitions_count: :desc).to_a
    end
  end
end
