# app/controllers/maps_users_controller.rb

require 'uva'

# This controller supports management of the *maps_users* table by authorized
# users.
#
# Maps users are the users who are allowed to administer maps.
#
# @see MapsAdministratorConcern
# @see MapsUser
#
# @see MapsController
#
class MapsUsersController < ApplicationController

  include MapsAdministratorConcern

  # ===========================================================================
  # :section:
  # ===========================================================================

  public

  # == GET /maps_users
  # List the map users.
  #
  def index
    set_maps_users
  end

  # == GET /maps_users/new
  # Start a new map user.
  #
  def new
    new_maps_user
  end

  # == POST /maps_users
  # Create a new map user.
  #
  def create
    user = params[:maps_user]
    saved  = new_maps_user(user)

    respond_to do |format|
      format.html do
        if saved
          flash[:notice] = MESSAGE[:maps_user][:created]
          redirect_to maps_users_path
        else
          flash[:error] = MESSAGE[:maps_user][:not_created]
          render action: 'new'
        end
      end
    end

  end

  # == DELETE /maps_users/ID
  # Delete a map user.
  #
  def destroy
    user_id = params[:id]
    user    = load_maps_user(user_id)
    status =
      if !user
        :not_found
      elsif user.destroy
        :deleted
      else
        :not_deleted
      end
    respond_to do |format|
      format.html do
        if status == :deleted
          flash[:notice] = MESSAGE[:maps_user][status] % user_id
        else
          flash[:error] = MESSAGE[:maps_user][status] % user_id
        end
        redirect_to maps_users_path
      end
    end
  end

end
