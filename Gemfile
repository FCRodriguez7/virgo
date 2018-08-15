# Gemfile

source 'http://rubygems.org'

# Virgo currently uses:
#    Ruby 1.9.3-p547  (ruby --version)
#    Rubygems 2.2.2   (gem --version)
#    Rake 10.3.2      (rake --version)
#    Rails 3.1.10     (rails --version)

gem 'rails', '3.1.10'
gem 'bundler'
gem 'blacklight', '3.3.2'
gem 'blacklight_advanced_search', '1.2.4'
gem 'authlogic', '3.1.0'
gem 'curb'
gem 'exception_notification'
gem 'hoe', '2.9.1'
gem 'marc', '0.4.3'
gem 'mysql', '2.8.1'
gem 'nokogiri', '1.5.0'
gem 'prawn'
gem 'prawnto_2', require: 'prawnto'
gem "recaptcha", require: "recaptcha/rails", tag: 'v0.4.0'
gem 'rest-client'
gem 'rsolr', '1.0.6'
gem 'rsolr-ext', '1.0.3'
# gem 'ruby-net-ldap', '0.0.4'
gem 'rubytree', '0.5.2'
gem 'will_paginate'
gem 'uva-happymapper', '0.4.1'
gem 'selenium-webdriver', '2.25.0'
gem 'xml-mapping'
gem 'yui-compressor'
gem 'htmlentities'
gem 'sanitize'
gem 'summon'
gem 'openurl'
gem 'multi_json', '1.2.0'
gem 'prometheus-client'

# Added for upgrade to Ruby 1.9.3-p547
gem 'rubyzip', '~> 0.9.9'
gem 'net-ldap'
gem 'kaminari', '0.13'

# =============================================================================
# Asset pipeline support for "rake assets:precompile".
# NOTE: Support for the :assets group goes away with Rails 4
# =============================================================================

group :assets do
  gem 'sprockets'
  gem 'sass-rails'
  gem 'compass-rails'
end

# =============================================================================
# Development and integration test
# =============================================================================

# Turn off Rails asset pipeline logging.
# @see config/application.rb
# @see https://github.com/evrone/quiet_assets
gem 'quiet_assets'

group :development, :test, :search_test, :cucumber do
  gem 'database_cleaner'
  gem 'fakeweb'
  gem 'mocha'
  gem 'cucumber', '1.2.1'
  gem 'gherkin'
  gem 'webrat'
  gem 'rspec', '~>2.7.0'
  gem 'rspec-rails', '~>2.7.0'
  gem 'launchy'
  gem 'webrick'
  gem 'simplecov', '~> 0.7.1', require: false
  gem 'poltergeist'
  gem 'factory_girl_rails'
  gem 'faker'
  gem 'vcr'
  gem 'webmock', '~> 2.2.0'
end

group :development, :test do
  gem 'pry'
  gem 'pry-rails'
  gem 'rb-readline'
end


group :test, :search_test, :cucumber do
  gem 'cucumber-rails', require: false
end

# For the deployed development server, "opacdev.lib.virginia.edu".
# NOTE: This has been removed for now because it causes SystemStackError
# in the /music and /video routes.
# group :search_development do
#   # Syslog support
#   gem 'syslogger'
# end

# The "production" environment assumes a desktop build with a local instance of
# Passenger installed.  (It isn't necessary to install Apache -- Passenger can
# use a built-in version of Nginx).
group :production do
  gem 'passenger'
end
