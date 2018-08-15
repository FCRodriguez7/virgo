# lib/uva/advanced_search/controller.rb

require 'uva'

module UVA::AdvancedSearch

  # UVA::AdvancedSearch::Controller
  #
  # This module gets mixed in to CatalogController to override
  # BlacklightAdvancedSearch::Controller#add_advanced_search_to_solr
  #
  module Controller

    # Hints for RubyMine (skipped during execution).
    include BlacklightAdvancedSearch::Controller unless ONLY_FOR_DOCUMENTATION

    include UVA
    include UVA::Helper::Library

    # =========================================================================
    # :section: BlacklightAdvancedSearch::Controller overrides
    # =========================================================================

    public

    # The only reason I'm overriding this method is to add the check for
    # "@advanced_query.range_queries.length > 0".
    #
    # This method should get added into the solr_search_params_logic
    # list, in a position AFTER normal query handling (:add_query_to_solr),
    # so it'll overwrite that if and only if it's an advanced search.
    #
    # Adds a 'q' and 'fq's based on advanced search form input.
    #
    # @param [Hash] solr_params
    # @param [Hash] url_params
    #
    # @return [void]
    #
    # Compare with:
    # @see BlacklightAdvancedSearch::Controller#add_advanced_search_to_solr
    #
    def add_advanced_search_to_solr(solr_params, url_params = nil)

      return unless solr_params.is_a?(Hash)
      url_params ||= params.rdup

      # If we've got the hint that we're doing an 'advanced' search, then
      # map that to solr #q, over-riding whatever some other logic may have
      # set, yeah. the hint right now is :search_field request param is set
      # to a magic key.
      config = current_blacklight_config
      url_key = config.advanced_search[:url_key]
      advanced = (url_params[:search_field] == url_key)
      range_facets = url_params[:f_inclusive].presence
      return unless advanced || range_facets

      # Translate the 'UVA' pseudo-value for :library_facet for browse-by
      # search in the "Virgo Classic" lens.
      library_facet = range_facets && range_facets[:library_facet]
      if library_facet.present?
        if library_facet[UVA::Helper::Library::ALL_LIBRARIES]
          remove_advanced_facet!(:library_facet, nil, url_params)
        elsif library_facet[UVA::Helper::Library::UVA_LIBRARIES]
          add_advanced_facet!(:library_facet, uva_libraries, url_params)
        end
      end

      # Set this as a controller instance variable, not sure if some
      # views/helpers depend on it. Better to leave it as a local variable
      # if not, more investigation later.
      adv_query = @advanced_query =
        UVA::AdvancedSearch::QueryParser.new(url_params, config)
      BlacklightAdvancedSearch.deep_merge!(solr_params, adv_query.to_solr)
      if adv_query.keyword_queries.present? || adv_query.range_queries.present?
        solr_params[:qt]      = config.advanced_search[:qt]
        solr_params[:defType] = 'lucene'
      end

    end

  end

end
