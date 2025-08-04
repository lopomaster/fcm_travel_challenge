require_relative 'spec_helper'
require_relative 'support/test_helpers'
require_relative '../reservation_parser'
require_relative '../reservation'
require_relative '../lib/errors/itinerary_app_errors'

Dir[File.join(File.dirname(__FILE__), '../lib/segments/*.rb')].each { |file| require file }
Dir[File.join(File.dirname(__FILE__), '../extended_segments_samples/*.rb')].each { |file| require file }

RSpec.describe ReservationParser do
  let(:test_file) { 'spec/fixtures/parser_test_input.txt' }

  before do
    Dir.mkdir('spec') unless Dir.exist?('spec')
    Dir.mkdir('spec/fixtures') unless Dir.exist?('spec/fixtures')
  end

  after do
    cleanup_test_file(test_file)
  end

  describe '.parse_file' do
    context 'with valid transport segments' do
      let(:file_content) do
        <<~CONTENT
          RESERVATION
          SEGMENT: Flight SVQ 2023-03-02 06:40 -> BCN 09:10

          RESERVATION
          SEGMENT: Train MAD 2023-02-15 09:30 -> SVQ 11:00

          RESERVATION
          SEGMENT: Bus BCN 2023-04-20 17:00 -> MAD 19:30
        CONTENT
      end

      it 'parses all transport segment types correctly' do
        create_test_file(test_file, file_content)
        reservations = described_class.parse_file(test_file)

        expect(reservations.length).to eq(3)
        expect(reservations[0].segments.first).to be_a(FlightSegment)
        expect(reservations[1].segments.first).to be_a(TrainSegment)
        expect(reservations[2].segments.first).to be_a(BusSegment)
      end

      it 'creates flight segment with correct attributes' do
        create_test_file(test_file, file_content)
        reservations = described_class.parse_file(test_file)
        flight = reservations[0].segments.first

        expect(flight.transport_type).to eq('Flight')
        expect(flight.origin).to eq('SVQ')
        expect(flight.destination).to eq('BCN')
        expect(flight.start_date.to_s).to eq('2023-03-02')
        expect(flight.start_time).to eq('06:40')
        expect(flight.end_time).to eq('09:10')
        expect(flight.start_datetime).to eq(DateTime.parse('2023-03-02 06:40'))
        expect(flight.end_datetime).to eq(DateTime.parse('2023-03-02 09:10'))
      end

      it 'creates train segment with correct attributes' do
        create_test_file(test_file, file_content)
        reservations = described_class.parse_file(test_file)
        train = reservations[1].segments.first

        expect(train.transport_type).to eq('Train')
        expect(train.origin).to eq('MAD')
        expect(train.destination).to eq('SVQ')
        expect(train.start_date.to_s).to eq('2023-02-15')
        expect(train.start_time).to eq('09:30')
        expect(train.end_time).to eq('11:00')
      end

      it 'creates bus segment with correct attributes' do
        create_test_file(test_file, file_content)
        reservations = described_class.parse_file(test_file)
        bus = reservations[2].segments.first

        expect(bus.transport_type).to eq('Bus')
        expect(bus.origin).to eq('BCN')
        expect(bus.destination).to eq('MAD')
      end
    end

    context 'with valid accommodation segments' do
      let(:file_content) do
        <<~CONTENT
          RESERVATION
          SEGMENT: Hotel BCN 2023-01-05 -> 2023-01-10

          RESERVATION
          SEGMENT: Apartment MAD 2023-02-15 -> 2023-02-17
        CONTENT
      end

      it 'parses all accommodation segment types correctly' do
        create_test_file(test_file, file_content)
        reservations = described_class.parse_file(test_file)

        expect(reservations.length).to eq(2)
        expect(reservations[0].segments.first).to be_a(HotelSegment)
        expect(reservations[1].segments.first).to be_a(ApartmentSegment)
      end

      it 'creates hotel segment with correct attributes' do
        create_test_file(test_file, file_content)
        reservations = described_class.parse_file(test_file)
        hotel = reservations[0].segments.first

        expect(hotel.accommodation_type).to eq('Hotel')
        expect(hotel.location).to eq('BCN')
        expect(hotel.start_date.to_s).to eq('2023-01-05')
        expect(hotel.end_date.to_s).to eq('2023-01-10')
        expect(hotel.start_datetime).to eq(DateTime.parse('2023-01-05 00:00'))
        expect(hotel.end_datetime).to eq(DateTime.parse('2023-01-10 23:59'))
      end

      it 'creates apartment segment with correct attributes' do
        create_test_file(test_file, file_content)
        reservations = described_class.parse_file(test_file)
        apartment = reservations[1].segments.first

        expect(apartment.accommodation_type).to eq('Apartment')
        expect(apartment.location).to eq('MAD')
        expect(apartment.start_date.to_s).to eq('2023-02-15')
        expect(apartment.end_date.to_s).to eq('2023-02-17')
      end
    end

    context 'with multiple segments in one reservation' do
      let(:file_content) do
        <<~CONTENT
          RESERVATION
          SEGMENT: Flight SVQ 2023-01-05 20:40 -> BCN 22:10
          SEGMENT: Hotel BCN 2023-01-05 -> 2023-01-10
          SEGMENT: Flight BCN 2023-01-10 10:30 -> SVQ 11:50
        CONTENT
      end

      it 'groups all segments under one reservation' do
        create_test_file(test_file, file_content)
        reservations = described_class.parse_file(test_file)

        expect(reservations.length).to eq(1)
        expect(reservations[0].segments.length).to eq(3)
        expect(reservations[0].segments[0]).to be_a(FlightSegment)
        expect(reservations[0].segments[1]).to be_a(HotelSegment)
        expect(reservations[0].segments[2]).to be_a(FlightSegment)
      end

      it 'separates transit and accommodation segments correctly' do
        create_test_file(test_file, file_content)
        reservations = described_class.parse_file(test_file)
        reservation = reservations[0]

        transit_segments = reservation.transit_segments
        accommodation_segments = reservation.accommodation_segments

        expect(transit_segments.length).to eq(2)
        expect(accommodation_segments.length).to eq(1)
        expect(transit_segments.all? { |s| s.is_a?(TransitReservation) }).to be true
        expect(accommodation_segments.all? { |s| s.is_a?(AccommodationReservation) }).to be true
      end
    end

    context 'with complex mixed reservations' do
      let(:file_content) do
        <<~CONTENT
          RESERVATION
          SEGMENT: Flight SVQ 2023-03-02 06:40 -> BCN 09:10

          RESERVATION
          SEGMENT: Hotel BCN 2023-03-02 -> 2023-03-05
          SEGMENT: Apartment BCN 2023-03-05 -> 2023-03-07

          RESERVATION
          SEGMENT: Train BCN 2023-03-07 14:30 -> MAD 17:00
          SEGMENT: Bus MAD 2023-03-10 18:00 -> SVQ 20:30

          RESERVATION
          SEGMENT: Flight SVQ 2023-06-15 08:00 -> BCN 09:30
          SEGMENT: Flight BCN 2023-06-15 12:00 -> NYC 19:45
        CONTENT
      end

      it 'handles complex mixed reservation patterns' do
        create_test_file(test_file, file_content)
        reservations = described_class.parse_file(test_file)

        expect(reservations.length).to eq(4)

        expect(reservations[0].segments.length).to eq(1)
        expect(reservations[0].segments.first).to be_a(FlightSegment)

        expect(reservations[1].segments.length).to eq(2)
        expect(reservations[1].segments.all? { |s| s.is_a?(AccommodationReservation) }).to be true

        expect(reservations[2].segments.length).to eq(2)
        expect(reservations[2].segments.all? { |s| s.is_a?(TransitReservation) }).to be true

        expect(reservations[3].segments.length).to eq(2)
        expect(reservations[3].segments.all? { |s| s.is_a?(FlightSegment) }).to be true
      end
    end

    context 'with invalid transport segment input' do
      context 'IATA code length errors' do
        let(:test_cases) do
          [
            {
              name: 'origin too short',
              content: 'SEGMENT: Flight SV 2023-03-02 06:40 -> BCN 09:10',
              error: /Invalid IATA origin code: SV. Must be exactly 3 characters/
            },
            {
              name: 'origin too long',
              content: 'SEGMENT: Train SVQX 2023-02-15 09:30 -> MAD 11:00',
              error: /Invalid IATA origin code: SVQX. Must be exactly 3 characters/
            },
            {
              name: 'destination too short',
              content: 'SEGMENT: Bus MAD 2023-04-20 17:00 -> BC 19:30',
              error: /Invalid IATA destination code: BC. Must be exactly 3 characters/
            },
            {
              name: 'destination too long',
              content: 'SEGMENT: Flight SVQ 2023-03-02 06:40 -> BCNX 09:10',
              error: /Invalid IATA destination code: BCNX. Must be exactly 3 characters/
            }
          ]
        end

        it 'raises specific IATA length errors for each case' do
          test_cases.each do |test_case|
            file_content = "RESERVATION\n#{test_case[:content]}"
            create_test_file(test_file, file_content)

            expect { described_class.parse_file(test_file) }
              .to raise_error(ItineraryAppErrors::ReservationParserError, test_case[:error])

            cleanup_test_file(test_file)
          end
        end
      end

      context 'IATA code format errors' do
        let(:test_cases) do
          [
            {
              name: 'origin lowercase',
              content: 'SEGMENT: Flight svq 2023-03-02 06:40 -> BCN 09:10',
              error: /Invalid IATA origin format: svq. Must be 3 uppercase letters/
            },
            {
              name: 'origin with numbers',
              content: 'SEGMENT: Train SV1 2023-02-15 09:30 -> MAD 11:00',
              error: /Invalid IATA origin format: SV1. Must be 3 uppercase letters/
            },
            {
              name: 'destination lowercase',
              content: 'SEGMENT: Bus MAD 2023-04-20 17:00 -> bcn 19:30',
              error: /Invalid IATA destination format: bcn. Must be 3 uppercase letters/
            },
            {
              name: 'destination with special chars',
              content: 'SEGMENT: Flight SVQ 2023-03-02 06:40 -> BC@ 09:10',
              error: /Invalid IATA destination format: BC@. Must be 3 uppercase letters/
            }
          ]
        end

        it 'raises specific IATA format errors for each case' do
          test_cases.each do |test_case|
            file_content = "RESERVATION\n#{test_case[:content]}"
            create_test_file(test_file, file_content)

            expect { described_class.parse_file(test_file) }
              .to raise_error(ItineraryAppErrors::ReservationParserError, test_case[:error])

            cleanup_test_file(test_file)
          end
        end
      end

      context 'date and time format errors' do
        let(:test_cases) do
          [
            {
              name: 'invalid date format',
              content: 'SEGMENT: Flight SVQ 2023/03/02 06:40 -> BCN 09:10',
              error: /Invalid flight segment format/
            },
            {
              name: 'invalid start time format',
              content: 'SEGMENT: Train SVQ 2023-02-15 9:30 -> MAD 11:00',
              error: /Invalid train segment format/
            },
            {
              name: 'invalid end time format',
              content: 'SEGMENT: Bus MAD 2023-04-20 17:00 -> BCN 19:3',
              error: /Invalid bus segment format/
            },
            {
              name: 'invalid hour',
              content: 'SEGMENT: Flight SVQ 2023-03-02 25:40 -> BCN 09:10',
              error: /Invalid hour: 25/
            },
            {
              name: 'invalid minute',
              content: 'SEGMENT: Train SVQ 2023-02-15 09:60 -> MAD 11:00',
              error: /Invalid minute: 60/
            }
          ]
        end

        it 'raises appropriate errors for date/time format issues' do
          test_cases.each do |test_case|
            file_content = "RESERVATION\n#{test_case[:content]}"
            create_test_file(test_file, file_content)

            expect { described_class.parse_file(test_file) }
              .to raise_error(ItineraryAppErrors::ReservationParserError, test_case[:error])

            cleanup_test_file(test_file)
          end
        end
      end
    end

    context 'with invalid accommodation segment input' do
      context 'IATA city code length errors' do
        let(:test_cases) do
          [
            {
              name: 'hotel city too short',
              content: 'SEGMENT: Hotel BC 2023-01-05 -> 2023-01-10',
              error: /Invalid IATA city code: BC. Must be exactly 3 characters/
            },
            {
              name: 'hotel city too long',
              content: 'SEGMENT: Hotel BCNX 2023-01-05 -> 2023-01-10',
              error: /Invalid IATA city code: BCNX. Must be exactly 3 characters/
            },
            {
              name: 'apartment city too short',
              content: 'SEGMENT: Apartment M 2023-02-15 -> 2023-02-17',
              error: /Invalid IATA city code: M. Must be exactly 3 characters/
            },
            {
              name: 'apartment city too long',
              content: 'SEGMENT: Apartment MADRID 2023-02-15 -> 2023-02-17',
              error: /Invalid IATA city code: MADRID. Must be exactly 3 characters/
            }
          ]
        end

        it 'raises specific IATA city length errors' do
          test_cases.each do |test_case|
            file_content = "RESERVATION\n#{test_case[:content]}"
            create_test_file(test_file, file_content)

            expect { described_class.parse_file(test_file) }
              .to raise_error(ItineraryAppErrors::ReservationParserError, test_case[:error])

            cleanup_test_file(test_file)
          end
        end
      end

      context 'IATA city code format errors' do
        let(:test_cases) do
          [
            # {
            #   name: 'hotel city lowercase',
            #   content: 'SEGMENT: Hotel bcn 2023-01-05 -> 2023-01-10',
            #   error: /Invalid IATA city format: bcn. Must be 3 uppercase letters/
            # },
            # {
            #   name: 'apartment city with numbers',
            #   content: 'SEGMENT: Apartment BC1 2023-02-15 -> 2023-02-17',
            #   error: /Invalid IATA city format: BC1. Must be 3 uppercase letters/
            # },
            {
              name: 'hotel city with special chars',
              content: 'SEGMENT: Hotel BC@ 2023-01-05 -> 2023-01-10',
              error: /Invalid IATA city format: BC@. Must be 3 uppercase letters/
            }
          ]
        end

        it 'raises specific IATA city format errors' do
          test_cases.each do |test_case|
            file_content = "RESERVATION\n#{test_case[:content]}"
            create_test_file(test_file, file_content)

            expect { described_class.parse_file(test_file) }
              .to raise_error(ItineraryAppErrors::ReservationParserError, test_case[:error])

            cleanup_test_file(test_file)
          end
        end
      end

      context 'date format and range errors' do
        let(:test_cases) do
          [
            {
              name: 'invalid start date format',
              content: 'SEGMENT: Hotel BCN 2023/01/05 -> 2023-01-10',
              error: /Invalid hotel segment format/
            },
            {
              name: 'invalid end date format',
              content: 'SEGMENT: Apartment MAD 2023-02-15 -> 2023/02/17',
              error: /Invalid apartment segment format/
            },
            {
              name: 'end date before start date',
              content: 'SEGMENT: Hotel BCN 2023-01-10 -> 2023-01-05',
              error: /End date \(2023-01-05\) must be after start date \(2023-01-10\)/
            },
            {
              name: 'same start and end date',
              content: 'SEGMENT: Apartment MAD 2023-02-15 -> 2023-02-15',
              error: /End date \(2023-02-15\) must be after start date \(2023-02-15\)/
            }
          ]
        end

        it 'raises appropriate errors for date issues' do
          test_cases.each do |test_case|
            file_content = "RESERVATION\n#{test_case[:content]}"
            create_test_file(test_file, file_content)

            expect { described_class.parse_file(test_file) }
              .to raise_error(ItineraryAppErrors::ReservationParserError, test_case[:error])

            cleanup_test_file(test_file)
          end
        end
      end
    end

    context 'with unknown segment types' do
      let(:file_content) do
        <<~CONTENT
          RESERVATION
          SEGMENT: Car SVQ 2023-03-02 06:40 -> BCN 09:10

          RESERVATION
          SEGMENT: Cruise BCN 2023-01-05 -> 2023-01-10

          RESERVATION
          SEGMENT: Helicopter MAD 2023-02-15 09:30 -> SVQ 11:00
        CONTENT
      end

      it 'raises errors for unknown segment types' do
        create_test_file(test_file, file_content)

        expect { described_class.parse_file(test_file) }
          .to raise_error(ItineraryAppErrors::ReservationParserError, /Unknown segment type: Car/)
      end
    end

    context 'with edge cases and malformed input' do
      context 'empty and whitespace handling' do
        let(:file_content) do
          <<~CONTENT
            RESERVATION
            SEGMENT: Flight SVQ 2023-03-02 06:40 -> BCN 09:10

            

            RESERVATION
            SEGMENT: Hotel BCN 2023-01-05 -> 2023-01-10
            
            # This is a comment
            Invalid line that should be skipped
            
          CONTENT
        end

        it 'handles empty lines and invalid content gracefully' do
          create_test_file(test_file, file_content)

          expect { described_class.parse_file(test_file) }
            .to output(/Skipping invalid line/).to_stdout

          reservations = described_class.parse_file(test_file)
          expect(reservations.length).to eq(2)
          expect(reservations[0].segments.first).to be_a(FlightSegment)
          expect(reservations[1].segments.first).to be_a(HotelSegment)
        end
      end

      context 'file with only invalid content' do
        let(:file_content) do
          <<~CONTENT
            # Just comments
            Invalid line 1
            Another invalid line
            Not a valid reservation
          CONTENT
        end

        it 'returns empty array for file with no valid reservations' do
          create_test_file(test_file, file_content)

          expect { described_class.parse_file(test_file) }
            .to output(/Skipping invalid line/).to_stdout

          reservations = described_class.parse_file(test_file)
          expect(reservations).to be_empty
        end
      end

      context 'completely empty file' do
        let(:file_content) { '' }

        it 'returns empty array for empty file' do
          create_test_file(test_file, file_content)
          reservations = described_class.parse_file(test_file)
          expect(reservations).to be_empty
        end
      end

      context 'reservation without segments' do
        let(:file_content) do
          <<~CONTENT
            RESERVATION

            RESERVATION
            SEGMENT: Flight SVQ 2023-03-02 06:40 -> BCN 09:10
          CONTENT
        end

        it 'handles reservation without segments' do
          create_test_file(test_file, file_content)
          reservations = described_class.parse_file(test_file)

          expect(reservations.length).to eq(2)
          expect(reservations[0].segments.length).to eq(0)
          expect(reservations[1].segments.length).to eq(1)
        end
      end
    end
  end

  describe 'private validation methods' do
    describe '.validate_iata_code_length' do
      it 'accepts valid 3-character codes' do
        expect { described_class.send(:validate_iata_code_length, 'SVQ', 'origin') }.not_to raise_error
        expect { described_class.send(:validate_iata_code_length, 'BCN', 'destination') }.not_to raise_error
        expect { described_class.send(:validate_iata_code_length, 'MAD', 'city') }.not_to raise_error
      end

      it 'rejects codes that are too short' do
        expect { described_class.send(:validate_iata_code_length, 'SV', 'origin') }
          .to raise_error(ItineraryAppErrors::ReservationParserError, /Invalid IATA origin code: SV. Must be exactly 3 characters/)

        expect { described_class.send(:validate_iata_code_length, 'B', 'destination') }
          .to raise_error(ItineraryAppErrors::ReservationParserError, /Invalid IATA destination code: B. Must be exactly 3 characters/)
      end

      it 'rejects codes that are too long' do
        expect { described_class.send(:validate_iata_code_length, 'SVQX', 'origin') }
          .to raise_error(ItineraryAppErrors::ReservationParserError, /Invalid IATA origin code: SVQX. Must be exactly 3 characters/)

        expect { described_class.send(:validate_iata_code_length, 'BARCELONA', 'city') }
          .to raise_error(ItineraryAppErrors::ReservationParserError, /Invalid IATA city code: BARCELONA. Must be exactly 3 characters/)
      end
    end

    describe '.validate_iata_code' do
      it 'accepts valid IATA codes' do
        expect { described_class.send(:validate_iata_code, 'SVQ', 'origin') }.not_to raise_error
        expect { described_class.send(:validate_iata_code, 'BCN', 'destination') }.not_to raise_error
        expect { described_class.send(:validate_iata_code, 'MAD', 'city') }.not_to raise_error
      end

      it 'rejects codes with lowercase letters' do
        expect { described_class.send(:validate_iata_code, 'svq', 'origin') }
          .to raise_error(ItineraryAppErrors::ReservationParserError, /Invalid IATA origin format: svq. Must be 3 uppercase letters/)

        expect { described_class.send(:validate_iata_code, 'Bcn', 'destination') }
          .to raise_error(ItineraryAppErrors::ReservationParserError, /Invalid IATA destination format: Bcn. Must be 3 uppercase letters/)
      end

      it 'rejects codes with numbers' do
        expect { described_class.send(:validate_iata_code, 'SV1', 'origin') }
          .to raise_error(ItineraryAppErrors::ReservationParserError, /Invalid IATA origin format: SV1. Must be 3 uppercase letters/)

        expect { described_class.send(:validate_iata_code, '123', 'city') }
          .to raise_error(ItineraryAppErrors::ReservationParserError, /Invalid IATA city format: 123. Must be 3 uppercase letters/)
      end

      it 'rejects codes with special characters' do
        expect { described_class.send(:validate_iata_code, 'SV@', 'origin') }
          .to raise_error(ItineraryAppErrors::ReservationParserError, /Invalid IATA origin format: SV@. Must be 3 uppercase letters/)

        expect { described_class.send(:validate_iata_code, 'BC-', 'destination') }
          .to raise_error(ItineraryAppErrors::ReservationParserError, /Invalid IATA destination format: BC-. Must be 3 uppercase letters/)
      end
    end

    describe '.validate_date' do
      it 'accepts valid dates' do
        expect { described_class.send(:validate_date, '2023-03-02') }.not_to raise_error
        expect { described_class.send(:validate_date, '2024-12-31') }.not_to raise_error
        expect { described_class.send(:validate_date, '2023-01-01') }.not_to raise_error
        expect { described_class.send(:validate_date, '2023-02-28') }.not_to raise_error
      end

      it 'rejects invalid date formats' do
        expect { described_class.send(:validate_date, '2023/03/02') }
          .to raise_error(ItineraryAppErrors::ReservationParserError, /Invalid date format: 2023\/03\/02. Must be YYYY-MM-DD/)

        expect { described_class.send(:validate_date, '23-03-02') }
          .to raise_error(ItineraryAppErrors::ReservationParserError, /Invalid date format: 23-03-02. Must be YYYY-MM-DD/)

        expect { described_class.send(:validate_date, '2023-3-2') }
          .to raise_error(ItineraryAppErrors::ReservationParserError, /Invalid date format: 2023-3-2. Must be YYYY-MM-DD/)
      end

      it 'rejects invalid dates' do
        expect { described_class.send(:validate_date, '2023-13-01') }
          .to raise_error(ItineraryAppErrors::ReservationParserError, /Invalid date: 2023-13-01/)

        expect { described_class.send(:validate_date, '2023-02-30') }
          .to raise_error(ItineraryAppErrors::ReservationParserError, /Invalid date: 2023-02-30/)

        expect { described_class.send(:validate_date, '2023-04-31') }
          .to raise_error(ItineraryAppErrors::ReservationParserError, /Invalid date: 2023-04-31/)
      end
    end

    describe '.validate_time' do
      it 'accepts valid times' do
        expect { described_class.send(:validate_time, '06:40') }.not_to raise_error
        expect { described_class.send(:validate_time, '23:59') }.not_to raise_error
        expect { described_class.send(:validate_time, '00:00') }.not_to raise_error
        expect { described_class.send(:validate_time, '12:30') }.not_to raise_error
      end

      it 'rejects invalid time formats' do
        expect { described_class.send(:validate_time, '6:40') }
          .to raise_error(ItineraryAppErrors::ReservationParserError, /Invalid time format: 6:40. Must be HH:MM/)

        expect { described_class.send(:validate_time, '06:4') }
          .to raise_error(ItineraryAppErrors::ReservationParserError, /Invalid time format: 06:4. Must be HH:MM/)

        expect { described_class.send(:validate_time, '6:4') }
          .to raise_error(ItineraryAppErrors::ReservationParserError, /Invalid time format: 6:4. Must be HH:MM/)
      end

      it 'rejects invalid times' do
        expect { described_class.send(:validate_time, '25:00') }
          .to raise_error(ItineraryAppErrors::ReservationParserError, /Invalid hour: 25/)

        expect { described_class.send(:validate_time, '12:60') }
          .to raise_error(ItineraryAppErrors::ReservationParserError, /Invalid minute: 60/)

        expect { described_class.send(:validate_time, '24:00') }
          .to raise_error(ItineraryAppErrors::ReservationParserError, /Invalid hour: 24/)
      end
    end

    describe '.validate_date_range' do
      it 'accepts valid date ranges' do
        expect { described_class.send(:validate_date_range, '2023-01-05', '2023-01-10') }.not_to raise_error
        expect { described_class.send(:validate_date_range, '2023-02-15', '2023-02-17') }.not_to raise_error
        expect { described_class.send(:validate_date_range, '2023-12-31', '2024-01-01') }.not_to raise_error
      end

      it 'rejects ranges where end date is before start date' do
        expect { described_class.send(:validate_date_range, '2023-01-10', '2023-01-05') }
          .to raise_error(ItineraryAppErrors::ReservationParserError, /End date \(2023-01-05\) must be after start date \(2023-01-10\)/)
      end

      it 'rejects ranges where end date equals start date' do
        expect { described_class.send(:validate_date_range, '2023-01-05', '2023-01-05') }
          .to raise_error(ItineraryAppErrors::ReservationParserError, /End date \(2023-01-05\) must be after start date \(2023-01-05\)/)
      end
    end
  end

  describe 'error priority and consistency' do
    it 'prioritizes IATA length errors over format errors' do
      file_content = "RESERVATION\nSEGMENT: Flight sv 2023-03-02 06:40 -> BCN 09:10"
      create_test_file(test_file, file_content)

      expect { described_class.parse_file(test_file) }
        .to raise_error(ItineraryAppErrors::ReservationParserError, /Invalid IATA origin code: sv. Must be exactly 3 characters/)
    end

    it 'prioritizes IATA errors over date/time format errors' do
      file_content = "RESERVATION\nSEGMENT: Flight SV 2023/03/02 06:40 -> BCN 09:10"
      create_test_file(test_file, file_content)

      expect { described_class.parse_file(test_file) }
        .to raise_error(ItineraryAppErrors::ReservationParserError, /Invalid IATA origin code: SV. Must be exactly 3 characters/)
    end

    it 'provides consistent error messages across segment types' do
      transport_content = "RESERVATION\nSEGMENT: Flight SV 2023-03-02 06:40 -> BCN 09:10"
      accommodation_content = "RESERVATION\nSEGMENT: Hotel SV 2023-01-05 -> 2023-01-10"

      # Transport segment error
      create_test_file(test_file, transport_content)
      expect { described_class.parse_file(test_file) }
        .to raise_error(ItineraryAppErrors::ReservationParserError, /Invalid IATA origin code: SV. Must be exactly 3 characters/)

      cleanup_test_file(test_file)

      create_test_file(test_file, accommodation_content)
      expect { described_class.parse_file(test_file) }
        .to raise_error(ItineraryAppErrors::ReservationParserError, /Invalid IATA city code: SV. Must be exactly 3 characters/)
    end
  end
end