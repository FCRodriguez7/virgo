# app/controllers/catalog_controller.rb

require 'uva'

# This controller supports catalog search-and-discovery via the web API to the
# Solr index service.
#
# === Implementation Notes
# This definition extends/overrides Blacklight's CatalogController.
#
# @see "#{Blacklight.controllers_dir}/catalog_controller.rb"
#
#--
# rubocop:disable Metrics/ClassLength # [627/300]
#++
class CatalogController < ApplicationController

  include Blacklight::Catalog
  include BlacklightAdvancedSearch::Controller

  include AccessAnyConcern
  include AccessArticlesConcern
  include AccessRepositoryConcern
  include ActionResponsesConcern
  include EmailConcern
  include LibraryPatronConcern
  include RoutingConcern
  include StarredItemsConcern
  include AccessIndexConcern

  extend BlacklightConfigConcern

  # ===========================================================================
  # :section: Blacklight Configuration
  # ===========================================================================

  public

  # === Facets ===
  # The order here defines the order in which facets are displayed in the
  # search results sidebar.
  CATALOG_FACETS = {
    # rubocop:disable Metrics/LineLength
    library_facet:            ['Library',             advanced: true,   missing: true],
    format_facet:             ['Format',              advanced: true],
    author_facet:             ['Author',              advanced: false],
    subject_facet:            ['Subject',             advanced: false],
    series_title_facet:       ['Series',              advanced: false],
    digital_collection_facet: ['Digital Collection',  advanced: true],
    call_number_broad_facet:  ['Call Number Range',   advanced: false],
    call_number_facet:        ['Call Number Range',   advanced: true],
    language_facet:           ['Language',            advanced: true,   sort: 'count', missing: true],
    region_facet:             ['Geographic Location', advanced: true,   sort: 'count', limit: 500],
    published_date_facet:     ['Publication Era',     advanced: false],
    category_facet:           ['Category',            advanced: false,  optional: true],
    group_facet:              ['Group',               advanced: false,  optional: true],
    signature_facet:          ['Signature',           advanced: false,  optional: true],
    use_facet:                ['Permissions',         advanced: true,   missing:  true],
    license_class_facet:      ['License',             advanced: true,   missing:  true],
    fund_code_facet:          ['Fund Code',           advanced: true,   optional: true],
    source_facet:             ['Source',              advanced: false],
    location2_facet:          ['Shelf Location',      advanced: true,   optional: true, missing: true],
    year_multisort_i:         ['Year',                advanced: false,  optional: true], # [1]
    collection_facet:         ['Coin Collection',     advanced: false,  optional: true], # [2]
    # rubocop:enable Metrics/LineLength
    #
    # NOTE:
    # [1] Only appears within "Switch to" links created on article search
    #     results pages.
    # [2] Specific collections within "Coins of the University of Virginia Art
    #     Museum"."
    #
  }.deep_freeze

  # === Search fields ===
  # The order here defines the order in which search fields are displayed on
  # the advanced search form.
  CATALOG_SEARCH_FIELDS = {
    # rubocop:disable Metrics/LineLength
    author:           ['Author',                          advanced: true],
    title:            ['Title',                           advanced: true],
    journal:          ['Journal Title',                   advanced: true],
    subject:          ['Subject',                         advanced: true],
    keyword:          ['Keyword',                         advanced: true],
    published:        ['Publisher/Place of Publication',  advanced: true],
    call_number:      ['Call Number',                     advanced: true],
    isbn:             ['ISBN',                            advanced: true],
    issn:             ['ISSN',                            advanced: false],
    publication_date: ['Date Published',                  advanced: true, range: true],
    # rubocop:enable Metrics/LineLength
  }.deep_freeze

  # === Sort fields ===

  BY_YEAR        = 'year_multisort_i'.freeze
  BY_RECEIPT     = 'date_received_facet'.freeze
  BY_TITLE       = 'title_sort_facet'.freeze
  BY_AUTHOR      = 'author_sort_facet'.freeze
  BY_CALL_NUMBER = 'call_number_sort_facet'.freeze

  BY_RECEIVED_DATE   = "#{BY_RECEIPT} desc".freeze
  BY_NEWEST          = "#{BY_YEAR} desc, #{BY_RECEIPT} desc".freeze
  BY_OLDEST          = "#{BY_YEAR} asc, #{BY_RECEIPT} asc".freeze
  IN_TITLE_ORDER     = "#{BY_TITLE} asc, #{BY_AUTHOR} asc".freeze
  IN_AUTHOR_ORDER    = "#{BY_AUTHOR} asc, #{BY_TITLE} asc".freeze
  IN_SHELF_ORDER     = "#{BY_CALL_NUMBER} asc".freeze
  IN_REV_SHELF_ORDER = "#{BY_CALL_NUMBER} desc".freeze
  BY_RELEVANCY       = "score desc, #{BY_NEWEST}".freeze

  # === Sort fields ===
  # The order here defines the order in which sort field selections are
  # displayed in the drop-down "Sort by" menu on search results pages.
  CATALOG_SORT_FIELDS = {
    # rubocop:disable Metrics/LineLength
    relevancy:       ['Relevancy',                     sort: BY_RELEVANCY],
    received:        ['Date Received',                 sort: BY_RECEIVED_DATE],
    published:       ['Date Published - newest first', sort: BY_NEWEST],
    published_a:     ['Date Published - oldest first', sort: BY_OLDEST],
    title:           ['Title',                         sort: IN_TITLE_ORDER],
    author:          ['Author',                        sort: IN_AUTHOR_ORDER],
    call_number:     ['Call Number',                   sort: IN_SHELF_ORDER],
    call_number_rev: ['Call Number (reverse)',         sort: IN_REV_SHELF_ORDER]
    # rubocop:enable Metrics/LineLength
  }.deep_freeze

  # ===========================================================================
  # :section: Blacklight Configuration
  #
  # @see Blacklight::Configurable::ClassMethods#configure_blacklight
  # @see Blacklight::Configuration::Fields#add_solr_field
  # ===========================================================================

  configure_blacklight do |config|

    config.default_solr_params = {
      qt:   'search',
      rows: 20
    }
    config.default_qt = config.default_solr_params[:qt]
    config.spell_max  = 5

    # Solr field values given special treatment in the search results view.
    config.index.show_link           = 'title_display'
    config.index.record_display_type = 'format'

    # Solr field values given special treatment in the item details view.
    config.show.heading      = 'title_display'
    config.show.html_title   = 'title_display'
    config.show.display_type = 'format'

    configure_facets(config, CATALOG_FACETS, qt: config.default_qt)
    configure_search_fields(config, CATALOG_SEARCH_FIELDS)
    configure_sort_fields(config, CATALOG_SORT_FIELDS)

  end

  # ===========================================================================
  # :section: Filters
  # ===========================================================================

  # rubocop:disable Metrics/LineLength

  # Actions that might result in a redirect or might modify the session.

  before_filter :recaptcha_check,           only: [:send_email_record]
  before_filter :adjust_old_style_params,   only: [:page_turner]
  before_filter :update_show_page_context,  only: [:update]
  before_filter :adjust_for_search_context, only: [:show]
  before_filter :adjust_for_full_view,      only: [:show]
  before_filter :adjust_for_classic,        only: [:index, :show]
  before_filter :adjust_for_spec_coll,      only: [:index]
  before_filter :validate_advanced,         only: [:index]
  before_filter :resolve_sort,              only: [:index]
  before_filter :cleanup_parameters,        only: [:index]
  before_filter :conditional_redirect

  # Actions involved in data acquisition (and might result in an exception).

  before_filter :get_document_list,         only: [:index]
  before_filter :get_advanced_facets,       only: [:advanced]
  before_filter :add_lean_query_type,       only: [:brief_availability, :image, :image_load]
  before_filter :get_solr_document,         only: [:show, :availability, :brief_availability, :fedora_metadata, :firehose, :hierarchy_children, :iiif, :image, :image_load, :page_turner, :tei]
  before_filter :set_documents,             only: [:email, :sms, :citation, :endnote, :ris]
  before_filter :set_articles,              only: [:email, :sms, :citation, :endnote, :ris]

  # Other actions before the page is rendered.

  before_filter :suppress_shelf_browse,     only: [:index, :show, :availability, :brief_availability]
  before_filter :notices_update,            only: [:index, :show]

  # Actions after the page is rendered.

  after_filter  :set_cors_headers

  # rubocop:enable Metrics/LineLength

  # ===========================================================================
  # :section: Exception Handlers
  # ===========================================================================

  # When RSolr::RequestError is raised, this block is executed.
  # The index action will more than likely throw this one.
  # Example, when the standard query parser is used, and a user submits a "bad"
  # query.
  rescue_from RSolr::Error::InvalidRubyResponse do |error|
    flash[:notice] = user_message(:search_failure)
    Rails.logger.info { "REDIRECT due to #{error}" }
    redirect_to portal_index_path
  end

  # Invoked when a request for /catalog/HIDDEN_SOLR_ID is made.
  rescue_from HiddenSolrID do |error|
    flash[:notice] = user_message(:bad_item)
    Rails.logger.info { "REDIRECT due to #{error}" }
    redirect_to portal_index_path
  end

  # Invoked when a path is requested that should result in a redirect.
  rescue_from RedirectNeeded do |error|
    Rails.logger.debug { "REDIRECT due to #{error}" }
    redirect_to error.new_url
  end

  # Invoked when `redirect_to :back` fails because there was no HTTP_REFERER.
  rescue_from ActionController::RedirectBackError do |error|
    Rails.logger.debug { 'REDIRECT due to failed `redirect_to :back`' }
    redirect_to portal_index_path
  end

  # Too many of these are showing up in ExceptionNotification emails, usually
  # generated by a bot crawling the site.  This is here to keep the email
  # volume lower.
  rescue_from ActionController::InvalidAuthenticityToken do |error|
    Rails.logger.debug { "REDIRECT due to #{error}" }
    redirect_to portal_index_path
  end

  # Some googlebot keeps doing an OPTIONS request on status, and status doesn't
  # allow that. Trying to reduce exception emails.
  rescue_from ActionController::MethodNotAllowed do |error|
    Rails.logger.debug { "REDIRECT due to MethodNotAllowed: #{error}" }
    redirect_to portal_index_path
  end

  # ===========================================================================
  # :section: Routes
  # ===========================================================================

  public

  # == GET /catalog
  # Get search results from the Solr index.
  #
  # This override of the Blacklight plugin method adds functionality:
  #   - Cleanup of empty parameters (generated by advanced search).
  #   - Cleanup of imbalanced double-quotes in search fields.
  #   - JSON-P responses.
  #
  # @see AccessIndexConcern#get_document_list
  #
  def index
    if home_page?
      respond_to do |format|
        format.html { render layout: 'home' }
        format.rss  { redirect_to params }
        format.xml  { render 'about/index', format: 'xml' }
        format.json { render 'about/index', format: 'json' }
      end
    else
      respond_to do |format|
        format.html { render layout: index_layout }
        format.rss  { render layout: false }
        format.xml  { render xml:  xml_response(@response) }
        format.json { render json: json_response(@response) }
      end
    end
  end

  # == GET /catalog/:id
  # Get a single document from the Solr index.
  #
  # (Overridden from Blacklight plugin to pass argument URL to the Virgo show
  # page of item, to EndNote and Zotero RIS export methods.)
  #
  # === Usage Notes
  # When called directly, the result will be lacking certain elements which are
  # dependent on search context.
  #
  # @see AccessIndexConcern#get_solr_document
  # @see self#update
  #
  def show
    respond_to do |format|
      format.html do
        setup_next_and_previous_documents
        setup_next_and_prev_components(@document)
      end
      format.json do
        render json: json_response(@response)
      end
      # Fall-back for export formats dynamically added by document extensions.
      # (Common formats should already be handled by the routes of the
      # "Citation Export" section.)
      @document.export_formats.except(:json).each_key do |format_name|
        format.send(format_name) do
          render text: @document.export_as(format_name), layout: false
        end
      end
    end
  end

  # == PUT /catalog/:id
  # Adds search context to the show page to support display of the count and
  # total ("Item N of M"), and "Previous" and "Next" links).
  #
  # === Implementation Notes
  # To provide search context information, Javascript modifies item links on
  # search results and item details pages so that they transmit search context
  # information through a PUT to the item URL rather than a GET.  This method
  # handles that route by saving the search context information in the
  # `session` before continuing on to the `show` method.
  #
  # @see AccessAnyConcern#update_show_page_context
  # @see AccessAnyConcern#conditional_redirect
  # @see app/assets/javascripts/feature/search-context
  #
  def update
  end

  # == GET /catalog/facet/:id
  # Display values and pagination links for a single facet field.
  # (Overridden from Blacklight plugin to add JSON response.)
  #
  def facet
    id = params[:id]
    @facet_list = get_catalog_facets(id)
    respond_to do |format|
      format.html { render layout: 'popup' }
      format.json { render json: json_response(@facet_list) }
      format.xml {
        render xml: xml_response(@facet_list, recursive: true, root: id)
      }
    end
  end

  # == GET /catalog/advanced
  #
  # @see AccessIndexConcern#get_advanced_facets
  #
  def advanced
    render 'advanced/index'
  end

  # ===========================================================================
  # :section: Routes - Availability
  # ===========================================================================

  public

  # == GET /catalog/:id/availability
  # == GET /catalog/:id/availability?popup=true
  # Get item availability status.
  #
  # @see app/assets/javascripts/catalog/index
  # @see app/assets/javascripts/catalog/show
  #
  def availability
    respond_to do |format|
      format.html { render layout: false }
      format.json
    end
  end

  # == GET /catalog/:id/brief_availability
  # Just get the availability info independently of the document.
  #
  # @see app/assets/javascripts/feature/availability
  #
  def brief_availability
    respond_to do |format|
      format.html { render layout: false }
      format.json
    end
  end

  # == GET /catalog/:id/firehose
  # Display raw availability results from Firehose.
  #
  def firehose
    availability = @document.availability || []
    respond_to do |format|
      format.html
      format.xml { render xml: availability.to_xml }
    end
  end

  # == GET /catalog/:id/image_load
  # AJAX loader page for image.
  #
  def image_load
  end

  # == GET /catalog/:id/image.jpg
  # Image for a single record.
  #
  # This is here for historical purposes, in case someone is externally
  # referencing this url.
  #
  def image
    respond_to do |format|
      format.jpg { redirect_to @document.image_path }
    end
  end

  # ===========================================================================
  # :section: Routes - E-mail
  # ===========================================================================

  public

  # == GET /catalog/email?id=:id
  # Email form which posts to /catalog/send_email_record.
  #
  def email
    @originator = __method__
    @field = params.slice(:to, :message, :full_record)
  end

  # == GET /catalog/sms?id=:id
  # Text message form which posts to /catalog/send_email_record.
  #
  def sms
    @originator = __method__
    @field = params.slice(:to, :carrier)
  end

  # == POST /catalog/send_email_record
  # Action for sending email.  This is meant to post from the form and to do
  # processing overriding from plugin for sending full record.
  #
  #--
  # rubocop:disable Metrics/AbcSize # [46.05/45]
  # rubocop:disable Metrics/MethodLength # [52/35]
  #++
  def send_email_record

    # Parameters
    originator   = params[:style].to_s.downcase.to_sym
    recipient    = params[:to].to_s.strip
    carrier      = params[:carrier]
    message      = params[:message]
    full_record  = params[:full_record]
    phone_number = nil

    # Validate parameters that were supplied from the request form.
    errors = []
    case originator
      when :email
        if recipient.blank?
          errors << :no_recipient
        elsif !valid_email_address(recipient)
          errors << :bad_email_addr
        end
      when :sms
        if recipient.blank?
          errors << :no_recipient
        elsif !(phone_number = valid_sms_recipient(recipient))
          errors << [:bad_ph_number, SMS_PHONE_DIGITS]
        end
        errors << :no_sms_carrier if carrier.blank?
    end

    # Show flash errors on original page with valid fields preserved.
    if errors.present?
      flash[:error] = errors.map { |error| user_message(*error) }
      parameters = {
        action:      originator,
        id:          params[:id],
        article_id:  params[:article_id],
        to:          recipient,
        carrier:     carrier,
        message:     message,
        full_record: full_record,
        aside:       in_aside?
      }.reject { |_, v| v.blank? }
      redirect_to parameters
      return
    end

    # Create and send message
    mail_message =
      case originator
        when :email
          RecordMailer.email_record(
            set_documents,
            set_articles,
            message,
            full_record,
            mail_properties(to: recipient)
          )
        when :sms
          RecordMailer.sms_record(
            set_documents,
            set_articles,
            carrier,
            mail_properties(to: phone_number)
          )
      end
    if mail_message && mail_message.deliver
      flash.now[:notice] = user_message(:sent)
      render_close_window
    else
      flash.now[:error] = user_message(:not_sent)
      render layout: 'error'
    end
    # rubocop:enable Metrics/AbcSize
    # rubocop:enable Metrics/MethodLength
  end

  # ===========================================================================
  # :section: Routes - Citation Export
  # ===========================================================================

  public

  # == GET /catalog/citation?id=:id
  #
  def citation
  end

  # == GET /catalog/refworks?id=:id
  #
  def refworks
    redirect_to(params.merge(controller: 'folder', action: 'refworks_texts'))
  end

  # == GET /catalog/endnote?id=:id
  #
  def endnote
    respond_to do |format|
      format.endnote
    end
  end

  # == GET /catalog/:id/ris
  #
  # Gets documents to export to file in RIS format.
  #
  def ris
    respond_to do |format|
      format.ris
    end
  end

  # ===========================================================================
  # :section: Routes - Repository Objects
  # ===========================================================================

  public

  # == GET /catalog/ID/tei
  # Display e-text.
  #
  def tei
    render layout: 'tei'
  end

  # == GET /catalog/ID/view
  # Displays the page turner UI, for viewing page images of DL text resources.
  #
  def page_turner

    # Redirect to the item show page (which has the embedded IIIF viewer).
    # NOTE: This is for the sake of old sites (explore.lib.virginia.edu) which
    # still have "hard-wired" links to the old page turner; for the time being,
    # it's easier to support a redirect than to fix those sites.
    if @document.is_iiif?
      redirect_to portal_show_path
      return
    end

    # Check to see if the current user is permitted to view this document.
    blocked, @access_label, @access_description = access_restricted(@document)
    if blocked
      render partial: 'catalog/access_denied', layout: layout_name
      return
    end

    pid = params[:id]
    # The id passed is the pid of the Fedora aggregation object (the book,
    # manuscript, etc. for which we want to display page images)
    @repository = @document.fedora_url
    # Get id of image to use for initial_page_pid.
    @exemplar_id = get_exemplar(@repository, pid)
    # Get list of pids for images belonging to this item.
    if @document.values_for(:digitized_item_pid_display).present?
      response = sparql_query_others_ead(@repository, pid)
      @images = get_pids_from_sparql(response)
      if @images.blank?
        response = sparql_query_others_ead(@repository, pid, false)
        @images = get_pids_from_sparql(response)
      end
    else
      response =
        sparql_query_others(
          @repository, pid, 'hasCatalogRecordIn',
          supp: 'dc:title', desc: 'dc:description'
        )
      @images = get_pids_from_sparql(response)
    end
    if @images.blank?
      title = @document.export_title
      notes = @document.values_for(:note_display).join('<br/>')
      @images = [{ pid: @exemplar_id, title: title, description: notes }]
    end
    render layout: 'page_turner'
  end

  # == GET /catalog/ID/iiif
  # Get the IIIF manifest.
  #
  def iiif
    id      = @document && @document.doc_id
    is_iiif = @document && @document.is_iiif?
    iiif_data, error = is_iiif && @document.iiif_metadata(params[:id])

    if !is_iiif
      logger.info { "#{__method__}: #{id}: #{error || 'non-IIIF document'}" }
      render text: user_message(:no_iiif), status: :not_found

    elsif iiif_data.blank?
      logger.warn { "#{__method__}: #{id}: #{error || 'no JSON data'}" }
      render text: user_message(:bad_iiif), status: :not_found

    elsif error
      logger.warn { "#{__method__}: #{id}: #{error}" }
      render json: iiif_data

    else
      logger.debug { "#{__method__}: #{id}: #{iiif_data.size} bytes" }
      render json: iiif_data

    end
  end

  # == GET /fedora_metadata/ID/PID.json
  # Emits JSON metadata for a Fedora object.
  #
  # === Usage Notes
  # - Invoked from app/assets/javascripts/feature/page-turner
  #
  def fedora_metadata
    url = @document.dl_jp2k_metadata(params[:pid])
    result = Net::HTTP.get_response(URI.parse(url))
    respond_to do |format|
      format.json { render json: result.body }
    end
  end

  # == GET /catalog/ID/children.json
  # JSON support (with XML for debugging) for the jstree plugin to present a
  # dynamic tree view of a hierarchical collection.
  #
  # A request parameter containing a node to be displayed may be included.
  #
  def hierarchy_children
    children, root = get_hierarchy_children(@document)
    node = @document.is_collection? ? root : children
    respond_to do |format|
      format.json { render json: node.to_json }
      format.xml  { render xml:  node.to_xml }
    end
  end

  # ===========================================================================
  # :section: Routes - Development
  # ===========================================================================

  public

  # == GET /catalog/direct?solr_parameters
  # For non-deployed-production settings, supply Solr parameters directly and
  # get back a display of the response.
  #
  # === Usage Notes
  # To use a request handler other than the default, add "qt=HANDLER_NAME" to
  # the query parameters used to invoke this route.
  #
  def direct
    @response, _docs = solr_request(params)
    respond_to do |format|
      format.html { render layout: true }
      format.rss  { render layout: false }
      format.xml  { render xml:  xml_response(@response) }
      format.json { render json: json_response(@response) }
    end
  end

  # ===========================================================================
  # :section: Filters
  # ===========================================================================

  protected

  # Toggle the state of the "Virgo Classic" lens basic on the presence of the
  # "classic" URL query parameter.
  #
  def adjust_for_classic
    return unless params.key?(:classic)
    if true_value?(params.delete(:classic))
      params[:controller] = 'classic'
    else
      session.delete(:classic)
    end
    will_redirect
  end

  # Permit Cross-Origin Resource Sharing to allow embeddable resources from
  # other sites.
  #
  # @return [void]
  #
  # === References
  # @see https://enable-cors.org
  #
  def set_cors_headers
    headers['Access-Control-Allow-Origin'] = '*'
  end

  # ===========================================================================
  # :section: Exception Handlers
  # ===========================================================================

  protected

  # Handler for RSolr::RequestError.
  #
  # Compare with
  # @see Blacklight::Catalog#rsolr_request_error
  #
  def rsolr_request_error
    if flash[:error] == user_message(:bad_request)
      # Server error - redirect loop.
      render template: 'public/500.html', layout: false, status: 500
    else
      # Set flash and direct.
      flash[:error] = user_message(:bad_request)
      redirect_to root_path, status: 400
    end
  end

  # Displays an error message when a bad id is selected.
  #
  # Compare with:
  # @see Blacklight::Catalog#invalid_solr_id_error
  #
  # === Usage Notes
  # This is set up by Blacklight::Catalog to handle a
  # Blacklight::Exceptions::InvalidSolrID exception.
  #
  def invalid_solr_id_error
    flash[:notice] = user_message(:bad_item)
    Rails.logger.info { 'REDIRECT from Blacklight due to InvalidSolrID' }
    redirect_to portal_index_path, status: 400
  end

  # ===========================================================================
  # :section:
  # ===========================================================================

  protected

  # index_layout
  #
  # @return [String]
  #
  def index_layout
    if combined_search_results?
      'combined'
    elsif home_page?
      'home'
    else
      'application'
    end
  end

  # Send HTML to cause the receiving browser tab to close.
  #
  # Used for temporary dialog pages that "dismiss" themselves if "Submit" was
  # successful.
  #
  # @return [ActiveSupport::SafeBuffer]
  #
  def render_close_window
    script = %q(<script type="text/javascript">close();</script>)
    render text: script.html_safe, layout: false
  end

  # Compose a flash message.
  #
  # @param [Array] args
  #
  # @return [String]
  #
  def user_message(*args)
    CatalogController.user_message(*args)
  end

  # ===========================================================================
  # :section: Class methods
  # ===========================================================================

  protected

  # Compose a flash message.
  #
  # @param [Array] args
  #
  # @return [String]
  #
  def self.user_message(*args)
    msg = args.shift
    msg = AccessIndexConcern::MESSAGE[msg] if msg.is_a?(Symbol)
    msg ? sprintf(msg, *args) : 'ERROR'
  end

  # rubocop:enable Metrics/ClassLength
end
