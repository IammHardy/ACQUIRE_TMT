class Public::ToolsController < ApplicationController
  ANALYZE_ACTIONS = %i[analyze_valuation analyze_market_comps analyze_buyers].freeze

  # Each analyze action calls the paid Claude API, so cap per-IP request volume
  # to contain cost and scripted abuse. Two layers: a short burst limit and an
  # hourly ceiling. The front-end already caps to 2 attempts via localStorage;
  # this guards the endpoints directly, which that can't.
  rate_limit to: 10, within: 1.minute, name: "analyze-burst",
             only: ANALYZE_ACTIONS, by: -> { request.remote_ip }, with: -> { rate_limited }
  rate_limit to: 40, within: 1.hour, name: "analyze-hourly",
             only: ANALYZE_ACTIONS, by: -> { request.remote_ip }, with: -> { rate_limited }

  def find_buyers
  end

  def valuation
  end

  def market_comps
  end

  # POST /tools/valuation/analyze — analyzes a website with Claude and returns
  # a real valuation range as JSON. Called by the valuation Stimulus controller.
  def analyze_valuation
    website = params[:website].to_s.strip
    revenue = params[:revenue].to_f
    profit  = params[:profit].to_f
    salary  = params[:salary].to_f

    if website.blank?
      return render json: { error: "Please enter your company website." }, status: :unprocessable_entity
    end
    if revenue <= 0 || profit <= 0
      return render json: { error: "Please enter your annual revenue and pre-tax profit." }, status: :unprocessable_entity
    end
    unless ClaudeClient.configured?
      return render json: { error: "The AI valuation engine isn't configured yet. Set ANTHROPIC_API_KEY and restart the server." },
                    status: :service_unavailable
    end

    analysis = WebsiteAnalyzer.new(website).call
    valuation = ValuationEngine.new(
      industry: analysis["industry"],
      revenue: revenue,
      profit: profit,
      salary_addback: salary
    ).call

    track_tool_run(ToolRun.create(
      tool_type: "valuation",
      website: website,
      company_name: analysis["company_name"],
      inputs: { "revenue" => revenue, "profit" => profit, "salary" => salary },
      analysis: analysis,
      result: valuation,
      status: "complete"
    ))

    render json: { analysis: analysis, valuation: valuation }
  rescue ClaudeClient::NotConfigured
    render json: { error: "The AI valuation engine isn't configured yet. Set ANTHROPIC_API_KEY and retry." },
           status: :service_unavailable
  rescue => e
    Rails.logger.error("[analyze_valuation] #{e.class}: #{e.message}")
    ToolRun.create(
      tool_type: "valuation",
      website: website,
      inputs: { "revenue" => revenue, "profit" => profit, "salary" => salary },
      status: "failed",
      error: "#{e.class}: #{e.message}"
    )
    render json: { error: "Something went wrong generating your valuation. Please try again." },
           status: :internal_server_error
  end

  # POST /tools/market-comps/analyze — classifies the website with Claude, then
  # returns a real sector comps snapshot + comparable listings as JSON.
  def analyze_market_comps
    website = params[:website].to_s.strip
    revenue = params[:revenue].to_f
    profit  = params[:profit].to_f

    if website.blank?
      return render json: { error: "Please enter your company website." }, status: :unprocessable_entity
    end
    if revenue <= 0 || profit <= 0
      return render json: { error: "Please enter your annual revenue and pre-tax profit." }, status: :unprocessable_entity
    end
    unless ClaudeClient.configured?
      return render json: { error: AI_NOT_CONFIGURED }, status: :service_unavailable
    end

    analysis = WebsiteAnalyzer.new(website).call
    comps = CompsEngine.new(
      industry: analysis["industry"],
      revenue: revenue,
      earnings: profit
    ).call

    track_tool_run(ToolRun.create(
      tool_type: "market_comps",
      website: website,
      company_name: analysis["company_name"],
      inputs: { "revenue" => revenue, "profit" => profit },
      analysis: analysis,
      result: comps,
      status: "complete"
    ))

    render json: { analysis: analysis, comps: comps }
  rescue ClaudeClient::NotConfigured
    render json: { error: AI_NOT_CONFIGURED }, status: :service_unavailable
  rescue => e
    Rails.logger.error("[analyze_market_comps] #{e.class}: #{e.message}")
    ToolRun.create(
      tool_type: "market_comps",
      website: website,
      inputs: { "revenue" => revenue, "profit" => profit },
      status: "failed",
      error: "#{e.class}: #{e.message}"
    )
    render json: { error: "Something went wrong generating your comps report. Please try again." },
           status: :internal_server_error
  end

  # POST /tools/find-buyers/analyze — classifies the website with Claude, then
  # returns a real buyer-universe estimate + archetypes as JSON. Revenue arrives
  # as a banded label (e.g. "$1M - $5M") from the tool's dropdown.
  def analyze_buyers
    website = params[:website].to_s.strip
    revenue_range = params[:revenue_range].to_s
    profit_range  = params[:profit_range].to_s
    revenue = revenue_from_range(revenue_range)

    if website.blank?
      return render json: { error: "Please enter your company website." }, status: :unprocessable_entity
    end
    unless ClaudeClient.configured?
      return render json: { error: AI_NOT_CONFIGURED }, status: :service_unavailable
    end

    analysis = WebsiteAnalyzer.new(website).call
    # Prefer live data (Consulti/Apollo, + Claude fit ranking) when configured;
    # otherwise fall back to the seeded Buyer dataset.
    buyers = (BuyerSourcer.live? &&
              BuyerSourcer.new(industry: analysis["industry"], revenue: revenue, analysis: analysis).call) ||
             BuyerMatcher.new(industry: analysis["industry"], revenue: revenue).call

    track_tool_run(ToolRun.create(
      tool_type: "buyer_map",
      website: website,
      company_name: analysis["company_name"],
      inputs: { "revenue_range" => revenue_range, "profit_range" => profit_range },
      analysis: analysis,
      result: buyers,
      status: "complete"
    ))

    render json: { analysis: analysis, buyers: buyers }
  rescue ClaudeClient::NotConfigured
    render json: { error: AI_NOT_CONFIGURED }, status: :service_unavailable
  rescue => e
    Rails.logger.error("[analyze_buyers] #{e.class}: #{e.message}")
    ToolRun.create(
      tool_type: "buyer_map",
      website: website,
      inputs: { "revenue_range" => revenue_range, "profit_range" => profit_range },
      status: "failed",
      error: "#{e.class}: #{e.message}"
    )
    render json: { error: "Something went wrong building your BuyerMap. Please try again." },
           status: :internal_server_error
  end

  private

  AI_NOT_CONFIGURED = "The AI engine isn't configured yet. Set ANTHROPIC_API_KEY and restart the server.".freeze

  # Remember the tool runs this visitor generated so they can be linked to the
  # Lead they become when they submit a tool's lead form (see
  # Public::LeadsController#create). Capped to the visitor's recent runs.
  def track_tool_run(run)
    return unless run&.persisted?

    # Public controller doesn't auto-resume the session; do it so a logged-in
    # seller's runs attach to their account immediately.
    resume_session
    run.update_column(:user_id, Current.user.id) if Current.user

    ids = Array(session[:tool_run_ids]) + [run.id]
    session[:tool_run_ids] = ids.uniq.last(10)
  end

  # Rendered when a client trips one of the rate limits above.
  def rate_limited
    render json: { error: "You're going a bit fast. Please wait a moment and try again." },
           status: :too_many_requests
  end

  # Maps a banded revenue label from the BuyerMap dropdown to a representative
  # midpoint dollar figure for the matcher's size scaling.
  def revenue_from_range(label)
    case label
    when "Under $1M"     then 500_000
    when "$1M - $5M"     then 3_000_000
    when "$5M - $25M"    then 15_000_000
    when "$25M - $100M"  then 60_000_000
    when "$100M+"        then 150_000_000
    else 1_000_000
    end
  end
end
