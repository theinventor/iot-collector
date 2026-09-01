Rails.application.routes.draw do
  root "dashboard#index"

  get "up" => "rails/health#show", as: :rails_health_check
  resource :access, only: [ :create, :destroy ], controller: "collector_access"
  resource :settings, only: [ :show, :update ]
  resources :notification_channels, only: [ :new, :create, :edit, :update, :destroy ] do
    post :test, on: :member
  end
  resources :devices, only: :show, param: :identifier do
    resource :battery_profile, only: [ :create, :update, :destroy ]
    resources :alert_rules, only: [ :new, :create, :edit, :update ] do
      post :toggle, on: :member
    end
    resource :alert_presets, only: :create
    resources :alert_incidents, only: [] do
      post :acknowledge, on: :member
      post :snooze, on: :member
    end
  end

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
