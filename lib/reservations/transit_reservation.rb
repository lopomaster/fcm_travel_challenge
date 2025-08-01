require_relative 'reservation_segment'

class TransitReservation < ReservationSegment
  attr_reader :transport_type, :origin, :destination, :start_time, :end_time

  def initialize(transport_type:, origin:, destination:, start_date:, start_time:, end_time:)
    super(start_date: start_date)
    @transport_type = transport_type
    @origin = origin
    @destination = destination
    @start_date_time = start_time
    @end_time = end_time
  end

  def start_datetime
    DateTime.parse("#{@start_date} #{@start_time}")
  end

  def end_datetime
    DateTime.parse("#{@start_date} #{@end_time}")
  end

  def to_s
    "#{transport_type} from #{origin} to #{destination} at #{start_date} #{start_time} to #{end_time}"
  end

end
