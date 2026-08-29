Rails.application.routes.draw do
  root "dashboard#index"

  get "up" => "rails/health#show", as: :rails_health_check
  get "devices/:id" => "devices#show", as: :device

  namespace :api do
    namespace :v1 do
      match "readings" => "readings#create", via: [ :get, :post ]
    end
  end
end
