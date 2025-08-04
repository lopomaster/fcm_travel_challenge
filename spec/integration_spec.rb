# require 'rails_helper'
require_relative '../intinerary_app'
require_relative '../main'

RSpec.describe 'Integration Tests' do
  let(:test_file) { 'spec/fixtures/integration_test_input.txt' }

  before do
    File.write(test_file, file_content)
  end

  after do
    File.delete(test_file) if File.exist?(test_file)
  end

  describe 'Complete application flow' do
    context 'with sample input from the project' do
      let(:file_content) do
        <<~CONTENT
          RESERVATION
          SEGMENT: Flight SVQ 2023-03-02 06:40 -> BCN 09:10

          RESERVATION
          SEGMENT: Hotel BCN 2023-01-05 -> 2023-01-10

          RESERVATION
          SEGMENT: Flight SVQ 2023-01-05 20:40 -> BCN 22:10
          SEGMENT: Flight BCN 2023-01-10 10:30 -> SVQ 11:50

          RESERVATION
          SEGMENT: Train SVQ 2023-02-15 09:30 -> MAD 11:00
          SEGMENT: Train MAD 2023-02-17 17:00 -> SVQ 19:30

          RESERVATION
          SEGMENT: Hotel MAD 2023-02-15 -> 2023-02-17

          RESERVATION
          SEGMENT: Flight BCN 2023-03-02 15:00 -> NYC 22:45
        CONTENT
      end

      it 'processes the complete sample correctly' do
        app = ItineraryApp.new('SVQ')
        output = capture_stdout { app.process_file(test_file) }

        # Should create multiple trips
        expect(output.scan(/TRIP to/).length).to be >= 2

        # Should include different destinations
        expect(output).to include('TRIP to BCN')
        expect(output).to include('TRIP to MAD')
        expect(output).to include('TRIP to NYC')

        # Should include various segment types
        expect(output).to include('Flight from SVQ to BCN')
        expect(output).to include('Train from SVQ to MAD')
        expect(output).to include('Hotel at BCN')
        expect(output).to include('Hotel at MAD')
      end

      it 'sorts trips chronologically' do
        app = ItineraryApp.new('SVQ')
        output = capture_stdout { app.process_file(test_file) }

        # Extract trip lines to check order
        trip_lines = output.split("\n").select { |line| line.start_with?('TRIP to') }

        # First trip should be to BCN (January dates)
        expect(trip_lines.first).to include('TRIP to BCN')
      end
    end

    context 'with different base airports' do
      let(:file_content) do
        <<~CONTENT
          RESERVATION
          SEGMENT: Flight MAD 2023-03-02 06:40 -> BCN 09:10

          RESERVATION
          SEGMENT: Flight BCN 2023-03-05 15:00 -> MAD 16:30
        CONTENT
      end

      it 'works with MAD as base airport' do
        app = ItineraryApp.new('MAD')
        output = capture_stdout { app.process_file(test_file) }

        output = output.split("\n")
        expect(output[0]).to include('TRIP to BCN')
        expect(output[1]).to include('Flight from MAD to BCN at 2023-03-02 06:40 to 09:10')
      end
    end

    context 'with complex multi-city trips' do
      let(:file_content) do
        <<~CONTENT
          RESERVATION
          SEGMENT: Flight SVQ 2023-06-01 08:00 -> BCN 09:30

          RESERVATION
          SEGMENT: Train BCN 2023-06-01 12:00 -> MAD 15:00

          RESERVATION
          SEGMENT: Hotel MAD 2023-06-01 -> 2023-06-03

          RESERVATION
          SEGMENT: Flight MAD 2023-06-03 16:00 -> NYC 23:00

          RESERVATION
          SEGMENT: Hotel NYC 2023-06-03 -> 2023-06-07

          RESERVATION
          SEGMENT: Flight NYC 2023-06-07 10:00 -> SVQ 22:00
        CONTENT
      end

      it 'builds complex multi-city trip chains' do
        app = ItineraryApp.new('SVQ')
        output = capture_stdout { app.process_file(test_file) }

        # Should be one connected trip
        expect(output.scan(/TRIP to/).length).to eq(1)

        # Should include all segments in order
        expect(output).to include('TRIP to NYC')
        expect(output).to include('Flight from SVQ to BCN')
        expect(output).to include('Train from BCN to MAD')
        expect(output).to include('Hotel at MAD')
        expect(output).to include('Flight from MAD to NYC')
        expect(output).to include('Hotel at NYC')
        expect(output).to include('Flight from NYC to SVQ')
      end
    end

    context 'with disconnected segments' do
      let(:file_content) do
        <<~CONTENT
          RESERVATION
          SEGMENT: Flight SVQ 2023-03-02 06:40 -> BCN 09:10

          RESERVATION
          SEGMENT: Flight BCN 2023-03-05 15:00 -> SVQ 16:30

          RESERVATION
          SEGMENT: Flight SVQ 2023-07-15 10:00 -> MAD 11:30

          RESERVATION
          SEGMENT: Flight MAD 2023-07-18 18:00 -> SVQ 19:30
        CONTENT
      end

      it 'creates separate trips for disconnected segments' do
        app = ItineraryApp.new('SVQ')
        output = capture_stdout { app.process_file(test_file) }

        # Should create two separate trips
        expect(output.scan(/TRIP to/).length).to eq(2)
        expect(output).to include('TRIP to BCN')
        expect(output).to include('TRIP to MAD')
      end
    end

    context 'with accommodation-only destinations' do
      let(:file_content) do
        <<~CONTENT
          RESERVATION
          SEGMENT: Flight SVQ 2023-06-01 08:00 -> BCN 09:30

          RESERVATION
          SEGMENT: Hotel BCN 2023-06-01 -> 2023-06-05

          RESERVATION
          SEGMENT: Apartment BCN 2023-06-05 -> 2023-06-08

          RESERVATION
          SEGMENT: Flight BCN 2023-06-08 16:00 -> SVQ 17:30
        CONTENT
      end

      it 'determines destination based on accommodation' do
        app = ItineraryApp.new('SVQ')
        output = capture_stdout { app.process_file(test_file) }

        expect(output).to include('TRIP to BCN')
        expect(output).to include('Hotel at BCN')
        expect(output).to include('Apartment at BCN')
      end
    end

    context 'error handling integration' do
      context 'with mixed valid and invalid segments' do
        let(:file_content) do
          <<~CONTENT
            RESERVATION
            SEGMENT: Flight SVQ 2023-03-02 06:40 -> BCN 09:10

            RESERVATION
            SEGMENT: Flight INVALID 2023-03-05 15:00 -> SVQ 16:30
          CONTENT
        end

        it 'stops processing on first error' do
          app = ItineraryApp.new('SVQ')

          expect { app.process_file(test_file) }
            .to output(/Error processing file/).to_stdout
                                               .and raise_error(SystemExit)
        end
      end

      context 'with no base airport segments' do
        let(:file_content) do
          <<~CONTENT
            RESERVATION
            SEGMENT: Flight BCN 2023-03-02 06:40 -> MAD 09:10

            RESERVATION
            SEGMENT: Flight MAD 2023-03-05 15:00 -> BCN 16:30
          CONTENT
        end

        it 'provides meaningful error message' do
          app = ItineraryApp.new('SVQ')

          expect { app.process_file(test_file) }
            .to output(/Error: There are not reservations from SVQ/).to_stdout
                                                                    .and raise_error(SystemExit)
        end
      end
    end

    context 'edge cases' do
      context 'with same-day connections' do
        let(:file_content) do
          <<~CONTENT
            RESERVATION
            SEGMENT: Flight SVQ 2023-06-01 08:00 -> BCN 09:30

            RESERVATION
            SEGMENT: Flight BCN 2023-06-01 11:00 -> NYC 18:00
          CONTENT
        end

        it 'connects same-day flights' do
          app = ItineraryApp.new('SVQ')
          output = capture_stdout { app.process_file(test_file) }

          expect(output.scan(/TRIP to/).length).to eq(1)
          expect(output).to include('TRIP to NYC')
        end
      end

      context 'with exactly 24-hour gap' do
        let(:file_content) do
          <<~CONTENT
            RESERVATION
            SEGMENT: Flight SVQ 2023-06-01 10:00 -> BCN 11:30

            RESERVATION
            SEGMENT: Flight BCN 2023-06-02 11:30 -> NYC 18:00
          CONTENT
        end

        it 'does not connect flights with 24+ hour gap' do
          app = ItineraryApp.new('SVQ')
          output = capture_stdout { app.process_file(test_file) }

          # Should create separate trips due to 24h+ gap
          expect(output.scan(/TRIP to/).length).to be >= 1
        end
      end

      context 'with various transport types' do
        let(:file_content) do
          <<~CONTENT
            RESERVATION
            SEGMENT: Flight SVQ 2023-06-01 08:00 -> BCN 09:30

            RESERVATION
            SEGMENT: Train BCN 2023-06-01 12:00 -> MAD 15:00

            RESERVATION
            SEGMENT: Bus MAD 2023-06-01 18:00 -> SVQ 21:00
          CONTENT
        end

        it 'handles mixed transport types' do
          app = ItineraryApp.new('SVQ')
          output = capture_stdout { app.process_file(test_file) }

          expect(output).to include('Flight from SVQ to BCN')
          expect(output).to include('Train from BCN to MAD')
          expect(output).to include('Bus from MAD to SVQ')
        end
      end
    end
  end

  describe 'Main class integration' do
    let(:original_argv) { ARGV.dup }

    before do
      ARGV.clear
    end

    after do
      ARGV.replace(original_argv)
    end

    context 'with command line arguments' do

      let(:file_content) do
        <<~CONTENT
            RESERVATION
            SEGMENT: Flight SVQ 2023-06-01 08:00 -> BCN 09:30

            RESERVATION
            SEGMENT: Flight BCN 2023-06-01 11:00 -> NYC 18:00
          CONTENT
      end

      it 'processes file via command line interface' do
        ARGV << test_file

        output = capture_stdout do
          Main.execute
        end

        expect(output).to start_with('TRIP to NYC')
      end

      it 'shows usage when no arguments provided' do
        output = capture_stdout do
          expect { Main.execute }.to raise_error(SystemExit)
        end

        expect(output).to include('Usage: ruby')
        expect(output).to include('Options:')
        expect(output).to include('BASED=<airport>')
        expect(output).to include('DEBUG=1')
      end
    end

    context 'with environment variables' do
      before { ENV['BASED'] = 'MAD' }
      after { ENV.delete('BASED') }

      let(:file_content) do
        <<~CONTENT
          RESERVATION
          SEGMENT: Flight MAD 2023-03-02 06:40 -> BCN 09:10

          RESERVATION
          SEGMENT: Flight BCN 2023-03-05 15:00 -> MAD 16:30
        CONTENT
      end

      it 'uses BASED environment variable' do
        ARGV << test_file

        output = capture_stdout do
          Main.execute
        end

        expect(output).to include('TRIP to BCN')
        expect(output).to include('Flight from MAD to BCN')
      end

    end
  end

  private

  def capture_stdout
    original_stdout = $stdout
    $stdout = fake = StringIO.new
    begin
      yield
      fake.string
    rescue SystemExit
      fake.string
    ensure
      $stdout = original_stdout
    end
  end
end