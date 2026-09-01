namespace :alerts do
  desc "Evaluate missing telemetry, schedule reminders, and deliver queued notifications"
  task process: :environment do
    AlertProcessor.new.call
  end
end
