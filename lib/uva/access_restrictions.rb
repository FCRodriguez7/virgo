# lib/uva/access_restrictions.rb

require 'uva'

module UVA

  # UVA::AccessRestrictions
  #
  module AccessRestrictions

    include UVA
    include UVA::Networks

    ACCESS_POLICIES = {
      public:  %w(public  uva-lib:2141109),
      uva:     %w(uva     uva-lib:2141110),
      private: %w(private uva-lib:2141112),
    }.deep_freeze

    # =========================================================================
    # :section:
    # =========================================================================

    public

    # Checks if the resource described by the supplied Solr document is blocked
    # for the current user.  If it is, the method returns an array of
    #
    #   - true
    #   - the label of the policy
    #   - the full text description of the policy that blocks access
    #
    # If not, the same array is returned but with an initial value of false.
    #
    # @param [SolrDocument] doc
    #
    # @return [Array<(Boolean,String,String)>]
    #
    def access_restricted(doc)
      policy_pid = doc && doc.values_for(:policy_facet).first
      policy =
        if policy_pid.blank?
          :public
        else
          ACCESS_POLICIES.find { |k, v| break k if v.include?(policy_pid) }
        end
      case policy || policy_pid
        when :public
          blocked     = false
          label       = nil
          description = nil

        when :uva
          blocked     = !on_grounds?
          label       = 'UVA-Only'
          description = %q(
            Due to intellectual property and/or licensing restrictions, access
            to digital representations of this resource is only available to
            users on the University of Virginia Grounds or connected through
            the UVA virtual private network.
          ).squish

        when :private
          blocked     = true
          label       = 'Unavailable'
          description = %q(
            The digitized version of this resource is not currently available
            to the public.
          ).squish

        else
          blocked     = true
          label       = 'Unknown'
          description = "Unknown access control policy: \"#{policy_pid}\""
      end
      return blocked, label, description
    end

  end

end
