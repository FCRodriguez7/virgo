# app/controllers/account_requests_controller.rb

require 'uva'

# This controller supports the generation of requests by the current user:
#
# - Circulation requests are sent to the Sirsi/Dynix Unicorn OPAC via the
#   custom "Firehose" interface.
#
# - ILL requests result in redirects to ILLiad forms.
#
# @see LibraryPatronConcern
# @see IlliadPatronConcern
#
class AccountRequestsController < ApplicationController

  include LibraryPatronConcern
  include IlliadPatronConcern

  # Set to true to turn redirect hold/recall requests to an error message.
  #
  # @see app/views/account_requests/error.html.erb
  #
  DISABLE_RECALLS = false

  # ===========================================================================
  # :section: Filters
  # ===========================================================================

  # rubocop:disable Metrics/LineLength

  before_filter :notices_update
  before_filter :solr_lookup,            only:   [:start_hold, :create_hold, :ill_leo, :ill_ivy]
  before_filter :verify_account,         except: [:ill_leo, :ill_ivy]
  before_filter :verify_account_ill_leo, only:   [:ill_leo]
  before_filter :verify_account_ill_ivy, only:   [:ill_ivy]
  before_filter :verify_renew_request,   only:   [:renew]
  before_filter :verify_hold_request,    only:   [:start_hold, :create_hold]
  before_filter :disable_recalls,        only:   [:start_hold, :create_hold] if DISABLE_RECALLS

  # rubocop:enable Metrics/LineLength

  # ===========================================================================
  # :section: Exception Handlers
  # ===========================================================================

  rescue_from RenewError do |error|
    flash[:notice] = MESSAGE[:not_renewed] % error
    Rails.logger.info { "RENEW ERROR: #{error}" }
    redirect checkouts_accounts_path(path_opt)
  end

  rescue_from HoldError do |error|
    flash[:notice] = MESSAGE[:not_requested] % error
    Rails.logger.info { "HOLD ERROR: #{error}" }
    render 'error', layout: layout_name
  end

  rescue_from Blacklight::Exceptions::InvalidSolrID do |error|
    flash[:notice] = MESSAGE[:bad_item] % error
    Rails.logger.info { "REDIRECT due to #{error}" }
    redirect checkouts_accounts_path(path_opt)
  end

  rescue_from UVA::Exceptions::HiddenSolrID do |error|
    flash[:notice] = MESSAGE[:bad_item] % error
    Rails.logger.info { "REDIRECT due to #{error}" }
    redirect checkouts_accounts_path(path_opt)
  end

  # ===========================================================================
  # :section: Sirsi OPAC Requests
  # ===========================================================================

  public

  # == GET /account_requests/CATKEY/start_hold
  #
  def start_hold
    set_library_list
    render layout: layout_name
  end

  # == POST /account_requests/CATKEY/create_hold
  #
  def create_hold
    request_hold(current_user.login, params)
    render layout: layout_name
  end

  # == GET /account_requests/CATKEY/renew/CHECKOUT_KEY
  #
  def renew
    request_renew(current_user.login, params)
    redirect checkouts_accounts_path(path_opt)
  end

  # == GET /account_requests/renew_all
  #
  def renew_all
    request_renew_all(current_user.login, params)
    redirect checkouts_accounts_path(path_opt)
  end

  # ===========================================================================
  # :section: ILLiad Interlibrary Loan Requests
  # ===========================================================================

  public

  # == POST /account_requests/ill_main
  # Go to the ILLiad main page.
  #
  # If an ILLiad session has not already been established, render the view to
  # prompt for selection of an ILLiad; otherwise, go directly to the requested
  # page.
  #
  def ill_main
    illiad = get_illiad_session
    if illiad
      redirect illiad.base_url
    else
      render layout: layout_name
    end
  end

  # == POST /account_requests/ill_requests
  # Go to the ILLiad page for pending requests.
  #
  # If an ILLiad session has not already been established, render the view to
  # prompt for selection of an ILLiad; otherwise, go directly to the requested
  # page.
  #
  def ill_requests
    illiad = get_illiad_session
    if illiad
      redirect illiad.all_requests_url
    else
      render layout: layout_name
    end
  end

  # == GET /account_requests/ill_reset
  # Reset the selected ILLiad.
  #
  # Erase the ILLiad selection then prompt for a new selection.
  #
  def ill_reset
    clear_illiad_session
    render 'ill_main', layout: layout_name
  end

  # == GET  /account_requests/CATKEY/ill_leo
  # == POST /account_requests/CATKEY/ill_leo
  # Transition the client browser to ILLiad.
  #
  # If a selection has been provided then the link action is to redirect to the
  # ILLiad form URL associated with the requested item; if no selection has
  # been provided, render the associated view to prompt for a selection.
  #
  def ill_leo
    illiad = get_illiad_session(@document)
    if illiad
      redirect illiad.request_url
    else
      render layout: layout_name
    end
  end

  # == GET  /account_requests/CATKEY/ill_ivy
  # == POST /account_requests/CATKEY/ill_ivy
  # Transition the client browser to ILLiad.
  #
  # If a selection has been provided then the link action is to redirect to the
  # ILLiad form URL associated with the requested item; if no selection has
  # been provided, render the associated view to prompt for a selection.
  #
  def ill_ivy
    illiad = get_illiad_session(@document, :sid_ivy)
    if illiad
      redirect illiad.request_url
    else
      render layout: layout_name
    end
  end

end
