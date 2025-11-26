# frozen_string_literal: true

Bookclub::Engine.routes.draw do
  # API endpoints
  scope format: :json do
    # Publications (books/journals)
    get "/publications" => "publications#index"
    get "/publications/:slug" => "publications#show"
    get "/publications/:slug/chapters" => "publications#chapters"
    get "/publications/:slug/toc" => "publications#toc"

    # Chapter content (reading)
    get "/publications/:slug/chapters/:number" => "content#show"
    put "/publications/:slug/chapters/:number/progress" => "content#update_progress"

    # Reading progress
    get "/reading-progress" => "reading_progress#index"
    get "/reading-progress/:publication_slug" => "reading_progress#show"
    put "/reading-progress/:publication_slug" => "reading_progress#update"
    get "/reading-streak" => "reading_progress#streak"

    # Pricing and subscriptions
    get "/publications/:slug/pricing" => "pricing#tiers"
    get "/publications/:slug/subscription" => "pricing#subscription_status"
    post "/publications/:slug/checkout" => "pricing#create_checkout"
    post "/publications/:slug/customer-portal" => "pricing#create_portal_session"
    get "/publications/:slug/subscription-success" => "pricing#success"
    get "/publications/:slug/subscription-cancelled" => "pricing#cancelled"
  end

  # Author dashboard
  scope "/author", as: "author" do
    get "/" => "author_dashboard#index"
    get "/publications" => "author_dashboard#publications"
    get "/publications/:slug" => "author_dashboard#publication"
    get "/publications/:slug/analytics" => "author_dashboard#analytics"
    # Direct slug access (for client-side route compatibility)
    get "/:slug" => "author_dashboard#publication"

    # Chapter management
    post "/publications/:slug/chapters" => "author_dashboard#create_chapter"
    put "/publications/:slug/chapters/reorder" => "author_dashboard#reorder_chapters"
    put "/publications/:slug/chapters/:number" => "author_dashboard#update_chapter"
    delete "/publications/:slug/chapters/:number" => "author_dashboard#delete_chapter"
  end

  # Feedback/reviews (public scholarship)
  scope "/feedback", format: :json do
    get "/publications/:slug/chapters/:number" => "feedback#index"
    post "/publications/:slug/chapters/:number" => "feedback#create"
    put "/feedback/:id" => "feedback#update"
    delete "/feedback/:id" => "feedback#destroy"

    # Suggestions workflow
    post "/suggestions/:id/accept" => "feedback#accept_suggestion"
    post "/suggestions/:id/decline" => "feedback#decline_suggestion"
  end
end
