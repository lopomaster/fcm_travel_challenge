class Trip
  attr_reader :destination, :segments

  def initialize(destination)
    @destination = destination
    @segments = []
  end

  def add_segments(segments = [])
    @segments = segments
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

  def to_s
    result = ["TRIP to #{destination}"]
    @segments.each { |segment| result << segment.to_s }
    result.join("\n")
  end
end