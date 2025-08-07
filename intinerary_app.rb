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

    output_orphaned_segments if @trip_builder.has_orphaned_segments?

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

  def output_orphaned_segments
    puts "=" * 50
    puts "ORPHANED RESERVATIONS (Not connected to trips from #{@base_airport}):"
    puts "=" * 50

    orphaned_transits = @trip_builder.orphaned_segments.select { |s| s.is_a?(TransitReservation) }
    orphaned_accommodations = @trip_builder.orphaned_segments.select { |s| s.is_a?(AccommodationReservation) }

    if orphaned_transits.any?
      puts "TRANSPORTS:"
      orphaned_transits.each_with_index do |segment, index|
        puts "  #{index + 1}. #{segment}"
      end
      puts
    end

    if orphaned_accommodations.any?
      puts "ACCOMMODATIONS:"
      orphaned_accommodations.each_with_index do |segment, index|
        puts "  #{index + 1}. #{segment}"
      end
      puts
    end

    puts "Total orphaned reservations: #{@trip_builder.orphaned_segments.length}"
    puts
  end


end