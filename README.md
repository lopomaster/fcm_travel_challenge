# FCM Travel Challenge

A Ruby application for processing travel reservations and generating organized itineraries with advanced orphaned segment detection.

## Description

This application processes a text file containing flight, train, bus travels and hotel or apartment reservations and generates organized trips based on logical connections between segments. The system automatically identifies and reports reservations that cannot be connected to trips from the base airport (orphaned segments).

## Features

- **Core Processing**
    - Processing of multiple transport types (flights, trains, buses)
    - Support for accommodations (hotels, apartments)
    - Automatic travel chain construction
    - Robust input data validation
    - Comprehensive error handling
    - Flexible base airport configuration

- **Advanced Features**
    - **Orphaned Segment Detection**: Identifies reservations not connected to trips from base airport
    - **Smart Categorization**: Separates orphaned segments by type (Transports/Accommodations)
    - **Detailed Reporting**: Shows numbered lists with total counts

## Project Structure

```
fcm_travel_challenge/
├── main.rb                           # Main entry point
├── intinerary_app.rb                 # Main application
├── reservation.rb                    # Reservation class
├── reservation_parser.rb             # Reservation parser
├── lib/
│   ├── errors/
│   │   └── itinerary_app_errors.rb   # Custom error classes
│   ├── reservations/
│   │   ├── reservation_segment.rb    # Base class for segments
│   │   ├── transit_reservation.rb    # Transport reservations
│   │   └── accommodation_reservation.rb # Accommodation reservations
│   ├── segments/
│   │   ├── flight_segment.rb         # Flight segments
│   │   ├── train_segment.rb          # Train segments
│   │   ├── hotel_segment.rb          # Hotel segments
│   │   └── ...                       # Other segment types
│   └── trip/
│       ├── trip.rb                   # Trip class
│       └── trip_builder.rb           # Trip builder with orphan detection
├── extended_segments_samples/
│   ├── bus_segment.rb                # Extended segment example
│   └── apartment_segment.rb          # Extended accommodation example
├── spec/                             # Comprehensive test suite
│   ├── spec_helper.rb                # RSpec configuration
│   ├── support/
│   │   └── test_helpers.rb           # Test helper methods
│   ├── itinerary_app_spec.rb         # Application logic tests
│   ├── trip_builder_spec.rb          # Trip building and orphan detection tests
│   ├── reservation_parser_spec.rb    # Parser validation tests
│   ├── segments_spec.rb              # Segment behavior tests
│   └── integration/
│       └── orphaned_segments_integration_spec.rb # End-to-end orphan tests
├── input.txt                         # Sample input file
├── Gemfile                           # Ruby dependencies
├── Gemfile.lock                      # Locked versions
├── Dockerfile                        # Docker configuration
├── docker-compose.yml               # Docker Compose setup
└── README.md                        # This file
```

## Getting Started

### Prerequisites

- Ruby 3.3.5
- Bundler 2.5.16
- Docker (optional)

### Installation

#### Local Setup

1. **Clone the repository:**
   ```bash
   git clone <repository-url>
   cd fcm_travel_challenge
   ```

2. **Install dependencies:**
   ```bash
   bundle install
   ```

3. **Run the application:**
   ```bash
   ruby main.rb input.txt
   ```

#### Docker Setup

1. **Build and run with Docker Compose:**
   ```bash
   # Build the container
   docker-compose build

   # Run the application
   docker-compose run --rm fcm_travel ruby main.rb input.txt

   # Run with custom base airport
   docker-compose run --rm fcm_travel env BASED=MAD ruby main.rb input.txt

   # Run tests
   docker-compose run --rm fcm_travel bundle exec rspec

   # Run with debug mode
   docker-compose run --rm fcm_travel env DEBUG=1 ruby main.rb input.txt
   ```

## Usage

### Basic Usage

```bash
ruby main.rb input.txt
```

### Advanced Options

