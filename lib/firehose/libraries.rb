# lib/firehose/libraries.rb

require 'firehose/api'

# Firehose::Libraries
#
module Firehose::Libraries

  include UVA

  extend self

  # ===========================================================================
  # :section:
  # ===========================================================================

  public

  # Get the list of libraries known to Firehose.
  #
  # @param [Hash]   opt               Options to cache #fetch.
  #
  # @return [Firehose::LibraryList]
  # @return [nil]                     If the data could not be acquired.
  #
  def get_library_list(opt = nil)
    opt ||= {}
    get_args = ['list', 'libraries', opt]
    xml = Firehose::API.get(*get_args)
    Firehose::LibraryList.parse(xml, single: true)

  rescue SocketError, EOFError
    Firehose::API.discard(*get_args)
    raise # Handled by ApplicationController

  rescue => e
    Firehose::API.discard(*get_args)
    Rails.logger.debug { "FIREHOSE #{__method__}: #{e.message}" }
    nil
  end

end
