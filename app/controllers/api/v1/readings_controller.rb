class Api::V1::ReadingsController < ActionController::API
  wrap_parameters false

  rescue_from ActionDispatch::Http::Parameters::ParseError, with: :malformed_json
  rescue_from IngestReading::Unauthorized, with: :unauthorized
  rescue_from IngestReading::InvalidPayload, with: :invalid_payload

  def create
    result = IngestReading.new(
      params: ingest_params,
      remote_ip: request.remote_ip,
      user_agent: request.user_agent
    ).call

    render json: {
      ok: true,
      device: result.device.identifier,
      reading_id: result.reading.id,
      recorded_at: result.reading.recorded_at.iso8601,
      metrics: result.measurements.size
    }, status: :created
  end

  private

  def ingest_params
    request.query_parameters.merge(request.request_parameters).tap do |parameters|
      parameters["key"] ||= bearer_token || request.headers["X-IoT-Collector-Key"].presence
    end
  end

  def bearer_token
    scheme, token = request.authorization.to_s.split(" ", 2)
    token if scheme&.casecmp("Bearer")&.zero?
  end

  def unauthorized
    render json: { ok: false, error: "unauthorized" }, status: :unauthorized
  end

  def invalid_payload(error)
    render json: { ok: false, error: error.message }, status: :unprocessable_entity
  end

  def malformed_json
    render json: { ok: false, error: "malformed JSON" }, status: :bad_request
  end
end
