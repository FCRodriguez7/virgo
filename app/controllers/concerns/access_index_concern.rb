# app/controllers/concerns/access_index_concern.rb

require 'active_support/concern'
require 'uva'

# Support for controller actions involving index search.
#
module AccessIndexConcern

  extend ActiveSupport::Concern

  include AccessAnyConcern

  include UVA::Helper::Articles
  include UVA::AdvancedSearch::Controller
  include UVA::AdvancedSearch::CatalogHelperOverride

  # Code to be added to the including controller class definition.
  included do
    [Blacklight::SolrHelper, UVA::Solr].each do |mod|
      next if include?(mod)
      console_output(
        "AccessIndexConcern causing #{self} to include #{mod}"
      ) if DEBUG_INCLUDE
      include mod
    end
  end

  # Hints for RubyMine (skipped during execution).
  include UVA::Solr unless ONLY_FOR_DOCUMENTATION

  # ===========================================================================
  # :section:
  # ===========================================================================

  public

  # Messages displayed to the user by CatalogController.
  MESSAGE = {
    bad_email_addr: 'You must enter a valid email address.',
    bad_iiif:       'IIIF metadata missing',
    bad_item:       'Sorry, you seem to have encountered an error.',
    bad_ph_number:  'You must enter a valid %d digit phone number.',
    bad_request:    "Sorry, I don't understand your search.",
    bad_results:    'Virgo did not understand the search request. ' \
                      'Check the search text for unclosed parentheses or ' \
                      'other unbalanced characters like quotes, brackets, ' \
                      'etc. and try again.',
    no_iiif:        'IIIF metadata unavailable',
    no_recipient:   'You must enter a recipient to send this message.',
    no_sms_carrier: 'You must select a mobile carrier.',
    search_failure: "Sorry, I don't understand your search.",
    sent:           'Message sent',
    not_sent:       'There was a problem sending the e-mail.'
  }.deep_freeze

  # ===========================================================================
  # :section: Blacklight::Catalog overrides
  # ===========================================================================

  protected

  # Set up "Previous" and "Next" context.
  #
  # @return [void]
  #
  # @see self#setup_previous_document
  # @see self#setup_next_document
  #
  # Compare with:
  # @see Blacklight::Catalog#setup_next_and_previous_documents
  #
  def setup_next_and_previous_documents
    counter = search_session[:counter].to_i
    total   = search_session[:total].to_i
    setup_previous_document(counter, total)
    setup_next_document(counter, total)
  end

  # Context for previous document in search results.
  #
  # @param [Fixnum] counter         Search index position of the current item.
  # @param [Fixnum] total           Total in search result set.
  #
  # @return [SolrDocument]
  # @return [nil]
  #
  # Compare with:
  # @see Blacklight::Catalog#setup_previous_document
  #
  def setup_previous_document(counter = nil, total = nil)
    counter = (counter || search_session[:counter]).to_i
    unused(total)
    @previous_document =
      if counter > 1
        setup_document_by_counter(counter - 1)
      end
  end

  # Context for next document in search results.
  #
  # @param [Fixnum] counter         Search result position of the current item.
  # @param [Fixnum] total           Total in search result set.
  #
  # @return [SolrDocument]
  # @return [nil]
  #
  # Compare with:
  # @see Blacklight::Catalog#setup_next_document
  #
  def setup_next_document(counter = nil, total = nil)
    counter = (counter || search_session[:counter]).to_i
    total   = (total   || search_session[:total]).to_i
    @next_document =
      if (0 < counter) && (counter < total)
        setup_document_by_counter(counter + 1)
      end
  end

  # Gets a document based on its position within a result set.
  #
  # @param [Fixnum] counter
  #
  # @return [SolrDocument]
  # @return [nil]
  #
  # Compare with:
  # @see Blacklight::Catalog#setup_document_by_counter
  #
  def setup_document_by_counter(counter)
    return if (counter.to_i < 1) || search_session.blank?
    get_single_doc_via_search(counter, search_session)
  end

  # ===========================================================================
  # :section:
  # ===========================================================================

  public

  # get_catalog_facets
  #
  # @param [String] facet_field
  #
  # @return [Array<RSolr::Ext::Response::Facets::FacetItem>]
  #
  def get_catalog_facets(facet_field)
    list = get_facet_pagination(facet_field, extra_solr_params)
    (list && list.items) || []
  end

  # Special parameters to exclude UNDISCOVERABLE records in normal searches
  # (but not advanced searches, or searches for which a collection facet has
  # been selected).
  #
  # @return [Hash]
  #
  def extra_solr_params
    result = {}
    unless collection_search? || search_within_collections?
      result[:fq] ||= []
      result[:fq] << '-shadowed_location_facet:UNDISCOVERABLE'
    end
    result
  end

  # Put quotes around a call number query.
  #
  # @param [Hash] p                   Default: `params`.
  #
  # @return [String]                  The original `p[:q]` string.
  # @return [nil]                     If modification was not needed.
  #
  # @see self#cleanup_call_number_search
  #
  def adjust_call_number_search(p = nil)
    p ||= params
    return unless p[:search_field] == 'call_number'
    old_q = p[:q]
    return if null_search_term?(old_q)
    return unless (new_q = old_q.dup.tr!((SQUOTE + DQUOTE), ''))
    p[:q] = new_q
    old_q
  end

  # Restore the original call number query.
  #
  # @param [String] original_q        The original `p[:q]` value.
  # @param [Hash]   p                 Default: `params`.
  #
  # @return [String]                  The value of *original_q*.
  # @return [nil]                     The value of *original_q*.
  #
  # @see self#adjust_call_number_search
  #
  def restore_call_number_search(original_q, p = nil)
    return unless original_q
    p ||= params
    p[:q] = original_q
  end

  # ===========================================================================
  # :section: Filters
  # ===========================================================================

  public

  # Updates the @documents array for the given set of ids.
  #
  # @param [Array] args
  #
  # @return [Array<SolrDocument>]     The new contents of @documents.
  #
  # @see UVA::Solr#get_solr_response_for_field_values
  #
  def set_documents(*args)
    args << params[:id] if args.empty?
    ids = args.flatten.join(',').split(',').reject(&:blank?).uniq.presence
    @response, @documents = ids && get_solr_response_for_field_values(:id, ids)
    @documents = Array(@documents).compact
  end

  # Updates @document with the Solr entry associated with the given id.
  #
  # @param [Array] args
  #
  # @option args [Boolean] :raise     See Solr#extract_internal_options
  #
  # @return [Array<(RSolr::Ext::Response::Base, SolrDocument)>]
  # @return [nil]                     If no :id was present.
  #
  # @raise [InvalidSolrID]            If no results were returned.
  # @raise [HiddenSolrID]             If the initial result document is hidden.
  #
  # @see UVA::Solr#get_solr_response_for_doc_id
  #
  def get_solr_document(*args)
    opt = args.last.is_a?(Hash) ? args.pop : params
    opt = opt ? opt.dup : {}
    id = opt.delete(:id)
    id = args.first if args.first
    return unless id.present?
    opt[:raise] = true unless opt.key?(:raise)
    resp, doc = get_solr_response_for_doc_id(id, opt)
    @response, @document = resp, doc unless args.first
    return resp, doc
  end

  # Updates @document_list with the Solr entries as directed by URL parameters
  # and saves the search session for the current portal.
  #
  # @param [Hash] url_params          Default: `params`.
  #
  # @return [Array<(RSolr::Ext::Response::Base, Array<SolrDocument>)>]
  #
  # @see UVA::Solr#get_solr_response_for_doc_id
  #
  def get_document_list(url_params = nil)

    # Since the root routes through "catalog#index", this action will be called
    # for that page, however it does not actually perform a search.
    return if home_page?

    url_params ||= params

    # Adjust query and get search results.
    update_query!(url_params)
    q = adjust_call_number_search(url_params)
    extra_params = extra_solr_params
    @response, @document_list = get_search_results(url_params, extra_params)
    restore_call_number_search(q, url_params)

    # Update search session values.
    save_current_search(url_params, @response) unless print_view? || rss_view?

    return @response, @document_list

  rescue => e
    flash_alert(MESSAGE[:bad_results], e) unless rescue_with_handler(e)
    nil

  end

  # Updates @response to acquire facets and facet counts.
  #
  # @return [RSolr::Ext::Response::Base>]
  #
  # @see UVA::Solr#get_solr_advanced_search_facets
  #
  def get_advanced_facets
    @response = get_solr_advanced_search_facets
  end

  # Used for images, since we don't need much data for them.
  #
  # @return [String]
  #
  def add_lean_query_type
    params[:qt] = 'document_lean'
  end

  # Modifies parameters based on whether we are in the Special Collections
  # lens.
  #
  # @return [void]
  #
  def adjust_for_spec_coll

    return unless params.key?(:special_collections)

    # Set the session state if "&special_collections=" was included in the URL
    # query parameters.
    sc_current = session[:special_collections]
    sc_updated = !false_value?(params[:special_collections])
    return if sc_current == sc_updated

    # Update session; the :special_collections parameter has served its purpose
    # so it is removed.
    if sc_updated
      session[:special_collections] = true
    else
      session.delete(:special_collections)
    end
    params.delete(:special_collections)

    # Ensure that the main page for Special Collections is the catalog home.
    will_redirect(catalog_home_path) if home_page?
  end

  # This exists only to avoid error messages from Pinterest due to old links
  # to the page viewer which are now actually handled by the IIIF viewer.
  #
  # @return [void]
  #
  def adjust_old_style_params
    redirect_to request.path if params && params[:page]
  end

  # Do not make virtual shelf browse available to visitors; they would be
  # seeing titles that are not available to them because they are not
  # requestable from the Special Collections reading room.
  #
  # @return [void]
  #
  def suppress_shelf_browse
    suppressed =
      if session[:special_collections]
        option = UVA::ShelfBrowse.option
        unsupported  = !option[:sc_supported]
        unauthorized = option[:sc_netbadge] && !netbadge_session?
        unsupported || unauthorized
      end
    UVA::ShelfBrowse.feature_suppressed(suppressed)
  end

  # ===========================================================================
  # :section: Filters
  # ===========================================================================

  protected

  # params_to_keep
  #
  # @return [Hash]
  #
  def params_to_keep
    no_query = params[:q].blank?
    result = no_query ? advanced_search_values : {}
    fields = [:f, :format, :sort_key] << (no_query ? :search_field : :q)
    result.merge(params.slice(*fields))
  end

end
