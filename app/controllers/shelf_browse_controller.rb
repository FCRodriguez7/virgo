# app/controllers/shelf_browse_controller.rb

require 'uva'

# This controller implements "virtual shelf browse", a.k.a.
# "call number browse".
#
class ShelfBrowseController < ApplicationController

  include ShelfBrowseHelper

  # ===========================================================================
  # :section:
  # ===========================================================================

  public

  # == GET /shelf_browse[?options]
  # Display the "shelf browse lens" main page.
  #
  # @see UVA::Helper::ShelfBrowse#get_virtual_shelf_window
  #
  def index
    opt = params.reverse_merge(base: request.path, offset: :left)
    @document_list = get_virtual_shelf_window(nil, opt)
    request.parameters[:width] = @document_list.length
    respond_to do |format|
      format.html { render layout: layout_name }
      format.xml  { render xml:  xml_response(@document_list) }
      format.json { render json: json_response(@document_list) }
    end
  end

  # == GET /shelf_browse/CATKEY[?options]
  # Display shelf browse popup
  #
  # @option params [Boolean] :popup
  #
  # @see UVA::Helper::ShelfBrowse#get_virtual_shelf_window
  #
  def show
    id = params[:id]
    id = params[:article_id] if id == 'article'
    opt = params.reverse_merge(base: request.path, offset: :center)
    @document_list = get_virtual_shelf_window(id, opt)
    request.parameters[:width] = @document_list.length
    respond_to do |format|
      format.html { render layout: layout_name }
      format.xml  { render xml:  xml_response(@document_list) }
      format.json { render json: json_response(@document_list) }
    end
  end

  # == GET /shelf_browse/hierarchy[?options]
  # Get the LCC hierarchy.  With no options, the entire hierarchy is returned
  # as a root node with descendants which are the LC class subtrees.
  #
  # @option params [String] :class      Get this LC class and descendants.
  # @option params [String] :subclass   Get this LC subclass and descendants.
  # @option params [String] :range      Get this LC range and descendants.
  #
  # @see UVA::Helper::ShelfBrowse#get_lcc_hierarchy
  #
  # === Usage Notes
  # The normal response is JSON, since this route supports the JavaScript
  # function makeLccTree().  The HTML response is for testing only; it is not
  # actually used in the shelf browse display.
  #
  # === Implementation Notes
  # If the LCC tree were to be made into a standalone control, some additional
  # work would have to be done to the CSS and JavaScript to support this.
  #
  def hierarchy
    @tree = get_lcc_hierarchy(params)
    respond_to do |format|
      format.html { render layout: 'wide' } unless Virgo.deployed_production?
      format.json { render json: get_jstree(@tree) }
      format.xml  { render xml:  @tree.to_xml(params) }
    end
  end

  # ===========================================================================
  # :section: Blacklight::Controller Overrides
  # ===========================================================================

  protected

  # Overrides ApplicationController#layout_name to change layout based on
  # whether the destination is a popup or a web page.
  #
  # @return [false]                   If `popup` is *true*.
  # @return [String]                  Otherwise.
  #
  def layout_name
    in_popup? ? false : 'wide'
  end

end
