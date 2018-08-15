# lib/uva/advanced_search/catalog_helper_override.rb

require 'uva'

module UVA::AdvancedSearch

  # UVA::AdvancedSearch::CatalogHelperOverride
  #
  # An override of BlacklightAdvancedSearch::CatalogHelperOverride to modify
  # BlacklightAdvancedSearch::CatalogHelperOverride#remove_advanced_facet_param
  # behavior.
  #
  module CatalogHelperOverride

    include UVA

    # =========================================================================
    # :section: BlacklightHelperBehavior overrides
    # =========================================================================

    public

    # An override of Blacklight functionality to do a "deep dup" of the
    # *params* argument.
    #
    # @param [String, Symbol] field       The facet field to change.
    # @param [String]         value       The facet value to remove.
    # @param [Hash]           url_params  Default: `params`
    #
    # @return [Hash]
    #
    def remove_advanced_facet_param(field, value, url_params = nil)
      remove_advanced_facet(field, value, url_params)
    end

  end

end
