class ApplicationController < ActionController::Base
  COLLECTOR_COOKIE = :iot_collector_key

  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  private

  attr_reader :collector

  def authenticate_collector!
    supplied_key = params[:key].presence
    key = supplied_key || remembered_collector_key
    @collector = ::Collector.find_by_key(key)

    if @collector
      remember_collector_key(key)
      if supplied_key
        redirect_to keyless_current_url, status: :see_other
      end
      return
    end

    forget_collector_key unless supplied_key

    render "dashboard/access_required", status: :unauthorized
  end

  def remember_collector_key(key)
    cookies.permanent.encrypted[COLLECTOR_COOKIE] = {
      value: key,
      httponly: true,
      same_site: :lax,
      secure: Rails.env.production?
    }
  end

  def forget_collector_key
    cookies.delete(COLLECTOR_COOKIE)
  end

  def remembered_collector_key
    cookies.encrypted[COLLECTOR_COOKIE].to_s
  end

  def keyless_current_url
    query = request.query_parameters.except("key").to_query
    query.present? ? "#{request.path}?#{query}" : request.path
  end
end