```bash
# Set custom base airport
BASED=SVQ ruby main.rb input.txt

# Enable debug mode
DEBUG=1 ruby main.rb input.txt

# Combine options
BASED=SVQ DEBUG=1 ruby main.rb input.txt
```

## Input File Format

The input file must follow this format:

```
RESERVATION
SEGMENT: Flight SVQ 2023-03-02 06:40 -> BCN 09:10

RESERVATION
SEGMENT: Hotel BCN 2023-01-05 -> 2023-01-10

RESERVATION
SEGMENT: Flight SVQ 2023-01-05 20:40 -> BCN 22:10
SEGMENT: Flight BCN 2023-01-10 10:30 -> SVQ 11:50
```

### Supported Segment Types

#### Transport Segments
- `Flight ABC 2023-01-01 12:00 -> DEF 14:30`
- `Train ABC 2023-01-01 12:00 -> DEF 14:30`
- `Bus ABC 2023-01-01 12:00 -> DEF 14:30`

#### Accommodation Segments
- `Hotel ABC 2023-01-01 -> 2023-01-03`
- `Apartment ABC 2023-01-01 -> 2023-01-03`

### Format Rules

- **IATA Codes**: Must be exactly 3 uppercase letters (SVQ, BCN, MAD, etc.)
- **Dates**: YYYY-MM-DD format
- **Times**: HH:MM format (24-hour)
- **Transport**: Origin Date Time -> Destination Time
- **Accommodation**: Location StartDate -> EndDate

## Output Examples

### Regular Trips

```
TRIP to BCN
Flight from SVQ to BCN at 2023-01-05 20:40 to 22:10
Hotel at BCN on 2023-01-05 to 2023-01-10
Flight from BCN to SVQ at 2023-01-10 10:30 to 11:50

TRIP to MAD
Train from SVQ to MAD at 2023-02-15 09:30 to 11:00
Hotel at MAD on 2023-02-15 to 2023-02-17
Train from MAD to SVQ at 2023-02-17 17:00 to 19:30
```

### With Orphaned Segments

```
TRIP to BCN
Flight from SVQ to BCN at 2023-01-05 20:40 to 22:10
Hotel at BCN on 2023-01-05 to 2023-01-10
Flight from BCN to SVQ at 2023-01-10 10:30 to 11:50

==================================================
ORPHANED RESERVATIONS (Not connected to trips from SVQ):
==================================================
TRANSPORTS:
  1. Flight from BCN to NYC at 2023-03-02 15:00 to 22:45
  2. Train from NYC to WAS at 2023-03-05 10:00 to 14:00

ACCOMMODATIONS:
  1. Hotel at PAR on 2023-04-01 to 2023-04-05
  2. Apartment at LON on 2023-05-01 to 2023-05-07

Total orphaned reservations: 4
```

## Testing

### Running Tests

```bash
# Run all tests
bundle exec rspec
```

## Development

### Adding New Segment Types

1. **Create the segment class:**
   ```ruby
   # lib/segments/ferry_segment.rb
   class FerrySegment < TransitReservation
     def initialize(origin:, destination:, start_date:, start_time:, end_time:)
        super(
          transport_type: 'Ferry',
          origin: origin,
          destination: destination,
          start_date: start_date,
          start_time: start_time,
          end_time: end_time
        )
     end
   end
   ```

2. **Update the parser:**
   ```ruby
   # reservation_parser.rb
   TRANSPORT_TYPES = %w[Flight Train Bus Ferry].freeze
   ```

3. **Add tests:**
   ```ruby
   # spec/segments_spec.rb
   describe FerrySegment do
     # Add comprehensive tests
   end
   ```

## Deployment
### Production Docker Build

# Build production image
docker build -t fcm-travel-challenge:latest .

# Run production container
docker run --rm \
-v $(pwd):/app \
-w /app \
fcm-travel-challenge \
ruby main.rb input.txt

### Environment Variables

- `BASED`: Set base airport (default: SVQ)
- `DEBUG`: Enable debug mode (default: 0)
- `RUBY_ENV`: Set Ruby environment


