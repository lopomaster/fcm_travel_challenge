require_relative '../lib/reservations/accommodation_reservation'

class BusSegment < TransitReservation

  def initialize(origin:, destination:, start_date:, start_time:, end_time:)
    super(
      transport_type: 'Bus',
      origin: origin,
      destination: destination,
      start_date: start_date,
      start_time: start_time,
      end_time: end_time
    )
  end

  def to_s
    "Bus from #{origin} to #{destination} at #{start_date} #{start_time} to #{end_time}"
  end

end