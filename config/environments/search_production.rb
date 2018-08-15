# config/environments/search_production.rb
#
# Settings here will take precedence over those in config/application.rb.

Virgo::Application.configure do

  # ===========================================================================
  # Caching
  # ===========================================================================

  # The production environment is meant for finished, "live" apps.
  # Code is not reloaded between requests.
  config.cache_classes = true
  config.action_controller.perform_caching = true

  # Do not display error reports for failed requests.
  config.consider_all_requests_local = false

  # ===========================================================================
  # Logging
  # ===========================================================================

  # Reduce clutter in the production log by assuming that accidental calls on
  # nil will be noted in development.
  config.whiny_nils = false

  # ===========================================================================
  # Assets
  # ===========================================================================

  # Disable Rails static asset server; this will be handled by the web server.
  config.serve_static_assets = false

  # ===========================================================================
  # Notifications
  # ===========================================================================

  # Mail delivery.
  config.action_mailer.delivery_method       = :smtp
  config.action_mailer.perform_deliveries    = true
  config.action_mailer.raise_delivery_errors = true
  config.action_mailer.smtp_settings = {
    address: 'localhost',
    domain:  'search.lib.virginia.edu'
  }

  # Send a mail message for every exception.
  config.middleware.use ExceptionNotification::Rack, email: {
    email_prefix:         '[virgo] ',
    sender_address:       '"Error" <xxx@virginia.edu>',
    exception_recipients: %w(xxx@virginia.edu)
  }

  # ===========================================================================
  # Exceptions
  # ===========================================================================

  # Send deprecation notices to registered listeners.
  config.active_support.deprecation = :notify

  # ===========================================================================
  # I18N
  # ===========================================================================

  # Makes lookups for any locale fall back to `I18n.default_locale` when a
  # translation can not be found.  (Invalid locales should have already been
  # detected in development.)
  config.i18n.fallbacks = true

  # ===========================================================================
  # Other
  # ===========================================================================

  # Tune settings for multi-threaded operation.
  config.threadsafe!

  # GC.copy_on_write_friendly = true
  # GC.limit = 256000000

  # ===========================================================================
  # Constants
  # ===========================================================================

  FEEDBACK_RECIPIENTS = %w(xxx@virginia.edu).freeze
  FEEDBACK_FROM       = 'xxx@virginia.edu'.freeze
  FEEDBACK_SUBJECT    = 'Virgo Feedback'.freeze

  RESERVE_EMAIL               = 'xxx@virginia.edu'.freeze
  RESERVE_COORDINATOR_SCI     = RESERVE_EMAIL
  RESERVE_COORDINATOR_CLEMONS = RESERVE_EMAIL
  RESERVE_COORDINATOR_FA      = RESERVE_EMAIL
  RESERVE_COORDINATOR_LAW     = 'xxx@virginia.edu'.freeze
  RESERVE_COORDINATOR_MUSIC   = RESERVE_EMAIL
  RESERVE_COORDINATOR_PHYS    = RESERVE_EMAIL
  RESERVE_COORDINATOR_RMC     = "RMC Resv <#{RESERVE_EMAIL}>".freeze

  FIREHOSE_URL = 'http://xxx.virginia.edu/xxx'.freeze

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
