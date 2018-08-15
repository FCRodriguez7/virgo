# app/controllers/concerns/course_reserve_concern.rb

require 'active_support/concern'
require 'uva'

# Support for controller actions involving Course Reserve workflows.
#
# @see UVA::Helper::CourseReserve
#
module CourseReserveConcern

  extend ActiveSupport::Concern

  include EmailConcern
  include LibraryPatronConcern
  include LoginSessionConcern
  include AccessIndexConcern
  include StarredItemsConcern

  # ===========================================================================
  # :section:
  # ===========================================================================

  public

  # Messages displayed to the user by this feature.
  MESSAGE = {
    no_auth:      'You are not authorized to place items on course reserve.',
    bad_email:    'There was a problem sending e-mail - ',
    none_sent:    'no requests were delivered.',
    too_few_sent: 'only %d of %d messages were delivered.',
  }.deep_freeze

  # E-mail addresses for local users match this pattern.
  LOCAL_DOMAIN = /@.*virginia\.edu$/i.freeze

  # E-mail address from local users have this domain part.
  PREFERRED_DOMAIN = '@virginia.edu'.freeze

  # ===========================================================================
  # :section:
  # ===========================================================================

  public

  # Send an e-mail to each reserve coordinator as indicated by the reserve
  # items in the request.
  #
  # @param [ReserveRequest] req
  #
  # @return [true]                    If all messages were delivered.
  # @return [false]                   If too few messages were delivered.
  # @return [nil]                     If *req* was not valid.
  #
  def deliver_email_records(req = nil)
    req ||= @reserve_request
    return unless req.is_a?(ReserveRequest) && req.valid?
    mail_options = mail_properties(from: @reserve_request.email)
    addresses = req.reserve_items_by_coordinators.keys
    to_send   = addresses.size
    delivered =
      addresses.map { |addr|
        email = RecordMailer.email_reserves(req, mail_options.merge(to: addr))
        email.deliver if email
      }.compact.size
    return true if to_send == delivered

    # If not all of the messages were delivered, set up a flash message
    # explaining what happened.
    Rails.logger.warn {
      "#{__method__}: sent #{to_send} but delivered #{delivered}"
    }
    error = MESSAGE[:bad_email]
    error +=
      if delivered.zero?
        MESSAGE[:none_sent]
      else
        MESSAGE[:too_few_sent] % [delivered, to_send]
      end
    flash.now[:error] = error
    false
  end

  # ===========================================================================
  # :section: Filters
  # ===========================================================================

  public

  # Fill @documents with starred catalog items that are reservable.
  #
  # @return [void]
  #
  # @see AccessIndexConcern#set_documents
  #
  def set_documents
    params[:show_max_per_page] = 'true'
    params[:sort_key]          = 'call_number_rev'
    super(starred_document_ids)
    @documents.keep_if(&:reservable?)
  end

  # Verify login and account status.
  #
  # If the user is logged in account status is verified; otherwise, a flash
  # message is displayed with convenience sign-on buttons in place which will
  # redirect after login back to the calling feature.
  #
  # @return [void]
  #
  # Compare with:
  # @see LibraryPatronConcern#do_verify_account
  #
  def validate_user
    if current_user.nil?
      # The user is not logged in.  Construct a flash message containing
      # sign-on buttons that redirect to the original route that the filter
      # intercepted.
      flash[:error] = login_message('reserve_request', params[:id])
      redirect_to folders_path

    elsif (@account = get_patron(current_user.login)).nil?
      # Could not acquire patron information for this user login.
      render 'account/not_found'

    elsif @account.barred?
      render 'account/barred'

    elsif !@account.can_make_reserves?
      # Information for the patron does not indicate authorization.
      flash[:error] = MESSAGE[:no_auth]
      redirect_to folders_path
    end
  end

  # Create the @reserve_request from `params`.
  #
  # Per request from the JIRA Service Desk administrator, 'xxx@virginia.edu'
  # addresses are sent as 'xxx@virginia.edu' so the requesting user
  # can be automatically associated with the right JIRA account (auto-created
  # from LDAP information).
  #
  # @return [void]
  #
  # @see self#LOCAL_DOMAIN
  # @see self#PREFERRED_DOMAIN
  #
  def build_request
    @account ||= set_patron
    return unless @account.present?
    name  = params[:name]  || @account.display_name
    email = params[:email] || @account.email
    if email =~ LOCAL_DOMAIN
      email = email.gsub(LOCAL_DOMAIN, PREFERRED_DOMAIN)
    elsif !email.include?('@')
      email += PREFERRED_DOMAIN
    end
    @reserve_request =
      ReserveRequest.new(
        name,
        email,
        params[:course_id],
        params[:semester],
        params[:instructor_cid],
        params[:instructor_name],
        params[:is_instructor]
      )
    @reserve_request.reserve_items =
      @documents.map { |doc|
        next unless doc.is_a?(SolrDocument)
        id          = doc.doc_id
        library     = params[:library]     && params[:library][id]
        loan_period = params[:loan_period] && params[:loan_period][id]
        notes       = params[:notes]       && params[:notes][id]
        ReserveItem.new(doc, library, loan_period, notes)
      }.compact
  end

end
