# app/controllers/concerns/special_collections_concern.rb

require 'active_support/concern'
require 'ipaddr'
require 'uva'

# Support for controller actions involving access to the Special Collections
# request queue.
#
# @see UVA::Helper::SpecialCollections
#
module SpecialCollectionsConcern

  extend ActiveSupport::Concern

  include LibraryPatronConcern

  include UVA
  include UVA::Helper::SpecialCollections

  # ===========================================================================
  # :section:
  # ===========================================================================

  public

  # Configuration file listing subnets from which clients may view the
  # Special Collections work queue.
  SC_SUBNETS = 'config/special_collections_subnets.yml'.freeze

  # Messages displayed to the user by this feature.
  MESSAGE = {
    created:
      'Request successfully submitted.',
    bad_item:
      'Sorry, there was a problem: %s.',
    no_admin_auth:
      'You are not authorized to manage Special Collections Requests.',
    no_admin_user:
      'Please %s to manage Special Collections Requests.',
    no_items:
      'You must select at least one item.',
    no_netbadge:
      'UVA members should use NetBadge to authenticate.',
    no_patron:
      'Unable to locate your patron record.  ' +
        'Please verify your login information and try again.',
    no_patron_info:
      'There is something wrong with your patron record.  ' +
        'Please have a librarian verify your library account.',
    no_req:
      'Could not locate the record for this request.',
    no_user:
      'You must log in before making a request.',
    not_created:
      'An error occurred; your request was not submitted.',
    not_updated:
      'A database error occurred; your request was not updated.',
    req_error:
      'A probable one-time network error corrupted your request.  ' +
        'Please try again and report if the problem persists.',
    updated:
      'Request successfully updated.',
    ip_restricted:
      'Please make your request from the Special Collections Library.',
  }.deep_freeze

  # ===========================================================================
  # :section:
  # ===========================================================================

  public

  # Get all requests in the Special Collections request queue.
  #
  # @return [Array<SpecialCollectionsRequest>]
  #
  def get_requests
    session[:sc_search] = params

    @sc_requests = SpecialCollectionsRequest.scoped

    # Determine the date range to display, silently correcting date inversion.
    @start_date = make_date(params[:start])
    @end_date   = make_date(params[:end])
    @start_date, @end_date = [@start_date, @end_date].sort

    # Get matching requests from the database table and get the information
    # for each of their requested items.
    start_time = @start_date
    end_time   = @end_date + 1.day
    @sc_requests = @sc_requests.where(created_at: start_time..end_time)

    doc_id = params[:doc_id]
    @sc_requests = @sc_requests.where(document_id: doc_id) if doc_id.present?

    user_id = params[:user_id]
    @sc_requests = @sc_requests.where(user_id: user_id) if user_id.present?

    instructional = params[:instructional_queue]
    if instructional.present?
      case instructional
        when 'Hide'
          @sc_requests = @sc_requests.where(is_instructional: false)
        when 'Only'
          @sc_requests = @sc_requests.where(is_instructional: true)
      end
    else
      # default to hidden sc_requests
      @sc_requests = @sc_requests.where(is_instructional: false)
    end

    @sc_requests =
      @sc_requests.paginate(page: params[:page], per_page: 50).order('id desc')

    @sc_requests.each do |r|
      _response, doc = get_solr_document(r.document_id, {})
      r.document = doc
    end

  end

  # initialize_request
  #
  # @param [String] id                Document id.
  #
  # @return [SolrDocument]
  #
  # @raise [InvalidSolrID]            If no results were returned.
  # @raise [HiddenSolrID]             If the initial result document is hidden.
  #
  def initialize_request(id)
    _response, doc = get_solr_document(id)
    @sc_request.document = doc
  end

  # create_request
  #
  # @return [Symbol]                  One of :created, :not_created, or
  #                                     :no_items.
  #
  def create_request
    if @sc_request.special_collections_request_items.empty?
      :no_items
    elsif @sc_request.save
      session.delete(:non_uva_login)
      :created
    else
      logger.warn {
        issue =
          if params.blank?
            'empty params'
          elsif request.blank?
            'missing params[:special_collections_request]'
          elsif params[:location_plus_call_number].blank?
            'missing params[:location_plus_call_number]'
          else
            'unexpected error'
          end
        "#{__method__}: #{issue}"
      }
      :not_created
    end
  end

  # update_request
  #
  # @param [String] req_id
  # @param [Hash]   attributes
  #
  # @return [Symbol]                  One of :updated, :not_updated, or
  #                                     :not_found.
  #
  def update_request(req_id, attributes)
    req_id     ||= params[:id]
    attributes ||= params[:special_collections_request]
    req = load_request(req_id)
    if !req
      :not_found
    elsif req.update_attributes(attributes)
      :updated
    else
      :not_updated
    end
  end

  # load_request
  #
  # @param [String] id
  # @param [Hash]   opt               Options to ActiveRecord::Base#find.
  #
  # @return [CallNumberRange]
  # @return [nil]
  #
  def load_request(id, opt = {})
    @sc_request = SpecialCollectionsRequest.find(id, opt)
  rescue ActiveRecord::RecordNotFound
    @sc_request = nil
  end

  # ===========================================================================
  # :section: Filters
  # ===========================================================================

  public

  # Verify that the current user is a Special Collections administrator.
  #
  # @params [User] user               By default, `current_user`.
  #
  # @return [void]
  #
  def verify_admin(user = nil)
    user ||= current_user
    if !user.is_a?(User)
      message = MESSAGE[:no_admin_user] % login_link
    elsif !user_is_admin?(user.login) && !sc_admin?(user)
      message = MESSAGE[:no_admin_auth]
    else # User verified.
      return
    end
    flash[:error] = message.html_safe
    redirect catalog_index_path(path_opt)
  end

  # Skip login if the user is already logged in.
  #
  # @params [String] doc_id           By default, from `params[:id]`.
  #
  # @return [void]
  #
  def bypass_login(id = nil)
    return unless current_user && current_user.login
    id ||= params && params[:id]
    redirect new_special_collections_request_path(id, path_opt)
  end

  # Generate a new Special Collections request based on the id in the params.
  #
  # @params [String] doc_id           By default, from `params[:id]`.
  #
  # @return [void]
  #
  def new_request(id = nil)
    id ||= params && params[:id]
    @sc_request = SpecialCollectionsRequest.new
    @sc_request.document_id = id
  end

  # Build out a request from the params.
  #
  # @params [String] req              `params[:special_collections_request]`.
  # @params [String] loc              `params[:location_plus_call_number]`.
  #
  # @return [void]
  #
  def build_request(req = nil, loc = nil)
    req ||= params && params[:special_collections_request]
    loc ||= params && params[:location_plus_call_number]
    @sc_request = SpecialCollectionsRequest.new(req)
    @sc_request.build(loc)
  end

  # Ensure that there is a user id present.
  #
  # If the non-UVa login route was specified, verify that the supplied id is
  # not a UVa computing id, then do a patron lookup to ensure that it's a valid
  # patron.
  #
  # @params [User] user               By default, `current_user`.
  #
  # @return [void]
  #
  def validate_user(user = nil)
    # If we came from a non-UVa login id, set that in session.
    user ||= current_user
    if user
      @sc_request.user_id = user[:login]
    else
      uid = params[:user_id]
      session[:non_uva_login] = uid unless uid.blank?
      @sc_request.user_id = session[:non_uva_login]
      check_for_uva_id
    end
    patron_lookup
  end

  # ===========================================================================
  # :section:
  # ===========================================================================

  protected

  # Make a valid date from a hash of values.
  #
  # Missing values are replaced with those from today's date.  Invalid month or
  # day values are silently limited to the nearest valid value.  Bad day values
  # like September 31 or February 29 on a non-leap-year are silently corrected
  # to the last day of the month.
  #
  # @param [Hash] date            A hash of the form:
  #                               { 'year' => yy, 'month' => mm, 'day' => dd }
  #
  # @return [DateTime]
  #
  def make_date(date = nil)
    date ||= {}

    # Get year, defaulting to this year.
    year = date['year'].to_i
    year = DateTime.current.year if year.zero?

    # Get month, defaulting to this month.
    month =
      if (mm = date['month'].to_i).zero?
        DateTime.current.month
      else
        [[1, mm].max, 12].min
      end

    # Get day, defaulting to this day.
    day =
      if (dd = date['day'].to_i).zero?
        DateTime.current.day
      else
        [[1, dd].max, 31].min
      end

    # Silently correct invalid day.
    until (result = DateTime.civil(year, month, day) rescue nil)
      day -= 1
      break unless day > 1
    end
    result
  end

  # Special Collections Requests login link.
  #
  # @param [Hash] opt                 HTML options.
  #
  # @return [ActiveSupport::SafeBuffer]
  #
  def login_link(opt = nil)
    html_opt = {
      class: 'btn small',
      label: 'log in',
      url:   '/login?redirect=special_collections_admin'
    }
    html_opt.merge!(opt) if opt.present?
    label = html_opt.delete(:label)
    url   = html_opt.delete(:url)
    view_context.link_to(label, url, html_opt)
  end

  # Look up the user id to see if it's a UVa computing id.
  #
  # @return [void]
  #
  def check_for_uva_id
    return if @sc_request.user_id.blank?
    @sc_request.extend(UVA::Ldap)
    return if @sc_request.full_name.blank?
    # The user is in LDAP and shouldn't be attempting to log in as a patron.
    session.delete(:non_uva_login)
    auth_error_response(:no_netbadge)
  end

  # Look up the user id to see if it's a valid patron.  Sets the name from the
  # the patron record.
  #
  # @return [void]
  #
  def patron_lookup
    user_id = @sc_request.user_id
    if user_id.blank?
      # The request is not associated with a user id; the user needs to log in.
      auth_error_response(:no_user)

    elsif user_id.start_with?('demo_')
      # Test user (non-production deployments only).
      @sc_request.name = user_id

    elsif (patron = get_patron(user_id)).blank?
      # Could not get information about this user's account.
      session.delete(:non_uva_login)
      auth_error_response(:no_patron)

    elsif (name = get_patron_name(patron)).blank?
      # Maybe the record from Firehose was corrupt...
      session.delete(:non_uva_login)
      auth_error_response(:no_patron_info)

    else
      # Patron name has been validated.
      @sc_request.name = name
    end
  end

  # get_patron_name
  #
  # @param [Firehose::User] patron
  #
  # @return [String]
  #
  def get_patron_name(patron)
    last_name = patron.last_name
    if last_name.blank?
      patron.display_name
    else
      last   = "#{last_name},"
      first  = patron.first_name
      middle = patron.middle_name
      [last, first, middle].reject(&:blank?).join(SPACE)
    end
  end

  # Display an error message on the original page.
  #
  # @param [String, Symbol] message
  #
  # @return [false]
  #
  def auth_error_response(message = nil)
    respond_to do |format|
      format.html do
        message   = MESSAGE[message] if message.is_a?(Symbol)
        message ||= MESSAGE[:no_user]
        flash[:error] = message.html_safe
        doc_id = @sc_request.document_id
        redirect start_special_collections_request_path(doc_id, path_opt)
      end
    end
    false
  end


  # Indicate whether the user is a Special Collections administrator.
  #
  # @params [User, String] user               By default, `current_user`.
  #
  def sc_admin?(user = nil)
    user ||= current_user
    id = (user.is_a?(User) ? user.login : user.to_s).presence
    id && SpecialCollectionsUser.admins.find_by_computing_id(id).present?
  end

  # Is the request IP in an allowed SC subnet?
  #
  # @return [Boolean]
  #
  def allowed_ip?
    ip_addr = get_current_ip
    return true if private_subnet?(ip_addr)
    ip = IPAddr.new(ip_addr)
    allowed_subnets.any? { |range| range.include?(ip) }
  end

  # Load allowed special collections subnets from yml and convert to an IPAddr.
  #
  # @return [Array<IPAddr>]
  #
  def allowed_subnets
    @allowed_subnets ||=
      YAML::load(File.open(SC_SUBNETS)).map do |subnet|
        IPAddr.new(subnet)
      end
  end

  # ===========================================================================
  # :section: Filters
  # ===========================================================================

  public

  # Ensure that the request is coming from an allowed IP address or that the
  # user is an administrator or a Special Collections user.
  #
  # @return [void]
  #
  def verify_ip
    return if allowed_ip? || sc_user? || user_is_admin?
    flash[:error] = MESSAGE[:ip_restricted]
    redirect request.referrer
  end

end
