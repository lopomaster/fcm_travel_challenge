require_relative '../reservations/transit_reservation'

class FlightSegment < TransitReservation
  def initialize(origin:, destination:, start_date:, start_time:, end_time:)
    super(
      transport_type: 'Flight',
      origin: origin,
      destination: destination,
      start_date: start_date,
      start_time: start_time,
      end_time: end_time
    )
  end
end