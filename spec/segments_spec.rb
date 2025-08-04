
require_relative './support/test_helpers'
require_relative '../lib/segments/flight_segment'
require_relative '../lib/segments/train_segment'
require_relative '../lib/segments/hotel_segment'

RSpec.describe 'Segment Classes' do
  describe FlightSegment do
    let(:flight) { create_flight_segment }

    it 'inherits from TransitReservation' do
      expect(flight).to be_a(TransitReservation)
    end

    it 'has correct transport type' do
      expect(flight.transport_type).to eq('Flight')
    end

    it 'has all required attributes' do
      expect(flight.origin).to eq('SVQ')
      expect(flight.destination).to eq('BCN')
      expect(flight.start_date.to_s).to eq('2023-03-02')
      expect(flight.start_time).to eq('06:40')
      expect(flight.end_time).to eq('09:10')
    end

    it 'calculates start_datetime correctly' do
      expected_datetime = DateTime.parse('2023-03-02 06:40')
      expect(flight.start_datetime).to eq(expected_datetime)
    end

    it 'calculates end_datetime correctly' do
      expected_datetime = DateTime.parse('2023-03-02 09:10')
      expect(flight.end_datetime).to eq(expected_datetime)
    end

    it 'has correct string representation' do
      expected_string = 'Flight from SVQ to BCN at 2023-03-02 06:40 to 09:10'
      expect(flight.to_s).to eq(expected_string)
    end
  end

  describe TrainSegment do
    let(:train) { create_train_segment }

    it 'inherits from TransitReservation' do
      expect(train).to be_a(TransitReservation)
    end

    it 'has correct transport type' do
      expect(train.transport_type).to eq('Train')
    end

    it 'has all required attributes' do
      expect(train.origin).to eq('SVQ')
      expect(train.destination).to eq('MAD')
      expect(train.start_date.to_s).to eq('2023-02-15')
      expect(train.start_time).to eq('09:30')
      expect(train.end_time).to eq('11:00')
    end

    it 'calculates datetime correctly' do
      start_datetime = DateTime.parse('2023-02-15 09:30')
      end_datetime = DateTime.parse('2023-02-15 11:00')

      expect(train.start_datetime).to eq(start_datetime)
      expect(train.end_datetime).to eq(end_datetime)
    end
  end

  describe HotelSegment do
    let(:hotel) { create_hotel_segment }

    it 'inherits from AccommodationReservation' do
      expect(hotel).to be_a(AccommodationReservation)
    end

    it 'has correct accommodation type' do
      expect(hotel.accommodation_type).to eq('Hotel')
    end

    it 'has all required attributes' do
      expect(hotel.location).to eq('BCN')
      expect(hotel.start_date.to_s).to eq('2023-01-05')
      expect(hotel.end_date.to_s).to eq('2023-01-10')
    end

    it 'calculates start_datetime correctly' do
      expected_datetime = DateTime.parse('2023-01-05 00:00')
      expect(hotel.start_datetime).to eq(expected_datetime)
    end

    it 'calculates end_datetime correctly' do
      expected_datetime = DateTime.parse('2023-01-10 23:59')
      expect(hotel.end_datetime).to eq(expected_datetime)
    end

    it 'has correct string representation' do
      expected_string = 'Hotel at BCN on 2023-01-05 to 2023-01-10'
      expect(hotel.to_s).to eq(expected_string)
    end
  end

end

RSpec.describe TransitReservation do
  let(:transit) do
    described_class.new(
      transport_type: 'Flight',
      origin: 'SVQ',
      destination: 'BCN',
      start_date: '2023-03-02',
      start_time: '06:40',
      end_time: '09:10'
    )
  end

  it 'initializes with correct attributes' do
    expect(transit.transport_type).to eq('Flight')
    expect(transit.origin).to eq('SVQ')
    expect(transit.destination).to eq('BCN')
    expect(transit.start_time).to eq('06:40')
    expect(transit.end_time).to eq('09:10')
  end

  it 'parses start date correctly' do
    expect(transit.start_date).to eq(Date.parse('2023-03-02'))
  end

  it 'calculates datetime objects correctly' do
    start_datetime = DateTime.parse('2023-03-02 06:40')
    end_datetime = DateTime.parse('2023-03-02 09:10')

    expect(transit.start_datetime).to eq(start_datetime)
    expect(transit.end_datetime).to eq(end_datetime)
  end
end

RSpec.describe AccommodationReservation do
  let(:accommodation) do
    described_class.new(
      accommodation_type: 'Hotel',
      location: 'BCN',
      start_date: '2023-01-05',
      end_date: '2023-01-10'
    )
  end

  it 'initializes with correct attributes' do
    expect(accommodation.accommodation_type).to eq('Hotel')
    expect(accommodation.location).to eq('BCN')
  end

  it 'parses dates correctly' do
    expect(accommodation.start_date).to eq(Date.parse('2023-01-05'))
    expect(accommodation.end_date).to eq(Date.parse('2023-01-10'))
  end

  it 'calculates datetime objects correctly' do
    start_datetime = DateTime.parse('2023-01-05 00:00')
    end_datetime = DateTime.parse('2023-01-10 23:59')

    expect(accommodation.start_datetime).to eq(start_datetime)
    expect(accommodation.end_datetime).to eq(end_datetime)
  end
end

RSpec.describe ReservationSegment do
  it 'raises NotImplementedError for start_datetime' do
    segment = described_class.new(start_date: '2023-01-01')
    expect { segment.start_datetime }.to raise_error(NotImplementedError)
  end

  it 'raises NotImplementedError for end_datetime' do
    segment = described_class.new(start_date: '2023-01-01')
    expect { segment.end_datetime }.to raise_error(NotImplementedError)
  end

  it 'sets end_date to start_date if not provided' do
    segment = described_class.new(start_date: '2023-01-01')
    expect(segment.end_date).to eq(segment.start_date)
  end

  it 'sets end_date when provided' do
    segment = described_class.new(start_date: '2023-01-01', end_date: '2023-01-02')
    expect(segment.end_date).to eq(Date.parse('2023-01-02'))
  end
end