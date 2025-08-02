class AccommodationReservation < ReservationSegment
  attr_reader :accommodation_type, :location

  def initialize(accommodation_type:, location:, start_date:, end_date:)
    super(start_date: start_date, end_date: end_date)
    @accommodation_type = accommodation_type
    @location = location
  end

  def start_datetime
    DateTime.parse("#{@start_date} 00:00")
  end

  def end_datetime
    DateTime.parse("#{@end_date} 23:59")
  end

  def accommodation_segment?
    true
  end

  def to_s
    "#{accommodation_type} at #{location} on #{start_date} to #{end_date}"
  end
end