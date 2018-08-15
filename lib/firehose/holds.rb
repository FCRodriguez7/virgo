# lib/firehose/holds.rb

require 'firehose/api'

# Firehose::Holds
#
module Firehose::Holds

  extend Firehose::Common

  include UVA

  # ===========================================================================
  # :section:
  # ===========================================================================

  public

  MESSAGE = {
    no_items:      'There were no items to request',
    not_cataloged: 'This item is not available for requests yet',
    failed:        'Unable to request items right now',
  }.deep_freeze

  FIREHOSE_RESPONSE = {
    no_items:       'no items',
    not_cataloged:  'does not exist',
    failed:         nil
  }.deep_freeze

  # ===========================================================================
  # :section:
  # ===========================================================================

  public

  # Get the requests (holds and recalls) associated with the given patron.
  #
  # @param [String] computing_id
  # @param [Hash]   opt               Options to cache #fetch.
  #
  # @return [Firehose::User]
  # @return [nil]
  #
  def get_holds(computing_id, opt = nil)
    return if computing_id.blank?
    opt ||= {}
    get_args = ['users', computing_id, 'holds', opt]
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

  # Request a hold/recall of an item on behalf of a given patron.
  #
  # @param [String] computing_id
  # @param [String] id
  # @param [String] library_id
  # @param [String] call_number
  #
  # @return [String]
  #
  # @raise [Firehose::HoldError]
  #
  def place_hold(computing_id, id, library_id, call_number = nil)
    return if computing_id.blank?
    http_params = {
      'computingId'     => computing_id,
      'catalogId'       => ckey_converter(id),
      'pickupLibraryId' => library_id
    }
    http_params['callNumber'] = call_number unless call_number.blank?
    result = Firehose::API.post('request', 'hold', http_params)
    unless result.is_a?(Net::HTTPSuccess) || result.is_a?(Net::HTTPRedirection)
      message = get_error_message(result, __method__)
      key = key_lookup(message, FIREHOSE_RESPONSE)
      message = MESSAGE[key] if key
      raise Firehose::HoldError, message
    end
    result.body
  end

end
