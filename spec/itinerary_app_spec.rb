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