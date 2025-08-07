require_relative './spec_helper'
require_relative 'support/test_helpers'
require_relative '../reservation_parser'
require_relative '../intinerary_app'
require_relative '../lib/trip/trip_builder'
require_relative '../lib/trip/trip'
require_relative '../lib/errors/itinerary_app_errors'

Dir[File.join(File.dirname(__FILE__), '../lib/segments/*.rb')].each { |file| require file }
Dir[File.join(File.dirname(__FILE__), '../extended_segments_samples/*.rb')].each { |file| require file }

RSpec.describe ItineraryApp do
  let(:base_airport) { 'SVQ' }
  let(:app) { described_class.new(base_airport) }
  let(:test_file) { 'spec/fixtures/test_input.txt' }

  describe '#initialize' do
    it 'sets base airport' do
      expect(app.instance_variable_get(:@base_airport)).to eq(base_airport)
    end

    it 'creates a TripBuilder instance' do
      trip_builder = app.instance_variable_get(:@trip_builder)
      expect(trip_builder).to be_a(TripBuilder)
    end

    it 'uses default base airport if none provided' do
      default_app = described_class.new
      expect(default_app.instance_variable_get(:@base_airport)).to eq('SVQ')
    end
  end

  describe '#process_file' do
    before do
      Dir.mkdir('spec') unless Dir.exist?('spec')
      Dir.mkdir('spec/fixtures') unless Dir.exist?('spec/fixtures')
      File.write(test_file, file_content)
    end

    after do
      File.delete(test_file) if File.exist?(test_file)
    end

    context 'with valid input file' do
      let(:file_content) do
        <<~CONTENT
          RESERVATION
          SEGMENT: Flight SVQ 2023-03-02 06:40 -> BCN 09:10

          RESERVATION
          SEGMENT: Hotel BCN 2023-03-02 -> 2023-03-05

          RESERVATION
          SEGMENT: Flight BCN 2023-03-05 15:00 -> SVQ 16:30
        CONTENT
      end

      it 'processes file successfully' do
        expect { app.process_file(test_file) }.to output(/TRIP to BCN/).to_stdout
      end

      it 'outputs trip information' do
        output = capture_stdout { app.process_file(test_file) }

        expect(output).to include('TRIP to BCN')
        expect(output).to include('Flight from SVQ to BCN')
        expect(output).to include('Hotel at BCN')
        expect(output).to include('Flight from BCN to SVQ')
      end

      it 'does not output orphaned segments section when all segments are connected' do
        output = capture_stdout { app.process_file(test_file) }

        expect(output).not_to include('ORPHANED RESERVATIONS')
        expect(output).not_to include('TRANSPORTS:')
        expect(output).not_to include('ACCOMMODATIONS:')
        expect(output).not_to include('Total orphaned reservations:')
      end
    end

    context 'with multiple trips' do
      let(:file_content) do
        <<~CONTENT
          RESERVATION
          SEGMENT: Flight SVQ 2023-03-02 06:40 -> BCN 09:10

          RESERVATION
          SEGMENT: Flight BCN 2023-03-05 15:00 -> SVQ 16:30

          RESERVATION
          SEGMENT: Train SVQ 2023-04-15 09:30 -> MAD 11:00

          RESERVATION
          SEGMENT: Train MAD 2023-04-17 17:00 -> SVQ 19:30
        CONTENT
      end

      it 'outputs multiple trips' do
        output = capture_stdout { app.process_file(test_file) }

        expect(output).to include('TRIP to BCN')
        expect(output).to include('TRIP to MAD')
      end

      it 'separates trips with blank lines' do
        output = capture_stdout { app.process_file(test_file) }
        trips = output.split(/\n\s*\n/)

        expect(trips.length).to be >= 2
      end
    end

    context 'with orphaned segments' do
      let(:base_airport) { 'SVQ' }

      let(:file_content) do
        <<~CONTENT
          RESERVATION
          SEGMENT: Flight SVQ 2023-01-05 20:40 -> BCN 22:10

          RESERVATION
          SEGMENT: Hotel BCN 2023-01-05 -> 2023-01-10

          RESERVATION
          SEGMENT: Flight BCN 2023-01-10 10:30 -> SVQ 11:50

          RESERVATION
          SEGMENT: Flight BCN 2023-03-02 15:00 -> NYC 22:45

          RESERVATION
          SEGMENT: Hotel PAR 2023-04-01 -> 2023-04-05
        CONTENT
      end

      it 'outputs orphaned segments section when orphans are present' do
        output = capture_stdout { app.process_file(test_file) }

        expect(output).to include('ORPHANED RESERVATIONS (Not connected to trips from SVQ):')
      end

      it 'outputs transports section for orphaned transit segments' do
        output = capture_stdout { app.process_file(test_file) }

        expect(output).to include('TRANSPORTS:')
        expect(output).to include('Flight from BCN to NYC at 2023-03-02 15:00 to 22:45')
      end

      it 'outputs accommodations section for orphaned accommodation segments' do
        output = capture_stdout { app.process_file(test_file) }

        expect(output).to include('ACCOMMODATIONS:')
        expect(output).to include('Hotel at PAR on 2023-04-01 to 2023-04-05')
      end

      it 'numbers orphaned segments correctly within each category' do
        output = capture_stdout { app.process_file(test_file) }

        expect(output).to match(/TRANSPORTS:\s*\n\s+1\. Flight from BCN to NYC/)
        expect(output).to match(/ACCOMMODATIONS:\s*\n\s+1\. Hotel at PAR/)
      end

      it 'outputs total count of orphaned reservations' do
        output = capture_stdout { app.process_file(test_file) }

        expect(output).to include('Total orphaned reservations: 2')
      end

      it 'separates orphaned section from trips with divider line' do
        output = capture_stdout { app.process_file(test_file) }

        expect(output).to match(/={50}/)
        expect(output).to match(/TRIP to BCN.*={50}.*ORPHANED RESERVATIONS/m)
      end
    end

    context 'with only orphaned transport segments' do
      let(:file_content) do
        <<~CONTENT
          RESERVATION
          SEGMENT: Flight SVQ 2023-01-05 20:40 -> BCN 22:10

          RESERVATION
          SEGMENT: Flight BCN 2023-01-10 10:30 -> SVQ 11:50

          RESERVATION
          SEGMENT: Flight BCN 2023-03-02 15:00 -> NYC 22:45

          RESERVATION
          SEGMENT: Train MAD 2023-04-15 09:30 -> PAR 15:00
        CONTENT
      end

      it 'outputs only transports section, not accommodations' do
        output = capture_stdout { app.process_file(test_file) }

        expect(output).to include('TRANSPORTS:')
        expect(output).not_to include('ACCOMMODATIONS:')
        expect(output).to include('Total orphaned reservations: 3')
      end

      it 'numbers multiple transport segments correctly' do
        output = capture_stdout { app.process_file(test_file) }

        expect(output).to match(/1\. Flight from BCN to SVQ/)
        expect(output).to match(/2\. Flight from BCN to NYC/)
        expect(output).to match(/3\. Train from MAD to PAR/)
      end
    end

    context 'with only orphaned accommodation segments' do
      let(:file_content) do
        <<~CONTENT
          RESERVATION
          SEGMENT: Flight SVQ 2023-01-05 20:40 -> BCN 22:10

          RESERVATION
          SEGMENT: Flight BCN 2023-01-10 10:30 -> SVQ 11:50

          RESERVATION
          SEGMENT: Hotel PAR 2023-04-01 -> 2023-04-05

          RESERVATION
          SEGMENT: Apartment NYC 2023-05-01 -> 2023-05-07
        CONTENT
      end

      it 'outputs only accommodations section, not transports' do
        output = capture_stdout { app.process_file(test_file) }

        expect(output).to include('ACCOMMODATIONS:')
        expect(output).to include('TRANSPORTS:')
        expect(output).to include('Total orphaned reservations: 3')
      end

      it 'numbers multiple accommodation segments correctly' do
        output = capture_stdout { app.process_file(test_file) }

        expect(output).to match(/1\. Hotel at PAR/)
        expect(output).to match(/2\. Apartment at NYC/)
      end
    end

    context 'with mixed orphaned segments from different reservations' do
      let(:file_content) do
        <<~CONTENT
          RESERVATION
          SEGMENT: Flight SVQ 2023-01-05 20:40 -> BCN 22:10
          SEGMENT: Flight BCN 2023-01-10 10:30 -> SVQ 11:50

          RESERVATION
          SEGMENT: Flight BCN 2023-03-02 15:00 -> NYC 22:45

          RESERVATION
          SEGMENT: Train NYC 2023-03-05 10:00 -> WAS 14:00

          RESERVATION
          SEGMENT: Hotel PAR 2023-04-01 -> 2023-04-05

          RESERVATION
          SEGMENT: Apartment LON 2023-05-01 -> 2023-05-07
        CONTENT
      end

      it 'correctly categorizes and counts all orphaned segments' do
        output = capture_stdout { app.process_file(test_file) }

        expect(output).to include('TRANSPORTS:')
        expect(output).to include('ACCOMMODATIONS:')
        expect(output).to include('Total orphaned reservations: 5')

        # Verify transport segments
        expect(output).to include('Flight from BCN to NYC')
        expect(output).to include('Train from NYC to WAS')

        # Verify accommodation segments
        expect(output).to include('Hotel at PAR')
        expect(output).to include('Apartment at LON')
      end
    end

    context 'with different base airports' do
      let(:madrid_app) { described_class.new('MAD') }
      let(:file_content) do
        <<~CONTENT
          RESERVATION
          SEGMENT: Flight MAD 2023-01-05 20:40 -> BCN 22:10

          RESERVATION
          SEGMENT: Flight SVQ 2023-03-02 15:00 -> NYC 22:45
        CONTENT
      end

      it 'shows correct base airport in orphaned segments header' do
        output = capture_stdout { madrid_app.process_file(test_file) }

        expect(output).to include('ORPHANED RESERVATIONS (Not connected to trips from MAD):')
        expect(output).to include('Flight from SVQ to NYC')
      end
    end

    context 'with parser errors' do
      let(:file_content) do
        <<~CONTENT
          RESERVATION
          SEGMENT: Flight INVALID 2023-03-02 06:40 -> BCN 09:10
        CONTENT
      end

      it 'handles ReservationParserError gracefully' do
        expect { app.process_file(test_file) }
          .to output(/Error processing file/).to_stdout
                                             .and raise_error(SystemExit) { |error| expect(error.status).to eq(1) }
      end

      it 'shows error message without backtrace by default' do
        expect { app.process_file(test_file) }
          .to output(/Error processing file: Invalid IATA origin code: INVALID. Must be exactly 3 characters/).to_stdout
                                                                                                              .and raise_error(SystemExit)
      end

      context 'with DEBUG mode enabled' do
        before { ENV['DEBUG'] = '1' }
        after { ENV.delete('DEBUG') }

        it 'shows backtrace in debug mode' do
          expect { app.process_file(test_file) }
            .to output(/Error processing file.*reservation_parser\.rb.*validate_iata_code_length/m).to_stdout
                                                                                                   .and raise_error(SystemExit)
        end
      end
    end

    context 'with itinerary app errors' do
      let(:file_content) do
        <<~CONTENT
          RESERVATION
          SEGMENT: Flight BCN 2023-03-02 06:40 -> MAD 09:10
        CONTENT
      end

      it 'handles ItineraryAppError gracefully' do
        expect { app.process_file(test_file) }
          .to output(/Error: There are not reservations from SVQ/).to_stdout
                                                                  .and raise_error(SystemExit) { |error| expect(error.status).to eq(1) }
      end
    end

    context 'with empty file' do
      let(:file_content) { '' }

      it 'handles empty file gracefully' do
        expect { app.process_file(test_file) }
          .to output(/Error: There are not reservations from SVQ/).to_stdout
                                                                  .and raise_error(SystemExit)
      end
    end

    context 'with non-existent file' do
      let(:file_content) { nil }

      it 'raises appropriate error' do
        expect { app.process_file('non_existent_file.txt') }
          .to output(/Error processing file: File not found non_existent_file.txt/).to_stdout
                                                                                   .and raise_error(SystemExit) { |error| expect(error.status).to eq(1) }
      end
    end
  end

  describe 'private methods' do
    describe '#output_trips' do
      let(:trips) do
        trip1 = Trip.new('BCN')
        trip1.add_segment(create_flight_segment)

        trip2 = Trip.new('MAD')
        trip2.add_segment(create_train_segment)

        [trip1, trip2]
      end

      it 'outputs each trip followed by blank line' do
        output = capture_stdout { app.send(:output_trips, trips) }

        lines = output.split("\n")
        expect(lines).to include('TRIP to BCN')
        expect(lines).to include('TRIP to MAD')

        # Check for blank lines between trips
        expect(output).to match(/TRIP to BCN.*\n.*\n\nTRIP to MAD/m)
      end
    end

    describe '#output_orphaned_segments' do
      let(:trip_builder) { app.instance_variable_get(:@trip_builder) }

      before do
        allow(trip_builder).to receive(:orphaned_segments).and_return(orphaned_segments)
      end

      context 'with mixed orphaned segments' do
        let(:orphaned_segments) do
          [
            create_flight_segment(origin: 'BCN', destination: 'NYC', date: '2023-03-02', start_time: '15:00', end_time: '22:45'),
            create_train_segment(origin: 'MAD', destination: 'PAR', date: '2023-04-15', start_time: '09:30', end_time: '15:00'),
            create_hotel_segment(city: 'PAR', start_date: '2023-04-01', end_date: '2023-04-05'),
            create_apartment_segment(city: 'LON', start_date: '2023-05-01', end_date: '2023-05-07')
          ]
        end

        it 'outputs correct header with base airport' do
          output = capture_stdout { app.send(:output_orphaned_segments) }

          expect(output).to include("ORPHANED RESERVATIONS (Not connected to trips from #{base_airport}):")
          expect(output).to match(/={50}/)
        end

        it 'separates transports and accommodations into different sections' do
          output = capture_stdout { app.send(:output_orphaned_segments) }

          expect(output).to include('TRANSPORTS:')
          expect(output).to include('ACCOMMODATIONS:')
        end

        it 'numbers segments correctly within each category' do
          output = capture_stdout { app.send(:output_orphaned_segments) }

          # Transport segments should be numbered 1, 2
          expect(output).to match(/TRANSPORTS:\s*\n\s+1\. Flight/)
          expect(output).to match(/\n\s+2\. Train/)

          # Accommodation segments should be numbered 1, 2 (separate from transports)
          expect(output).to match(/ACCOMMODATIONS:\s*\n\s+1\. Hotel/)
          expect(output).to match(/\n\s+2\. Apartment/)
        end

        it 'outputs correct total count' do
          output = capture_stdout { app.send(:output_orphaned_segments) }

          expect(output).to include('Total orphaned reservations: 4')
        end

        it 'includes segment details' do
          output = capture_stdout { app.send(:output_orphaned_segments) }

          expect(output).to include('Flight from BCN to NYC at 2023-03-02 15:00 to 22:45')
          expect(output).to include('Train from MAD to PAR at 2023-04-15 09:30 to 15:00')
          expect(output).to include('Hotel at PAR on 2023-04-01 to 2023-04-05')
          expect(output).to include('Apartment at LON on 2023-05-01 to 2023-05-07')
        end
      end

      context 'with only transport segments' do
        let(:orphaned_segments) do
          [
            create_flight_segment(origin: 'BCN', destination: 'NYC'),
            create_train_segment(origin: 'MAD', destination: 'PAR')
          ]
        end

        it 'outputs only transports section' do
          output = capture_stdout { app.send(:output_orphaned_segments) }

          expect(output).to include('TRANSPORTS:')
          expect(output).not_to include('ACCOMMODATIONS:')
          expect(output).to include('Total orphaned reservations: 2')
        end
      end

      context 'with only accommodation segments' do
        let(:orphaned_segments) do
          [
            create_hotel_segment(city: 'PAR'),
            create_apartment_segment(city: 'LON')
          ]
        end

        it 'outputs only accommodations section' do
          output = capture_stdout { app.send(:output_orphaned_segments) }

          expect(output).to include('ACCOMMODATIONS:')
          expect(output).not_to include('TRANSPORTS:')
          expect(output).to include('Total orphaned reservations: 2')
        end
      end

      context 'with no orphaned segments' do
        let(:orphaned_segments) { [] }

        it 'outputs header and zero count' do
          output = capture_stdout { app.send(:output_orphaned_segments) }

          expect(output).to include('ORPHANED RESERVATIONS')
          expect(output).to include('Total orphaned reservations: 0')
          expect(output).not_to include('TRANSPORTS:')
          expect(output).not_to include('ACCOMMODATIONS:')
        end
      end

      context 'with single segment of each type' do
        let(:orphaned_segments) do
          [
            create_flight_segment(origin: 'BCN', destination: 'NYC'),
            create_hotel_segment(city: 'PAR')
          ]
        end

        it 'numbers single segments correctly' do
          output = capture_stdout { app.send(:output_orphaned_segments) }

          expect(output).to match(/TRANSPORTS:\s*\n\s+1\. Flight/)
          expect(output).to match(/ACCOMMODATIONS:\s*\n\s+1\. Hotel/)
          expect(output).to include('Total orphaned reservations: 2')
        end
      end

      context 'with multiple segments of same transport type' do
        let(:orphaned_segments) do
          [
            create_flight_segment(origin: 'BCN', destination: 'NYC', date: '2023-03-02'),
            create_flight_segment(origin: 'MAD', destination: 'PAR', date: '2023-04-15'),
            create_flight_segment(origin: 'SVQ', destination: 'LON', date: '2023-05-01')
          ]
        end

        it 'numbers all flights in sequence' do
          output = capture_stdout { app.send(:output_orphaned_segments) }

          expect(output).to match(/1\. Flight from BCN to NYC/)
          expect(output).to match(/2\. Flight from MAD to PAR/)
          expect(output).to match(/3\. Flight from SVQ to LON/)
          expect(output).to include('Total orphaned reservations: 3')
        end
      end
    end
  end

  private

  def capture_stdout
    original_stdout = $stdout
    $stdout = fake = StringIO.new
    yield
    fake.string
  ensure
    $stdout = original_stdout
  end
end