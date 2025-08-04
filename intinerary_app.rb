require_relative 'lib/trip/trip_builder'
require_relative 'reservation_parser'
require_relative 'lib/errors/itinerary_app_errors'

class ItineraryApp
  include ItineraryAppErrors

  def initialize(base_airport = 'SVQ')
    @base_airport = base_airport
    @trip_builder = TripBuilder.new(base_airport)
  end

  def process_file(filename)
    unless File.exist?(filename)
      raise ItineraryAppErrors::ReservationParserError, "File not found #{filename}"
    end

    reservations = ReservationParser.parse_file(filename)
    trips = @trip_builder.build_trips(reservations)

    output_trips(trips)
  rescue ItineraryAppErrors::ReservationParserError => e
    puts "Error processing file: #{e.message}"
    puts_backtrace(e)
    exit 1
  rescue ItineraryAppErrors::ItineraryAppError => e
    puts "Error: #{e.message}"
    puts_backtrace(e)
    exit 1
  rescue => e
    puts "Error: #{e.message}"
    puts_backtrace(e)
    exit 1
  end

  private

  def output_trips(trips)
    trips.each do |trip|
      puts trip
      puts
    end
  end

  def puts_backtrace e
    if ENV['DEBUG']
      puts '----------'
      puts e.backtrace
    end
  end
end