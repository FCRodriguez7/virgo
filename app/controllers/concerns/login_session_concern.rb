# app/controllers/concerns/login_session_concern.rb

require 'active_support/concern'
require 'uva'
require 'firehose'

# Support for controller actions involving access and management of
# authenticated login sessions.
#
# @see UVA::Helper::LoginSession
#
module LoginSessionConcern

  extend ActiveSupport::Concern

  include UVA
  include UVA::Administration
  include UVA::Helper::LoginSession

  include Firehose::Patron

  # ===========================================================================
  # :section:
  # ===========================================================================

  public

  # Messages displayed to the user by this feature.
  MESSAGE = {
    bad_auth:      'Incorrect user or pin',
    bad_db:        'The system failed to retrieve the User database record.',
    bad_id:        'Invalid patron ID "<strong>%s</strong>" at character %d.',
    bad_session:   'The system failed to create a UserSession.',
    bad_recaptcha: %q(You must check "I'm not a robot".),
  }.deep_freeze

  # ===========================================================================
  # :section:
  # ===========================================================================

  public

  # Get the user associated with the current session.
  #
  # @param [String] user_id
  #
  # @return [User]
  # @return [nil]
  #
  # === Implementation Notes
  # If `session[:login]` is not present, check for the request parameters
  # `params[:login]` or `params[:user]`, then check for the 'REMOTE_USER'
  # environment variable (supplied by the application launcher).
  #
  def get_user_login(user_id = nil)
    if user_id
      # User identity supplied directly to the method.
      logger.info { %Q(User "#{user_id}" set by #{__method__}.) }
      ::User.find_or_create_by_login(user_id)

    elsif (user_id = session[:login])
      # Use the current user ID from the session if it exists.
      logger.info { %Q(User "#{user_id}" already logged via session.) }
      ::User.find_by_login(user_id)

    elsif (user_id = (params[:login] || params[:user])) && login_param_allowed?
      # Developer login with "/login?login=user_id" or "/login?user=user_id".
      auth = request.env['REMOTE_USER']
      auth = auth ? %Q("#{auth}") : "(#{Rails.env})"
      logger.info { %Q(User #{auth} logging in as user "#{user_id}".) }
      ::User.find_or_create_by_login(user_id)

    elsif (user_id = request.env['REMOTE_USER'])
      # Request coming from PubCookie; get the user ID from REMOTE_USER.
      logger.info { %Q(User "#{user_id}" login.) }
      ::User.find_or_create_by_login(user_id)

    else
      # Otherwise, create a temp/demo user for this session.
      user_id = "demo_#{::User.count}"
      logger.info { %Q(User "#{user_id}" created.) }
      ::User.create(login: user_id)
    end
  end

  # Get the user associated with the current session.
  #
  # @param [String] patron_id
  # @param [String] patron_pin
  #
  # @return [User]
  # @return [nil]
  #
  # === Implementation Notes
  # If `session[:login]` is not present, check for the request parameters
  # `params[:login]` or `params[:user]`.
  #
  def get_patron_login(patron_id = nil, patron_pin = nil)

    patron_id  ||= params[:login] || params[:user]
    patron_pin ||= params[:pin]

    if (bad_char = patron_id_invalid(patron_id)).nonzero?
      # Supplied patron ID does not look like a valid Sirsi account.
      logger.info { %Q(User "#{patron_id}" patron account invalid.) }
      flash[:error] = (MESSAGE[:bad_id] % [patron_id, bad_char]).html_safe
      redirect_to patron_login_path
      nil

    elsif (patron = get_patron(patron_id)).nil?
      # Supplied patron ID is not a valid Sirsi account.
      logger.info { %Q(User "#{patron_id}" patron account not found.) }
      flash[:error] = MESSAGE[:bad_auth]
      redirect_to patron_login_path
      nil

    elsif !check_pin(patron, patron_pin)
      # Supplied PIN was not validated by Sirsi.
      logger.info { %Q(User "#{patron_id}" patron authentication failure.) }
      flash[:error] = MESSAGE[:bad_auth]
      redirect_to patron_login_path
      nil

    elsif (old_id = session[:login])
      # Existing user changing identity to a new patron ID.
      logger.info { %Q(User "#{old_id}" logging in as patron "#{patron_id}".) }
      ::User.find_by_login(patron_id)

    else
      # Supplied patron ID is used as the session user identity.
      logger.info { %Q(User "#{patron_id}" patron login.) }
      ::User.find_or_create_by_login(patron_id)
    end
  end

  # get_logout
  #
  # @return [User]                    The current user.
  # @return [nil]                     If there is no login session active.
  #
  def get_logout
    current_user.tap do |user|
      logger.info {
        user_id = user ? user.login : 'anonymous'
        %Q(User "#{user_id}" logout.)
      }
    end
  end

  # Creates a session for the user and returns a link to redirect to the
  # originating page.
  #
  # @param [User]   user              Current user.
  # @param [String] redirect          Optional redirect path.
  #
  # @return [String]
  # @return [nil]                     If *user* is not valid.
  #
  def begin_netbadge_session(user, redirect = nil)
    begin_login_session(user, redirect, :netbadge)
  end

  # Creates a session for the user and returns a link to redirect to the
  # originating page.
  #
  # @param [User]   user              Current user.
  # @param [String] redirect          Optional redirect path.
  #
  # @return [String]
  # @return [nil]                     If *user* is not valid.
  #
  def begin_sirsi_session(user, redirect = nil)
    begin_login_session(user, redirect, :sirsi)
  end

  # Creates a session for the user and returns a link to redirect to the
  # originating page.
  #
  # If no *redirect* is given, the request parameters :redirect, :referrer and
  # :referer will be used; if none of those are present `request.referer` will
  # be used.  Regardless of the mechanism, if the redirect contains a relative
  # or absolute path, that will be used directly.
  #
  # @param [User]   user              Current user.
  # @param [String] redirect          Optional redirect path.
  # @param [Symbol] auth_method       Type of user authentication.
  #
  # @return [String]
  # @return [nil]                     If *user* is not valid.
  #
  def begin_login_session(user, redirect = nil, auth_method = nil)
    if !user.is_a?(User)
      flash[:error] = MESSAGE[:bad_db]
    elsif !(@user_session = UserSession.create(user, true))
      flash[:error] = MESSAGE[:bad_session]
    else
      session[:login] = user.login
      set_authentication_method(auth_method)
    end
    if redirect.blank? && params.present?
      redirect = params[:redirect] || params[:referer] || params[:referrer]
    end
    if redirect.blank? && request.present?
      redirect = request.referer
    end
    #--
    # rubocop:disable Metrics/LineLength
    #++
    case redirect
      when nil                         then root_path(search_session)
      when 'account'                   then accounts_path
      when 'checkouts'                 then checkouts_accounts_path
      when 'ill_leo'                   then ill_leo_path(params[:id])
      when 'ill_ivy'                   then ill_ivy_path(params[:id])
      when 'maps'                      then maps_path
      when 'recall'                    then start_hold_account_request_path(params[:id])
      when 'reserve_request'           then reserves_email_path
      when 'special_collections_admin' then special_collections_requests_path
      when 'special_collections_user'  then new_special_collections_request_path(id: params[:id], qt: 'document')
      when %r{^(\w+://|/)}             then redirect
      else                                  "/#{redirect}"
    end
    #--
    # rubocop:enable Metrics/LineLength
    #++
  end

  # Ends the session and returns a link to redirect to the logged-out page.
  #
  # @return [ActiveSupport::SafeBuffer]
  #
  def end_login_session
    in_special_collections = session[:special_collections]
    reset_session
    user_session.destroy if user_session
    session[:special_collections] = true if in_special_collections
    logged_out_url
  end

  # ===========================================================================
  # :section:
  # ===========================================================================

  protected

  # Indicate whether the "?login=computing_id" parameter is to be honored.
  #
  # @param [String] user_id           The (intended) current user.
  #
  def login_param_allowed?(user_id = nil)
    Virgo.desktop? || test_user?(user_id)
  end

  # Indicate whether the user is a test user (who is allowed to specify a
  # login name).
  #
  # @param [String] user_id           The (intended) current user.
  #
  def test_user?(user_id = nil)
    user_id ||= current_user && current_user.login
    user_id ||= request.env['REMOTE_USER']
    user_is_admin?(user_id)
  end

  # Returns the position of the first bad character of an invalid patron ID,
  # where 1 is the first character and 0 indicates that the ID was not invalid.
  #
  # @param [String] patron_id
  #
  # @return [Numeric]
  #
  def patron_id_invalid(patron_id)
    pos = patron_id.to_s.index(/[^a-z0-9_-]/i)
    pos ? (pos + 1) : 0
  end

  # ===========================================================================
  # :section: Filters
  # ===========================================================================

  public

  # Do Recaptcha check before allowing email to be sent out.
  #
  # @return [nil]
  # @return [String] - If a problem was encountered.
  #
  def recaptcha_check
    return if user_verified?
    flash[:error] = MESSAGE[:bad_recaptcha]
    redirect_to :back
  end

end
