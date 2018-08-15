# lib/uva/helper/facets.rb

require 'uva'

module UVA::Helper

  # UVA::Helper::Facets
  #
  module Facets

    include Blacklight::FacetsHelperBehavior

    include UVA
    include UVA::BlacklightOverride
    include UVA::Scope
    include UVA::Helper::AdvancedSearch

    # =========================================================================
    # :section:
    # =========================================================================

    public

    FACET_SORT_SCHEME = {
      alpha: 'A-Z',
      hits:  'Number of Results',
    }.deep_freeze

    DEFAULT_FACET_SORT_SCHEME = :hits

    DEFAULT_FACET_LIMIT = 500

    NO_FACET_LIMIT = -1

    # Values for these (Solr) facets are displayed as they are received; values
    # for all other facets are displayed with titleization.
    NO_TITLEIZE_FACETS = [
      :call_number_facet,
      :digital_collection_facet,
      :format_facet,
      :language_facet,
      :library_facet,
      :published_date_facet,
      :recording_format_facet,
      :recordings_and_scores_facet,
      :region_facet,
      :source_facet,
      :video_genre_facet,
    ].freeze

    # Fields of `params` which hold facet values.
    FACET_PARAMS = [:f, :f_inclusive].freeze

    # Fields of `params` which are not included when creating parameters for a
    # facet link.
    FACET_IGNORED_KEYS = [
      :commit,
      :counter,
      :facet_sort,
      :id,
      :page,
      :sort,
      :total,
      :utf8
    ].freeze

    FACET_LINK_TIP     = %q(Limit results to items with %s "%s".).freeze
    FACET_SELECTED_TIP = 'Already selected for the current search.'.freeze

    # =========================================================================
    # :section:
    # =========================================================================

    public

    # Returns the selected sort scheme for the facet values.
    #
    # If we are generating this link prior to actually visiting the facet list
    # (i.e. - the "more>>" link), then we want a different sort option to
    # appear than if we are already viewing the facet values at the page
    # /catalog/facet/facet_name.
    #
    # @param [String] facet_name      Default: `params[:facet_sort]`.
    #
    # @return [Symbol]                One of `FACET_SORT_SCHEME.keys`.
    #
    # NOTE: Currently the default sort is 'hits' for all facets.
    # Originally there were two cases where 'alpha' was the default sort:
    # - if facet_name == 'call_number_facet'
    # - if facet_name == 'subject_facet' && params[:controller] == 'video'
    #
    def facet_sort_scheme(facet_name = nil)
      (facet_name || params[:facet_sort] || DEFAULT_FACET_SORT_SCHEME).to_sym
    end

    # The current facet sort scheme and its label.
    #
    # @param [String] facet_name         Currently unused.
    #
    # @return [Array<(Symbol, String)>]  Sort scheme and label.
    #
    def current_facet_sort(facet_name = nil)
      sort_scheme = facet_sort_scheme(facet_name)
      return sort_scheme, FACET_SORT_SCHEME[sort_scheme]
    end

    # Gives the value and label of the inverse of the current facet sort
    # scheme.
    #
    # @param [String] facet_name         Currently unused.
    #
    # @return [Array<(Symbol, String)>]  Sort scheme and label.
    #
    def inverse_facet_sort(facet_name = nil)
      sort_scheme =
        case facet_sort_scheme(facet_name)
          when :alpha then :hits
          when :hits  then :alpha
        end
      return sort_scheme, FACET_SORT_SCHEME[sort_scheme]
    end

    # Sorts facet values in memory, after lower-casing them.
    #
    # We are doing this because Solr sorting doesn't lowercase, so things like
    # "eBooks" don't sort the way we'd want them to.
    #
    # @param [Array<FacetItem>] items
    # @param [String]           facet_name
    #
    # @return [Array<FacetItem>]
    #
    # @see RSolr::Ext::Response::Facets::FacetItem
    # @see UVA::Article::FacetItem
    #
    def facet_sort(items, facet_name = nil)
      items ||= []
      case facet_sort_scheme(facet_name)
        when :alpha
          items.sort { |a, b| a.value.downcase <=> b.value.downcase }
        when :hits
          items.sort { |a, b| -a.hits.to_i <=> -b.hits.to_i }
      end
    end

    # default_facet_limit
    #
    # @return [Fixnum]
    #
    def default_facet_limit
      DEFAULT_FACET_LIMIT
    end

    # current_facet_limit
    #
    # @return [Fixnum]
    #
    def current_facet_limit
      (params[:'facet.limit'] || DEFAULT_FACET_LIMIT).to_i
    end

    # Sifts through `params` to see what we should keep for facet values.
    # Of the acceptable keys, only ones with a non-blank value are retained.
    #
    # @return [ActiveSupport::HashWithIndifferentAccess]
    #
    def params_for_facet_values
      keepers = advanced_search_params
      keepers += [
        :controller,
        :special_collections,
        :f,
        :f_inclusive,
        :qt,
        :sort_key,
        :search_field,
        :op,
        :title_nostem,
        :journal_nostem,
        :author_nostem,
        :subject_nostem,
        :keyword_nostem,
        :keyword_full,
      ]
      keepers << :q unless null_search?
      params.select { |field, value|
        keepers.include?(field.to_sym) && value.present?
      }.with_indifferent_access
    end

    # The string representation of the value of the given facet item.
    #
    # @param [Symbol, String]    facet_name
    # @param [FacetItem, String] item
    #
    # @return [ActiveSupport::SafeBuffer]
    #
    # @see RSolr::Ext::Response::Facets::FacetItem
    # @see UVA::Article::FacetItem
    #
    def facet_display_value(facet_name, item)
      if item.is_a?(UVA::Article::FacetItem)
        item.display_value(facet_name)
      else
        facet_name &&= facet_name.to_sym
        item =
          case item
            when RSolr::Ext::Response::Facets::FacetItem then item.value
            when Array then item.last # for facet == :tlevel
            else item.to_s
          end
        result =
          if facet_name == :tlevel
            item.titlecase
          elsif NO_TITLEIZE_FACETS.include?(facet_name)
            item
          else
            titleize(item)
          end
        ERB::Util.h(result).gsub(/\s*--\s*/, EM_DASH).html_safe
      end
    end

    # facet_link_params
    #
    # @param [Symbol] action          Default: *nil*.
    #
    # @return [Hash]
    #
    def facet_link_params(action = nil)
      params_for_facet_values.tap do |result|
        result[:'facet.limit'] = current_facet_limit
      end
    end

    # =========================================================================
    # :section: Blacklight::FacetsHelperBehavior overrides
    # =========================================================================

    public

    # facet_configuration_for_field
    #
    # @param [Symbol] field
    #
    # @return [Blacklight::Configuration::FacetField]
    #
    # @see Blacklight::FacetsHelperBehavior#facet_configuration_for_field
    #
    def facet_configuration_for_field(field)
      facet_fields_config[field] ||
        Blacklight::Configuration::FacetField.new(field: field)
    end

    # facet_field_labels
    #
    # @return [Hash{String=>String}]
    #
    # @see Blacklight::FacetsHelperBehavior#facet_field_labels
    #
    def facet_field_labels
      facet_fields_config.map { |key, field_def| [key, field_def.label] }.to_h
    end

    # facet_field_names
    #
    # @return [Array<String>]
    #
    # @see Blacklight::FacetsHelperBehavior#facet_field_names
    #
    def facet_field_names
      facet_fields_config.keys.map(&:to_s)
    end

    # Overriding so as to take into account facets from advanced search.
    #
    # @param [Symbol] field
    # @param [String] value
    #
    # @see Blacklight::FacetsHelperBehavior#facet_in_params?
    #
    def facet_in_params?(field, value)
      val = non_blank_chars(value)
      [:f, :f_inclusive].find do |key|
        case (f_val = params && params[key] && params[key][field])
          when Hash   then f_val.keys.any? { |k| non_blank_chars(k) == val }
          when Array  then f_val.any? { |v| non_blank_chars(v) == val }
          when String then non_blank_chars(f_val) == val
        end
      end
    end

    # Overriding from Blacklight plugin to add logic for cleaning up the page
    # references.
    #
    # @param [Symbol] field
    # @param [String] value
    #
    # @return [Hash]                  A modified copy of `params`.
    #
    # @see Blacklight::FacetsHelperBehavior#add_facet
    #
    def add_facet_params(field, value)
      add_facet(field, value)
    end

    # Overriding from the Blacklight plugin to remove :f param if it is empty.
    #
    # @param [Symbol] field
    # @param [String] value
    # @param [Hash]   url_params      Default: `params`
    #
    # @return [Hash]                  A modified copy of *url_params*.
    #
    def remove_facet_params(field, value, url_params = nil)
      remove_facet(field, value, url_params)
    end

    # =========================================================================
    # :section:
    # =========================================================================

    public

    # Logic for the #add_facet_params override was moved to this method to work
    # around the fact the RubyMine marked use of the third parameter as an
    # error even though the method executed fine.
    #
    # @param [Symbol] field
    # @param [String] value
    # @param [Hash]   url_params      Default: `params`
    #
    # @return [Hash]                  A modified copy of *url_params*.
    #
    # @see Blacklight::FacetsHelperBehavior#add_facet
    #
    def add_facet(field, value, url_params = nil)
      add_facet!(field, value, make_facet_params(url_params))
    end

    # Create a copy of *url_params* with a facet value removed.
    #
    # @param [String, Symbol] field       The facet field to change.
    # @param [String]         value       The facet value to remove; if *nil*
    #                                       then all facet values are removed.
    # @param [Hash]           url_params  Default: `params`
    #
    # @return [Hash]                  A modified copy of *url_params*.
    #
    def remove_facet(field, value, url_params = nil)
      remove_facet!(field, value, make_facet_params(url_params))
    end

    # Add a facet value to a params hash, creating the :f param if necessary.
    #
    # @param [String, Symbol] field       The facet field to change.
    # @param [String]         value       The facet value to add.
    # @param [Hash]           url_params  Default: `params`
    #
    # @return [Hash]                  The modified *url_params* or `params`.
    #
    def add_facet!(field, value, url_params = nil)
      (url_params || params).tap do |result|
        values = Array(value).reject(&:blank?)
        if values.present?
          result[:f] ||= {}
          result[:f][field] ||= []
          result[:f][field] += values
          result[:f][field].uniq!
        end
      end
    end

    # Remove a facet value from a params hash, deleting the facet if it
    # contained no other values and deleting the :f param if it contained no
    # other facets.
    #
    # @param [String, Symbol]        field    The facet field to change.
    # @param [String, Array<String>] value    The facet value(s) to remove;
    #                                           if *nil* then all facet values
    #                                           will be removed.
    # @param [Hash] url_params                Default: `params`
    #
    # @return [Hash]                  The modified *url_params* or `params`.
    #
    def remove_facet!(field, value, url_params = nil)
      remove_facet_values(:f, field, value, url_params)
    end

    # =========================================================================
    # :section:
    # =========================================================================

    public

    # Add a facet value to a params hash, creating the :f_inclusive param if
    # necessary.
    #
    # @param [String, Symbol]        field    The facet field to change.
    # @param [String, Array<String>] value    The facet value(s) to add.
    # @param [Hash] url_params                Default: `params`
    #
    # @return [Hash]                  A modified copy of *url_params*.
    #
    def add_advanced_facet(field, value, url_params = nil)
      add_advanced_facet!(field, value, make_facet_params(url_params))
    end

    # Create a copy of *url_params* with a facet value removed.
    #
    # @param [String, Symbol] field       The facet field to change.
    # @param [String]         value       The facet value to remove.
    # @param [Hash]           url_params  Default: `params`
    #
    # @return [Hash]                  A modified copy of *url_params*.
    #
    def remove_advanced_facet(field, value, url_params = nil)
      remove_advanced_facet!(field, value, make_facet_params(url_params))
    end

    # Add a facet value to a params hash, creating the :f_inclusive param if
    # necessary.
    #
    # @param [String, Symbol]        field    The facet field to change.
    # @param [String, Array<String>] value    The facet value(s) to add.
    # @param [Hash] url_params                Default: `params`
    #
    # @return [Hash]                  A modified copy of *url_params*.
    #
    def add_advanced_facet!(field, value, url_params = nil)
      (url_params || params).tap do |result|
        values = Array(value).reject(&:blank?)
        if values.present?
          result[:f_inclusive] ||= {}
          result[:f_inclusive][field] ||= {}
          values.each { |v| result[:f_inclusive][field][v] ||= '1' }
        end
      end
    end

    # Remove a facet value from a params hash, deleting the facet if it
    # contained no other values and deleting the :f_inclusive param if it
    # contained no other facet values.
    #
    # @param [String, Symbol]        field    The facet field to change.
    # @param [String, Array<String>] value    The facet value(s) to remove;
    #                                           if *nil* then all facet values
    #                                           will be removed.
    # @param [Hash] url_params                Default: `params`
    #
    # @return [Hash]                  The modified *url_params* or `params`.
    #
    def remove_advanced_facet!(field, value, url_params = nil)
      remove_facet_values(:f_inclusive, field, value, url_params)
    end

    # =========================================================================
    # :section:
    # =========================================================================

    public

    # The current value of `url_params[:f][:tlevel]`
    #
    # @param [Hash] url_params        Default: `params`.
    #
    # @return [String]
    # @return [nil]
    #
    def get_tlevel(url_params = nil)
      (url_params ||= params) && url_params[:f] && url_params[:f][:tlevel]
    end

    # Set or unset `url_params[:f][:tlevel]` according to the current value of
    # `session[:peer_reviewed]`.
    #
    # @param [Hash] url_params        Default: `params`.
    #
    # @return [true]                  Contents of *url_params* was changed.
    # @return [false]                 Contents of *url_params* already match
    # @return [nil]
    #
    def adjust_tlevel!(url_params = nil)
      return unless session.key?(:peer_reviewed)
      url_params ||= params
      set_peer_reviewed = session[:peer_reviewed]
      now_peer_reviewed = get_tlevel(url_params).present?
      change_required   = (set_peer_reviewed != now_peer_reviewed)
      if change_required
        if set_peer_reviewed
          add_tlevel!(url_params)
        else
          remove_tlevel!(url_params)
        end
      end
      change_required
    end

    # add_tlevel!
    #
    # @param [Hash] url_params        Default: `params`.
    #
    # @return [Hash]                  The modified *url_params* or `params`.
    # @return [nil]                   If `url_params[:peer_reviewed]` is false.
    #
    def add_tlevel!(url_params = nil)
      add_facet!(:tlevel, 'peer_reviewed', (url_params || params))
    end

    # remove_tlevel!
    #
    # @param [Hash] url_params        Default: `params`.
    #
    # @return [Hash]                  The modified *url_params* or `params`.
    # @return [nil]                   If `url_params[:peer_reviewed]` is false.
    #
    def remove_tlevel!(url_params = nil)
      remove_facet!(:tlevel, 'peer_reviewed', (url_params || params))
    end

    # =========================================================================
    # :section:
    # =========================================================================

    protected

    # Create a copy of parameters from which a facet search can be generated.
    #
    # @param [Hash] url_params        Default: `params`
    #
    # @return [Hash]                  A modified copy of *url_params*.
    #
    def make_facet_params(url_params = nil)
      url_params ||= params
      ignored_keys = FACET_IGNORED_KEYS
      ignored_keys += [:q] if null_search_term?(url_params[:q])
      url_params.except(*ignored_keys).rdup
    end

    # Remove a facet value from a params hash, deleting the facet if it
    # contained no other values and deleting the *top_level* param if it
    # contained no other facet values.
    #
    # @param [String, Symbol]        top_level  Container for facet field.
    # @param [String, Symbol]        field      The facet field to change.
    # @param [String, Array<String>] value      The facet value(s) to remove;
    #                                             if '*' or *nil* then the
    #                                             entire facet will be removed
    #                                             along with all of its values.
    # @param [Hash] url_params                  Default: `params`
    #
    # @return [Hash]                  The modified *url_params*.
    #
    def remove_facet_values(top_level, field, value, url_params = nil)
      url_params ||= params
      url_params.tap do |result|
        if result[top_level].present?
          delete = true
          field  = field.to_s
          value  = nil if value == '*'
          facet  = value && result[top_level][field].presence
          if facet.is_a?(Array) || facet.is_a?(Hash)
            Array(value).each { |v| facet.delete(v) if v.present? }
            delete = facet.blank?
          end
          result[top_level].delete(field) if delete
        end
        result.delete(top_level) if result[top_level].blank?
      end
    end

    # =========================================================================
    # :section:
    # =========================================================================

    public

    # Search link which adds the given facet value to the search.
    #
    # @param [String]            facet_name
    # @param [FacetItem, String] item
    # @param [Hash]              opt
    #
    # @option opt [Hash]    :params
    # @option opt [Boolean] :no_hits
    #
    # @return [ActiveSupport::SafeBuffer]
    #
    def add_facet_link(facet_name, item, opt = nil)

      html_opt   = opt ? opt.dup : {}
      url_params = html_opt.delete(:params)
      no_hits    = html_opt.delete(:no_hits)
      no_tooltip = html_opt.key?(:title) && html_opt[:title].nil?
      html_opt.delete(:title) if no_tooltip

      value         = item.is_a?(String) ? item : item.value
      value_label   = facet_display_value(facet_name, item)
      peer_reviewed = (facet_name.to_s == 'tlevel')

      facet_applied =
        (peer_reviewed && session[:peer_reviewed]) ||
        facet_in_params?(facet_name, value)

      result =
        if facet_applied
          # Show already-applied facet as text only.
          html_opt[:title] = FACET_SELECTED_TIP unless no_tooltip
          content_tag(:span, value_label, html_opt)
        else
          # Create a link which applies the facet limit to the current search.
          url_params = url_params ? url_params.dup : params_for_facet_values
          if peer_reviewed
            url_params[:peer_reviewed] = 'true'
          else
            url_params = add_facet(facet_name, value, url_params)
          end
          link_path = portal_index_path(url_params)
          unless no_tooltip
            facet_label = facet_field_labels[facet_name]
            value_text  = html_decode(value_label)
            html_opt[:title] = FACET_LINK_TIP % [facet_label, value_text]
          end
          link_to(value_label, link_path, html_opt)
        end

      unless no_hits || peer_reviewed || item.is_a?(String)
        result << ' (' << format_num(item.hits) << ')'
      end

      result.html_safe

    end

    # =========================================================================
    # :section:
    # =========================================================================

    protected

    # extract_advanced_search
    #
    # @param [Hash] url_params
    #
    # @return [ActiveSupport::HashWithIndifferentAccess]
    #
    # @note Not currently used
    #
    def extract_advanced_search(url_params)
      fields = [:q, :search_field, :f, :f_inclusive]
      fields += advanced_search_fields.keys
      fields += extended_search_fields.keys
      fields.map!(&:to_sym)
      url_params.slice(*fields).with_indifferent_access
    end

  end

end
