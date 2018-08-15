# lib/firehose/patron.rb

require 'firehose/api'

# Firehose::Patron
#
module Firehose::Patron

  include UVA

  # ===========================================================================
  # :section:
  # ===========================================================================

  public

  # Get Sirsi account information about the given patron.
  #
  # @param [String] computing_id
  # @param [Hash]   opt               Options to cache #fetch.
  #
  # @return [Firehose::User]
  # @return [nil]
  #
  def get_patron(computing_id, opt = nil)
    computing_id = computing_id.to_s.strip
    return if computing_id.blank?
    opt ||= {}
    get_args = ['users', computing_id, opt]
    xml = Firehose::API.get(*get_args)
    Firehose::User.parse(xml, single: true)

  rescue SocketError, EOFError
    Firehose::API.discard(*get_args)
    raise # Handled by ApplicationController

  rescue => e
    Firehose::API.discard(*get_args)
    Rails.logger.warn {
      "FIREHOSE #{__method__}(#{computing_id}): #{e.message}"
    }
    nil
  end

  # Returns true if the *patron* has the given *pin*.
  #
  # @param [Firehose::User] patron
  # @param [String] pin
  #
  # @return [Boolean]
  #
  def check_pin(patron, pin)
    patron.is_a?(Firehose::User) && (patron.pin == pin.to_s.strip)
  end

end
