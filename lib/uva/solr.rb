# lib/uva/solr.rb

require 'uva'

module UVA

  # Overrides to Blacklight::SolrHelper.
  #
  module Solr

    # Hints for RubyMine (skipped during execution).
    include Blacklight::SolrHelper unless ONLY_FOR_DOCUMENTATION

    include UVA
    include UVA::Cache
    include UVA::Classic
    include UVA::Exceptions
    include UVA::Scope
    include UVA::Util::StringMethods
    include UVA::AdvancedSearch::AdvancedSearchFields

    # =========================================================================
    # :section:
    # =========================================================================

    public

    INTERNAL_OPTIONS = [:override, :raise, :skip].freeze

    # =========================================================================
    # :section: Module methods
    # =========================================================================

    public

    # Actions taken when this module is included.
    #
    # Set up search_params_logic, which will get sent with every search.
    #
    # @param [Module] base            The including module or class.
    #
    # @return [void]
    #
    def self.included(base) # :nodoc:

      if base.respond_to?(:controller_name)
        [Blacklight::SolrHelper].each do |mod|
          next if base.include?(mod)
          console_output(
            "#{name} causing #{base} to include #{mod}"
          ) if DEBUG_INCLUDE
          base.send(:include, mod)
        end
      end

      if base.respond_to?(:solr_search_params_logic)
        base.solr_search_params_logic << :show_only_public_records
        base.solr_search_params_logic << :add_special_collections_lens
        base.solr_search_params_logic << :add_max_per_page
        base.solr_search_params_logic << :add_facet_limit
        base.solr_search_params_logic << :add_video_filter
        base.solr_search_params_logic << :modify_for_advanced_search
      end

      [UVA::Exceptions].each do |mod|
        next if base.include?(mod)
        console_output(
          "#{name} causing #{base} to include #{mod}"
        ) if DEBUG_INCLUDE
        base.send(:include, mod)
      end
    end

    # =========================================================================
    # :section: Filters for solr_search_params_logic
    # =========================================================================

    public

    # modify_for_advanced_search
    #
    # May modify solr_params[:op] and/or solr_params[:q].
    #
    # @param [Hash] solr_params       To be sent to Solr (via RSolr)
    # @param [Hash] url_params        User-supplied values (often `params`)
    #
    # @return [String]
    # @return [nil]
    #
    def modify_for_advanced_search(solr_params, url_params)
      return unless solr_params
      return unless url_params && advanced_search_results?(url_params)
      solr_params[:op] = url_params[:op] || 'AND'
      # Order matters here - fulltext MUST occur BEFORE unstemmed.
      add_fulltext_overrides(solr_params, url_params)
      add_unstemmed_overrides(solr_params, url_params)
    end

    # add_unstemmed_overrides
    #
    # May modify solr_params[:q].
    #
    # @param [Hash] solr_params       To be sent to Solr (via RSolr)
    # @param [Hash] url_params        User-supplied values (often `params`)
    #
    # @return [String]
    # @return [nil]
    #
    def add_unstemmed_overrides(solr_params, url_params)
      solr_query = solr_params && solr_params[:q]
      return if solr_query.blank? || url_params.blank?
      terms_to_edit =
        NOSTEM_FIELDS.keys.map { |nostem_param|
          nostem_param = nostem_param.to_s
          next unless url_params[nostem_param].present?
          solr_term = nostem_param.sub(/_nostem$/, '')
          solr_term = 'journal_title' if solr_term == 'journal'
          # First check for the presence of /[qp]f_TERM_full/ (which will
          # currently only match for f_keyword_full) then check for the
          # presence of /[qp]f_TERM/.
          %W(f_#{solr_term}_full f_#{solr_term}).find do |field_pattern|
            solr_query.include?(field_pattern)
          end
        }.reject(&:blank?)
      return if terms_to_edit.blank?
      terms_to_edit = terms_to_edit.join('|')
      solr_params[:q].gsub!(/(#{terms_to_edit})/, '\&_unstemmed')
    end

    # add_fulltext_overrides
    #
    # May modify solr_params[:q].  Currently only applies to "keyword".
    #
    # @param [Hash] solr_params       To be sent to Solr (via RSolr)
    # @param [Hash] url_params        User-supplied values (often `params`)
    #
    # @return [String]
    # @return [nil]
    #
    def add_fulltext_overrides(solr_params, url_params)
      solr_query = solr_params && solr_params[:q]
      return if solr_query.blank? || url_params.blank?
      terms_to_edit =
        FULLTEXT_FIELDS.keys.map { |fulltext_param|
          fulltext_param = fulltext_param.to_s
          next unless url_params[fulltext_param].present?
          solr_term = fulltext_param.sub(/_full$/, '')
          field_pattern = "f_#{solr_term}"
          field_pattern if solr_query.include?(field_pattern)
        }.reject(&:blank?)
      return if terms_to_edit.blank?
      terms_to_edit = terms_to_edit.join('|')
      solr_params[:q].gsub!(/(#{terms_to_edit})/, '\&_full')
    end

    # show_only_public_records
    #
    # May modify solr_params[:fq].
    #
    # @param [Hash] solr_params       To be sent to Solr (via RSolr)
    # @param [Hash] url_params        Ignored
    #
    # @return [Array<String>]
    # @return [nil]
    #
    def show_only_public_records(solr_params, url_params)
      return unless solr_params
      unused(url_params)
      solr_params[:fq] ||= []
      solr_params[:fq] << '-shadowed_location_facet:HIDDEN'
    end

    # Add library facet of Special Collections if it's the Special Collections
    # lens.
    #
    # May modify solr_params[:fq].
    #
    # @param [Hash] solr_params       To be sent to Solr (via RSolr)
    # @param [Hash] url_params        User-supplied values (often `params`)
    #
    # @return [Array<String>]
    # @return [nil]
    #
    def add_special_collections_lens(solr_params, url_params)
      return unless solr_params
      return unless special_collections_lens? ||
        (url_params && true_value?(url_params[:special_collections]))
      solr_params[:fq] ||= []
      solr_params[:fq] << 'library_facet:"Special Collections"'
    end

    # Show as many search results as allowed if requested.
    #
    # May modify solr_params[:rows].
    #
    # @param [Hash] solr_params       To be sent to Solr (via RSolr)
    # @param [Hash] url_params        User-supplied values (often `params`)
    #
    # @return [Fixnum]
    # @return [nil]
    #
    def add_max_per_page(solr_params, url_params)
      return unless solr_params && url_params
      solr_params[:rows] = 100 if url_params[:show_max_per_page]
    end

    # Set a facet limit based on user input.
    #
    # May modify solr_params[:'facet.limit'].
    #
    # @param [Hash] solr_params       To be sent to Solr (via RSolr)
    # @param [Hash] url_params        User-supplied values (often `params`)
    #
    # @return [String]
    # @return [nil]
    #
    def add_facet_limit(solr_params, url_params)
      return unless solr_params && url_params
      key = :'facet.limit'
      facet_limit = url_params[key]
      solr_params[key] = facet_limit if facet_limit
    end

    # add_video_filter
    #
    # May modify solr_params[:fq].
    #
    # @param [Hash] solr_params       To be sent to Solr (via RSolr)
    # @param [Hash] url_params        User-supplied values (often `params`)
    #
    # @return [Array<String>]
    # @return [nil]
    #
    def add_video_filter(solr_params, url_params)
      return unless solr_params
      return unless video_lens? || video_lens?(url_params)
      solr_params[:fq] ||= []
      solr_params[:fq] << 'format_facet:Video'
    end

    # =========================================================================
    # :section: Filters for solr_search_params_logic
    # =========================================================================

    protected

    # Swap request handler based on old qt to new search_field.
    #
    # @param [Hash]   url_params
    # @param [String] original_qt
    # @param [String] search_field
    #
    # @return [void]
    #
    def swap_handler(url_params, original_qt, search_field)
      return unless url_params && (url_params[:qt] == original_qt)
      url_params.delete(:qt)
      url_params[:search_field] = search_field
    end

    # =========================================================================
    # :section: Blacklight::SolrHelper overrides
    # =========================================================================

    public

    # Overriding to use current_blacklight_config.
    #
    # @param [Hash] solr_params
    # @param [Hash] url_params        Unused.
    #
    # @see Blacklight::SolrHelper#default_solr_parameters
    #
    def default_solr_parameters(solr_params, url_params)
      unused(url_params)
      current_blacklight_config.default_solr_params.each do |key, value|
        solr_params[key] = value.rdup
      end
    end

    # Overriding to account for the fact that :sort is no longer carried as a
    # URL parameter, so the Solr sorting terms must be looked-up using the
    # :sort_key.
    #
    # @param [Hash] solr_params
    # @param [Hash] url_params
    #
    # @return [void]
    #
    # === Implementation Notes
    # In case it turns out that there's a good reason for providing the Solr
    # sort directly, :sort will be honored if present.
    #
    def add_sorting_to_solr(solr_params, url_params)
      return unless solr_params && url_params
      sort = solr_params[:sort] || url_params[:sort]
      sort_key = solr_params.delete(:sort_key) || url_params[:sort_key]
      unless sort.present?
        sort_key ||= get_current_sort_key(url_params)
        sort = solr_sort_value(sort_key)
      end
      solr_params[:sort] = sort if sort.present?
    end

    # Take the user-entered query, and put it in the solr params, including
    # config's "search field" params for current search field. also include
    # setting spellcheck.q.
    #
    # @param [Hash] solr_params
    # @param [Hash] url_params
    #
    # @return [void]
    #
    # @see Blacklight::SolrHelper#add_query_to_solr
    #
    def add_query_to_solr(solr_params, url_params)

      # added from plugin -- swapping qts
      swap_handler(url_params, 'subject_search',       'subject')
      swap_handler(url_params, 'title_search',         'title')
      swap_handler(url_params, 'journal_title_search', 'journal')
      swap_handler(url_params, 'call_number_search',   'call_number')

      # Merge in search field configured values, if present, over-writing
      # general defaults.

      # Legacy behavior of user param :qt is passed through, but over-ridden by
      # actual search field config if present.  We might want to remove this
      # legacy behavior at some point. It does not seem to be currently rspec'd
      (qt = url_params[:qt]) && (solr_params[:qt] = qt)

      # Overriding from plugin, where this is hard-coded as
      # Blacklight.search_field_def_for_key
      field_def = search_field_def_for_key(url_params[:search_field])
      if field_def
        (qt = field_def[:qt])              && (solr_params[:qt] = qt)
        (sp = field_def[:solr_parameters]) && solr_params.merge!(sp)
      end

      # Create Solr 'q' including the user-entered q, prefixed by any Solr
      # LocalParams in config, using solr LocalParams syntax.
      # @see https://wiki.apache.org/solr/LocalParams
      q = url_params[:q]
      if field_def && (lp = field_def[:solr_local_parameters])
        local_params =
          lp.map { |key, value|
            "#{key}=" + solr_param_quote(value, quote: "'")
          }.join(SPACE)
        solr_params[:q] = "{!#{local_params}}#{q}"
      elsif q
        solr_params[:q] = q
      end

      # Set Solr spellcheck.q to be original user-entered query, without our
      # local params, otherwise it'll try and spellcheck the local params!
      # Unless spellcheck.q has already been set by someone, respect that.
      #
      # TODO: Change calling code to expect this as a symbol instead of
      # a string, for consistency? :'spellcheck.q' is a symbol. Right now rspec
      # tests for a string and can't tell if other code may insist on a string.
      solr_params['spellcheck.q'] ||= q
    end

    # =========================================================================
    # :section: Blacklight::SolrHelper overrides
    # =========================================================================

    public

    # Do what the plugin does but swap out qt if it's specified.
    #
    # This helper method can be called within the context of an HTTP request
    # in which the params exist and independently outside an HTTP request.
    # In the latter case, the default :qt setting is used.
    #
    # @param [String] id
    # @param [Hash]   solr_params     Additional parameters to Solr.
    #
    # @return [Hash{Symbol=>String}]
    #
    # @see Blacklight::SolrHelper#solr_doc_params
    #
    def solr_doc_params(id = nil, solr_params = nil)
      values = request_params.slice(:id, :qt, :fl).reject { |_, v| v.blank? }
      values[:id] = id         if id.present?
      values[:qt] = 'document' unless values[:qt].present?
      values[:fl] = '*' if values.delete(:fields).to_s.casecmp('all').zero?
      solr_params ? solr_params.merge(values) : values
    end

    # Returns a params hash for a single facet field solr query.
    #
    # Used primarily by the get_facet_pagination method.
    #
    # Looks up Facet Paginator request params from current request params to
    # figure out sort and offset. Default limit for facet list can be specified
    # by defining a controller method facet_list_limit, otherwise 20.
    #
    # This is written to override the default behavior by using a recursive
    # merge for *extra_params*... the replaced implementation would, for
    # instance, replace all :fq values with the :fq value in the *extra_params*
    # instead of adding them to it.
    #
    # @param [String] facet_field
    # @param [Hash]   url_params
    # @param [Hash]   extra_params
    #
    # @return [Hash]
    #
    # @see Blacklight::SolrHelper#solr_facet_params
    #
    def solr_facet_params(facet_field, url_params = nil, extra_params = nil)

      url_params   ||= request_params
      extra_params ||= {}
      input = url_params.deep_merge(extra_params)

      # First start with a standard solr search params calculations, for any
      # search context in our request params.
      solr_params = solr_search_params(url_params)
      solr_params = merge_hash_of_arrays(solr_params, extra_params)

      # Now override with our specific things for fetching facet values.
      solr_params[:'facet.field'] = facet_field

      # Need to set as f.facet_field.facet.limit to make sure we override any
      # field-specific default in the Solr request handler.
      solr_params[:"f.#{facet_field}.facet.limit"] =
        if solr_params[:'facet.limit']
          solr_params[:'facet.limit'].to_i + 1
        elsif respond_to?(:facet_list_limit)
          facet_list_limit.to_s.to_i + 1
        else
          20 + 1
        end
      solr_params[:'facet.offset'] =
        input[Blacklight::Solr::FacetPaginator.request_keys[:offset]].to_i
      solr_params[:'facet.sort'] =
        input[Blacklight::Solr::FacetPaginator.request_keys[:sort]]
      solr_params[:rows] = 0

      solr_params
    end

    # Override which allows control over `solr_search_params_logic`.
    #
    # @param [Hash] url_params
    #
    # @option url_params [Boolean] :override  If *true*, will avoid applying
    #                                          `solr_search_params_logic`.
    #
    # @param [Hash]
    #
    def solr_search_params(url_params = nil)
      url_params ||= request_params
      url_params &&= url_params.rdup
      solr_params = {}
      unless url_params[:override]
        solr_search_params_logic.each do |method_name|
          send(method_name, solr_params, url_params)
        end
      end
      solr_params
    end

    # =========================================================================
    # :section:
    # Methods for Solr parameter setup.
    # =========================================================================

    public

    # solr_doc_by_alt_params
    #
    # @param [String] id
    # @param [Hash]   solr_params     Additional parameters to Solr.
    #
    # @return [Hash{Symbol=>String}]
    #
    # @see self#solr_doc_params
    #
    def solr_doc_by_alt_params(id = nil, solr_params = nil)
      id ||= request_params[:id]
      alt_q = "alternate_id_facet:\"#{id}\""
      solr_params ||= {}
      solr_doc_params(id, solr_params.merge(q: alt_q))
    end

    # =========================================================================
    # :section: Blacklight::SolrHelper overrides
    # Solr search methods.
    # =========================================================================

    public

    # Overriding from plugin to test for shadowedness, but also to change the
    # semantics of invocation so that this method can more easily be used in
    # settings other than CatalogController.
    #
    # @param [String] id
    # @param [Hash]   solr_params     @see self#extract_internal_options
    #
    # @return [Array<(RSolr::Ext::Response::Base, SolrDocument)>]
    # @return [Array<(RSolr::Ext::Response::Base, nil)>]
    #
    # @raise [InvalidSolrID]          If no results were returned.
    # @raise [HiddenSolrID]           If the initial result document is hidden.
    #
    # @see self#get_solr_doc_id_direct
    # @see Blacklight::SolrHelper#get_solr_response_for_doc_id
    #
    # === Usage Notes
    # To cause the method to raise exceptions, use { raise: true }; otherwise
    # the method returns a *nil* document if the item was either not findable
    # through Solr or was hidden.
    #
    def get_solr_response_for_doc_id(id = nil, solr_params = nil)

      # Normalize parameters to Solr and prepare for cache lookup, extracting
      # values which are used here and not passed on to Solr.
      solr_params  = solr_doc_params(id, solr_params)
      cache_params = solr_params.merge(portal: portal_controller)
      cache_params = Solr.generate_cache_params(cache_params)
      option = extract_internal_options(solr_params)

      # Get the response/document from Solr if not already cached.
      curr_response = nil
      response, doc =
        cache_fetch(cache_params) do
          curr_response, curr_doc =
            get_solr_doc_id_direct(id, solr_params, option)
          [curr_response, curr_doc] if curr_doc
        end
      response ||= curr_response

      # Raise exceptions if requested.
      if !doc
        raise Blacklight::Exceptions::InvalidSolrID if option[:raise]
      elsif doc.hidden?
        raise UVA::Exceptions::HiddenSolrID if option[:raise]
        doc = nil unless option[:override]
      end
      return response, doc

    end

    # A Solr query method.
    #
    # Given a user query, return a Solr response containing both result docs
    # and facets
    # - mixes in the Blacklight::Solr::SpellingSuggestions module
    # - the response will have a spelling_suggestions method
    #
    # Returns a two-element array (aka duple) with first the Solr response
    # object, and second an array of SolrDocuments representing the response
    # docs.
    #
    # This is written to override the default behavior by using a recursive
    # merge for the extra_controller_params... the replaced implementation
    # would, for instance replace all :fq values with the :fq value in the
    # extra_controller_params instead of adding them to it.
    #
    # @param [Hash] url_params
    # @param [Hash] extra_params
    #
    # @return [Array<(RSolr::Ext::Response::Base, Array<SolrDocument>)>]
    #
    # @see Blacklight::SolrHelper#get_search_results
    #
    def get_search_results(url_params = nil, extra_params = nil)

      # Normalize parameters to Solr, extracting values which are used here and
      # not passed on to Solr.
      url_params ||= request_params
      url_params &&= url_params.rdup
      option = extract_internal_options(url_params)
      url_params[:override] = option[:override] if option[:override]
      solr_params = solr_search_params(url_params)
      solr_params = merge_hash_of_arrays(solr_params, extra_params)

      # Prepare for cache lookup.
      cache_params = solr_params.merge(portal: portal_controller)
      cache_params = cache_params.merge(skip: option[:skip], report: true)
      cache_params = Solr.generate_cache_params(cache_params)

      # Get the response/documents from Solr if not already cached.
      cache_fetch(cache_params) do
        get_solr_docs_direct(solr_params, option)
      end
    end

    # Given a field name and array of values, get the matching Solr documents.
    #
    # @param [Symbol]                field
    # @param [String, Array<String>] values
    # @param [Hash]                  opt     @see self#extract_internal_options
    #
    # @return [Array<(RSolr::Ext::Response::Base, Array<SolrDocument>)]
    #
    # @see Blacklight::SolrHelper#get_solr_response_for_field_values
    #
    # @see CatalogController#ris
    # @see CatalogController#send_email_record
    # @see FolderController#csv
    # @see FolderController#refworks_texts
    # @see FolderController#ris
    #
    def get_solr_response_for_field_values(field, values, opt = nil)

      # To properly leverage caching, if the search is for multiple items by
      # ID, this will be handled by invoking self#get_solr_response_for_doc_id
      # on each item separately then combining the results into a single
      # response.
      if field.to_s == 'id'
        doc_ids = Array(values).reject(&:blank?)
        to_delete = []
        response = nil
        docs =
          doc_ids.map { |id|
            doc_response, doc = get_solr_response_for_doc_id(id, opt)
            next unless doc_response
            response = doc_response
            to_delete << id unless doc
            doc
          }.compact
        to_delete.each { |id| doc_ids.delete(id) }
        response['response']['docs'] = docs if response
        return response, docs
      end

      # Set up Solr search parameters.
      values = Array(values).reject(&:blank?)
      opt &&= opt.dup
      option = extract_internal_options(opt)
      skip = option[:skip]
      url_params =
        if option[:override]
          request_params.merge(override: option[:override])
        end
      q =
        if values.blank?
          'NOT *:*'
        else
          terms = values.map { |v| solr_param_quote(v) }.join(' OR ')
          "#{field}:(#{terms})"
        end
      solr_params = {
        defType:    'lucene',
        q:          q,
        fl:         '*',
        facet:      'false',
        spellcheck: 'false'
      }
      solr_params.merge!(opt) if opt.present?
      solr_params = solr_search_params(url_params).merge(solr_params)

      # Prepare for cache lookup.
      cache_params = solr_params.merge(portal: portal_controller, skip: skip)
      cache_params = Solr.generate_cache_params(cache_params)

      # Get the response/documents from Solr if not already cached.
      cache_fetch(cache_params) do
        get_solr_docs_direct(solr_params, option)
      end
    end

    # a solr query method
    # used to paginate through a single facet field's values
    # /catalog/facet/language_facet
    #
    # @param [String] facet_field
    # @param [Hash]   extra_params
    #
    # @return [Blacklight::Solr::FacetPaginator]
    #
    def get_facet_pagination(facet_field, extra_params = nil)

      # Set up Solr search parameters.
      solr_params = solr_facet_params(facet_field, params, extra_params)

      # Prepare for cache lookup.
      cache_params = solr_params.merge(portal: portal_controller)
      cache_params = Solr.generate_cache_params(cache_params)

      # Get the response from Solr if not already cached.
      response =
        cache_fetch(cache_params) do
          find(solr_params)
        end

      limit =
        if respond_to?(:facet_list_limit)
          facet_list_limit.to_s.to_i
        elsif (fl = solr_params[:"f.#{facet_field}.facet.limit"])
          fl - 1
        end
      rparams = response['responseHeader']['params']

      # Actually create the paginator!
      # NOTE: The sniffing of the proper sort from the solr response is not
      # currently tested for, tricky to figure out how to test, since the
      # default setup we test against doesn't use this feature.
      Blacklight::Solr::FacetPaginator.new(
        response.facets.first.items,
        offset: solr_params['facet.offset'],
        limit:  limit,
        sort:   rparams["f.#{facet_field}.facet.sort"] || rparams['facet.sort']
      )
    end

    # a solr query method
    # this is used when selecting a search result: we have a query and a
    # position in the search results and possibly some facets
    # Pass in an index where 1 is the first document in the list, and
    # the Blacklight app-level request params that define the search.
    #
    # @param [Fixnum] index           Position of the item in the results list.
    # @param [Hash]   url_params
    #
    # @return [SolrDocument]
    # @return [nil]                   If *index* was *nil* or the item could
    #                                   not be retrieved.
    #
    def get_single_doc_via_search(index, url_params)

      # Set up Solr search parameters.
      solr_params = solr_search_params(url_params)
      solr_params[:start] = (index - 1)
      solr_params[:rows]  = 1
      solr_params[:fl]    = '*'

      # Prepare for cache lookup.
      cache_params = solr_params.merge(portal: portal_controller)
      cache_params = Solr.generate_cache_params(cache_params)

      # Get the document from Solr if not already cached.
      cache_fetch(cache_params) do
        get_single_doc_direct(solr_params)
      end

    end

    # Get results from Solr.
    #
    # @param [Hash] solr_params       @see RSolr::Ext::Client#find
    #
    # @return [RSolr::Ext::Response::Base]
    #
    # @see Blacklight::SolrHelper#find
    # @see RSolr::Ext::Client#find
    #
    # @note This method doesn't actually modify the Blacklight method; it's
    # here to provide a location to insert debug statements as needed.
    #
    def find(solr_params)
      super(solr_params)
        .tap { |res| console_output("SOLR RESPONSE #{res.inspect}") if false }
    end

    # =========================================================================
    # :section:
    # Solr search methods.
    # =========================================================================

    protected

    # Request a single Solr document by ID.
    #
    # @param [String] id
    # @param [Hash]   solr_params     Solr parameters
    # @param [Hash]   option          Internal options
    #
    # @return [Array<(RSolr::Ext::Response::Base, SolrDocument)]
    # @return [Array<(RSolr::Ext::Response::Base, nil)]
    #
    # @see self#get_solr_response_for_doc_id
    #
    def get_solr_doc_id_direct(id, solr_params, option = nil)

      option ||= extract_internal_options(solr_params)

      # Send the Solr query.
      response = find(solr_params)
      docs = response && response.docs
      if docs.blank?
        response = find(solr_doc_by_alt_params(id))
        docs = response && response.docs
      end

      # Build a SolrDocument instance from the Solr response.
      doc = docs && docs.first
      doc &&= new_solr_document(doc, response, option[:skip])

      return response, doc

    end

    # Get the response for the matching Solr documents.
    #
    # @param [Hash] solr_params
    # @param [Hash] option            @see self#extract_internal_options
    #
    # @return [Array<(RSolr::Ext::Response::Base, Array<SolrDocument>)]
    #
    def get_solr_docs_direct(solr_params, option = nil)

      option ||= extract_internal_options(solr_params)

      # Send the Solr query.
      response = find(solr_params)
      docs = response && response.docs

      # Create SolrDocument instances from the Solr response.
      docs &&= docs.map { |d| new_solr_document(d, response, option[:skip]) }
      docs ||= []

      return response, docs
    end

    # Get the matching Solr document (discarding the response).
    #
    # @param [Hash] solr_params
    #
    # @return [SolrDocument]
    # @return [nil]
    #
    def get_single_doc_direct(solr_params)

      # Send the Solr query.
      response = find(solr_params)
      docs = response && response.docs

      # Build a SolrDocument instance from the Solr response.
      doc  = docs && docs.first
      new_solr_document(doc, response) if doc
    end

    # =========================================================================
    # :section:
    # Solr search methods.
    # =========================================================================

    public

    IGNORED_SOLR_PARAMS =
      %w(q qt per_page f facets facet.fields facet.limit facet.sort)
        .push(/^f\..+\.facet\.limit$/)
        .push(/^f\..+\.facet\.sort$/)
        .deep_freeze

    # Used to populate the "LIMIT RESULTS BY" menus on Catalog Advanced Search.
    #
    # @param [Hash] search_params     Solr parameters
    #
    # @return [RSolr::Ext::Response::Base]
    #
    # Compare with:
    # @see AccessArticlesConcern#get_article_advanced_search_facets
    # @see BlacklightAdvancedSearch::AdvancedController#get_advanced_search_facets
    #
    def get_solr_advanced_search_facets(search_params = nil)

      # If we have a search context, need to fetch facets from within that
      # context -- but we don't want to search within any existing :q or
      # ADVANCED facets, so we remove those params.
      solr_params =
        if advanced_search_context.present?
          ignored_url_params = search_fields.keys.map(&:to_sym)
          ignored_url_params << :f_inclusive
          url_params = request_params.except(*ignored_url_params)
          solr_search_params(url_params).reject do |k, _|
            match_any(k, IGNORED_SOLR_PARAMS)
          end
        elsif search_params.present?
          solr_search_params(request_params).merge(search_params)
        else
          solr_search_params(request_params)
        end
      solr_params ||= {}

      # Build Solr parameters directly.
      cfg = current_blacklight_config
      fsp = cfg.advanced_search[:form_solr_parameters]
      solr_params[:q]  ||= FACET_ONLY_SEARCH
      solr_params[:qt] ||= cfg.advanced_search[:qt] || cfg.default_qt
      solr_params[:rows] = 0
      solr_params.merge!(fsp) if fsp.present?

      # Prepare for cache lookup.
      cache_params = solr_params.merge(portal: portal_controller, report: true)
      cache_params = Solr.generate_cache_params(cache_params)

      # Get the response from Solr if not already cached.
      cache_fetch(cache_params) do
        find(solr_params)
      end

    end

    # get_solr_facets
    #
    # @param [String] facet_field
    # @param [Hash]   url_params      User-supplied values (often `params`)
    # @param [Hash]   extra_params
    #
    # @return [Array<(RSolr::Ext::Response::Base, Array<RSolr::Ext::Response::Facets::FacetItem>)]
    #
    def get_solr_facets(facet_field, url_params = nil, extra_params = nil)

      # Set up Solr search parameters.
      url_params ||= request_params
      solr_params = solr_facet_params(facet_field, url_params, extra_params)

      # Prepare for cache lookup.
      cache_params = solr_params.merge(portal: portal_controller)
      cache_params = Solr.generate_cache_params(cache_params)

      # Get the response from Solr if not already cached.
      response =
        cache_fetch(cache_params) do
          find(solr_params)
        end

      return response, response.facet.items

    end

    # get_browse_facets
    #
    # @param [String, Symbol] browse_mode
    # @param [Hash]           url_params
    #
    # @option url_params [Boolean] :all   If *true* do not paginate results.
    #
    # @return [Array<(RSolr::Ext::Response::Base, Array<RSolr::Ext::Response::Facets::FacetItem>)]
    #
    def get_browse_facets(browse_mode, url_params = nil)

      browse_mode = browse_mode.to_sym
      url_params ||= request_params
      url_params = url_params.dup

      facet_field = UVA::Classic.browse_mode_facet(browse_mode)
      cfg = current_blacklight_config
      fsp = cfg.advanced_search[:form_solr_parameters]

      # Get pagination properties.
      all      = url_params.delete(:all)
      page     = url_params.delete(:page).to_i
      page     = 1 if page.zero?
      per_page = url_params.delete(:per_page) || get_current_per_page

      # Set up Solr search parameters.
      solr_params = solr_search_params(url_params)
      facet_offset = solr_params.delete(:'facet.offset') || 0 # TODO: ???
      solr_params[:q]  ||= FACET_ONLY_SEARCH
      solr_params[:qt] ||= cfg.advanced_search[:qt] || cfg.default_qt
      solr_params[:rows] = 0
      solr_params.merge!(fsp) if fsp.present?
      solr_params[:'facet.field'] = [facet_field]

      # Prepare for cache lookup.
      cache_params = solr_params.merge(portal: portal_controller)
      cache_params = Solr.generate_cache_params(cache_params)

      # Get the facet results (from cache if possible), modifying the contents
      # of `response.facet_fields[facet_field]` so that it contains only values
      # matching the terms in `url_params[browse_mode]`.
      response, items =
        cache_fetch(cache_params) do
          resp = find(solr_params)
          generate_facet_list(resp, browse_mode, url_params)
        end

      # If paging, extract the subset of items now.
      if page && per_page && !all
        rows  = per_page
        start = (page - 1) * per_page
        response.header['params']['rows'] = rows.to_s
        response.response['start']    = start.to_s
        response.response['numFound'] = items.size.to_s
        items = items[start, rows]
      end

      return response, items

    end

    # Send a request directly to Solr.
    #
    # @param [Array] args             See Usage Notes.
    #
    # @return [Hash]                  Typical response value.
    # @return [String]                Only if specified by the request.
    # @return [nil]                   Request failure.
    #
    # === Usage Notes
    # To use a request handler other than the default, either invoke the method
    # as:
    #   solr_request(request_handler, url_params)
    # or:
    #   solr_request(url_params.merge(qt: request_handler))
    #
    # @see RSolr::Ext::Client#rsolr_request_arguments_for
    # @see RSolr::Client#send_and_receive
    #
    def solr_request(*args)

      handler    = (args.shift if args.first.is_a?(String))
      url_params = (args.shift if args.first.is_a?(Hash))

      # Set up Solr search parameters.
      solr_params = args.last.is_a?(Hash) ? args.pop : {}
      if url_params
        skip = [:controller, :action, :catalog_select, :counter, :total]
        url_params.except!(*skip)
        qt = url_params.delete(:qt)
        handler = qt unless handler || qt.blank?
        solr_params.merge!(params: RSolr::Ext::Request.map(url_params))
      end
      handler ||= 'select'

      # Prepare for cache lookup.
      cache_params = solr_params.merge(portal: portal_controller, qt: handler)
      cache_params = Solr.generate_cache_params(cache_params)

      # Get the document from Solr if not already cached.
      cache_fetch(cache_params) do
        Blacklight.solr.send_and_receive(handler, solr_params)
      end
    end

    # =========================================================================
    # :section:
    # =========================================================================

    protected

    # Slightly better than Hash.merge() since it will combine hash keys'
    # values into arrays.
    #
    # @param [Hash] subject
    # @param [Hash] other
    #
    # @return [Hash]
    #
    def merge_hash_of_arrays(subject, other)
      if other.blank?
        subject || {}
      else
        subject.dup.tap do |result|
          other.each_pair do |key, value|
            result[key] ||= []
            result[key] += Array(value).compact
          end
        end
      end
    end

    # Modify the given option hash to extract the internal options.
    #
    # @param [Hash] opt               Hash to modify.
    #
    # @option opt [Boolean] :override If *true*, then do not apply
    #                                   `solr_search_params_logic` to the
    #                                   search.
    #
    # @option opt [Boolean] :raise    Explicitly set this to *true* if invoking
    #                                   the method in a module where the code
    #                                   is designed to handle exceptions.
    #
    # @option opt [String,Array<String>] :skip
    #                                 A comma-delimited list controlling the
    #                                   creation of the SolrDocument.  List
    #                                   members relevant to this method are:
    #                                 - "availability": the created instance
    #                                   will not contact Firehose.
    #                                 - "freeze": prevents the SolrDocument
    #                                   initializer from freezing received
    #                                   data.
    #
    # @return [Hash]                  Internal option values.
    #
    def extract_internal_options(opt)
      result = {}
      if opt.present?
        INTERNAL_OPTIONS.each do |key|
          next unless opt.has_key?(key)
          value = opt.delete(key)
          case value.to_s.downcase
            when 'true'  then result[key] = true
            when 'false' then result[key] = false
            else              result[key] = value if value.present?
          end
        end
      end
      result
    end

    # Create a new SolrDocument instance.
    #
    # @param [Hash]                       doc
    # @param [RSolr::Ext::Response::Base] response
    # @param [String]                     skip
    #
    # @return [SolrDocument]
    #
    def new_solr_document(doc, response, skip = nil)
      opt =
        if skip.present?
          skip = skip.split(/\W+/) if skip.is_a?(String)
          skip = skip.map { |v| v.to_s.strip }.reject(&:blank?)
          skip.map { |v| [v.downcase.to_sym, false] }.to_h
        end
      SolrDocument.new(doc, response, opt)
    end

    # =========================================================================
    # :section:
    # =========================================================================

    private

    # Returns `params` if it is available.
    #
    # @return [Hash]
    #
    def request_params
      respond_to?(:params) ? params : {}
    end

    # =========================================================================
    # :section: Class methods
    # =========================================================================

    private

    class << self

      include UVA
      include UVA::Cache
      include UVA::Util::StringMethods

      IGNORED_PARAMETERS = [
        :canonical,
        :catalog_select,
        :complete,
        :controller,
        :format,
        :index,
        :raise,
        :utf8,
        :view,
        :width,
      ].deep_freeze

      IGNORED_SETTINGS = {
        'spellcheck.q' => /./,
      }.deep_freeze

      DEFAULT_CACHE_OPT = {
        namespace:  'SOLR',
        expires_in: SLOW_EXPIRE,
      }.deep_freeze

      # generate_cache_params
      #
      # @param [Hash] search_params
      #
      # @return [Array<(String, Hash)>]
      #
      def generate_cache_params(search_params)

        # Extract cache-specific options; what remains in *search_params* will
        # be used to generate the cache key.
        cache_opt = extract_cache_options(search_params)
        method = caller[0].to_s.sub(/^[^`]+`/, '').sub(/'$/, '')
        method = (cache_opt[:calling_method] ||= method)
        time_sensitive = (search_params[:action].to_s =~ /availability/)
        cache_opt[:expires_in] = FAST_EXPIRE if time_sensitive

        # Generate the cache key.
        cache_key =
          search_params.map { |k, v|
            next if v.blank?
            next if IGNORED_PARAMETERS.include?(k.to_sym)
            next if match_any(v, IGNORED_SETTINGS[k.to_s])
            %Q(#{k}=#{v.inspect})
          }.compact.sort.uniq.join(SPACE)
        Cache.log(:info, method) { "RAW ======> #{cache_key}" }
        cache_key = Digest::SHA2.hexdigest(cache_key)

        # Generate the rest of the cache options.
        Cache.log(:debug, method) { "KEY ======> #{cache_key}" }
        DEFAULT_CACHE_OPT.merge(cache_key: cache_key)

      end

    end

  end

end
