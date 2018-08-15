# lib/uva/ldap.rb

require 'net/ldap'
require 'uva'

module UVA

  # UVA::Ldap
  #
  module Ldap

    include UVA

    HOST = 'ldap.virginia.edu'.freeze
    BASE = 'o=University of Virginia,c=US'.freeze

    # =========================================================================
    # :section:
    # =========================================================================

    public

    # full_name
    #
    # @param [String] uid
    #
    # @return [String]
    #
    def full_name(uid = nil)
      uid ||= self.user_id
      ldap_value = {}

      # Query LDAP for the given UVa computing ID.
      ldap_args = {
        filter:        Net::LDAP::Filter.eq('userid', uid),
        attributes:    [],
        return_result: true
      }
      Net::LDAP.new(host: HOST, base: BASE).search(ldap_args) do |ldap_entry|
        ldap_entry.attribute_names.each do |n|
          ldap_value[n] = ldap_entry[n]
        end
      end

      # Return first and last names combined into a single String.
      [
        ldap_value[:givenname], # First name
        ldap_value[:sn]         # Last name
      ].map { |v| v && v.first }.compact.join(SPACE)
    end

  end
end
