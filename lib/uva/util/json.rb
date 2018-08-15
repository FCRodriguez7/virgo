# lib/uva/util/json.rb

require 'uva/util'

module UVA::Util

  module Json

    # A wrapper for parsing JSON (without raising exceptions by default).
    #
    # @param [Object]    object
    # @param [Hash, nil] opt
    #
    # @option opt [Boolean] :raise    Indicate whether exceptions are allowed
    #                                   to be raised (default: *false*).
    # @option opt [Object]  :default  The value to return if the parse fails
    #                                   (default: *nil*).
    #
    # @return [Hash, Array, Object, nil]
    #
    # == Usage Note
    # Exceptions are not logged.
    #
    def json_parse(object, opt = nil)
      opt ||= {}
      if opt[:raise]
        JSON.parse(object)
      else
        JSON.parse(object) rescue opt[:default]
      end
    end

  end

end
