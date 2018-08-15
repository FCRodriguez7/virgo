# app/controllers/concerns/debug_concern.rb

require 'active_support/concern'
require 'uva'

# Support for actions supporting development.
#
# @see UVA::Util::Dev
#
module DebugConcern

  extend ActiveSupport::Concern

  include UVA
  include UVA::Administration
  include UVA::Util::Dev

  # ===========================================================================
  # :section: Filters
  # ===========================================================================

  public

  # Toggle the debugging in the session.
  #
  # To avoid inadvertent activation, the parameter will only be honored for a
  # session associated with an authenticated administrator.
  #
  # @return [void]
  #
  # @see UVA::Administration#user_is_admin?
  #
  def adjust_for_debug
    return unless params.key?(:virgo_debug) && user_is_admin?
    session[:virgo_debug] = true_value?(params.delete(:virgo_debug))
    redirect_to params
  end

  # Make a log entry when the controller is entered.
  #
  # @return [void]
  #
  def controller_execution_marker
    console_output {
      "\n>>> CONTROLLER #{controller_name} - params = #{params.inspect}"
    } if DEBUG_INCLUDE
  end

end
