# lib/uva/advanced_search.rb

require 'uva'

module UVA

  # Namespace for Blacklight Advanced Search overrides.
  #
  # === Usage
  # Any class or module that depends upon UVA::AdvancedSearch definitions must
  # have
  #
  #   <code>include UVA</code>
  #   <i>Other UVA includes...</i>
  #   <code><b>include UVA::AdvancedSearch</b></code>
  #
  # near the top of its definition.  This ensures that all UVA::AdvancedSearch
  # modules will be autoloaded as needed.
  #
  module AdvancedSearch

    include UVA
    include UVA::Util

    # One time only: autoload all modules from "lib/uva/advanced_search".
    LIB_UVA_ADVANCED_SEARCH_AUTOLOADS ||= {
      AdvancedHelperOverride:   'uva/advanced_search/advanced_helper_override',
      QueryParser:              'uva/advanced_search/advanced_query_parser',
      AdvancedSearchFields:     'uva/advanced_search/advanced_search_fields',
      CatalogHelperOverride:    'uva/advanced_search/catalog_helper_override',
      Controller:               'uva/advanced_search/controller',
      ExpressionParserOverride: 'uva/advanced_search/expression_parser_override',
      RangeQueryParser:         'uva/advanced_search/range_query_parser',
    }.each_pair { |name, path| autoload(name, path) }

    # =========================================================================
    # :section: Module methods
    # =========================================================================

    public

    # Actions taken when this module is included.
    #
    # @param [Module] base            The including module or class.
    #
    # @return [void]
    #
    def self.included(base) # :nodoc:
      if base.respond_to?(:controller_name)
        [BlacklightAdvancedSearch::ParseBasicQ].each do |mod|
          next if base.include?(mod)
          console_output(
            "#{name} causing #{base} to include #{mod}"
          ) if DEBUG_INCLUDE
          base.send(:include, mod)
        end
      end
    end

    # =========================================================================
    # :section:
    # =========================================================================

    public

    # Gets the advanced search param list.
    #
    # @return [Array<Symbol>]
    #
    def advanced_search_params
      advanced_search_fields.flat_map { |key, field_def|
        if true_value?(field_def.range)
          %W(#{key}_start #{key}_end)
        else
          [key, nostem_field(key), fulltext_field(key)]
        end
      }.reject(&:blank?).map(&:to_sym)
    end

    # Remove a populated advanced search field.
    #
    # @param [Object] key
    # @param [Hash]   url_params
    #
    # @return [Hash]
    #
    def remove_advanced_search_field(key, url_params = nil)
      ignored_fields  = [:id, :page, :counter, :commit]
      ignored_fields += %W(#{key} #{key}_start #{key}_end).map(&:to_sym)
      (url_params || params).except(*ignored_fields)
    end

    # =========================================================================
    # :section:
    # =========================================================================

    public

    # Indicate whether we're currently in advanced search.
    #
    # @see CatalogController#adjust_for_spec_coll
    # @see CatalogController#extra_solr_params
    #
    def advanced_search?
      params[:f_inclusive].present? || advanced_search_values.present?
    end

    # Returns true if the parameter indicate that the current search is a
    # collection search (limited by the digital_collection_facet).
    #
    # @see CatalogController#extra_solr_params
    #
    def collection_search?
      params[:f].present? && params[:f][:digital_collection_facet].present?
    end

    # Indicate whether the current search is meant to include
    # collection members that are typically undiscoverable.
    #
    # @see CatalogController#extra_solr_params
    #
    def search_within_collections?
      params[:undiscoverable].present?
    end

  end

end
