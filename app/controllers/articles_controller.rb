# app/controllers/articles_controller.rb

require 'uva'

# This controller supports article search-and-discovery via the web API to the
# article search provider service.
#
# @see AccessArticlesConcern
#
class ArticlesController < ApplicationController

  include AccessArticlesConcern

  extend BlacklightConfigConcern

  # ===========================================================================
  # :section: Blacklight Configuration
  # ===========================================================================

  public

  # === Facets
  # The order here defines the order in which facets are displayed in the
  # search results sidebar.
  EBSCO_FACETS = {
    tlevel:            ['Designation',         advanced: false], # [1]
    PublicationYear:   ['Year',                advanced: false],
    SourceType:        ['Source Type',         advanced: true],
    SubjectEDS:        ['Subject',             advanced: false],
    Journal:           ['Journal',             advanced: false],
    Publisher:         ['Publisher',           advanced: true],
    Language:          ['Language',            advanced: true],
    SubjectGeographic: ['Geographic Location', advanced: true],
    ContentProvider:   ['Content Provider',    advanced: true],
    #
    # NOTE:
    # [1] "Peer reviewed" is handled as a checkbox on advanced search.
    #
  }.deep_freeze

  PRIMO_FACETS = {
    creationdate: 'Year',
    rtype:        'Format',
    creator:      'Author',
    topic:        'Subject',
    jtitle:       'Journal',
    lang:         'Language',
  }.deep_freeze

  SUMMON_FACETS = {
    PublicationDate:  'Year',
    ContentType:      'Format',
    Author:           'Author',
    SubjectTerms:     'Subject',
    PublicationTitle: 'Journal',
    Keywords:         'Keyword',
  }.deep_freeze

  ARTICLE_FACETS = {}.tap { |facets|
    facets.merge!(EBSCO_FACETS)
    if UVA::Article.switching_enabled?
      facets.merge!(PRIMO_FACETS)
      facets.merge!(SUMMON_FACETS)
    end
  }.deep_freeze

  # === Search fields
  # The order here defines the order in which search fields are displayed on
  # the advanced search form.
  ARTICLE_SEARCH_FIELDS = {
    # rubocop:disable Metrics/LineLength
    author:           ['Author',         facet: 'creator',      advanced: true],
    title:            ['Title',          facet: 'title',        advanced: true],
    journal:          ['Journal Title',  facet: 'jtitle',       advanced: true],
    subject:          ['Subject',        facet: 'sub',          advanced: true],
    keyword:          ['Keyword',        facet: 'any',          advanced: true],
    issn:             ['ISSN',           facet: 'issn',         advanced: true],
    publication_date: ['Date Published', facet: 'creationdate', advanced: true, range: true],
    # rubocop:enable Metrics/LineLength
  }.deep_freeze

  # === Sort fields
  # The order here defines the order in which sort field selections are
  # displayed in the drop-down "Sort by" menu on search results pages.
  ARTICLE_SORT_FIELDS = {
    articles_relevancy: ['Relevancy', sort: ''],
    articles_date:      ['Date',      sort: 'scdate'],
  }.deep_freeze

  # ===========================================================================
  # :section: Blacklight Configuration
  #
  # @see Blacklight::Configurable::ClassMethods#configure_blacklight
  # @see Blacklight::Configuration::Fields#add_solr_field
  # ===========================================================================

  configure_blacklight do |config|
    configure_facets(config, ARTICLE_FACETS)
    configure_search_fields(config, ARTICLE_SEARCH_FIELDS)
    configure_sort_fields(config, ARTICLE_SORT_FIELDS)
  end

  # ===========================================================================
  # :section: Filters
  # ===========================================================================

  # rubocop:disable Metrics/LineLength

  # Actions that might result in a redirect or might modify the session.

  before_filter :adjust_for_new_session
  before_filter :update_show_page_context,  only: [:update]
  before_filter :adjust_for_search_context, only: [:show, :full_text]
  before_filter :adjust_for_full_view,      only: [:show]
  before_filter :adjust_for_peer_reviewed,  only: [:index]
  before_filter :validate_advanced,         only: [:index]
  before_filter :resolve_sort,              only: [:index]
  before_filter :cleanup_parameters,        only: [:index]
  before_filter :conditional_redirect

  # Actions involved in data acquisition (and might result in an exception).

  before_filter :get_document_list,         only: [:index, :facet]
  before_filter :get_article,               only: [:show, :full_text]

  # rubocop:enable Metrics/LineLength

  # ===========================================================================
  # :section: Routes
  # ===========================================================================

  public

  # == GET /articles
  # Get search results from the article search provider.
  #
  # === Usage Notes
  # Invoked from loadArticles() in app/assets/javascripts/feature/shelf-browse
  #
  def index
    respond_to do |format|
      format.html { render 'catalog/index' }
      format.rss  { render 'catalog/index', layout: false }
      format.xml  { render xml:  xml_response(@response) }
      format.json { render json: json_response(@response) }
    end
  end

  # == GET /articles/article
  # Get a single article from the article search provider.
  #
  def show
    respond_to do |format|
      format.html { setup_next_and_previous_articles }
      format.xml  { render xml:  xml_response(@document) }
      format.json { render json: json_response(@document) }
    end
  end

  # == PUT /articles/article
  # Adds search context to the show page to support display of the count and
  # total ("Item N of M"), and "Previous" and "Next" links).
  #
  # === Usage Notes
  # @see app/assets/javascripts/feature/search-context
  #
  # === Implementation Notes
  # This method handles additional search context information for the case of
  # article details show page links from the combined search results page.
  #
  # @see self#update_show_page_context
  # @see AccessAnyConcern#conditional_redirect
  #
  def update
  end

  # == GET /articles/facet/ID
  #
  def facet
    id = params[:id]
    @facet_list = get_article_facets(id)
    respond_to do |format|
      format.html { render 'catalog/facet', layout: 'popup' }
      format.json { render json: json_response(@facet_list) }
      format.xml {
        render xml: xml_response(@facet_list, recursive: true, root: id)
      }
    end
  end

  # == GET /articles/advanced
  #
  def advanced
    @response = get_article_advanced_search_facets
    render 'advanced/index'
  end

  # ===========================================================================
  # :section: Routes - Citation Export
  # ===========================================================================

  public

  # == GET /articles/citation?id=:id
  # == GET /articles/citation?article_id=:id
  #
  def citation
    id = params[:id] || params[:article_id]
    redirect_to citation_catalog_path(path_opt.merge(article_id: id))
  end

  # == GET /articles/endnote?id=:id
  # == GET /articles/endnote?article_id=:id
  #
  def endnote
    id = params[:id] || params[:article_id]
    redirect_to endnote_catalog_path(article_id: id)
  end

  # == GET /articles/ris?id=:id
  # == GET /articles/ris?article_id=:id
  #
  def ris
    id = params[:id] || params[:article_id]
    redirect_to ris_catalog_path(article_id: id)
  end

  # ===========================================================================
  # :section: Routes - Articles
  # ===========================================================================

  public

  # == POST /articles/change_engine
  #
  # @see UVA::Helper::Articles#article_engine
  # @see app/assets/javascripts/feature/articles
  #
  def change_engine
    article_engine(params && params[:new_ae])
    head :ok # Render nothing
  end

  # == GET /articles/full_text
  # Displays article full-text in a dedicated browser tab without a scroller.
  #
  def full_text
    respond_to do |format|
      format.html
      format.xml { render xml: @document.download_text_to_xml }
    end
  end

  # ===========================================================================
  # :section: Routes - Development
  # ===========================================================================

  public

  # == GET /articles/direct
  # For non-deployed-production settings, supply EBSCO EDS parameters directly.
  # If responding with XML or JSON, the contents of the EBSCO response message
  # is returned.
  #
  def direct
    params[:EDS_direct] = true
    get_document_list
    respond_to do |format|
      format.html { render layout: true }
      format.xml  { render xml:  xml_response(@response) }
      format.json { render json: json_response(@response) }
    end
  end

  # ===========================================================================
  # :section: Filters
  # ===========================================================================

  protected

  # update_show_page_context
  #
  # @param [String, Hash] redirect_path
  #
  # @return [void]
  #
  # @see AccessAnyConcern#update_show_page_context
  #
  def update_show_page_context(redirect_path = nil)
    redirect_path ||=
      if URI.parse(request.url).fragment == 'full-text'
        { action: 'full_text', id: params[:id] }
      end
    super(redirect_path)
  end

end
