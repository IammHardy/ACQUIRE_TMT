Rails.application.routes.draw do
  resource :session
  resources :passwords, param: :token

  # Google OAuth
  get "/auth/:provider/callback", to: "sessions/omniauth#create"
  get "/auth/failure", to: redirect("/sign_in")

  # Accounts & dashboards (buyer + seller portals)
  get  "sign_up", to: "registrations#new",  as: :sign_up
  post "sign_up", to: "registrations#create"
  get   "sign_in", to: "sessions#new",      as: :sign_in
  get   "dashboard", to: "dashboards#show", as: :dashboard
  patch "dashboard/mandate", to: "buyer_mandates#update", as: :buyer_mandate

  get   "onboarding", to: "onboarding#show", as: :onboarding
  patch "onboarding", to: "onboarding#update"

  get   "settings", to: "settings#show", as: :settings
  patch "settings", to: "settings#update"
  patch "settings/password", to: "settings#update_password", as: :settings_password

  get "my-deals", to: "deals#mine", as: :my_deals
  resources :deals, only: %i[show] do
    post :request_access, on: :member
    post :sign_nda, on: :member
    resources :documents, only: %i[show], controller: "deal_documents"
  end

  root "public/pages#home"

  scope module: "public" do
    get "sell", to: "pages#sell"
    get "buyers", to: "pages#buyers"
    get "insights", to: "pages#insights"
    get "about", to: "pages#about"
    get "careers", to: "pages#careers"
    get "contact", to: "pages#contact"
    get "privacy", to: "pages#privacy"
    get "terms", to: "pages#terms"
    get "disclaimer", to: "pages#disclaimer"

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
    get    "login",  to: "sessions#new",     as: :login
    post   "login",  to: "sessions#create"
    delete "logout", to: "sessions#destroy", as: :logout

    resources :leads, only: [:index, :show, :update]
    resources :deals do
      resources :documents, only: [:create, :destroy], controller: "deal_documents"
      resources :offers, only: [:create, :destroy]
      resources :meetings, only: [:create, :destroy]
    end
    resources :deal_accesses, only: [:index] do
      member do
        patch :approve
        patch :decline
      end
    end
    resources :buyers, only: [:index] do
      member do
        patch :approve
        patch :decline
      end
    end
    # The acquirer ("Buyer" model) network — hand-curated, replaces seed-only data.
    resources :acquirers, controller: "acquirers"
  end
end