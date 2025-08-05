require 'simplecov'

SimpleCov.start do
  root Dir.pwd

  add_filter '/spec/'

  minimum_coverage 80

  at_exit do
    result = SimpleCov.result
    puts "\n" + "="*50
    puts "SIMPLECOV DEBUG REPORT"
    puts "="*50
    puts "Root: #{SimpleCov.root}"
    puts "Coverage: #{result.covered_percent.round(2)}%"
    puts "Files tracked: #{result.files.count}"
    puts "Command name: #{SimpleCov.command_name}"
    puts ""

    puts "✅ Files tracked:"
    result.files.each do |file|
      rel_path = file.filename.gsub("#{SimpleCov.root}/", "")
      puts "#{rel_path}: #{file.covered_percent.round(1)}% (#{file.covered_lines.count}/#{file.lines.count} lines)"
    end
  end
  puts "="*50

  begin
    FileUtils.mkdir_p(SimpleCov.coverage_dir)
    SimpleCov::Formatter::HTMLFormatter.new.format(result)
    html_file = File.join(SimpleCov.coverage_dir, 'index.html')
  rescue => e
    puts "Error HTML generation: #{e.message}"
    puts "Backtrace: #{e.backtrace.first(3).join(', ')}"
  end

  puts "="*60

end

def load_file_with_coverage(file_path, description = nil)
  abs_path = File.expand_path(file_path)

  if File.exist?(abs_path)
    begin
      syntax_check = `ruby -c "#{abs_path}" 2>&1`
      if $?.success?
        load abs_path
        return true
      else
        puts "Syntax error: #{syntax_check}"
        return false
      end
    rescue => e
      puts "   Loading file error: #{e.message}"
      puts "   Backtrace: #{e.backtrace.first(3).join(', ')}" if e.backtrace
      return false
    end
  else
    puts "File not found"
    return false
  end
end

files_to_load = [
  './reservation.rb',
  './reservation_parser.rb',
  './intinerary_app.rb',
  './lib/errors/itinerary_app_errors.rb',
  './lib/reservations/reservation_segment.rb',
  './lib/reservations/transit_reservation.rb',
  './lib/reservations/accommodation_reservation.rb',
  './lib/segments/flight_segment.rb',
  './lib/segments/hotel_segment.rb',
  './lib/segments/train_segment.rb',
  './lib/trip/trip.rb',
  './lib/trip/trip_builder.rb'
]

loaded_files = []
files_to_load.each do |file_path|
  if load_file_with_coverage(file_path)
    loaded_files << file_path
  end
end

segment_files = Dir.glob('./*_segment.rb') + Dir.glob('./extended_segments_samples/*_segment.rb')
segment_files.each do |file_path|
  if load_file_with_coverage(file_path, "Segment file")
    loaded_files << file_path
  end
end