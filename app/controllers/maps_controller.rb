# app/controllers/maps_controller.rb

require 'uva'

# This controller supports management of the *maps* table by authorized users.
#
# A map is just a description and URL for a map.
# Maps controller is only used by map administrators for creating map guides.
#
# @see MapsAdministratorConcern
# @see Map
#
# @see MapsUsersController
#
class MapsController < ApplicationController

  include MapsAdministratorConcern

  # ===========================================================================
  # :section:
  # ===========================================================================

  public

  # == GET /maps
  # List all of the maps.
  #
  def index
    set_maps
  end

  # == GET /maps/new
  # Start a new map.
  #
  def new
    new_map
  end

  # == POST /maps
  # Create a new map.
  #
  def create
    map_id = params[:map]
    saved  = new_map(map_id)
    respond_to do |format|
      format.html do
        if saved
          flash[:notice] = MESSAGE[:map][:created] % map_id
          redirect_to maps_path
        else
          flash[:error]  = MESSAGE[:map][:not_created] % map_id
          render action: 'new'
        end
      end
    end
  end

  # == GET /maps/ID/edit
  # Edit a map.
  #
  def edit
    map_id = params[:id]
    map    = load_map(map_id)
    flash[:error] = MESSAGE[:map][:not_found] % map_id unless map
  end

  # === UPDATE /maps/ID
  # Update a map.
  #
  def update

    # Get the database record and update it with the new information.
    map_id = params[:id]
    status = update_map(map_id, params[:map])

    # Direct to a new page if successful; go back to the edit page if not.
    respond_to do |format|
      format.html do
        if status == :updated
          flash[:notice] = MESSAGE[:map][status] % map_id
          redirect_to maps_path
        else
          flash[:error] = MESSAGE[:map][status] % map_id
          render action: 'edit'
        end
      end
    end

  end

  # == DELETE /maps/ID
  # Delete a map.
  #
  def destroy
    map_id = params[:id]
    status = delete_map(map_id)
    respond_to do |format|
      format.html do
        if status == :deleted
          flash[:notice] = MESSAGE[:map][status] % map_id
        else
          flash[:error] = MESSAGE[:map][status] % map_id
        end
        redirect_to maps_path
      end
    end
  end

end
