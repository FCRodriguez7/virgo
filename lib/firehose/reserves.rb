# lib/firehose/reserves.rb

require 'firehose/api'

# Firehose::Reserves
#
module Firehose::Reserves

  include UVA

  # ===========================================================================
  # :section:
  # ===========================================================================

  public

  # Get Sirsi reserves associated with the given patron.
  #
  # @param [String] computing_id
  # @param [Hash]   opt               Options to cache #fetch.
  #
  # @return [Firehose::User]
  # @return [nil]
  #
  def get_reserves(computing_id, opt = nil)
    return unless computing_id
    opt ||= {}
    get_args = ['users', computing_id, 'reserves', opt]
    xml = Firehose::API.get(*get_args)
    Firehose::User.parse(xml, single: true)

  rescue SocketError, EOFError
    Firehose::API.discard(*get_args)
    raise # Handled by ApplicationController

  rescue => e
    Firehose::API.discard(*get_args)
    Rails.logger.debug { "FIREHOSE #{__method__}: #{e.message}" }
    nil
  end

end
