# lib/uva/scope.rb

require 'uva'

module UVA

  # UVA::Scope
  #
  module Scope

    include UVA
    include UVA::BlacklightOverride
    include UVA::Portal

    # =========================================================================
    # :section:
    # =========================================================================

    public

    # Query parameters which do not have any bearing on whether a URL is
    # related to a search.
    NON_SEARCH_KEYS = %w(
      action
      browse_mode
      catalog_select
      commit
      controller
      counter
      facet.limit
      format
      op
      page
      portal
      search_field
      sort
      sort_key
      special_collections
      total
      utf8
      view
      width
    ).map(&:to_sym).freeze

    # This list comes from the "Search fields" section of CatalogController
    # which initializes the Blacklight configuration.
    #
    # (It would be more appropriate if it was generated dynamically.)
    #
    EXTENDED_SEARCH_FIELDS = [
      :author,
      :title,
      :journal,
      :subject,
      :keyword,
      :call_number,
      :published,
      :publication_date,
      :isbn,
      :issn,
    ].freeze

    # The search term used for a "facet-only" search.  This term works for
    # both EBSCO article search and Solr queries.
    #
    # To "turn off" the ability to do facet-only searches (that is, to require
    # the user to enter a search term in order to get results) then set this
    # value to *nil*.  (This mostly applies to article search - Solr is set up
    # to respond as you might expect to a search with no search terms - so
    # forbidding empty searches as an overall policy would require additional
    # work).
    #
    FACET_ONLY_SEARCH = '*'.freeze

    # URL parameters to ignore when saving to `search_session`.
    #
    # @see self#set_search_session
    #
    SEARCH_SESSION_IGNORED = %w(
      action
      controller
      counter
      facet.limit
      index
      total
    ).map(&:to_sym).freeze

    # =========================================================================
    # :section:
    # =========================================================================

    public

    # Keys for `params` hash that may hold a query.
    #
    # @return [Array<Symbol>]
    #
    def query_param_keys
      [:q, :keyword]
    end

    # Keys for `params` hash that may hold search terms entered through either
    # generic keyword search or through advanced search.
    #
    # @return [Array<Symbol>]
    #
    def extended_query_param_keys
      query_param_keys + EXTENDED_SEARCH_FIELDS
    end

    # =========================================================================
    # :section: Values based on `params`
    # =========================================================================

    public

    # Used to modify the generation of relative paths so that they propagate
    # the popup or aside URL query parameter if necessary.
    #
    # @return [Hash]
    #
    def path_opt
      result = {}
      result[:popup]    = true  if in_popup?
      result[:aside]    = true  if in_aside?
      result[:redirect] = false if no_redirects?
      result
    end

    # Indicate whether the current (search results) page resulted from an
    # advanced search.
    #
    # @param [Hash] url_params        Default: `params`
    #
    def advanced_search_results?(url_params = nil)
      url_params ||= params
      url_params[:search_field].to_s == 'advanced'
    end

    # Indicate whether the current page is not the result of a search.
    #
    # @param [Hash] url_params        Default: `params`
    #
    def searchless?(url_params = nil)
      url_params ||= params
      keys = url_params.keys.map(&:to_sym)
      keys -= NON_SEARCH_KEYS
      keys -= advanced_search_params
      keys.empty?
    end

    # Indicate whether the current search has no facets (or no facets other
    # than :tlevel, which should apply only to article searches).
    #
    # @param [Hash] url_params        Default: `params`
    #
    def facetless?(url_params = nil)
      url_params ||= params
      url_params.blank? || (
        url_params[:f_inclusive].blank? &&
        (url_params[:f].blank? || url_params[:f].except(:tlevel).blank?)
      )
    end

    # Indicate whether the current page is the main page of a "lens" with no
    # active search.
    #
    # @param [Hash] url_params        Default: `params`
    #
    def portal_home_page?(url_params = nil)
      return if advanced_search_results?(url_params)
      searchless?(url_params) && facetless?(url_params)
    end

    # Indicate whether the current page is a print view tab.
    #
    # @param [Hash] url_params        Default: `params`
    #
    def print_view?(url_params = nil)
      url_params ||= params
      url_params[:view].to_s == 'print'
    end

    # Indicate whether the current page is being rendered within the template
    # of another page.
    #
    # @param [Hash] url_params        Default: `params`
    #
    def inset_view?(url_params = nil)
      url_params ||= params
      url_params[:view].to_s == 'inset'
    end

    # Indicate whether the current page is generated for RSS.
    #
    # @param [Hash] url_params        Default: `params`
    #
    def rss_view?(url_params = nil)
      url_params ||= params
      url_params[:format].to_s == 'rss'
    end

    # Indicate whether user-supplied search terms are absent.
    #
    # @param [Hash] url_params        Default: `params`
    #
    def null_search?(url_params = nil)
      url_params ||= params
      null_search_term?(url_params[:q])
    end

    # Indicate whether the search term represents a null search.
    #
    # @param [String] term            Search term.
    #
    def null_search_term?(term)
      term = term.reject(&:blank?).join(SPACE) if term.is_a?(Array)
      term = term.squish if term.is_a?(String)
      term.blank? || (term == FACET_ONLY_SEARCH)
    end

    # The search term(s) in *url_params*.
    #
    # @param [Hash] url_params        By default, `params` is used.
    #
    # @return [String]
    # @return [nil]
    #
    # @see self#extended_query_terms
    #
    def current_query_term(url_params = nil)
      url_params ||= params
      query_param_keys.find do |k|
        v = url_params[k]
        return v unless null_search_term?(v)
      end
    end

    # The search term(s) in *url_params* which may include terms entered via
    # advanced search fields.
    #
    # @param [Hash] url_params        By default, `params` is used.
    #
    # @option url_params [Boolean,String] :quote
    #                                 If *true*, surround terms with double
    #                                   quotes if they contain spaces; if a
    #                                   string, that string is used for quotes
    #                                   instead of double quotes.
    #
    # @return [Array<String>]
    #
    # @see self#current_query_terms
    #
    # === Usage Notes
    # Use this method in situations where the user needs feedback on any of the
    # terms that might have been explicitly entered (either through generic
    # keyword search or via the advanced search form).
    #
    def extended_query_terms(url_params = nil)
      quote = url_params && url_params.delete(:quote).presence
      quote &&= DQUOTE unless quote.is_a?(String)
      url_params = params unless url_params.present?
      extended_query_param_keys.map { |k|
        v = url_params[k]
        next if null_search_term?(v)
        v.include?(' ') ? "#{quote}#{v}#{quote}" : v
      }.compact
    end

    # If the given parameter values have no search query term, update them with
    # a query for self#FACET_ONLY_SEARCH.
    #
    # @param [Hash] url_params        By default, `params` is used.
    #
    # @return [Hash]                  The *url_params*, potentially modified.
    # @return [nil]                   If self#FACET_ONLY_SEARCH is turned off.
    #
    def normalize_search_query(url_params = nil)
      (url_params || params).tap do |result|
        result[:q] = FACET_ONLY_SEARCH if extended_query_terms(result).blank?
      end
    end

    # =========================================================================
    # :section: Values based on `session`
    # =========================================================================

    public

    # Sets session parameters to save the current search.
    #
    # @param [Hash]                       url_params
    # @param [RSolr::Ext::Response::Base] response
    #
    # @return [void]
    #
    def save_current_search(url_params = nil, response = nil)
      url_params ||= params
      set_search_context(url_params)
      set_search_session(url_params)
      search_session(total:    response.total)        if response
      search_session(per_page: url_params[:per_page]) if url_params[:per_page]
    end

    # The portal for the current search.
    #
    # @return [Symbol]                The value of `session[:search_context]`.
    # @return [nil]                   If the value has not been set.
    #
    def search_context
      session[:search_context] if defined?(session)
    end

    # Save the portal of the current search.
    #
    # @param [Hash] url_params        Default: `params`.
    #
    # @return [Symbol]                New value of `session[:search_context]`.
    #
    def set_search_context(url_params = nil)
      session[:search_context] = current_portal_key(url_params)
    end

    # Forget the portal of the current search.
    #
    # @return [Symbol]                Old value of `session[:search_context]`.
    # @return [nil]                   If the value had not been set.
    #
    def clear_search_context
      session.delete(:search_context)
    end

    # Search parameters for each portal.
    #
    # @param [Symbol] portal          One of `UVA::Portal#PORTAL.keys` or nil.
    # @param [Hash]   values          If present, these values are merged into
    #                                   the selected session[:search] entry.
    #
    # @return [Hash]
    #
    # Overrides:
    # @see Blacklight::Catalog#search_session
    #
    def search_session(portal = nil, values = nil)
      return empty_session_hash unless defined?(session)

      if portal.is_a?(Hash)
        values = portal
        portal = current_portal_key
        specified_portal = nil
      else
        specified_portal = portal
        portal = portal_key(portal)
      end
      return empty_session_hash unless portal

      if values.present?
        set_search_session(specified_portal, values.merge(merge: true))
      else
        session[:search]         ||= empty_session_hash
        session[:search][portal] ||= empty_session_hash
      end
    end

    # Remember the current search.
    #
    # @param [Symbol] portal          One of `UVA::Portal#PORTAL.keys` or nil.
    # @param [Hash]   url_params      Default: `params`.
    #
    # @option url_params [Boolean] :merge   If *true*, *url_params* values will
    #                                         be merged into the current entry
    #                                         rather than replacing it.
    #
    # @return [Hash]                  Value of the selected `session[:search]`
    #                                   entry.
    # @return [nil]                   If *url_params* did not indicate a portal
    #                                   or if the new search is the same as the
    #                                   old search.
    #
    def set_search_session(portal = nil, url_params = nil)
      if portal.is_a?(Hash)
        url_params = portal
        portal     = nil
      end
      merge =
        if url_params.present? && url_params.key?(:merge)
          url_params = url_params.dup
          url_params.delete(:merge) && url_params.present?
        end
      url_params = params if url_params.blank?

      all = PORTAL[:all][:catalog_select]
      all_specified = (portal.to_s == all)
      portal =
        if portal || merge
          portal_key(portal)
        else
          current_portal_key(url_params)
        end
      return unless portal

      session[:search] ||= empty_session_hash
      url_params = url_params.except(*SEARCH_SESSION_IGNORED) unless merge

      true_portal = ((portal == :all) unless all_specified)
      true_portal &&= articles_lens? ? :articles : :catalog
      if (portal == :all) && (true_portal == :catalog)
        # Fill session[:search][:all]
        values = url_params.rdup.merge(catalog_select: all)
        if merge && session[:search][portal].present?
          session[:search][portal].merge!(values)
        else
          session[:search][portal] = values
        end
        # Fill session[:search][:articles]
        values = make_search_params(:articles, url_params)
        values.except!(*SEARCH_SESSION_IGNORED)
        if merge && session[:search][:articles].present?
          session[:search][:articles].merge!(values)
        else
          session[:search][:articles] = values
        end
        # The entry for session[:search][:catalog] is handled below.
      end

      portal = true_portal if true_portal
      values = url_params.rdup
      values = values.merge(catalog_select: all) if portal == :all
      if merge && session[:search][portal].present?
        session[:search][portal].merge!(values)
      else
        session[:search][portal] = values
      end
    end

    # Forget all saved searches.
    #
    # @param [Symbol] portal          One of `UVA::Portal#PORTAL.keys` or nil.
    #
    # @return [Hash]
    # @return [nil]
    #
    def clear_search_session(portal = nil)
      return unless session[:search]
      if portal
        portal = portal_key(portal)
        session[:search].delete(portal) if portal
      else
        session.delete(:search)
      end
    end

    # set_search_counter
    #
    # @param [Hash] url_params
    #
    # @return [Fixnum]
    #
    def set_search_counter(url_params = nil)
      url_params ||= params
      counter = (url_params[:index] || url_params[:counter]).to_i
      search_session(counter: counter) unless counter.zero?
      counter
    end

    # get_search_counter
    #
    # @param [Hash] url_params
    #
    # @return [Fixnum]
    #
    def get_search_counter(url_params = nil)
      url_params ||= params
      (url_params[:counter] || search_session[:counter]).to_i
    end

    # The current search results page size.
    #
    # @param [Hash] url_params
    #
    # @return [Fixnum]
    #
    def get_current_per_page(url_params = nil)
      url_params ||= params
      url_params[:per_page] ||
        search_session[:per_page] ||
        session[:per_page] ||
        current_blacklight_config.default_solr_params[:rows]
    end

    # The current search results sorting order.
    #
    # @param [Hash] url_params
    #
    # @return [String]
    #
    def get_current_sort_key(url_params = nil)
      url_params ||= params
      url_params[:sort_key] ||
        search_session[:sort_key] ||
        session[:sort_key] ||
        current_blacklight_config.default_sort_field
    end

    # Return the most appropriate portal key based on heuristics.
    #
    # - :all if `search_context` is :all.
    # - The current portal key if `session[:search][curr]` is non-blank.
    # - The key for the only non-blank `session[:search]` entry.
    # - If there are multiple non-blank entries and :catalog is one of them
    #     then :catalog will be returned.
    # - Otherwise the key for the first non-blank entry will be returned.
    # - If there are no valid `session[:search]` entries, :catalog will be
    #     returned.
    #
    # @param [Array<String,Symbol>] args    Zero or more portal keys to check.
    #
    # @return [Symbol]
    #
    def active_search_portal(*args)
      ss = args.last.is_a?(Hash) ? args.pop : (session[:search] || {})
      args.map!(&:to_sym)
      current = portal_controller.to_s.to_sym
      args.unshift(current) if current.present? && !args.include?(current)
      args.unshift(:all)    if (search_context == :all) && !args.include?(:all)
      portal = args.find { |arg| ss[arg].present? }
      unless portal
        catalog = nil
        portals = portal_controllers.map(&:to_sym)
        found =
          ss.count do |key, entry|
            key = key.to_sym
            next unless entry.present? && portals.include?(key)
            catalog = key if key == :catalog
            portal ||= key
          end
        portal ||= catalog if (found > 1)
        portal ||= :catalog
      end
      portal
    end

    # =========================================================================
    # :section:
    # =========================================================================

    protected

    # empty_session_hash
    #
    # @return [ActiveSupport::HashWithIndifferentAccess]
    #
    def empty_session_hash
      ActiveSupport::HashWithIndifferentAccess.new
    end

  end

end
