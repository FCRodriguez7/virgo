# lib/uva/helper/login_session.rb

require 'recaptcha'
require 'uva'

module UVA::Helper

  # UVA::Helper::LoginSession
  #
  module LoginSession

    include UVA
    include UVA::Helper::Layout
    include Recaptcha::Verify

    AUTHENTICATION_METHODS = [:netbadge, :sirsi].freeze

    # =========================================================================
    # :section:
    # =========================================================================

    public

    # Authentication type of the current session.
    #
    # @return [Symbol]                One of self#AUTHENTICATION_METHODS
    # @return [nil]                   Not authenticated.
    #
    def authentication_method
      session[:auth_method]
    end

    # Authentication type of the current session.
    #
    # @param [Symbol] type            One of self#AUTHENTICATION_METHODS
    #
    # @return [Symbol]                The value of *type*.
    # @return [nil]                   Not authenticated.
    #
    def set_authentication_method(type)
      if AUTHENTICATION_METHODS.include?(type)
        session[:auth_method] = type
      else
        Rails.logger.info {
          "#{__method__}: " \
          "#{type.inspect} not in #{AUTHENTICATION_METHODS.inspect}"
        }
        session.delete(:auth_method)
      end
    end

    # Indicate if the current user is logged in through a NetBadge session.
    #
    def netbadge_session?
      authentication_method == :netbadge
    end

    # Indicate whether the user has been verified -- either by logging-in or
    # via reCAPTCHA.
    #
    # @see self#logged_in?
    # @see Recaptcha::Verify#verify_recaptcha
    #
    def user_verified?
      netbadge_session? || verify_recaptcha(model: @post)
    end

    # =========================================================================
    # :section:
    # =========================================================================

    public

    # Returns true if the Virgo user is logged in by checking if there is a
    # login set in the session state.
    #
    # @param [User] user              Default: `current_user`.
    #
    def logged_in?(user = nil)
      user ||= current_user
      user && user.login.present?
    end

    # =========================================================================
    # :section:
    # =========================================================================

    public

    # A login prompt that can be displayed as a flash message, containing text
    # and buttons for UVa NetBadge and non-UVa patron logins.
    #
    # @param [String] redirect
    # @param [String] doc_id
    # @param [Hash]   opt             Passed to self#button
    #
    # @return [ActiveSupport::SafeBuffer]
    #
    def login_message(redirect = nil, doc_id = nil, opt = nil)
      lines = []
      if no_redirects?
        lines << 'You must be logged in for this request.'
      else
        redirect       = ("?redirect=#{redirect}" if redirect.present?)
        netbadge       = "#{login_path}#{redirect}"
        patron         = "#{patron_login_path}#{redirect}"
        sign_in        = button('sign in with NetBadge', netbadge, opt)
        patron_sign_in = button('non-UVA user', patron, opt)
        to_request     = (' to request this item' if doc_id.present?)
        lines << "Please #{sign_in}#{to_request}."
        lines << "Don't have a UVA account?  Sign in as a #{patron_sign_in}."
      end
      html_paragraphs(*lines)
    end

    # Produces the reCAPTCHA widget if the (anonymous) user needs to be
    # verified or a placeholder if the user is logged in with NetBadge.
    #
    # @return [ActiveSupport::SafeBuffer]
    #
    def recaptcha_widget
      verification =
        if netbadge_session?
          'Verified by NetBadge login.'
        elsif user_verified?
          'Verified.'
        end
      if verification
        content_tag(:div, verification, class: 'no-recaptcha')
      else
        recaptcha_tags(ssl: request.protocol.include?('https'))
      end
    end

    # =========================================================================
    # :section:
    # =========================================================================

    protected

    # Generate a link as a button.
    #
    # @param [String] label
    # @param [String] path
    # @param [Hash]   opt
    #
    # @return [ActiveSupport::SafeBuffer]
    #
    def button(label, path, opt = nil)
      html_opt = {
        class: 'btn small', # Show login links as buttons by default.
        role:  'button',
        rel:   'nofollow',  # Do not allow robots to follow login links.
      }
      html_opt.merge!(opt) if opt.present?
      ActionController::Base.helpers.link_to(label, path, html_opt)
    end

  end

end
