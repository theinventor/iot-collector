Rails.application.routes.draw do
  root "dashboard#index"

  get "up" => "rails/health#show", as: :rails_health_check
  get "devices/:identifier" => "devices#show", as: :device

  namespace :api do
    namespace :v1 do
      match "readings" => "readings#create", via: [ :get, :post ]
      get "status" => "status#show"
      get "loggers/:id/config" => "logger_configurations#show"
      put "loggers/:id/slots/:position" => "logger_configurations#update_slot"
      delete "loggers/:id/slots/:position" => "logger_configurations#destroy_slot"
      get "loggers/:id/discoveries" => "logger_configurations#discoveries"
      post "loggers/:id/discoveries" => "logger_configurations#create_discovery"
      resources :devices, only: [ :index, :show ], param: :id do
        resources :readings, only: :index, controller: "device_readings"
      end
    end
  end
end
