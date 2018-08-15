# lib/uva/exceptions.rb

require 'uva'

module UVA

  # UVA::Exceptions
  #
  module Exceptions

    include UVA

    # UVA::Exceptions::RedirectNeeded
    #
    class RedirectNeeded < RuntimeError

      # The redirect destination.
      #
      # @return [String]
      #
      alias_method(:new_url, :message)

    end

    # UVA::Exceptions::HiddenSolrID
    #
    class HiddenSolrID < RuntimeError; end

  end

end
