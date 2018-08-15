# config/environments/test.rb
#
# Settings here will take precedence over those in config/application.rb.
#
# The test environment is used exclusively to run your application's test
# suite.  You never need to work with it otherwise.  Remember that your test
# database is "scratch space" for the test suite and is wiped and recreated
# between test runs.  Don't rely on the data there!

Virgo::Application.configure do

  # ===========================================================================
  # Caching
  # ===========================================================================

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

  # ===========================================================================
  # Notifications
  # ===========================================================================

  # Do not deliver emails to the real world; the :test delivery method
  # accumulates sent emails in the ActionMailer::Base.deliveries array.
  config.action_mailer.delivery_method       = :test
  config.action_mailer.perform_deliveries    = true
  config.action_mailer.raise_delivery_errors = true

  # ===========================================================================
  # Exceptions
  # ===========================================================================

  # Raise exceptions instead of rendering exception templates.
  config.action_dispatch.show_exceptions = false

  # Send deprecation notices to stderr.
  config.active_support.deprecation = :stderr

  # ===========================================================================
  # Other
  # ===========================================================================

  # Disable request forgery protection in test environment.
  config.action_controller.allow_forgery_protection = false

  # Use SQL instead of Active Record's schema dumper when creating the test
  # database. This is necessary if your schema can't be completely dumped by
  # the schema dumper, like if you have constraints or database-specific column
  # types.
  # config.active_record.schema_format = :sql

  # ===========================================================================
  # Constants
  # ===========================================================================

  FEEDBACK_RECIPIENTS = %w(xxx@virginia.edu).freeze
  FEEDBACK_FROM       = 'xxx@virginia.edu'.freeze
  FEEDBACK_SUBJECT    = 'Virgo Feedback (test)'.freeze

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
    'http://xxx.virginia.edu/' \
    'PrimoWebServices/xservice/search/brief?' \
    'institution=UVA&onCampus=true'.freeze

  # Endpoint for Patron-Driven Acquisition (PDA) web service.
  PDA_WEB_SERVICE = 'http://xxx.virginia.edu/xxx'.freeze

  console_output "Configured for #{Rails.env}"

end
