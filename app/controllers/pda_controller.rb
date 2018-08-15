# app/controllers/pda_controller.rb

require 'uva'

# This controller is the user-facing portion of "Patron Driven Acquisitions"
# (PDA) -- otherwise known as the "Available-to-Order" service.
#
# @see PdaPurchaseConcern
#
class PdaController < ApplicationController

  include LibraryPatronConcern
  include IlliadPatronConcern
  include PdaPurchaseConcern

  # ===========================================================================
  # :section: Filters
  # ===========================================================================

  before_filter :validate_user, only: [:confirm, :purchase]
  before_filter :notices_update
  before_filter :solr_lookup

  # ===========================================================================
  # :section:
  # ===========================================================================

  public

  # == GET /pda/CATKEY/confirm
  #
  def confirm
    render layout: layout_name unless flash[:error]
  end

  # == POST /pda/CATKEY/purchase
  #
  def purchase
    message = place_purchase_order
    notices_update(true)
    flash[:notice] = message
    redirect catalog_path(params[:id]), path_opt
  end

end
