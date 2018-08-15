# app/controllers/concerns/access_articles_concern.rb

require 'active_support/concern'
require 'uva'

# Support for controller actions involving article search.
#
# @see UVA::Helper::Articles
#
module AccessArticlesConcern

  extend ActiveSupport::Concern

  include AccessAnyConcern
  include LoginSessionConcern

  include UVA::Helper::Articles
  include UVA::Helper::AdvancedSearch

  # Code to be added to the including controller class definition.
  included do
    [Blacklight::Configurable, AdvancedHelper].each do |mod|
      next if include?(mod)
      console_output(
        "AccessArticlesConcern causing #{self} to include #{mod}"
      ) if DEBUG_INCLUDE
      include mod
    end
  end

  # ===========================================================================
  # :section:
  # ===========================================================================

  public

  # Calls setup_previous_article then setup_next_article.
  # Used in the details action for single view pagination.
  #
  # @return [void]
  #
  # @see self#setup_previous_article
  # @see self#setup_next_article
  #
  # Compare with:
  # @see AccessIndexConcern#setup_next_and_previous_documents
  #
  def setup_next_and_previous_articles
    counter = search_session[:counter].to_i
    total   = search_session[:total].to_i
    setup_previous_article(counter, total)
    setup_next_article(counter, total)
  end

  # Context for previous article in search results.
  #
  # @param [Fixnum] counter         Search result position of the current item.
  # @param [Fixnum] total           Total in search result set.
  #
  # @return [UVA::ArticleDoc]
  # @return [nil]
  #
  # @see self#setup_article_by_counter
  #
  # Compare with:
  # @see AccessIndexConcern#setup_previous_document
  #
  def setup_previous_article(counter = nil, total = nil)
    counter = (counter || search_session[:counter]).to_i
    unused(total)
    @previous_article =
      if counter > 1
        setup_article_by_counter(counter - 1)
      end
  end

  # Context for next article in search results.
  #
  # @param [Fixnum] counter         Search result position of the current item.
  # @param [Fixnum] total           Total in search result set.
  #
  # @return [UVA::ArticleDoc]
  # @return [nil]
  #
  # @see self#setup_article_by_counter
  #
  # Compare with:
  # @see AccessIndexConcern#setup_next_document
  #
  def setup_next_article(counter = nil, total = nil)
    counter = (counter || search_session[:counter]).to_i
    total   = (total   || search_session[:total]).to_i
    @next_article =
      if (0 < counter) && (counter < total)
        setup_article_by_counter(counter + 1)
      end
  end

  # ===========================================================================
  # :section:
  # ===========================================================================

  protected

  # Gets an article based on its position within a results set.
  #
  # @param [Fixnum] counter
  #
  # @return [UVA::ArticleDoc]
  # @return [nil]
  #
  # Compare with:
  # @see AccessIndexConcern#setup_document_by_counter
  #
  def setup_article_by_counter(counter)
    return if (counter.to_i < 1) || search_session.blank?
    get_article_by_index(counter, search_session)
  end

  # ===========================================================================
  # :section:
  # ===========================================================================

  public

  # get_article_facets
  #
  # @param [String] facet_field
  #
  # @return [Array<UVA::Article::FacetItem>]
  #
  def get_article_facets(facet_field)
    facet_field = facet_field.to_s
    list = @response.facets.find { |f| f.name == facet_field }
    (list && list.items) || []
  end

  # Populates the "LIMIT RESULTS BY" menus on Articles Advanced Search.
  #
  # Compare with:
  # @see UVA::Solr#get_solr_advanced_search_facets
  # @see BlacklightAdvancedSearch::AdvancedController#get_advanced_search_facets
  #
  def get_article_advanced_search_facets

    # Get "facet-only" article results -- this method doesn't care about the
    # returned documents, only the facets in the response.
    url_params = advanced_search_context.rdup.with_indifferent_access
    response, _ = get_article_results(url_params)

    # Ignore facets that aren't configured to be displayed on the advanced
    # search form.
    # TODO: Is there a way to request limited facet results like with Solr?
    adv_facets = (advanced_facets if response.ok?)
    response.facets.keep_if { |f| adv_facets.include?(f.name) } if adv_facets
    response

  end

  # ===========================================================================
  # :section: Filters
  # ===========================================================================

  public

  # Force a new EBSCO session if `params[:new_session]` is true.
  #
  # @return [void]
  #
  # @see UVA::Helper::Articles#restart_article_session
  #
  def adjust_for_new_session
    return unless params.key?(:new_session)
    new_session = params.delete(:new_session)
    if true_value?(new_session)
      restart_article_session
    else
      Rails.logger.warn("#{__method__}: new_session = #{new_session.inspect}")
    end
    will_redirect
  end

  # The policy is to perform searches on peer-reviewed articles by default
  # unless the user has explicitly requested general searches by removing the
  # Designation "Peer Reviewed" limiter.
  #
  # @return [void]
  #
  def adjust_for_peer_reviewed
    if params.key?(:peer_reviewed)
      session[:peer_reviewed] = true_value?(params.delete(:peer_reviewed))
    elsif home_page? || !session.key?(:peer_reviewed)
      session[:peer_reviewed] = true
    end
    will_redirect if adjust_tlevel!
  end

  # Updates the @articles array for the current object.
  #
  # @param [Array] args
  #
  # @return [Array<UVA::ArticleDoc>]  The new contents of @articles.
  #
  def set_articles(*args)
    args << params[:article_id] if args.empty?
    ids = args.flatten.join(',').split(',').reject(&:blank?).uniq.presence
    @article_response, @articles = ids && get_article_results(ids)
    @articles = Array(@articles).compact
  end

  # Updates @document with the article associated with the given id.
  #
  # This method is used to retrieve an article by its id within the article
  # provider (Primo's or Ebsco's, etc. article id for the article).
  #
  # @see UVA::Helper::Articles#get_article_results
  #
  def get_article
    id = params[:id]
    if id.blank?
      respond_to do |format|
        format.json do
          message = { 'ERROR' => 'No id given', 'params' => params }
          render json: message, status: 400
        end
      end
    else
      @response, @document = get_article_results(id)
      @document = @document.first if @document.is_a?(Array)
    end
  end

  # Updates @document_list with article entries as directed by URL parameters
  # and saves the search session for the current portal.
  #
  # @param [Hash] url_params          Default: `params`.
  #
  # @return [Array<UVA::ArticleDoc::Response, Array<UVA::ArticleDoc>>]
  #
  # @see UVA::Helper::Articles#get_article_results
  #
  def get_document_list(url_params = nil)

    url_params ||= params

    # Adjust query and get search results.
    update_query!(url_params)
    @response, @document_list = get_article_results(url_params)
    @document_list = [@document_list] unless @document_list.is_a?(Array)
    @document_list.compact!

    # Update search session values.
    save_current_search(url_params, @response) unless print_view? || rss_view?

    return @response, @document_list
  end

end
