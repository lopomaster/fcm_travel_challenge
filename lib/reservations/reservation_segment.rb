require 'date'


class ReservationSegment
  attr_reader :start_date, :end_date

  def initialize(start_date:, end_date: nil)
    @start_date = parse_date(start_date)
    @end_date = end_date ? parse_date(end_date) : @start_date
  end

  def start_datetime
    raise NotImplementedError, "Subclasses must implement start_datetime"
  end

  def end_datetime
    raise NotImplementedError, "Subclasses must implement end_datetime"
  end

  private

  def parse_date(date_str)
    Date.parse(date_str)
  end

end