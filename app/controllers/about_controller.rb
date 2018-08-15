# app/controllers/about_controller.rb

require 'uva'

# This controller provides information about the nature of this application,
# along with additional runtime information for privileged users.
#
# @see LoginSessionConcern
#
class AboutController < ApplicationController

  include LibraryPatronConcern

  # ===========================================================================
  # :section:
  # ===========================================================================

  public

  # == GET /about
  #
  def index
    @can_view_about = user_has_about_access?
  end

  # == GET /about/list/TOPIC
  # Display an informational listing on a given subject.
  #
  # == GET /about/list/library
  # == GET /about/list/libraries
  #
  def list
    @topic = params[:topic].to_s.singularize.downcase.presence
    @topic &&= @topic.to_sym

    @topic_list =
      case @topic
        when :library  then Firehose::Libraries.get_library_list
        when :location then Firehose::Locations.get_location_list
      end

    respond_to do |format|
      format.html { render }
      format.xml  { render xml:  xml_response(@topic_list) }
      format.json { render json: json_response(@topic_list) }
    end
  end

  # ===========================================================================
  # :section:
  # ===========================================================================

  protected

  # Indicate whether the user is authorized to view additional "About"
  # information.
  #
  # @param [String] user_id
  #
  # @see AboutController#index
  # @see UserSessionsController#test_user?
  #
  def user_has_about_access?(user_id = nil)
    user_is_admin?(user_id) || admin_lookup('about', user_id).present?
  end

end
