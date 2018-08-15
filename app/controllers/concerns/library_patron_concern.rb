# app/controllers/concerns/library_patron_concern.rb

require 'active_support/concern'
require 'uva'
require 'firehose'

# Support for controller actions involving access and management of Sirsi OPAC
# patron accounts and library circulation.
#
# @see UVA::Helper::LoginSession
# @see Firehose
#
module LibraryPatronConcern

  extend ActiveSupport::Concern

  include AccessIndexConcern
  include LoginSessionConcern
  include RequestsConcern

  include Firehose
  include Firehose::Libraries
  include Firehose::Patron
  include Firehose::Checkouts
  include Firehose::Holds
  include Firehose::Reserves

  # ===========================================================================
  # :section:
  # ===========================================================================

  public

  # Messages displayed to the user by this feature.
  MESSAGE = {
    already_have:   'The selected item is already checked out to you.',
    bad_item:       'Sorry, there was a problem: %s.',
    no_info:        'Catalog information for this item could not be retrieved',
    cant_renew:     'The selected item is not eligible for renewal.',
    cant_request:   'The selected item is not eligible for holds or recalls.',
    renewed_all:    'Items successfully renewed.',
    renewed_item:   'Item successfully renewed.',
    requested_item: 'Item successfully requested.',
    not_renewed:    'Sorry, there was a problem: %s.',
    not_requested:  'Sorry, there was a problem: %s.',
    login:          'Please log in to access your account.',
  }.deep_freeze

  # ===========================================================================
  # :section:
  # ===========================================================================

  public

  # set_patron
  #
  # @param [String] user              E.g. `current_user.login`
  #
  # @return [Firehose::Patron]
  # @return [nil]
  #
  def set_patron(user = nil)
    user ||= current_user.login
    @account = get_patron(user)
  end

  # set_checkouts
  #
  # @param [String] user              E.g. `current_user.login`
  #
  # @return [Firehose::User]
  # @return [nil]
  #
  def set_checkouts(user = nil)
    user ||= current_user.login
    @user_checkouts = get_checkouts(user)
  end

  # set_holds
  #
  # @param [String] user              E.g. `current_user.login`
  #
  # @return [Firehose::User]
  # @return [nil]
  #
  def set_holds(user = nil)
    user ||= current_user.login
    @user_holds = get_holds(user)
  end

  # set_reserves
  #
  # @param [String] user              E.g. `current_user.login`
  #
  # @return [Firehose::User]
  # @return [nil]
  #
  def set_reserves(user = nil)
    user ||= current_user.login
    @user_reserves = get_reserves(user)
  end

  # set_notices
  #
  # @param [String] user              E.g. `current_user.login`
  #
  # @return [Firehose::User]
  # @return [nil]
  #
  def set_notices(user = nil)
    set_checkouts(user)
  end

  # set_library_list
  #
  # @return [Firehose::LibraryList]
  # @return [nil]
  #
  def set_library_list
    @library_list = get_library_list
  end

  # request_hold
  #
  # @param [String] user              By default, uses `current_user.login`
  # @param [Hash]   opt               By default, uses `params`.
  #
  # @return [String]
  #
  # @raise [Firehose::HoldError]
  #
  def request_hold(user = nil, opt = nil)
    user ||= current_user.login
    opt  ||= params
    place_hold(user, opt[:id], opt[:library_id], opt[:call_number])
  end

  # request_renew
  #
  # @param [String] user              By default, uses `current_user.login`
  # @param [Hash]   opt               By default, uses `params`.
  #
  # @return [String]
  #
  # @raise [Firehose::RenewError]
  #
  def request_renew(user = nil, opt = nil)
    user ||= current_user.login
    opt  ||= params
    do_renew(user, opt[:checkout_key])
    notices_update(true)
    flash[:notice] = MESSAGE[:renewed_item]
  end

  # request_renew_all
  #
  # @param [String] user              By default, uses `current_user.login`
  # @param [Hash]   _opt              E.g. `params`. (ignored)
  #
  def request_renew_all(user = nil, _opt = nil)
    user ||= current_user.login
    do_renew_all(user)
    notices_update(true)
    flash[:notice] = MESSAGE[:renewed_all]
  end

  # ===========================================================================
  # :section: Filters
  # ===========================================================================

  public

  # verify_login
  #
  # @return [void]
  #
  def verify_login
    unless current_user
      flash[:error] = MESSAGE[:login]
      redirect catalog_index_path(path_opt)
    end
  end

  # notices_update
  #
  # @param [Boolean] force_update
  #
  # @return [Fixnum]                  Number of notices for the user.
  #
  def notices_update(force_update = false)
    unless force_update
      expiration = session[:notices_expiration]
      return if expiration && (Time.current < expiration)
    end
    user = current_user && get_patron(current_user.login)
    return unless user.present?
    half_hour = 1800
    session[:notices_expiration] = half_hour.seconds.from_now
    session[:notices_count]      = user.overdue_count + user.recalled_count
  end

  # ===========================================================================
  # :section: Filters
  # ===========================================================================

  public

  # solr_lookup
  #
  # @return [void]
  #
  # @raise [InvalidSolrID]            If no results were returned.
  # @raise [HiddenSolrID]             If the initial result document is hidden.
  #
  # @see UVA::Solr#get_solr_response_for_doc_id
  #
  def solr_lookup
    opt = params.dup
    id = opt.delete(:id)
    opt[:raise] = true unless opt.key?(:raise)
    @response, @document = get_solr_response_for_doc_id(id, opt)
  end

  # verify_renew_request
  #
  # @return [void]
  #
  def verify_renew_request
    key = params[:checkout_key]
    selected = @account.checkouts.select { |checkout| checkout.key == key }
    if selected.empty?
      flash[:error] = MESSAGE[:cant_renew]
      redirect checkouts_accounts_path(path_opt)
    end
  end

  # verify_hold_request
  #
  # @return [void]
  #
  def verify_hold_request
    number       = params[:call_number]
    availability = @document && @document.availability
    error =
      if !availability
        :no_info
      elsif !availability.might_be_holdable?
        availability.holdability_error
      elsif number.present? && !availability.has_holdable_holding?(number)
        :cant_request
      elsif availability.user_has_checked_out?(@account, number)
        :already_have
      end
    if error
      flash[:error] = error.is_a?(Symbol) ? MESSAGE[error] : error.to_s
      render_flash_only
    end
  end

  # verify_account
  #
  # @return [void]
  #
  def verify_account
    do_verify_account
  end

  # verify_account_ill_leo
  #
  # To support Sirsi iLink request links, account verification is not performed
  # if the route has URL parameter "illiad_selection=???" where "???" matches
  # one of `UVA::Illiad#CONFIGURATION.keys`.
  #
  # @return [void]
  #
  def verify_account_ill_leo
    do_verify_account(:ill_leo) unless params[:illiad_selection].present?
  end

  # verify_account_ill_ivy
  #
  # To support Sirsi iLink request links, account verification is not performed
  # if the route has URL parameter "illiad_selection=???" where "???" matches
  # one of `UVA::Illiad#CONFIGURATION.keys`.
  #
  # @return [void]
  #
  def verify_account_ill_ivy
    do_verify_account(:ill_ivy) unless params[:illiad_selection].present?
  end

  # Verify login and account status.
  #
  # If the user is logged in account status is verified; otherwise, a flash
  # message is displayed with convenience sign-on buttons in place which will
  # redirect after login back to the calling feature.
  #
  # @param [Symbol, String] caller    Name of the calling feature.
  #
  # @return [void]
  #
  def do_verify_account(caller = nil)

    caller ||= :recall
    doc_id = params[:id].presence
    error_page = error_message = nil

    if current_user.nil?
      # The user is not logged in.  Construct a flash message containing
      # sign-on buttons that redirect to the original route intercepted by the
      # filter.
      redirect      = doc_id && "#{caller}&id=#{doc_id}"
      error_message = login_message(redirect, doc_id)
    elsif (@account = get_patron(current_user.login)).nil?
      error_page = 'account/not_found'
    elsif @account.barred?
      error_page = 'account/barred'
    end

    if error_page
      Rails.logger.info { "#{__method__}(#{caller}): #{error_page}" }
      render error_page, layout: layout_name
    elsif error_message
      flash[:error] = error_message
      path =
        if doc_id
          catalog_path(doc_id, path_opt.except(:popup))
        else
          root_path
        end
      redirect(path)
    end

  end

  # Disable the ability to make recall requests.
  #
  # @return [void]
  #
  def disable_recalls
    @disable_recalls = true
    render_flash_only
  end

end
