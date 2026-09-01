class ApplicationMailer < ActionMailer::Base
  default from: -> { ENV.fetch("ALERT_FROM_EMAIL", "alerts@iot.sunflower-vacations.com") }
  layout "mailer"
end
