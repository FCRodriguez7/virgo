# config/environments/development.rb
#
# Settings here will take precedence over those in config/application.rb.

Virgo::Application.configure do

  # ===========================================================================
  # Caching
  # ===========================================================================

  # In the development environment your application's code is reloaded on
  # every request.  This slows down response time but is perfect for
  # development since you don't have to restart the web server when you make
  # code changes.
  # config.cache_classes = false
  # config.action_controller.perform_caching = false

  # Display error reports for failed requests.
  config.consider_all_requests_local = true

  # ===========================================================================
  # Logging
  # ===========================================================================

  # Set logging level explicitly.
  config.log_level = :debug

  # Log error messages when you accidentally call methods on nil.
  config.whiny_nils = true

  # ===========================================================================
  # Assets
  # ===========================================================================

  # Compress JavaScripts and CSS in deployed environments.
  config.assets.compress = false

  # If we don't set a different assets path, the precompiled production
  # versions will be delivered in dev, making it very hard to debug JavaScript.
  config.assets.debug  = true
  config.assets.prefix = '/dev-assets'

  # ===========================================================================
  # Notifications
  # ===========================================================================

  # Mail "deliveries" are appended to "#{Rails.root}/tmp/mail/#{dst_addr}".
  config.action_mailer.delivery_method       = :file
  config.action_mailer.perform_deliveries    = true
  config.action_mailer.raise_delivery_errors = false
  config.action_mailer.file_settings = {
    location: Rails.root.join('tmp/mail')
  }

  # Send a mail message for every exception.
  config.middleware.use ExceptionNotification::Rack, email: {
    email_prefix:         '[virgo dev] ',
    sender_address:       '"Error" <xxx@virginia.edu>',
    exception_recipients: %w(xxx@virginia.edu)
  }

  # ===========================================================================
  # Constants
  # ===========================================================================

  FEEDBACK_RECIPIENTS = %w(xxx@virginia.edu).freeze
  FEEDBACK_FROM       = 'xxx@virginia.edu'.freeze
  FEEDBACK_SUBJECT    = 'Virgo Feedback (dev)'.freeze

  RESERVE_EMAIL               = 'xxx@virginia.edu'.freeze
  RESERVE_COORDINATOR_SCI     = "Sci Resv <#{RESERVE_EMAIL}>".freeze
  RESERVE_COORDINATOR_CLEMONS = "Clemons Resv <#{RESERVE_EMAIL}>".freeze
  RESERVE_COORDINATOR_FA      = "Fine Arts Resv <#{RESERVE_EMAIL}>".freeze
  RESERVE_COORDINATOR_LAW     = "Law Resv <#{RESERVE_EMAIL}>".freeze
  RESERVE_COORDINATOR_MUSIC   = "Music Resv <#{RESERVE_EMAIL}>".freeze
  RESERVE_COORDINATOR_PHYS    = "Physics Resv <#{RESERVE_EMAIL}>".freeze
  RESERVE_COORDINATOR_RMC     = "RMC Resv <#{RESERVE_EMAIL}>".freeze

  # FIREHOSE_URL = 'http://xxx.virginia.edu/xxx'.freeze
  FIREHOSE_URL = 'http://xxx.virginia.edu/xxx'.freeze
  # FIREHOSE_URL = 'http://xxx.virginia.edu/xxx'.freeze

  FEDORA_REST_URL = 'http://xxx.virginia.edu'.freeze
  FEDORA_USERNAME = 'xxx'.freeze
  FEDORA_PASSWORD = 'xxx'.freeze

  PRIMO_URL =
    'http://primo4.hosted.exlibrisgroup.com:1701/' \
    'PrimoWebServices/xservice/search/brief?' \
    'institution=UVA&onCampus=true'.freeze

  # Endpoint for Patron-Driven Acquisition (PDA) web service.
  PDA_WEB_SERVICE = 'http://xxx.virginia.edu/xxx'.freeze

  # ===========================================================================
  # Environment
  # ===========================================================================

  # ENV['COVER_IMAGE_URL'] = 'https://xxx.virginia.edu'

  console_output "Configured for #{Rails.env}"

end
