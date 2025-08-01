require_relative '../reservations/transit_reservation'
require_relative '../reservations/accommodation_reservation'
require_relative 'trip'

class TripBuilder
  def initialize(base_airport)
    @base_airport = base_airport
  end

  def build_trips(reservations)
    all_segments = extract_all_segments(reservations)
    all_segments_ordered = sort_segments_by_date(all_segments)

    transit_segments = all_segments_ordered.select { |s| s.is_a?(TransitReservation) }
    accommodation_segments = all_segments_ordered.select { |s| s.is_a?(AccommodationReservation) }

    reservation_chains = build_chains(transit_segments, accommodation_segments)
    reservation_chains
  end

  private

  def extract_all_segments(reservations)
    reservations.flat_map(&:segments)
  end

  def build_chains(transit_segments, accommodation_segments)
    base_transits = transit_segments.select { |s| s.origin == @base_airport }
    chains = []

    base_transits.each do |start_transit|
      next if already_in_chain?(start_transit, chains)

      chain = build_single_chain(start_transit, transit_segments, accommodation_segments)
      chains << chain if chain.any?
    end

    chains
  end

  def build_single_chain(start_transit, all_transits = [], all_accommodations = [], visited = Set.new)
    return [] if visited.include?(start_transit)

    visited.add(start_transit)
    chain = [start_transit]

    next_reservations = all_transits.select do |t|
      transits_connect_within_24h?(start_transit, t) && !visited.include?(t)
    end

    if next_reservations.empty?
      next_reservations = all_accommodations.select do |s|
        reservation_connect?(start_transit, s) && !visited.include?(s)
      end
    end


    next_reservations.each do |next_reservation|
      chain << next_reservation
      sub_chain = build_single_chain(next_reservation, all_transits, all_accommodations, visited.dup)
      chain.concat(sub_chain)
    end

    chain.uniq
  end

  def transits_connect_within_24h?(reservation, transit2)
    if reservation.is_a?(TransitReservation)
      city = reservation.destination
    else
      city = reservation.location
    end
    return false if city != transit2.origin

    time_diff_hours = ((transit2.start_datetime - reservation.end_datetime) * 24).abs.to_f
    time_diff_hours >= 0 && time_diff_hours < 24
  end

  def reservation_connect?(transit1, transit2)
    if transit1.is_a?(TransitReservation)
      city = transit1.destination
    else
      city = transit1.location
    end

    return false unless city == transit2.location

    time_diff_hours = ((transit2.start_datetime - transit1.end_datetime) * 24).abs.to_f
    time_diff_hours >= 0 && time_diff_hours < 24
  end

  def already_in_chain?(transit, chains)
    chains.any? { |chain| chain.include?(transit) }
  end

  def sort_segments_by_date segments
    segments.sort_by do |segment|
      segment.start_datetime
    end
  end

end