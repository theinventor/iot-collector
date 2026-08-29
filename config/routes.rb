Rails.application.routes.draw do
  root "dashboard#index"

  get "up" => "rails/health#show", as: :rails_health_check
  get "devices/:identifier" => "devices#show", as: :device

  namespace :api do
    namespace :v1 do
      match "readings" => "readings#create", via: [ :get, :post ]
      get "status" => "status#show"
      resources :devices, only: [ :index, :show ], param: :id do
        resources :readings, only: :index, controller: "device_readings"
      end
    end
  end
end
