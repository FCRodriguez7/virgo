# config/initializers/cookie_verification_secret.rb
#--
# rubocop:disable Metrics/LineLength
#++

# Your secret key for verifying cookie session data integrity.
# If you change this key, all old sessions will become invalid!
# Make sure the secret is at least 30 characters and all random,
# no regular words or you'll be exposed to dictionary attacks.
Rails.application.config.secret_token = 'xxx'
