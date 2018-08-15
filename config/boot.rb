# config/boot.rb
#--
# rubocop:disable Rails/Exit
#++

# For use within initialization code to branch between code that is intended
# for the Rails application versus code that is run in other contexts (e.g.,
# rake).
#
def running_rails_application?
  defined?(APP_PATH) || $0.end_with?('rails') || ENV['IN_PASSENGER']
end

# =============================================================================
# Initial console/log message before the normal boot sequence.
# =============================================================================

# The time that the application was started.  This value is available globally.
BOOT_TIME = Time.now

if running_rails_application?

  # Write a line to $stderr prefixed with the time since BOOT_TIME.
  # @param [String] line
  # @return [void]
  def console_output(line) # :nodoc:
    delta_t = Time.gm(0) + (Time.now - BOOT_TIME)
    STDERR.puts("#{delta_t.strftime('%T.%L')} #{line}")
  end

  console_output "boot @ #{BOOT_TIME}"

else

  # Do not output to $stderr from rake and other applications.
  # @param [String] *  (arguments ignored)
  # @return [void]
  def console_output(*) # :nodoc:
  end

  STDERR.puts("Running #{$0.inspect}") unless $0.end_with?('rake')

end

# =============================================================================
# BOOT
# =============================================================================

require 'rubygems'
require 'yaml'

# =============================================================================
# Load environment.yml.
#
# If the environment.yml file exists, any environment variables declared in it
# are set in the executing environment.
# =============================================================================

env_file = File.expand_path('../environment.yml', __FILE__)
if File.exist?(env_file)
  console_output "boot - reading #{env_file} ..."
  begin
    YAML.load_file(env_file).each do |key, value|
      ENV[key] = value.strip unless value.empty?
    end
  rescue => e
    STDERR.puts "Error reading the #{env_file} file:\n#{e}: #{e.message}"
    exit!
  end
else
  console_output "boot - skipping #{env_file} ..."
end

# =============================================================================
# Set up gems listed in the Gemfile.
# =============================================================================

gemfile = File.expand_path('../../Gemfile', __FILE__)
if File.exist?(gemfile)
  console_output "boot - bundler #{gemfile} ..."
  begin
    ENV['BUNDLE_GEMFILE'] = gemfile
    require 'bundler'
    Bundler.setup
  rescue Bundler::GemNotFound => e
    STDERR.puts "#{e.message}\nTry running `bundle install`."
    exit!
  end
else
  console_output "boot - skipping #{gemfile} ..."
end

console_output 'Starting Rails...'
