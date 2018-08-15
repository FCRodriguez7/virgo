# config/environments/production.rb
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

  # Disable Rails static asset server; this will be handled by the web server.
  config.serve_static_assets = false

  # Compress JavaScripts and CSS in deployed environments.
  config.assets.compress = false

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
    email_prefix:         '[virgo] ',
    sender_address:       '"Error" <xxx@virginia.edu>',
    exception_recipients: %w(xxx@virginia.edu)
  }

  # Specifies the header that your server uses for sending files.
  # - For Apache:
  # config.action_dispatch.x_sendfile_header = 'X-Sendfile'
  # - For Nginx:
  config.action_dispatch.x_sendfile_header = 'X-Accel-Redirect'
  # - If you have no front-end server then just comment these out and Rails
  # will serve the files.

  # ===========================================================================
  # Other
  # ===========================================================================

  # Tune settings for multi-threaded operation.
  config.threadsafe!

  # ===========================================================================
  # Constants
  # ===========================================================================

  FEEDBACK_RECIPIENTS = %w(xxx@virginia.edu).freeze
  FEEDBACK_FROM       = 'xxx@virginia.edu'.freeze
  FEEDBACK_SUBJECT    = 'Virgo Feedback (production)'.freeze

  RESERVE_EMAIL               = 'xxx@virginia.edu'.freeze
  RESERVE_COORDINATOR_SCI     = "Sci Resv <#{RESERVE_EMAIL}>".freeze
  RESERVE_COORDINATOR_CLEMONS = "Clemons Resv <#{RESERVE_EMAIL}>".freeze
  RESERVE_COORDINATOR_FA      = "Fine Arts Resv <#{RESERVE_EMAIL}>".freeze
  RESERVE_COORDINATOR_LAW     = "Law Resv <#{RESERVE_EMAIL}>".freeze
  RESERVE_COORDINATOR_MUSIC   = "Music Resv <#{RESERVE_EMAIL}>".freeze
  RESERVE_COORDINATOR_PHYS    = "Physics Resv <#{RESERVE_EMAIL}>".freeze
  RESERVE_COORDINATOR_RMC     = "RMC Resv <#{RESERVE_EMAIL}>".freeze

  FIREHOSE_URL = 'http://xxx.virginia.edu/xxx'.freeze
  # FIREHOSE_URL = 'http://xxx.virginia.edu/xxx'.freeze
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

  console_output "Configured for #{Rails.env}"

end
