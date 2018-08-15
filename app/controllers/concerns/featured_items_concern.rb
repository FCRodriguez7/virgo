# app/controllers/concerns/featured_items_concern.rb

require 'active_support/concern'
require 'uva'

# Support for controller actions involving the setup of "feature item" displays
# for the "music lens" and "video lens".
#
# @see UVA::Helper::FeaturedItems
#
# @see MusicController
# @see VideoController
#
module FeaturedItemsConcern

  extend ActiveSupport::Concern

  include UVA
  include UVA::Scope
  include UVA::Helper::FeaturedItems

  # Hints for RubyMine (skipped during execution).
  include UVA::Solr unless ONLY_FOR_DOCUMENTATION

  # ===========================================================================
  # :section:
  # ===========================================================================

  public

  DEF_FEATURED_ITEM_TOTAL = 20
  DEF_MAX_ATTEMPTS        = 4
  DEF_ONLY_WITH_COVERS    = false
  DEF_RANDOM_ORDER        = false

  # ===========================================================================
  # :section:
  # ===========================================================================

  public

  # Solr search filters to select featured items.
  #
  # @return [Hash]
  #
  # @note Must be overridden by the controller class including this module.
  #
  def selection_filters
    {}
  end

  # Number of items to display.
  #
  # @return [Fixnum]
  #
  # @note May be overridden by the controller class including this module.
  #
  def featured_item_total
    DEF_FEATURED_ITEM_TOTAL
  end

  # Indicate whether only items with cover images should be shown.
  #
  # @note May be overridden by the controller class including this module.
  #
  def only_with_covers?
    DEF_ONLY_WITH_COVERS
  end

  # Indicate whether items should be shown in random order.
  #
  # @note May be overridden by the controller class including this module.
  #
  def randomize?
    DEF_RANDOM_ORDER
  end

  # Number of items to retrieve from Solr per request.
  #
  # @return [Fixnum]
  #
  # @note May be overridden by the controller class including this module.
  #
  def page_size
    result = featured_item_total
    result *= 2 if only_with_covers?
    result
  end

  # Maximum number of Solr search requests to make to get featured documents.
  #
  # @return [Fixnum]
  #
  # @note May be overridden by the controller class including this module.
  #
  def max_attempts
    DEF_MAX_ATTEMPTS
  end

  # ===========================================================================
  # :section: Filters
  # ===========================================================================

  public

  # Overrides the index action for the home page of the lens to get featured
  # documents in addition to performing a search so that facet values can be
  # acquired.
  #
  # @param [Hash] url_params          Default: `params`.
  #
  # @return [Array<(RSolr::Ext::Response::Base, Array<SolrDocument>)>]
  #
  # @see self#load_featured_documents
  # @see AccessIndexConcern#get_document_list
  #
  def get_document_list(url_params = nil)
    load_featured_documents if portal_home_page?
    super
  end

  # Gets cover images for featured documents.
  #
  # @return [void]
  #
  # === Implementation Notes
  # If #only_with_covers? is *true* then #get_featured_documents will be run
  # as many times as necessary (up to #max_attempts times) to get the requested
  # number of items (#featured_item_total).
  #
  def load_featured_documents
    return unless facetless? && params[:q].blank? && !advanced_search_results?
    docs = []
    page = 0
    while ((featured_item_total - docs.size) > 0) && (page < max_attempts)
      page += 1
      current_set = get_featured_documents(page)
      break if current_set.empty?
      docs += current_set
    end
    docs.sort_by { rand } if randomize?
    @featured_documents = docs.first(featured_item_total)
  end

  # ===========================================================================
  # :section: Filters
  # ===========================================================================

  protected

  # Retrieves documents from Solr.
  #
  # @param [Fixnum] page              Page of Solr results to request.
  #
  # @return [void]
  #
  def get_featured_documents(page = nil)
    page ||= 1
    _response, document_list =
      get_search_results(
        page:     page,
        per_page: page_size,
        f:        selection_filters,
        qt:       'search',
        fl:       %w(id format_facet library_facet video_genre_facet),
        sort_key: date_received_sort_key,
      )
    document_list ||= []
    document_list.keep_if(&:has_image?) if only_with_covers?
    document_list
  end

end
