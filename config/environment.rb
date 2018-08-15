# config/environment.rb

# Load the Rails application.
require File.expand_path('../application', __FILE__)

# Initialize the Rails application.
Virgo::Application.initialize!

# Determine the version number based on the git repo tag.
unless defined?(APP_VERSION)
  APP_VERSION = (`git describe --abbrev=0` || '3.xx').to_s.strip.freeze
end

# Announce startup in the log and via email.
running_rails_application? && Rails.logger.unknown {
  bar = '-' * 72
  <<-EOS.gsub(/^ *\|/, '').rstrip
    |\n#{bar}
    |STARTING #{Rails.application.config.application_name} AT #{DateTime.now}
    |  APP_VERSION     = #{APP_VERSION}
    |  RAILS_ENV       = #{ENV['RAILS_ENV']}
    |  Virgo.deployed? = #{Virgo.deployed?}
    |  SOLR_URL        = #{Blacklight.solr.options[:url]}
    |  FIREHOSE_URL    = #{FIREHOSE_URL}
    |  PDA_WEB_SERVICE = #{PDA_WEB_SERVICE}
    |  FEDORA_REST_URL = #{FEDORA_REST_URL}
    |  COVER_IMAGE_URL = #{ENV['COVER_IMAGE_URL']}
    |  CACHE_DIR       = #{ENV['CACHE_DIR']}
    |  RUBY_VERSION    = #{ENV['RUBY_VERSION']}
    |  RUBYOPT         = #{ENV['RUBYOPT']}
    |  LANG            = #{ENV['LANG']}
    |  LOGNAME         = #{ENV['LOGNAME']}
    |  PWD             = #{ENV['PWD']}
    |  SHELL           = #{ENV['SHELL']}
    |#{bar}
  EOS
}.tap { |body|
  # Send an email to "error" destination to visually separate errors reported
  # before the restart from errors reported after the restart.
  if Virgo.deployed?
    dst_addr  = 'xxx@virginia.edu'
    app_name  = Rails.application.config.application_name
    full_host = Socket.gethostname
    host_name = full_host.to_s.sub(/\..*$/, '')
    msg = {
      from:    "Restart #{host_name} <#{dst_addr}>",
      to:      dst_addr,
      subject: "STARTING #{app_name} ON #{full_host}",
      body:    "#{body.to_s.strip}\n\n"
    }
    ActionMailer::Base.mail(msg).deliver
  end
}
