# app/controllers/call_number_ranges_controller.rb

require 'uva'

# This controller supports management of the *call_number_ranges* table by
# authorized users.
#
# @see MapsAdministratorConcern
# @see CallNumberRange
#
class CallNumberRangesController < ApplicationController

  include MapsAdministratorConcern

  # ===========================================================================
  # :section:
  # ===========================================================================

  public

  # == POST /call_number_ranges/create
  #
  # Add a call number range.
  #
  def create
    saved = new_call_number_range(params[:call_number_range])
    respond_to do |format|
      format.html do
        if saved
          flash[:notice] = MESSAGE[:call_number_range][:created]
        else
          flash[:error]  = MESSAGE[:call_number_range][:not_created]
        end
        redirect_to(maps_path)
      end
    end

  end

  # == DELETE /call_number_ranges
  #
  # Remove a call number range.
  #
  def destroy
    id     = params[:id]
    status = delete_call_number_range(id)
    respond_to do |format|
      format.html do
        if status == :deleted
          flash[:notice] = MESSAGE[:call_number_range][status] % id
        else
          flash[:error]  = MESSAGE[:call_number_range][status] % id
        end
        redirect_to(maps_path)
      end
    end

  end

end
