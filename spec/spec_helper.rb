
# require_relative 'support/simplecov'

require 'rspec'

RSpec.configure do |config|
  config.expect_with :rspec do |expectations|
    expectations.include_chain_clauses_in_custom_matcher_descriptions = true
  end

  config.mock_with :rspec do |mocks|
    mocks.verify_partial_doubles = true
  end

  config.shared_context_metadata_behavior = :apply_to_host_groups
  config.filter_run_when_matching :focus
  config.example_status_persistence_file_path = "spec/examples.txt"
  config.disable_monkey_patching!
  config.warnings = true

  if config.files_to_run.one?
    config.default_formatter = "doc"
  end

  # config.profile_examples = 10
  config.order = :random
  Kernel.srand config.seed

  # Create fixtures directory before tests run
  config.before(:suite) do
    Dir.mkdir('spec') unless Dir.exist?('spec')
    Dir.mkdir('spec/fixtures') unless Dir.exist?('spec/fixtures')
  end

  # Clean up fixtures after tests
  config.after(:suite) do
    if Dir.exist?('spec/fixtures')
      Dir.glob('spec/fixtures/test_*.txt').each { |f| File.delete(f) rescue nil }
      Dir.glob('spec/fixtures/integration_*.txt').each { |f| File.delete(f) rescue nil }
    end
  end
end