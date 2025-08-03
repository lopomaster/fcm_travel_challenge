# FCM Travel Challenge

A Ruby application for processing travel reservations and generating organized itineraries.

## Description

This application processes a text file containing flight, train, bus, and accommodation reservations, and generates organized trips based on logical connections between segments.

## Features

- Processing of multiple transport types (flights, trains, buses)
- Support for accommodations (hotels, apartments)
- Automatic travel chain construction
- Robust input data validation
- Comprehensive error handling
- Flexible base airport configuration

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
│       └── trip_builder.rb           # Trip builder
├── extended_segments_samples/
│   ├── bus_segment.rb                # Extended segment example
│   └── apartment_segment.rb          # Extended accommodation example
├── spec/                             # Tests
├── input.txt                         # Sample input file
├── Gemfile                           # Ruby dependencies
├── Gemfile.lock                      # Locked versions
├── Rakefile                          # Rake tasks
└── README.md                         # This file
```

## Input file format

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

### Supported segment types

#### Transport
- `Flight ABC 2023-01-01 12:00 -> DEF 14:30`
- `Train ABC 2023-01-01 12:00 -> DEF 14:30`
- `Bus ABC 2023-01-01 12:00 -> DEF 14:30`

#### Accommodation
- `Hotel ABC 2023-01-01 -> 2023-01-03`
- `Apartment ABC 2023-01-01 -> 2023-01-03`


## Development

### Adding new segment types

1. Create a new class in `lib/segments/` that inherits from `TransitReservation` or `AccommodationReservation`
2. Add the type to the corresponding array in `ReservationParser`
3. Create unit tests for the new segment
4. Add factory for the new segment

## Error Handling

The application handles several types of errors:

- **ReservationParserError**: Format errors in input file
- **ItineraryAppError**: Application logic errors
- **System errors**: File not found, etc.

In DEBUG mode, complete backtraces are shown.

## Extensibility

The design allows easy extension:

- New transport types
- New accommodation types
- New connection rules between segments
- New output formats

## Output Examples

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
