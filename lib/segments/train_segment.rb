require_relative '../reservations/transit_reservation'


class TrainSegment < TransitReservation
  def initialize(origin:, destination:, start_date:, start_time:, end_time:)
    super(
      transport_type: 'Train',
      origin: origin,
      destination: destination,
      start_date: start_date,
      start_time: start_time,
      end_time: end_time
    )
  end
end