require_relative 'intinerary_app'

class Main

  def self.execute
    new.execute
  end

  def execute
    beginning_time = Time.now

    if ARGV.empty?
      puts "Usage: ruby #{$0} <input_file>"
      puts ""
      puts "Options:"
      puts "  BASED=<airport>  Set base airport (default: SVQ)"
      puts "  DEBUG=1          Enable debug mode"
      puts ""
      puts "Examples:"
      puts "  ruby #{$0} input.txt"
      puts "  BASED=MAD ruby #{$0} input.txt"
      exit 1
    end

    base_airport = ENV['BASED'] || 'SVQ'
    app = ItineraryApp.new(base_airport)
    app.process_file(ARGV[0])

    end_time = Time.now
    puts "execution time: #{end_time - beginning_time} seconds"

  end

end

Main.execute if __FILE__ == $0