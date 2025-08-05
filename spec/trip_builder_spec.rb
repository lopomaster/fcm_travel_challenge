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
  end

  describe '#build_trips' do
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