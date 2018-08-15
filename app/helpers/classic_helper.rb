# app/helpers/classic_helper.rb

require 'uva'

# Definitions to support "Virgo Classic" lens view templates.
#
# @see ArticlesController
#
module ClassicHelper

  include CatalogHelper
  include UVA::Classic

  # ===========================================================================
  # :section:
  # ===========================================================================

  public

  CLASSIC_CLOSE_BUTTON_LABEL   = '&utrif;CLOSE'.html_safe.freeze
  CLASSIC_CLOSE_BUTTON_TOOLTIP = 'Click to close these details.'.freeze

  # ===========================================================================
  # :section:
  # ===========================================================================

  public

  # browse_mode_label
  #
  # @param [String, Symbol] mode      Browse search mode.
  #
  # @return [String]
  # @return [nil]
  #
  def browse_mode_label(mode = nil)
    UVA::Classic.browse_mode_label(mode || params[:browse_mode])
  end

  # browse_mode_facet
  #
  # @param [String, Symbol] mode      Browse search mode.
  #
  # @return [String]
  # @return [nil]
  #
  def browse_mode_facet(mode = nil)
    UVA::Classic.browse_mode_facet(mode || params[:browse_mode])
  end

  # ===========================================================================
  # :section: Blacklight::CatalogHelperBehavior overrides
  # ===========================================================================

  public

  # For Kaminari paginate.
  PageScope = Struct.new(:current_page, :num_pages, :limit_value)

  # Pass in an RSolr::Response (or duck-typed similar) object,
  # it translates to a Kaminari-paginatable
  # object, with the keys Kaminari views expect.
  #
  # @param [RSolr::Ext::Response::Base] response
  #
  # @return [Struct]
  #
  def paginate_params(response)

    per_page = (response && response.rows).to_i
    per_page = get_current_per_page.to_i if per_page < 1

    start_page = (response && response.start).to_i
    start_page = nil if start_page < 1

    current_page = 1
    current_page += (start_page / per_page).ceil if start_page

    hits = response && hit_count(response)
    page_count = hits ? (hits / per_page.to_f).ceil : 0

    PageScope.new(current_page, page_count, per_page)

  end

  # ===========================================================================
  # :section: Item details (show page)
  # ===========================================================================

  public

  # Floating "close" button for item details show page panel.
  #
  # @param [String] which           CSS class "top" or "bottom"
  # @param [String] label           Default: self#CLASSIC_CLOSE_BUTTON_LABEL
  # @param [String] tip             Default: self#CLASSIC_CLOSE_BUTTON_TOOLTIP
  #
  # @return [ActiveSupport::SafeBuffer]
  #
  def classic_details_close_button(which, label = nil, tip = nil)
    opt = {
      title:    (tip || CLASSIC_CLOSE_BUTTON_TOOLTIP),
      class:    "item-toggle btn small #{which.to_s.downcase}".squish,
      role:     'button',
      tabindex: 0,
    }
    content_tag(:div, (label || CLASSIC_CLOSE_BUTTON_LABEL), opt)
  end

end
