require_relative '../reservations/accommodation_reservation'


class HotelSegment < AccommodationReservation
  def initialize(city:, start_date:, end_date:)
    super(
      accommodation_type: 'Hotel',
      location: city,
      start_date: start_date,
      end_date: end_date
    )
  end
end
