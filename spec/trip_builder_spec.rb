require_relative '../lib/trip/trip_builder'
require_relative '../reservation'
require_relative '../lib/reservations/reservation_segment'
require_relative '../lib/errors/itinerary_app_errors'

Dir["./lib/segments/*.rb"].each {|file| require file }


RSpec.describe TripBuilder do
  let(:base_airport) { 'SVQ' }
  let(:trip_builder) { described_class.new(base_airport) }

  describe '#initialize' do
    it 'sets the base airport' do
      expect(trip_builder.instance_variable_get(:@base_airport)).to eq(base_airport)
    end

    it 'initializes orphaned_segments as empty array' do
      expect(trip_builder.orphaned_segments).to eq([])
    end
  end

  describe '#orphaned_segments' do
    it 'returns the orphaned segments array' do
      expect(trip_builder.orphaned_segments).to be_an(Array)
    end
  end

  describe '#has_orphaned_segments?' do
    context 'when there are no orphaned segments' do
      it 'returns false' do
        expect(trip_builder.has_orphaned_segments?).to be false
      end
    end

    context 'when there are orphaned segments' do
      let(:orphaned_segment) do
        TransitReservation.new(
          transport_type: 'Flight',
          origin: 'BCN',
          destination: 'NYC',
          start_date: '2023-03-02',
          start_time: '15:00',
          end_time: '22:45'
        )
      end

      before do
        trip_builder.instance_variable_set(:@orphaned_segments, [orphaned_segment])
      end

      it 'returns true' do
        expect(trip_builder.has_orphaned_segments?).to be true
      end
    end
  end

  describe '#orphaned_segments_by_type' do
    let(:flight_segment) do
      TransitReservation.new(
        transport_type: 'Flight',
        origin: 'BCN',
        destination: 'NYC',
        start_date: '2023-03-02',
        start_time: '15:00',
        end_time: '22:45'
      )
    end

    let(:hotel_segment) do
      AccommodationReservation.new(
        accommodation_type: 'Hotel',
        location: 'NYC',
        start_date: '2023-03-02',
        end_date: '2023-03-05'
      )
    end

    before do
      trip_builder.instance_variable_set(:@orphaned_segments, [flight_segment, hotel_segment])
    end

    it 'returns segments grouped by type' do
      result = trip_builder.orphaned_segments_by_type

      expect(result[:transit]).to contain_exactly(flight_segment)
      expect(result[:accommodation]).to contain_exactly(hotel_segment)
    end

    context 'with only transit segments' do
      before do
        trip_builder.instance_variable_set(:@orphaned_segments, [flight_segment])
      end

      it 'returns empty accommodation array' do
        result = trip_builder.orphaned_segments_by_type

        expect(result[:transit]).to contain_exactly(flight_segment)
        expect(result[:accommodation]).to be_empty
      end
    end

    context 'with only accommodation segments' do
      before do
        trip_builder.instance_variable_set(:@orphaned_segments, [hotel_segment])
      end

      it 'returns empty transit array' do
        result = trip_builder.orphaned_segments_by_type

        expect(result[:transit]).to be_empty
        expect(result[:accommodation]).to contain_exactly(hotel_segment)
      end
    end
  end

  describe '#orphaned_segments_count' do
    context 'when there are no orphaned segments' do
      it 'returns 0' do
        expect(trip_builder.orphaned_segments_count).to eq(0)
      end
    end

    context 'when there are orphaned segments' do
      let(:segments) do
        [
          TransitReservation.new(
            transport_type: 'Flight',
            origin: 'BCN',
            destination: 'NYC',
            start_date: '2023-03-02',
            start_time: '15:00',
            end_time: '22:45'
          ),
          AccommodationReservation.new(
            accommodation_type: 'Hotel',
            location: 'NYC',
            start_date: '2023-03-02',
            end_date: '2023-03-05'
          )
        ]
      end

      before do
        trip_builder.instance_variable_set(:@orphaned_segments, segments)
      end

      it 'returns the correct count' do
        expect(trip_builder.orphaned_segments_count).to eq(2)
      end
    end
  end

  describe '#build_trips' do

    context 'with orphaned segments' do
      let(:reservations) do
        connected_reservation = Reservation.new
        connected_reservation.add_segment(
          TransitReservation.new(
            transport_type: 'Flight',
            origin: 'SVQ',
            destination: 'BCN',
            start_date: '2023-01-05',
            start_time: '20:40',
            end_time: '22:10'
          )
        )
        connected_reservation.add_segment(
          AccommodationReservation.new(
            accommodation_type: 'Hotel',
            location: 'BCN',
            start_date: '2023-01-05',
            end_date: '2023-01-10'
          )
        )
        connected_reservation.add_segment(
          TransitReservation.new(
            transport_type: 'Flight',
            origin: 'BCN',
            destination: 'SVQ',
            start_date: '2023-01-10',
            start_time: '10:30',
            end_time: '11:50'
          )
        )

        orphaned_reservation = Reservation.new
        orphaned_reservation.add_segment(
          TransitReservation.new(
            transport_type: 'Flight',
            origin: 'BCN',
            destination: 'NYC',
            start_date: '2023-03-02',
            start_time: '15:00',
            end_time: '22:45'
          )
        )

        [connected_reservation, orphaned_reservation]
      end

      it 'builds trips and identifies orphaned segments' do
        trips = trip_builder.build_trips(reservations)

        expect(trips.length).to eq(1)
        expect(trip_builder.has_orphaned_segments?).to be true
        expect(trip_builder.orphaned_segments_count).to eq(1)

        orphaned_segment = trip_builder.orphaned_segments.first
        expect(orphaned_segment).to be_a(TransitReservation)
        expect(orphaned_segment.origin).to eq('BCN')
        expect(orphaned_segment.destination).to eq('NYC')
      end

      it 'correctly categorizes orphaned segments by type' do
        trip_builder.build_trips(reservations)

        by_type = trip_builder.orphaned_segments_by_type
        expect(by_type[:transit].length).to eq(1)
        expect(by_type[:accommodation].length).to eq(0)
      end
    end

    context 'with no orphaned segments' do
      let(:reservations) do
        reservation = Reservation.new
        reservation.add_segment(
          TransitReservation.new(
            transport_type: 'Flight',
            origin: 'SVQ',
            destination: 'BCN',
            start_date: '2023-01-05',
            start_time: '20:40',
            end_time: '22:10'
          )
        )
        reservation.add_segment(
          TransitReservation.new(
            transport_type: 'Flight',
            origin: 'BCN',
            destination: 'SVQ',
            start_date: '2023-01-06',
            start_time: '10:30',
            end_time: '11:50'
          )
        )

        [reservation]
      end

      it 'does not have orphaned segments' do
        trips = trip_builder.build_trips(reservations)

        expect(trips.length).to eq(1)
        expect(trip_builder.has_orphaned_segments?).to be false
        expect(trip_builder.orphaned_segments_count).to eq(0)
      end
    end

    context 'with multiple types of orphaned segments' do
      let(:reservations) do
        # Connected trip
        connected_reservation = Reservation.new
        connected_reservation.add_segment(
          TransitReservation.new(
            transport_type: 'Flight',
            origin: 'SVQ',
            destination: 'MAD',
            start_date: '2023-01-05',
            start_time: '20:40',
            end_time: '22:10'
          )
        )

        orphaned_flight_reservation = Reservation.new
        orphaned_flight_reservation.add_segment(
          TransitReservation.new(
            transport_type: 'Flight',
            origin: 'BCN',
            destination: 'NYC',
            start_date: '2023-03-02',
            start_time: '15:00',
            end_time: '22:45'
          )
        )

        orphaned_hotel_reservation = Reservation.new
        orphaned_hotel_reservation.add_segment(
          AccommodationReservation.new(
            accommodation_type: 'Hotel',
            location: 'PAR',
            start_date: '2023-04-01',
            end_date: '2023-04-05'
          )
        )

        [connected_reservation, orphaned_flight_reservation, orphaned_hotel_reservation]
      end

      it 'identifies both transit and accommodation orphaned segments' do
        trips = trip_builder.build_trips(reservations)

        expect(trip_builder.orphaned_segments_count).to eq(2)

        by_type = trip_builder.orphaned_segments_by_type
        expect(by_type[:transit].length).to eq(1)
        expect(by_type[:accommodation].length).to eq(1)

        transit_segment = by_type[:transit].first
        expect(transit_segment.destination).to eq('NYC')

        accommodation_segment = by_type[:accommodation].first
        expect(accommodation_segment.location).to eq('PAR')
      end
    end

    context 'with simple round trip' do
      let(:reservations) do
        reservation1 = Reservation.new
        reservation1.add_segment(FlightSegment.new(
          origin: 'SVQ',
          destination: 'BCN',
          start_date: '2023-03-02',
          start_time: '06:40',
          end_time: '09:10'
        ))

        reservation2 = Reservation.new
        reservation2.add_segment(FlightSegment.new(
          origin: 'BCN',
          destination: 'SVQ',
          start_date: '2023-03-02',
          start_time: '15:00',
          end_time: '16:30'
        ))

        [reservation1, reservation2]
      end

      it 'builds one trip' do
        trips = trip_builder.build_trips(reservations)
        expect(trips.length).to eq(1)
      end

      it 'creates trip with correct destination' do
        trips = trip_builder.build_trips(reservations)
        expect(trips.first.destination).to eq('BCN')
      end

      it 'includes all segments in the trip' do
        trips = trip_builder.build_trips(reservations)
        expect(trips.first.segments.length).to eq(2)
      end

      it 'sorts segments by date' do
        trips = trip_builder.build_trips(reservations)
        segments = trips.first.segments

        expect(segments.first.start_datetime).to be < segments.last.start_datetime
      end
    end

    describe '#build_trips - reservations with more than 24h' do
      context 'with simple round trip' do
        let(:reservations) do
          reservation1 = Reservation.new
          reservation1.add_segment(FlightSegment.new(
            origin: 'SVQ',
            destination: 'BCN',
            start_date: '2023-03-02',
            start_time: '06:40',
            end_time: '09:10'
          ))

          reservation2 = Reservation.new
          reservation2.add_segment(FlightSegment.new(
            origin: 'SVQ',
            destination: 'MAD',
            start_date: '2023-03-05',
            start_time: '15:00',
            end_time: '16:30'
          ))


          reservation3 = Reservation.new
          reservation3.add_segment(FlightSegment.new(
            origin: 'MAD',
            destination: 'SVQ',
            start_date: '2023-05-05',
            start_time: '15:00',
            end_time: '16:30'
          ))

          [reservation1, reservation2, reservation3]
        end

        it 'builds one trip' do
          trips = trip_builder.build_trips(reservations)
          expect(trips.length).to eq(2)
          expect(trip_builder.orphaned_segments.length).to eq(1)
        end

        it 'creates two trips with correct destination' do
          trips = trip_builder.build_trips(reservations)
          expect(trips.first.destination).to eq('BCN')
          expect(trips.first.segments.size).to eq(1)

          expect(trips.last.destination).to eq('MAD')
          expect(trips.last.segments.size).to eq(1)
        end

        it 'includes all segments in two trip' do
          trips = trip_builder.build_trips(reservations)
          expect(trips.first.segments.length).to eq(1)
          expect(trips.last.segments.length).to eq(1)
        end
      end
    end

    context 'with accommodation' do
      let(:reservations) do
        reservation1 = Reservation.new
        reservation1.add_segment(FlightSegment.new(
          origin: 'SVQ',
          destination: 'BCN',
          start_date: '2023-03-02',
          start_time: '06:40',
          end_time: '09:10'
        ))

        reservation2 = Reservation.new
        reservation2.add_segment(HotelSegment.new(
          city: 'BCN',
          start_date: '2023-03-02',
          end_date: '2023-03-05'
        ))

        reservation3 = Reservation.new
        reservation3.add_segment(FlightSegment.new(
          origin: 'BCN',
          destination: 'SVQ',
          start_date: '2023-03-05',
          start_time: '15:00',
          end_time: '16:30'
        ))

        [reservation1, reservation2, reservation3]
      end

      it 'builds trip with accommodation' do
        trips = trip_builder.build_trips(reservations)

        expect(trips.length).to eq(1)
        expect(trips.first.segments.length).to eq(3)
        expect(trips.first.accommodation_segments.length).to eq(1)
        expect(trips.first.transit_segments.length).to eq(2)
      end

      it 'determines destination based on accommodation' do
        trips = trip_builder.build_trips(reservations)
        expect(trips.first.destination).to eq('BCN')
      end
    end

    context 'with multiple separate trips' do
      let(:reservations) do
        # Trip 1: SVQ -> BCN -> SVQ
        reservation1 = Reservation.new
        reservation1.add_segment(FlightSegment.new(
          origin: 'SVQ',
          destination: 'BCN',
          start_date: '2023-03-02',
          start_time: '06:40',
          end_time: '09:10'
        ))

        reservation2 = Reservation.new
        reservation2.add_segment(FlightSegment.new(
          origin: 'BCN',
          destination: 'SVQ',
          start_date: '2023-03-05',
          start_time: '15:00',
          end_time: '16:30'
        ))

        # Trip 2: SVQ -> MAD -> SVQ
        reservation3 = Reservation.new
        reservation3.add_segment(TrainSegment.new(
          origin: 'SVQ',
          destination: 'MAD',
          start_date: '2023-04-15',
          start_time: '09:30',
          end_time: '11:00'
        ))

        reservation4 = Reservation.new
        reservation4.add_segment(TrainSegment.new(
          origin: 'MAD',
          destination: 'SVQ',
          start_date: '2023-04-17',
          start_time: '17:00',
          end_time: '19:30'
        ))

        [reservation1, reservation2, reservation3, reservation4]
      end

      it 'builds multiple trips' do
        trips = trip_builder.build_trips(reservations)
        expect(trips.length).to eq(2)
      end

      it 'sorts trips by start date' do
        trips = trip_builder.build_trips(reservations)

        expect(trips[0].segments.first.start_datetime).to be < trips[1].segments.first.start_datetime
        expect(trips[0].destination).to eq('BCN')
        expect(trips[1].destination).to eq('MAD')
      end
    end

    context 'with no reservations from base airport' do
      let(:reservations) do
        reservation = Reservation.new
        reservation.add_segment(FlightSegment.new(
          origin: 'BCN',
          destination: 'MAD',
          start_date: '2023-03-02',
          start_time: '06:40',
          end_time: '09:10'
        ))
        [reservation]
      end

      it 'raises error when no reservations from base airport' do
        expect { trip_builder.build_trips(reservations) }
          .to raise_error(ItineraryAppErrors::ItineraryAppError, /There are not reservations from SVQ/)
      end
    end

    context 'with complex trip chain' do
      let(:reservations) do
        # SVQ -> BCN -> NYC
        reservation1 = Reservation.new
        reservation1.add_segment(FlightSegment.new(
          origin: 'SVQ',
          destination: 'BCN',
          start_date: '2023-03-02',
          start_time: '06:40',
          end_time: '09:10'
        ))

        reservation2 = Reservation.new
        reservation2.add_segment(FlightSegment.new(
          origin: 'BCN',
          destination: 'NYC',
          start_date: '2023-03-02',
          start_time: '15:00',
          end_time: '22:45'
        ))

        [reservation1, reservation2]
      end

      it 'builds connected trip chain' do
        trips = trip_builder.build_trips(reservations)

        expect(trips.length).to eq(1)
        expect(trips.first.segments.length).to eq(2)
        expect(trips.first.destination).to eq('NYC')
      end
    end
  end

  describe 'private methods' do
    describe '#extract_all_segments' do
      let(:reservations) do
        flight_segment = FlightSegment.new(
          origin: 'SVQ',
          destination: 'BCN',
          start_date: '2023-03-02',
          start_time: '06:40',
          end_time: '09:10'
        )
        hotel_segment = HotelSegment.new(
            city: 'BCN',
            start_date: '2023-03-02',
            end_date: '2023-03-05'
        )

        reservation1 = Reservation.new
        reservation1.add_segment(flight_segment)

        reservation2 = Reservation.new
        reservation2.add_segment(hotel_segment)

        [reservation1, reservation2]
      end

      it 'extracts all segments from reservations' do
        segments = trip_builder.send(:extract_all_segments, reservations)
        expect(segments.length).to eq(2)
      end
    end

    describe '#sort_segments_by_date' do
      let(:segments) do
        [
          FlightSegment.new(
            origin: 'SVQ',
            destination: 'BCN',
            start_date: '2023-03-05',
            start_time: '15:00',
            end_time: '16:30'
          ),
          FlightSegment.new(
            origin: 'SVQ',
            destination: 'MAD',
            start_date: '2023-03-02',
            start_time: '06:40',
            end_time: '09:10'
          )
        ]
      end

      it 'sorts segments by start datetime' do
        sorted_segments = trip_builder.send(:sort_segments_by_date, segments)

        expect(sorted_segments.first.start_datetime).to be < sorted_segments.last.start_datetime
        expect(sorted_segments.first.destination).to eq('MAD')
        expect(sorted_segments.last.destination).to eq('BCN')
      end
    end

    describe '#transits_connect_within_24h?' do
      let(:first_transit) do
        FlightSegment.new(
          origin: 'SVQ',
          destination: 'BCN',
          start_date: '2023-03-02',
          start_time: '06:40',
          end_time: '09:10'
        )
      end

      context 'when transits connect within 24 hours' do
        let(:second_transit) do
          FlightSegment.new(
            origin: 'BCN',
            destination: 'NYC',
            start_date: '2023-03-02',
            start_time: '15:00',
            end_time: '22:45'
          )
        end

        it 'returns true' do
          result = trip_builder.send(:transits_connect_within_24h?, first_transit, second_transit)
          expect(result).to be true
        end
      end

      context 'when transits do not connect (different cities)' do
        let(:second_transit) do
          FlightSegment.new(
            origin: 'MAD',
            destination: 'NYC',
            start_date: '2023-03-02',
            start_time: '15:00',
            end_time: '22:45'
          )
        end

        it 'returns false' do
          result = trip_builder.send(:transits_connect_within_24h?, first_transit, second_transit)
          expect(result).to be false
        end
      end

      context 'when transits connect but outside 24h window' do
        let(:second_transit) do
          FlightSegment.new(
            origin: 'BCN',
            destination: 'NYC',
            start_date: '2023-03-04',
            start_time: '15:00',
            end_time: '22:45'
          )
        end

        it 'returns false' do
          result = trip_builder.send(:transits_connect_within_24h?, first_transit, second_transit)
          expect(result).to be false
        end
      end
    end

    describe '#determine_final_destination' do
      context 'with accommodation' do
        let(:chain) do
          [
            FlightSegment.new(
              origin: 'SVQ',
              destination: 'BCN',
              start_date: '2023-03-02',
              start_time: '06:40',
              end_time: '09:10'
            ),
            HotelSegment.new(
              city: 'BCN',
              start_date: '2023-03-02',
              end_date: '2023-03-05'
            )
          ]
        end

        it 'returns accommodation location' do
          destination = trip_builder.send(:determine_final_destination, chain)
          expect(destination).to eq('BCN')
        end
      end

      context 'without accommodation' do
        let(:chain) do
          [
            FlightSegment.new(
              origin: 'SVQ',
              destination: 'BCN',
              start_date: '2023-03-02',
              start_time: '06:40',
              end_time: '09:10'
            ),
            FlightSegment.new(
              origin: 'BCN',
              destination: 'NYC',
              start_date: '2023-03-02',
              start_time: '15:00',
              end_time: '22:45'
            )
          ]
        end

        it 'returns final non-base destination' do
          destination = trip_builder.send(:determine_final_destination, chain)
          expect(destination).to eq('NYC')
        end
      end

      context 'with empty chain' do
        let(:chain) { [] }

        it 'returns nil' do
          destination = trip_builder.send(:determine_final_destination, chain)
          expect(destination).to be_nil
        end
      end
    end
  end
end