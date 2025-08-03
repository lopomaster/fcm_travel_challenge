require_relative '../lib/reservations/accommodation_reservation'

class ApartmentSegment < AccommodationReservation

  def initialize(city:, start_date:, end_date:)
    super(
      accommodation_type: 'Apartment',
      location: city,
      start_date: start_date,
      end_date: end_date
    )
  end

end