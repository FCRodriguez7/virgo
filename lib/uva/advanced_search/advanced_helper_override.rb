# lib/uva/advanced_search/advanced_helper_override.rb

require 'uva'

module UVA::AdvancedSearch

  # UVA::AdvancedSearch::AdvancedHelperOverride
  #
  # An override of Blacklight advanced search AdvancedHelper.
  #
  module AdvancedHelperOverride

    include AdvancedHelper

    include UVA
    include UVA::Scope

    # =========================================================================
    # :section:
    # =========================================================================

    public

    IGNORE_FOR_ADVANCED = %w(
      page
      commit
      f_inclusive
      q
      search_field
      op
      action
      index
      sort
      controller
    ).map(&:to_sym).freeze

    # =========================================================================
    # :section: AdvancedHelper overrides
    # =========================================================================

    public

    # label_tag_default_for
    #
    # @param [Symbol, String] key
    #
    # @return [String]
    # @return [nil]
    #
    # Compare with:
    # @see AdvancedHelper#label_tag_default_for
    #
    def label_tag_default_for(key)
      if !null_search_term?(params[key])
        params[key]
      elsif params[:search_field].to_s == key.to_s
        params[:q]
      end
    end

    # advanced_search_context
    #
    # @return [Hash]
    #
    # Compare with:
    # @see AdvancedHelper#advanced_search_context
    #
    def advanced_search_context
      ignored = IGNORE_FOR_ADVANCED + search_fields_for_advanced_search.keys
      params.except(*ignored)
    end

    # search_fields_for_advanced_search
    #
    # @return [Hash]
    #
    # Compare with:
    # @see AdvancedHelper#search_fields_for_advanced_search
    #
    def search_fields_for_advanced_search
      @search_fields_for_advanced_search ||=
        advanced_search_fields.reject do |_, field_def|
          false_value?(field_def.include_in_advanced_search)
        end
    end

  end

end
