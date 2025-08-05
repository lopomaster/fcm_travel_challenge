require_relative './support/test_helpers'
require_relative '../lib/segments/flight_segment'
require_relative '../lib/segments/train_segment'
require_relative '../lib/segments/hotel_segment'
require_relative '../reservation'
require_relative '../lib/trip/trip'

RSpec.describe Reservation do
  let(:reservation) { described_class.new }
  let(:flight_segment) { create_flight_segment }
  let(:hotel_segment) { create_hotel_segment }
  let(:train_segment) { create_train_segment }

  describe '#initialize' do
    it 'initializes with empty segments' do
      expect(reservation.segments).to be_empty
    end
  end

  describe '#add_segment' do
    it 'adds a segment to the reservation' do
      reservation.add_segment(flight_segment)
      expect(reservation.segments).to include(flight_segment)
    end

    it 'can add multiple segments' do
      reservation.add_segment(flight_segment)
      reservation.add_segment(hotel_segment)

      expect(reservation.segments.length).to eq(2)
      expect(reservation.segments).to include(flight_segment, hotel_segment)
    end
  end

  describe '#transit_segments' do
    before do
      reservation.add_segment(flight_segment)
      reservation.add_segment(hotel_segment)
      reservation.add_segment(train_segment)
    end

    it 'returns only transit segments' do
      transit_segments = reservation.transit_segments

      expect(transit_segments.length).to eq(2)
      expect(transit_segments).to all(be_a(TransitReservation))
      expect(transit_segments).to include(flight_segment, train_segment)
    end

    it 'does not include accommodation segments' do
      transit_segments = reservation.transit_segments
      expect(transit_segments).not_to include(hotel_segment)
    end
  end

  describe '#accommodation_segments' do
    before do
      reservation.add_segment(flight_segment)
      reservation.add_segment(hotel_segment)
      reservation.add_segment(train_segment)
    end

    it 'returns only accommodation segments' do
      accommodation_segments = reservation.accommodation_segments

      expect(accommodation_segments.length).to eq(1)
      expect(accommodation_segments).to all(be_a(AccommodationReservation))
      expect(accommodation_segments).to include(hotel_segment)
    end

    it 'does not include transit segments' do
      accommodation_segments = reservation.accommodation_segments
      expect(accommodation_segments).not_to include(flight_segment, train_segment)
    end
  end
end

RSpec.describe Trip do
  let(:trip) { described_class.new('BCN') }
  let(:flight_segment) { create_flight_segment }
  let(:hotel_segment) { create_hotel_segment }
  let(:train_segment) { create_train_segment }

  describe '#initialize' do
    it 'initializes with destination and empty segments' do
      expect(trip.destination).to eq('BCN')
      expect(trip.segments).to be_empty
    end
  end

  describe '#add_segment' do
    it 'adds a segment to the trip' do
      trip.add_segment(flight_segment)
      expect(trip.segments).to include(flight_segment)
    end

    it 'can add multiple segments' do
      trip.add_segment(flight_segment)
      trip.add_segment(hotel_segment)

      expect(trip.segments.length).to eq(2)
      expect(trip.segments).to include(flight_segment, hotel_segment)
    end
  end

  describe '#add_segments' do
    it 'replaces segments with new array' do
      segments = [flight_segment, hotel_segment]
      trip.add_segments(segments)

      expect(trip.segments).to eq(segments)
    end

    it 'handles empty array' do
      trip.add_segment(flight_segment)
      trip.add_segments([])

      expect(trip.segments).to be_empty
    end
  end

  describe '#transit_segments' do
    before do
      trip.add_segment(flight_segment)
      trip.add_segment(hotel_segment)
      trip.add_segment(train_segment)
    end

    it 'returns only transit segments' do
      transit_segments = trip.transit_segments

      expect(transit_segments.length).to eq(2)
      expect(transit_segments).to all(be_a(TransitReservation))
      expect(transit_segments).to include(flight_segment, train_segment)
    end
  end

  describe '#accommodation_segments' do
    before do
      trip.add_segment(flight_segment)
      trip.add_segment(hotel_segment)
      trip.add_segment(train_segment)
    end

    it 'returns only accommodation segments' do
      accommodation_segments = trip.accommodation_segments

      expect(accommodation_segments.length).to eq(1)
      expect(accommodation_segments).to all(be_a(AccommodationReservation))
      expect(accommodation_segments).to include(hotel_segment)
    end
  end

  describe '#to_s' do
    before do
      trip.add_segment(flight_segment)
      trip.add_segment(hotel_segment)
    end

    it 'returns formatted string representation' do
      output = trip.to_s

      expect(output).to include("TRIP to BCN")
      expect(output).to include(flight_segment.to_s)
      expect(output).to include(hotel_segment.to_s)
    end

    it 'includes all segments in output' do
      lines = trip.to_s.split("\n")

      expect(lines.length).to eq(3)
      expect(lines[0]).to eq("TRIP to BCN")
      expect(lines[1]).to eq(flight_segment.to_s)
      expect(lines[2]).to eq(hotel_segment.to_s)
    end
  end
end