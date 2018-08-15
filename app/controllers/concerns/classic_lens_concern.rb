# app/controllers/concerns/classic_lens_concern.rb

require 'active_support/concern'
require 'uva'

# Support for controller actions involving the "Virgo Classic" lens.
#
# @see UVA::Classic
#
module ClassicLensConcern

  extend ActiveSupport::Concern

  include UVA
  include UVA::Classic

  # ===========================================================================
  # :section:
  # ===========================================================================

  public

  # Messages displayed to the user by this feature.
  MESSAGE = {
    no_browse_mode:  'No browse mode indicated.',
    no_search_terms: 'No search terms given.',
  }.deep_freeze

  # ===========================================================================
  # :section:
  # ===========================================================================

  public

  # get_classic_facets
  #
  # @param [String, Symbol] browse_mode
  # @param [Hash]           url_params    Default: `params`.
  #
  # @return [Array<(RSolr::Ext::Response::Base, Array<RSolr::Ext::Response::Facets::FacetItem>)>]
  #
  def get_classic_facets(browse_mode, url_params = nil)
    get_browse_facets(browse_mode, url_params)
  end

  # ===========================================================================
  # :section: Filters
  # ===========================================================================

  public

  # Overrides the index action for the home page of the lens since no search is
  # performed in that case.
  #
  # @param [Hash] url_params          Default: `params`.
  #
  # @return [Array<(RSolr::Ext::Response::Base, Array<SolrDocument>)>]
  # @return [nil]                     If on the main page of the lens.
  #
  # @see AccessIndexConcern#get_document_list
  #
  def get_document_list(url_params = nil)
    super unless portal_home_page?
  end

  # Toggle the state of the "Virgo Classic" lens basic on the presence of the
  # "classic" URL query parameter.
  #
  def adjust_for_classic
    return unless params.key?(:classic)
    if false_value?(params.delete(:classic))
      params[:controller] = 'catalog'
    else
      session[:classic] = true
    end
    will_redirect
  end

end
