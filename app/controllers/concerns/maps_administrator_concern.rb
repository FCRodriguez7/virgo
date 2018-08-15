# app/controllers/concerns/maps_administrator_concern.rb

require 'active_support/concern'
require 'uva'

# Support for controller actions involving maintenance of stacks maps (Maps,
# MapsUsers, and CallNumberRanges).
#
# @see Map
# @see MapsUser
# @see CallNumberRange
#
module MapsAdministratorConcern

  extend ActiveSupport::Concern

  include UVA

  # Code to be added to the including controller class definition.
  included do
    before_filter :verify_map_user
  end

  # ===========================================================================
  # :section:
  # ===========================================================================

  public

  # Messages displayed to the user by this feature.
  MESSAGE = {
    no_auth:
      'You are not authorized to manage maps.',
    no_user:
      'You must be logged in to manage maps. ' \
      '<a href="/login?redirect=maps">Log in</a>'.html_safe,
    map: {
      created:     'Map successfully created.',
      deleted:     'Map "%s" removed.',
      updated:     'Map successfully updated.',
      not_created: 'Map "%s" could not be created.',
      not_deleted: 'Map "%s" could not be removed.',
      not_found:   'Map "%s" not found.',
      not_updated: 'Map "%s" could not be updated.',
    },
    maps_user: {
      created:     'Maps user successfully created.',
      deleted:     'Maps user "%s" removed.',
      not_created: 'Maps user could not be created.',
      not_deleted: 'Maps user "%s" could not be removed.',
      not_found:   'Maps user "%s" not found.',
    },
    call_number_range: {
      created:     'Entry successfully saved',
      deleted:     'Entry "%s" removed.',
      not_created: 'Could not save entry.',
      not_deleted: 'Entry "%s" could not be removed.',
      not_found:   'Entry "%s" not found.',
    },
  }.deep_freeze

  # ===========================================================================
  # :section: Maps
  # ===========================================================================

  public

  # set_maps
  #
  # @return [void]
  #
  def set_maps
    @maps = Map.joins(:library).order('name, description')
  end

  # new_map
  #
  # @param [String] map_id
  #
  # @return [Map]
  # @return [nil]
  #
  def new_map(map_id = nil)
    if map_id.blank?
      @map = Map.new
    else
      @map = Map.new(map_id)
      @map && @map.save
    end
  end

  # load_map
  #
  # @param [String] map_id
  #
  # @return [Map]
  # @return [nil]
  #
  def load_map(map_id)
    @map = Map.find(map_id)
  rescue ActiveRecord::RecordNotFound
    @map = nil
  end

  # update_map
  #
  # @param [String] map_id
  # @param [Hash]   attributes
  #
  # @return [Symbol]                  One of :updated, :not_updated, or
  #                                     :not_found.
  #
  def update_map(map_id, attributes)
    map_id     ||= params[:id]
    attributes ||= params[:map]
    map = load_map(map_id)
    if !map
      :not_found
    elsif map.update_attributes(attributes)
      :updated
    else
      :not_updated
    end
  end

  # delete_map
  #
  # @param [String] map_id
  #
  # @return [Symbol]                  One of :deleted, :not_deleted, or
  #                                     :not_found.
  #
  def delete_map(map_id)
    map_id ||= params[:id]
    map = load_map(map_id)
    if !map
      :not_found
    elsif map.destroy
      :deleted
    else
      :not_deleted
    end
  end

  # ===========================================================================
  # :section: MapsUsers
  # ===========================================================================

  public

  # set_maps_users
  #
  # @return [void]
  #
  def set_maps_users
    @maps_users = MapsUser.all
  end

  # new_maps_user
  #
  # @param [String] user_id
  #
  # @return [Map]
  # @return [nil]
  #
  def new_maps_user(user_id = nil)
    if user_id.blank?
      @maps_user = MapsUser.new
    else
      @maps_user = MapsUser.new(user_id)
      @maps_user && @maps_user.save
    end
  end

  # load_maps_user
  #
  # @param [String] user_id
  #
  # @return [MapsUser]
  # @return [nil]
  #
  def load_maps_user(user_id)
    @maps_user = MapsUser.find(user_id)
  rescue ActiveRecord::RecordNotFound
    @maps_user = nil
  end

  # delete_maps_user
  #
  # @param [String] user_id
  #
  # @return [Symbol]                  One of :deleted, :not_deleted, or
  #                                     :not_found.
  #
  def delete_maps_user(user_id)
    user_id ||= params[:id]
    maps_user = load_maps_user(user_id)
    if !maps_user
      :not_found
    elsif maps_user.destroy
      :deleted
    else
      :not_deleted
    end
  end

  # ===========================================================================
  # :section: CallNumberRanges
  # ===========================================================================

  public

  # new_call_number_range
  #
  # @param [String] range_id
  # @param [String] location
  # @param [String] map_id
  #
  # @return [CallNumberRange]
  # @return [nil]
  #
  def new_call_number_range(range_id = nil, location = nil, map_id = nil)
    if range_id.blank?
      @call_number_range = CallNumberRange.new
    else
      @call_number_range = CallNumberRange.new(user_id)
      @call_number_range && @call_number_range.save
    end
  end

  # load_call_number_range
  #
  # @param [String] range_id
  #
  # @return [CallNumberRange]
  # @return [nil]
  #
  def load_call_number_range(range_id)
    @call_number_range = CallNumberRange.find(range_id)
  rescue ActiveRecord::RecordNotFound
    @call_number_range = nil
  end

  # delete_call_number_range
  #
  # @param [String] range_id
  #
  # @return [Symbol]                  One of :deleted, :not_deleted, or
  #                                     :not_found.
  #
  def delete_call_number_range(range_id)
    call_number_range = load_call_number_range(range_id)
    if !call_number_range
      :not_found
    elsif call_number_range.destroy
      :deleted
    else
      :not_deleted
    end
  end

  # ===========================================================================
  # :section: Filters
  # ===========================================================================

  public

  # Ensures that the current user is allowed to administer maps.
  #
  # @return [nil]                        If the user is authorized.
  # @return [ActiveSupport::SafeBuffer]  If the user is not authorized.
  #
  def verify_map_user
    if !current_user
      error = :no_user
    elsif !MapsUser.find_by_computing_id(current_user[:login])
      error = :no_auth
    else
      return
    end
    flash[:error] = MESSAGE[error]
    redirect_to root_path
  end

end
