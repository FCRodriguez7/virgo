# app/controllers/user_sessions_controller.rb

require 'uva'

# This controller supports the management of the user authorization through
# either NetBadge (Shibboleth) or Firehose (Sirsi/Dynix OPAC account).
#
# PubCookie will only be used to trigger the authentication server once.
# After the user successfully logs in, PubCookie will redirect back to the
# "new" action here.  Once we get the *REMOTE_USER* value from PubCookie
# (Apache) we set our own session value and never bother with PubCookie again.
#
# === Apache web server configuration
#
# In production, for the *:80* section of the configs, Apache should be set up
# to redirect */login* and */logout* to an SSL request.  Also, for the *:443*
# section of the config, */login* and */logout* should be set up to turn on
# and off NetBadge authentication. If these steps aren't in place, a temp
# account will be created.
#
# @example Apache configuration *:80* section
#
#   RewriteEngine On
#   RewriteLog  "/var/log/httpd/blacklight_rewrite_log"
#   RewriteLogLevel 2
#   RewriteCond %{HTTPS} != on
#   RewriteRule ^/login https://%{HTTP_HOST}/login [R=301,L]
#   RewriteRule ^/logout https://%{HTTP_HOST}/logout [R=301,L]
#
# @example Apache configuration *:443* section
#
#   <Location /login>
#     AuthType NetBadge
#     require valid-user
#     PubcookieAppId blacklight
#     PubcookieInactiveExpire -1
#   </Location>
#   <Location /logout>
#     PubcookieEndSession on
#   </Location>
#
# @see LoginSessionConcern
#
class UserSessionsController < ApplicationController

  include LoginSessionConcern
  include AccessArticlesConcern

  # ===========================================================================
  # :section: Filters
  # ===========================================================================

  before_filter :clear_session, only: [:new, :do_patron_login, :destroy]

  # ===========================================================================
  # :section:
  # ===========================================================================

  public

  # == GET /login
  # The standard login acquires the user ID from the session, PubCookie, or the
  # request parameters.  If none of those apply then temporary "demo" user is
  # created.
  #
  def new
    user = get_user_login
    redirect = begin_netbadge_session(user)
    redirect = root_path if redirect.blank?
    redirect_to redirect
  end

  # == POST /do_patron_login
  # The alternate login (for users without NetBadge) acquires the user ID from
  # the Sirsi account and performs authentication.
  #
  def do_patron_login
    user = get_patron_login
    if user.present?
      redirect = begin_sirsi_session(user)
      redirect = root_path if redirect.blank?
      redirect_to redirect
    end
  end

  # == GET /logout
  # Logs out the user; maintains the Special Collections lens, if applicable.
  #
  def destroy
    get_logout
    redirect = end_login_session
    redirect = root_path if redirect.blank?
    redirect_to redirect
  end

  # == GET /patron_login
  # Dispatches to patron login.
  #
  def patron_login
  end

  # == GET /logged_out
  # Dummy method so that we can dispatch to a logged out page.
  #
  def logged_out
  end

  # ===========================================================================
  # :section: Filters
  # ===========================================================================

  protected

  # Prepare for a fresh user session.
  #
  # @return [void]
  #
  def clear_session
    stop_article_session
    clear_forged_ip
  end

end
