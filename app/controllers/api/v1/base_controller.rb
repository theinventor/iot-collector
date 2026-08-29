class Api::V1::BaseController < ActionController::API
  before_action :authenticate_collector!
  rescue_from ActiveRecord::RecordNotFound, with: :not_found

  private

  attr_reader :collector

  def authenticate_collector!
    @collector = Collector.find_by_key(collector_key)
    return if @collector

    render json: { ok: false, error: "unauthorized" }, status: :unauthorized
  end

  def collector_key
    bearer_token || request.headers["X-IoT-Collector-Key"].presence || params[:key].presence
  end

  def bearer_token
    scheme, token = request.authorization.to_s.split(" ", 2)
    token if scheme&.casecmp("Bearer")&.zero?
  end

  def not_found
    render json: { ok: false, error: "not found" }, status: :not_found
  end
end
