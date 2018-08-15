# config/initializers/mime_types.rb
#--
# rubocop:disable Metrics/LineLength
#++

# Be sure to restart your server when you modify this file.

# Add new mime types for use in respond_to blocks:
# Mime::Type.register 'text/richtext', :rtf
# Mime::Type.register_alias 'text/html', :iphone
Mime::Type.register_alias 'image/jpeg',                    :jpg     unless Mime::Type.lookup_by_extension(:jpg)
Mime::Type.register 'application/x-endnote-refer',         :endnote unless Mime::Type.lookup_by_extension(:endnote)
Mime::Type.register 'application/x-research-info-systems', :ris     unless Mime::Type.lookup_by_extension(:ris)
Mime::Type.register 'application/marc',                    :marc    unless Mime::Type.lookup_by_extension(:marc)
