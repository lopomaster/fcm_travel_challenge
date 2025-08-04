
module TestHelpers
  def create_test_file(filename, content)
    Dir.mkdir('spec') unless Dir.exist?('spec')
    Dir.mkdir('spec/fixtures') unless Dir.exist?('spec/fixtures')
    File.write(filename, content)
  end

  def cleanup_test_file(filename)
    File.delete(filename) if File.exist?(filename)
  end

  def capture_stdout_and_stderr
    original_stdout = $stdout
    original_stderr = $stderr
    $stdout = fake_out = StringIO.new
    $stderr = fake_err = StringIO.new
    begin
      yield
      [fake_out.string, fake_err.string]
    rescue SystemExit
      [fake_out.string, fake_err.string]
    ensure
      $stdout = original_stdout
      $stderr = original_stderr
    end
  end

  def sample_reservation_content
    <<~CONTENT
      RESERVATION
      SEGMENT: Flight SVQ 2023-03-02 06:40 -> BCN 09:10

      RESERVATION
      SEGMENT: Hotel BCN 2023-03-02 -> 2023-03-05

      RESERVATION
      SEGMENT: Flight BCN 2023-03-05 15:00 -> SVQ 16:30
    CONTENT
  end

  def create_flight_segment(origin: 'SVQ', destination: 'BCN', date: '2023-03-02', start_time: '06:40', end_time: '09:10')
    FlightSegment.new(
      origin: origin,
      destination: destination,
      start_date: date,
      start_time: start_time,
      end_time: end_time
    )
  end

  def create_train_segment(origin: 'SVQ', destination: 'MAD', date: '2023-02-15', start_time: '09:30', end_time: '11:00')
    TrainSegment.new(
      origin: origin,
      destination: destination,
      start_date: date,
      start_time: start_time,
      end_time: end_time
    )
  end

  def create_hotel_segment(city: 'BCN', start_date: '2023-01-05', end_date: '2023-01-10')
    HotelSegment.new(
      city: city,
      start_date: start_date,
      end_date: end_date
    )
  end

  def create_trip_with_segments(destination, *segments)
    trip = Trip.new(destination)
    segments.each { |segment| trip.add_segment(segment) }
    trip
  end
end

RSpec.configure do |config|
  config.include TestHelpers
end