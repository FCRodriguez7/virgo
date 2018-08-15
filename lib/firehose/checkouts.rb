# lib/firehose/checkouts.rb

require 'firehose/api'

# Firehose::Checkouts
#
module Firehose::Checkouts

  extend Firehose::Common

  include UVA

  # ===========================================================================
  # :section:
  # ===========================================================================

  public

  MESSAGE = {
    no_items: 'There were no items to renew',
    failed:   'Unable to renew all items right now',
  }.deep_freeze

  FIREHOSE_RESPONSE = {
    no_items:  /no items/i,
    failed:    nil
  }.deep_freeze

  # ===========================================================================
  # :section:
  # ===========================================================================

  public

  # get_checkouts
  #
  # @param [String] computing_id
  # @param [Hash]   opt               Options to cache #fetch.
  #
  # @return [Firehose::User]
  # @return [nil]
  #
  def get_checkouts(computing_id, opt = nil)
    return if computing_id.blank?
    opt ||= {}
    get_args = ['users', computing_id, 'checkouts', opt]
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

  # do_renew_all
  #
  # @param [String] computing_id
  #
  # @return [String]
  #
  # @raise [Firehose::RenewError]
  #
  def do_renew_all(computing_id)
    return if computing_id.blank?
    http_params = {
      'computingId' => computing_id
    }
    result = Firehose::API.post('request', 'renewAll', http_params)
    unless result.is_a?(Net::HTTPSuccess) || result.is_a?(Net::HTTPRedirection)
      message = get_error_message(result, __method__)
      key = key_lookup(message, FIREHOSE_RESPONSE)
      message = MESSAGE[key] if key
      raise Firehose::RenewError, message
    end
    result.body
  end

  # do_renew
  #
  # @param [String] computing_id
  # @param [String] checkout_key
  #
  # @return [String]
  #
  # @raise [Firehose::RenewError]
  #
  def do_renew(computing_id, checkout_key = nil)
    return unless computing_id
    http_params = {
      'computingId' => computing_id,
      'checkoutKey' => checkout_key
    }
    result = Firehose::API.post('request', 'renew', http_params)
    unless result.is_a?(Net::HTTPSuccess) || result.is_a?(Net::HTTPRedirection)
      message = get_error_message(result, __method__)
      key = key_lookup(message, FIREHOSE_RESPONSE)
      message = MESSAGE[key] if key
      raise Firehose::RenewError, message
    end
    result.body
  end

end
