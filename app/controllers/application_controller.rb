class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  helper_method :collector_key

  private

  attr_reader :collector

  def authenticate_collector!
    @collector = ::Collector.find_by_key(collector_key)
    return if @collector

    render "dashboard/access_required", status: :unauthorized
  end

  def collector_key
    @collector_key ||= params[:key].to_s
  end
end
