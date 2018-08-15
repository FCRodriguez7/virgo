# config/application.rb

require File.expand_path('../boot', __FILE__)
require 'rails/all'

# If you have a Gemfile, require the gems listed there, including any gems
# you've limited to :test, :development, or :production.
if defined?(Bundler)
  if Rails::VERSION::MAJOR < 4
    # For Rails 3, production already has compiled assets but non-production
    # environments need gems from the :assets group.
    non_production = [:development, :test, :search_development, :search_test]
    Bundler.require(*Rails.groups(assets: non_production))
  else
    # For Rails 4, back to the original way.
    # @see https://stackoverflow.com/questions/9304607/sass-rails-helpers-image-url-asset-url-are-not-working-in-rails-3-2-1
    Bundler.require(:default, Rails.env)
  end
end

# Wrap error messages with a span of class "fieldWithErrors".
ActionView::Base.field_error_proc =
  proc do |html_tag, _instance|
    content_tag(:span, html_tag.html_safe, class: 'fieldWithErrors')
  end

require 'exception_notification'

module Virgo

  # The Rails application which provides the Virgo service.
  #
  # Settings in config/environments/* take precedence over those specified
  # here. Application configuration should go into files in config/initializers
  # -- all .rb files in that directory are automatically loaded.
  #
  class Application < Rails::Application

    config.application_name = 'Virgo'

    # Configure the default encoding used in templates for Ruby 1.9.
    config.encoding = 'utf-8'

    # Set Time.zone default to the specified zone and make Active Record
    # auto-convert to this zone. Run "rake -D time" for a list of tasks for
    # finding time zone names. Default is UTC.
    config.time_zone = 'Eastern Time (US & Canada)'
    config.active_record.default_timezone = :local

    # =========================================================================
    # Paths
    # =========================================================================

    # Custom directories with classes and modules you want to be autoloadable.
    rails_3 = (Rails::VERSION::MAJOR < 4)
    eager_dirs = %w(lib/ext lib/uva lib/firehose)
    eager_dirs += %w(app/controllers/concerns app/models/concerns) if rails_3
    eager_dirs.each do |path|
      path = "#{config.root}/#{path}" if rails_3
      config.eager_load_paths << path if Dir.exist?(path)
    end

    # =========================================================================
    # Caching
    # =========================================================================

    # The production environment is meant for finished, "live" apps.
    # Code is not reloaded between requests.
    config.cache_classes = true
    config.action_controller.perform_caching = true

    # Do not display error reports for failed requests.
    config.consider_all_requests_local = false

    # Use a different cache store if directed.
    # config.cache_store = :mem_cache_store
    config.cache_store = :file_store, ENV['CACHE_DIR'] if ENV['CACHE_DIR']

    # =========================================================================
    # Logging
    # =========================================================================

    # Configure sensitive parameters which will be filtered from the log file.
    config.filter_parameters += [:password]

    # Set logging level explicitly.
    config.log_level = :info

    # =========================================================================
    # Assets
    # =========================================================================

    # Use the asset pipeline.
    config.assets.enabled = true

    # With `config.assets.digest = true` this number can stay constant.  If it
    # is changed then *all* assets will be expired, and the browser client will
    # be forced to reload *all* assets.
    config.assets.version = '3.0'

    # Compress JavaScripts and CSS in deployed environments.
    config.assets.compress = true
    config.assets.digest   = true

    # Choose the compressors to use if config.assets.compress is *true*.
    config.assets.css_compressor = :yui
    config.assets.js_compressor  = :yui

    # Include stored vendor assets.
    config.assets.paths << Rails.root.join('vendor/assets').to_s

    # Precompile all top-level Javascript and CSS files.
    config.assets.precompile +=
      Dir['app/assets/*/*.{js,*css}'].map { |f| File.basename(f, '.scss') }

    # JavaScript files you want as :defaults
    # (application.js is always included).
    # config.action_view.javascript_expansions[:defaults] = %w(jquery rails)

    # Quiet_assets control:
    # Simply installing Quiet Assets will suppress the log messages
    # automatically. However, if you wish to temporarily re-enable the logging
    # of the asset pipeline messages, uncomment this line:
    # config.quiet_assets = false

    # Quiet_assets control:
    # If you need to suppress output for other paths you can do so
    # by uncommenting this line and specifying a path where /silent/ is:
    # config.quiet_assets_paths << '/silent/'

    # Enable serving of images, stylesheets and scripts from an asset server.
    # config.action_controller.asset_host = 'http://assets.example.com'

    # =========================================================================
    # Notifications
    # =========================================================================

    # Specifies the header that your server uses for sending files.
    # - For Apache:
    config.action_dispatch.x_sendfile_header = 'X-Sendfile'
    # - For Nginx:
    # config.action_dispatch.x_sendfile_header = 'X-Accel-Redirect'
    # - If you have no front-end server then just comment these out and Rails
    # will serve the files.

    # =========================================================================
    # Exceptions
    # =========================================================================

    # Send deprecation notices to the Rails logger.
    config.active_support.deprecation = :log

    # =========================================================================
    # I18N
    # =========================================================================

    config.i18n.enforce_available_locales = false

    # The default locale is :en and all translations from
    # config/locales/*.rb,yml are auto loaded.
    # config.i18n.default_locale = :en
    # config.i18n.load_path +=
    #   Dir[Rails.root.join('my', 'locales', '*.{rb,yml}').to_s]

    # Raise an error if no translation exists for the specified locale.
    config.i18n.fallbacks = false

    # =========================================================================
    # Other
    # =========================================================================

    # Only load the plugins named here, in the order given (default is
    # alphabetical). :all can be used as a placeholder for all plugins not
    # explicitly named.
    # config.plugins = [:exception_notification, :ssl_requirement, :all]
    config.plugins = [:all]

    # Activate observers that should always be running.
    # config.active_record.observers =
    #   :cacher, :garbage_collector, :forum_observer

    # =========================================================================
    # Constants
    # =========================================================================

    # API KEYS FOR UVA
    LIBRARY_THING_API_KEY = 'xxx'.freeze
    LAST_FM_API_KEY       = 'xxx'.freeze

    # =========================================================================
    # Environment
    # =========================================================================

    ENV['CACHE_DIR']           ||= Rails.root.join('tmp/cache/file_store').to_s
    ENV['COVER_IMAGE_URL']     ||= 'https://xxx.virginia.edu'
    ENV['RECAPTCHA_PUBLIC_KEY']  = 'xxx'
    ENV['RECAPTCHA_PRIVATE_KEY'] = 'xxx'

    # =========================================================================
    # Initializers
    # =========================================================================

    class Engine < Rails::Engine

      # We don't use the Blacklight gem's assets, and they cause problems with
      # rake assets:precompile, so we remove everything besides
      # /app/assets/javascripts/, /app/assets/stylesheets/,
      # /vendor/assets/stylesheets/, /vendor/assets/javascripts/, and
      # /vendor/assets/images/ from our asset paths.
      #
      # === References
      # @see https://stackoverflow.com/questions/7163264/rails-3-1-asset-pipeline-ignore-assets-from-a-gem
      #
      initializer 'remove extra assets from pipeline' do |app|
        all_paths        = app.config.assets.paths
        blacklight_paths = all_paths.grep(%r{/blacklight(-[0-9]|_advanced)})
        app.config.assets.paths = (all_paths - blacklight_paths).uniq
      end

      # Wipe cache before responding to the first request.  This has to be done
      # "manually" for ActiveSupport::Cache::FileStore.  (It would have been
      # preferable to do `Rails.cache.cleanup` but there seems to be a problem
      # with that in this version of Rails.)
      #
      # This causes problems with rake, so only perform the action if running
      # the Rails application.
      #
      initializer 'clean cache', after: :initialize_cache do |app|
        if running_rails_application? && Rails.cache.respond_to?(:cache_path)
          if Dir.exist?(Rails.cache.cache_path)
            Rails.cache.clear
          else
            FileUtils.mkpath(Rails.cache.cache_path)
          end
        end
      end

    end

    console_output "Starting #{config.application_name}..."

  end

end
