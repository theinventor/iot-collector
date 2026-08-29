class Api::V1::LoggerConfigurationsController < Api::V1::BaseController
  rescue_from ActiveRecord::RecordInvalid, with: :invalid_record

  def show
    slots = collector.victron_slots.where(logger_identifier: logger_identifier).index_by(&:position)

    render json: {
      ok: true,
      logger: logger_identifier,
      updated_at: slots.values.map(&:updated_at).max&.iso8601,
      slots: VictronSlot::POSITIONS.map { |position| slot_json(slots[position], position:) }
    }
  end

  def update_slot
    slot = collector.victron_slots.find_or_initialize_by(
      logger_identifier: logger_identifier,
      position: position
    )
    slot.assign_attributes(slot_params)
    slot.enabled = true
    slot.save!

    render json: { ok: true, logger: logger_identifier, slot: slot_json(slot) }
  end

  def destroy_slot
    slot = collector.victron_slots.find_or_initialize_by(
      logger_identifier: logger_identifier,
      position: position
    )
    slot.disable
    slot.save!

    render json: { ok: true, logger: logger_identifier, slot: slot_json(slot) }
  end

  def discoveries
    configured_macs = collector.victron_slots
      .where(logger_identifier: logger_identifier)
      .where(enabled: true)
      .pluck(:mac_address)

    records = collector.victron_discoveries
      .where(logger_identifier: logger_identifier)
      .order(last_seen_at: :desc, mac_address: :asc)
      .limit(100)

    render json: {
      ok: true,
      logger: logger_identifier,
      discoveries: records.map { |record| discovery_json(record, configured_macs:) }
    }
  end

  def create_discovery
    mac_address = VictronSlot.normalize_mac(discovery_params[:mac_address])
    record = collector.victron_discoveries.find_or_initialize_by(
      logger_identifier: logger_identifier,
      mac_address: mac_address
    )
    record.assign_attributes(discovery_params.except(:mac_address))
    record.last_seen_at = Time.current
    record.save!

    collector.victron_discoveries
      .where(logger_identifier: logger_identifier, last_seen_at: ...30.days.ago)
      .delete_all

    render json: { ok: true, discovery: discovery_json(record, configured_macs: []) }, status: :created
  end

  private

  def logger_identifier
    @logger_identifier ||= Device.normalize_identifier(params[:id])
  end

  def position
    @position ||= Integer(params[:position], exception: false)
    raise ActiveRecord::RecordNotFound unless VictronSlot::POSITIONS.include?(@position)

    @position
  end

  def slot_params
    params.permit(:device_identifier, :name, :mac_address, :bind_key)
  end

  def discovery_params
    params.permit(:mac_address, :product_id, :rssi)
  end

  def slot_json(slot, position: slot&.position)
    return { position: position, managed: false, configured: false } unless slot

    unless slot.enabled?
      return {
        position: slot.position,
        managed: true,
        configured: false,
        updated_at: slot.updated_at.iso8601
      }
    end

    {
      position: slot.position,
      managed: true,
      configured: true,
      device_identifier: slot.device_identifier,
      name: slot.name,
      mac_address: slot.mac_address,
      bind_key: slot.bind_key,
      updated_at: slot.updated_at.iso8601
    }
  end

  def discovery_json(record, configured_macs:)
    {
      mac_address: record.mac_address,
      product_id: record.product_id,
      rssi: record.rssi,
      last_seen_at: record.last_seen_at.iso8601,
      configured: configured_macs.include?(record.mac_address)
    }
  end

  def invalid_record(error)
    render json: { ok: false, error: error.record.errors.full_messages.to_sentence }, status: :unprocessable_entity
  end
end
