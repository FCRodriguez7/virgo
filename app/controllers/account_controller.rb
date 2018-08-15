# app/controllers/account_controller.rb

require 'uva'

# This controller provides information about the current user's patron account
# status in the Sirsi/Dynix Unicorn OPAC via the custom "Firehose" interface.
#
# @see LibraryPatronConcern
#
class AccountController < ApplicationController

  include LibraryPatronConcern

  # ===========================================================================
  # :section: Filters
  # ===========================================================================

  before_filter :verify_login, except: [:renew, :review, :select]
  before_filter :notices_update

  # ===========================================================================
  # :section:
  # ===========================================================================

  public

  # == GET /account
  #
  def index
    set_patron or auth_error_response
  end

  # == GET /account/checkouts
  #
  def checkouts
    set_checkouts or auth_error_response
  end

  # == GET /account/holds
  #
  def holds
    set_holds or auth_error_response
  end

  # == GET /account/reserves
  #
  def reserves
    set_reserves or auth_error_response
  end

  # == GET /account/notices
  #
  def notices
    set_notices or auth_error_response
  end

  # == GET /account/not_found
  #
  def not_found
  end

  # == GET /account/renew
  #
  def renew
    if current_user
      redirect_to checkouts_accounts_path
    else
      redirect_to select_accounts_path(redirect: 'checkouts')
    end
  end

  # == GET /account/review
  #
  def review
    if current_user
      redirect_to accounts_path
    else
      redirect_to select_accounts_path(redirect: 'account')
    end
  end

  # == GET /account/select
  #
  def select
  end

  # ===========================================================================
  # :section:
  # ===========================================================================

  protected

  # Display an error message on the originating page.
  #
  # @param [String, Symbol] _message  Not currently used.
  #
  # @return [ActiveSupport::SafeBuffer]
  #
  def auth_error_response(_message = nil)
    respond_to do |format|
      format.html do
        render :not_found
      end
    end
  end
end
