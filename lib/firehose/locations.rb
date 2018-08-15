# lib/firehose/locations.rb

require 'firehose/api'

# Firehose::Locations
#
module Firehose::Locations

  include UVA

  extend self

  # ===========================================================================
  # :section:
  # ===========================================================================

  public

  # Get the list of home locations known to Firehose.
  #
  # @param [Hash]   opt               Options to cache #fetch.
  #
  # @return [Firehose::LocationList]
  # @return [nil]                     If the data could not be acquired.
  #
  def get_location_list(opt = nil)
    opt ||= {}
    get_args = ['list', 'locations', opt]
    xml = Firehose::API.get(*get_args)
    Firehose::LocationList.parse(xml, single: true)

  rescue SocketError, EOFError
    Firehose::API.discard(*get_args)
    raise # Handled by ApplicationController

  rescue => e
    Firehose::API.discard(*get_args)
    Rails.logger.debug { "FIREHOSE #{__method__}: #{e.message}" }
    nil
  end

end
