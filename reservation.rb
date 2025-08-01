class Reservation
  attr_reader :segments

  def initialize
    @segments = []
  end

  def add_segment(segment)
    @segments << segment
  end

  def transit_segments
    @segments.select { |s| s.is_a?(TransitReservation) }
  end

  def accommodation_segments
    @segments.select { |s| s.is_a?(AccommodationReservation) }
  end

end