# app/controllers/application_controller.rb

require 'uva'

# This is the base class for controllers in this application.
#
# Filters added to this controller apply to all controllers in the application.
# Likewise, all the methods defined here will be available to all controllers.
#
# @see Blacklight::Controller
#
class ApplicationController < ActionController::Base

  include Blacklight::Controller

  include ActionResponsesConcern
  include DebugConcern
  include NetworkConcern

  include UVA::Util::DateMethods

  helper_method :user_session, :current_user

  # See ActionController::RequestForgeryProtection for details.
  protect_from_forgery except: [:change_engine]

  # Include the UVA constants in the compiled *.html.erb files.
  [UVA::Config, UVA::Util::TextConstants, UVA::View::Constants].each do |mod|
    next if ActionView::CompiledTemplates.include?(mod)
    ActionView::CompiledTemplates.send(:include, mod)
  end

  # ===========================================================================
  # :section:
  # ===========================================================================

  public

  # Messages displayed to the user by this controller.
  APP_MESSAGE = {
    err_eof:     'The Virgo server cannot contact required network services.',
    err_request: 'Please re-phrase your request (%s).',
    err_socket:  'The Virgo server is experiencing network problems (%s).',
  }.deep_freeze

  # Mapping of known types of ArgumentError with the flash message to display
  # to the user when it is encountered.
  KNOWN_ERRORS = {
    /invalid byte sequence/ => :err_request
  }.deep_freeze

  # ===========================================================================
  # :section: Filters
  # ===========================================================================

  before_filter :adjust_for_debug
  before_filter :adjust_for_forged_ip
  before_filter :controller_execution_marker if Virgo.desktop_development?

  # ===========================================================================
  # :section: Exception Handlers
  # ===========================================================================

  # Invoked when Virgo cannot reach Solr or other network services.
  #
  rescue_from EOFError do |exception|
    flash_alert(APP_MESSAGE[:err_eof], exception)
    render rescue redirect_to root_path
  end

  # Invoked when network DNS problems arise
  # (e.g. "getaddrinfo: Name or service not known")
  #
  rescue_from SocketError do |exception|
    flash_alert((APP_MESSAGE[:err_socket] % exception), exception)
    render rescue redirect_to root_path
  end

  # If invoked, checks for common issues that should be reported so that the
  # user can correct them (rather than getting a message which makes it appear
  # as if the server is at fault).  Unexpected exceptions are re-raised.
  #
  rescue_from ArgumentError do |exception|
    known_error =
      KNOWN_ERRORS.find do |pattern, error_type|
        break error_type if exception.message =~ pattern
      end
    raise exception unless known_error
    flash_alert((APP_MESSAGE[known_error] % exception), exception)
    redirect request.path
  end

  # ===========================================================================
  # :section:
  # ===========================================================================

  public

  # user_session
  #
  # @return [UserSession]
  # @return [nil]                     If the user is not logged in.
  #
  def user_session
    @current_user_session ||= UserSession.find
  end

  # current_user
  #
  # @return [User]
  # @return [nil]                     If the user is not logged in.
  #
  def current_user
    @current_user ||= user_session && user_session.record
  end

  # ===========================================================================
  # :section: Blacklight::Controller overrides
  # ===========================================================================

  protected

  # Local override to change what layout Blacklight controllers use.
  #
  # @return [String]
  #
  def layout_name
    'application'
  end

end
