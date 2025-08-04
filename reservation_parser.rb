require_relative 'reservation'
require_relative 'lib/errors/itinerary_app_errors'
Dir["./lib/segments/*.rb"].each {|file| require file }
Dir["./extended_segments_samples/*.rb"].each {|file| require file }

class ReservationParser
  include ItineraryAppErrors

  TRANSPORT_TYPES = %w[Flight Train Bus].freeze
  ACCOMMODATION_TYPES = %w[Hotel Apartment].freeze

  def self.parse_file(filename)
    reservations = []
    current_reservation = nil

    File.foreach(filename) do |line|
      line = line.strip
      next if line.empty?

      if line == 'RESERVATION'
        reservations << current_reservation if current_reservation
        current_reservation = Reservation.new
      elsif line.start_with?('SEGMENT:')
        segment = parse_segment(line)
        current_reservation&.add_segment(segment)
      else
        # Ignore
        puts "Skipping invalid line: #{line}"
      end
    end

    reservations << current_reservation if current_reservation
    reservations
  end

  private

  def self.parse_segment(line)
    type_match = line.match(/^SEGMENT: (\w+)/)
    raise ItineraryAppErrors::ReservationParserError, "Invalid segment format" unless type_match

    segment_type = type_match[1]

    if TRANSPORT_TYPES.include?(segment_type)
      parse_transport_segment(line, segment_type)
    elsif ACCOMMODATION_TYPES.include?(segment_type)
      parse_accommodation_segment(line, segment_type)
    else
      raise ItineraryAppErrors::ReservationParserError, "Unknown segment type: #{segment_type}"
    end
  end

  def self.parse_transport_segment(line, type)
    # Pattern: SEGMENT: Type ABC 2024-12-25 14:30 -> DEF 16:45

    flexible_pattern = /^SEGMENT: #{type} (\S+) (\S+) (\S+) -> (\S+) (\S+)$/
    flexible_match = line.match(flexible_pattern)

    raise ItineraryAppErrors::ReservationParserError, "Invalid #{type.downcase} segment format" unless flexible_match

    origin, date, start_time, destination, end_time = flexible_match[1..5]

    validate_iata_code_length(origin, "origin")
    validate_iata_code_length(destination, "destination")

    strict_pattern = /^SEGMENT: #{type} (\S{3}) (\d{4}-\d{2}-\d{2}) (\d{2}:\d{2}) -> (\S{3}) (\d{2}:\d{2})$/
    strict_match = line.match(strict_pattern)

    raise ItineraryAppErrors::ReservationParserError, "Invalid #{type.downcase} segment format" unless strict_match

    validate_iata_code(origin, "origin")
    validate_iata_code(destination, "destination")
    validate_date(date)
    validate_time(start_time)
    validate_time(end_time)

    segment_class = Object.const_get("#{type}Segment")
    segment_class.new(
      origin: origin,
      destination: destination,
      start_date: date,
      start_time: start_time,
      end_time: end_time
    )
  end

  def self.parse_accommodation_segment(line, type)
    # Pattern: SEGMENT: Type ABC 2024-12-25 -> 2024-12-27

    flexible_pattern = /^SEGMENT: #{type} (\S+) (\S+) -> (\S+)$/
    flexible_match = line.match(flexible_pattern)

    raise ItineraryAppErrors::ReservationParserError, "Invalid #{type.downcase} segment format" unless flexible_match

    city, start_date, end_date = flexible_match[1..3]

    validate_iata_code_length(city, "city")

    strict_pattern = /^SEGMENT: #{type} (\S{3}) (\d{4}-\d{2}-\d{2}) -> (\d{4}-\d{2}-\d{2})$/
    strict_match = line.match(strict_pattern)

    raise ItineraryAppErrors::ReservationParserError, "Invalid #{type.downcase} segment format" unless strict_match

    validate_iata_code(city, "city")
    validate_date(start_date)
    validate_date(end_date)
    validate_date_range(start_date, end_date)

    segment_class = Object.const_get("#{type}Segment")
    segment_class.new(
      city: city,
      start_date: start_date,
      end_date: end_date
    )
  end

  def self.validate_iata_code(code, field_name)
    unless code.match?(/^[A-Z]{3}$/)
      raise ItineraryAppErrors::ReservationParserError, "Invalid IATA #{field_name} format: #{code}. Must be 3 uppercase letters"
    end
  end

  def self.validate_iata_code_length(code, field_name)
    unless code.length == 3
      raise ItineraryAppErrors::ReservationParserError, "Invalid IATA #{field_name} code: #{code}. Must be exactly 3 characters"
    end
  end

  def self.validate_date(date_str)
    unless date_str.match?(/^\d{4}-\d{2}-\d{2}$/)
      raise ItineraryAppErrors::ReservationParserError, "Invalid date format: #{date_str}. Must be YYYY-MM-DD"
    end

    begin
      Date.parse(date_str)
    rescue Date::Error
      raise ItineraryAppErrors::ReservationParserError, "Invalid date: #{date_str}"
    end
  end

  def self.validate_time(time_str)
    unless time_str.match?(/^\d{2}:\d{2}$/)
      raise ItineraryAppErrors::ReservationParserError, "Invalid time format: #{time_str}. Must be HH:MM"
    end

    hour, minute = time_str.split(':').map(&:to_i)
    raise ItineraryAppErrors::ReservationParserError, "Invalid hour: #{hour}" unless (0..23).include?(hour)
    raise ItineraryAppErrors::ReservationParserError, "Invalid minute: #{minute}" unless (0..59).include?(minute)
  end

  def self.validate_date_range(start_date, end_date)
    start_d = Date.parse(start_date)
    end_d = Date.parse(end_date)

    if end_d <= start_d
      raise ItineraryAppErrors::ReservationParserError, "End date (#{end_date}) must be after start date (#{start_date})"
    end
  end

end