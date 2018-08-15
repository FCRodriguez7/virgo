# lib/uva/helper/action_responses.rb

require 'uva'

module UVA::Helper

  # UVA::Helper::ActionResponses
  #
  module ActionResponses

    include UVA
    include UVA::Util::Dev

    # =========================================================================
    # :section:
    # =========================================================================

    public

    # Display a flash message error and log an exception.
    #
    # This is intended for exception handlers and rescue blocks in the case
    # where a truly unexpected exception has stopped the flow of control.
    #
    # @param [String]    message
    # @param [Exception] e
    #
    # @return [nil]
    #
    def flash_alert(message, e = nil)
      if e.is_a?(Exception)
        # Log exception and call path within the application.
        Rails.logger.error {
          call_stack = UVA::Util::Dev.app_call_stack
          log_message = "ERROR (#{e.class}): #{e.message}"
          log_message << " in:\n#{call_stack}" if call_stack.present?
          log_message
        }
        # For desktop development, include the exception in the flash message.
        if Virgo.desktop_development?
          message += "<br/><br/>[#{e.class}: #{ERB::Util.h(e.message)}]"
          message = message.html_safe
        end
      end
      flash[:error] = message
      nil
    end

  end

end
