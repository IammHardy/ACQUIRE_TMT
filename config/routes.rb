Rails.application.routes.draw do
  root "public/pages#home"

  scope module: "public" do
    get "sell", to: "pages#sell"
    get "buyers", to: "pages#buyers"
    get "insights", to: "pages#insights"
    get "about", to: "pages#about"
    get "contact", to: "pages#contact"

    get "tools/find-buyers", to: "tools#find_buyers"
    get "tools/valuation", to: "tools#valuation"
    get "tools/market-comps", to: "tools#market_comps"

    post "tools/valuation/analyze", to: "tools#analyze_valuation", as: :analyze_valuation
    post "tools/market-comps/analyze", to: "tools#analyze_market_comps", as: :analyze_market_comps
    post "tools/find-buyers/analyze", to: "tools#analyze_buyers", as: :analyze_buyers

    get "industries/:slug", to: "industries#show", as: :industry

    resources :leads, only: [:create]
  end

  namespace :admin do
    resources :leads, only: [:index, :show, :update]
  end
end