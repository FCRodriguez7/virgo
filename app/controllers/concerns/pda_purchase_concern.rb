# app/controllers/concerns/pda_purchase_concern.rb

require 'active_support/concern'
require 'uva'

# Support for controller actions involving PDA (Patron Driven Acquisitions).
#
# @see UVA::Helper::Pda
#
module PdaPurchaseConcern

  extend ActiveSupport::Concern

  # TODO: Rework error messages that depend on views to be use a template.
  include UVA
  include UVA::Util::Json
  include UVA::Util::RouteMethods
  include ActionView::Helpers::UrlHelper

  include EmailConcern
  include RequestsConcern

  include UVA::Helper::Layout
  include UVA::Helper::Pda
  include UVA::Helper::Links

  # ===========================================================================
  # :section:
  # ===========================================================================

  public

  # Messages displayed to the user by this feature.
  MESSAGE = {
    on_order: 'This item is already on order.',
    no_order: 'A problem occurred and we could not fulfill your request.',
  }.deep_freeze

  # ===========================================================================
  # :section:
  # ===========================================================================

  public

  # place_purchase_order
  #
  # @return [String]                  The flash message to be displayed.
  #
  #--
  # rubocop:disable Metrics/MethodLength # [61/35]
  #++
  def place_purchase_order

    # Assemble purchase information.
    pda_params = {
      isbn:        (isbn = @document.pda_isbn_display),
      catkey:      (ckey = @document.pda_catkey_display),
      loc:         (loc  = @document.pda_feature_display),
      computingID: (cid  = current_user.login)
    }
    user_desc = @account.description
    user_ou   = @account.organizational_unit

    Rails.logger.info {
      "PURCHASE ATTEMPT: #{cid} (#{user_desc}:#{user_ou} " \
      "attempting purchase of  ISBN: #{isbn}  CAT KEY: #{ckey}  LOC: #{loc})"
    }

    # Place the order through the PDA web service.
    pda_code = pda_message = order_number = '???'
    begin
      result =
        Curl::Easy.http_post(PDA_WEB_SERVICE, pda_params.to_json) do |curl|
          curl.headers['Content-Type'] = 'application/json'
        end
      json_parse(result.body_str, raise: true).tap do |json|
        pda_code     = json['Code']
        pda_message  = json['Message']
        order_number = json['OrderNumber']
      end
    rescue => e
      rescue_with_handler(e) || Rails.logger.info {
        "PURCHASE FAILED (#{e}): #{cid} (#{user_desc}:#{user_ou} " \
        "attempting purchase of  ISBN: #{isbn}  CAT KEY: #{ckey}  LOC: #{loc})"
      }
    end

    # Possible return codes from the PDA web service are:
    #
    #  100 = success
    #  200 = interface error (as in bad or missing parameters, from Coutts)
    #  400 = order error (from Coutts)
    #  502 = attempt to order item already on order (from PDA web service)
    #  602 = local database error (from PDA web service)
    #
    problem =
      case pda_code
        when 100 then nil
        when 502 then :on_order
        else          :no_order
      end
    Rails.logger.info {
      result =
        case pda_code
          when 100 then "SUCCESS: order number #{order_number}"
          when 502 then "ALREADY ON ORDER: [code #{pda_code}] #{pda_message}"
          else          "ERROR: [code #{pda_code}] #{pda_message}"
        end
      "PURCHASE #{result}: #{cid} (#{user_desc}:#{user_ou} " \
      "purchase of  ISBN: #{isbn}  CAT KEY: #{ckey}  LOC: #{loc})"
    }

    # Generate and return the flash message to be displayed.
    m = []
    if problem
      # Report a problem with the order.
      problem = MESSAGE[problem] if problem.is_a?(Symbol)
      m << "We're sorry. #{problem}"
      m << "Please #{ask_a_librarian} for other options to obtain this item."
    else
      # Send a confirmation email.
      m << 'Thank you! Your request has been successfully submitted.'
      m << '&nbsp'
      if send_purchase_email
        m << 'An email has been sent to you with your request confirmation.'
        m << 'You will be notified by a second email when your item arrives.'
      else
        m << 'There was a problem sending your request confirmation email, ' \
             'but that should not affect the status of your order.'
        m << 'You will be notified by email when your item arrives.'
      end
      m << '&nbsp'
      m << 'If you have questions about the status of your order, ' \
           "please #{ask_a_librarian}."
    end
    html_paragraphs(*m)

    # rubocop:enable Metrics/MethodLength
  end

  # send_purchase_email
  #
  # @return [Mail::Message]
  #
  def send_purchase_email
    mail_options = mail_properties.merge(to: @account.email)
    mail_message = RecordMailer.email_purchase(@document, mail_options)
    mail_message.deliver if mail_message
  end

  # ===========================================================================
  # :section: Filters
  # ===========================================================================

  public

  # Verify login and user classification.
  #
  # @return [void]
  #
  # Compare with:
  # @see LibraryPatronConcern#do_verify_account
  # @see UVA::Helper::LoginSession#login_message
  #
  def validate_user

    doc_id = params[:id].presence
    error_page  = nil
    error_lines = []

    if current_user.nil?
      # The user is not logged in. Construct a flash message containing sign-on
      # buttons that redirect to the original route intercepted by the filter.
      sign_in    = 'sign in'
      to_request = doc_id && ' to request this item'
      unless no_redirects?
        path = login_path
        path += "?redirect=#{catalog_index_path}&id=#{doc_id}" if doc_id
        sign_in = link_to(sign_in, path, style: 'text-decoration:underline')
      end
      error_lines <<
        "UVA faculty, staff and students must #{sign_in}#{to_request}."

    elsif (@account = get_patron(current_user.login)).nil?
      error_page = 'account/not_found'

    elsif @account.barred?
      error_page = 'account/barred'

    elsif !permitted_to_buy?(@account)
      error_lines <<
        'Only authorized UVA faculty, staff, students, and instructors may ' \
          'request this item.'
      error_lines <<
        "If you believe there has been an error, or if you'd like help " \
          "finding other ways to obtain this item, please #{ask_a_librarian}."

    end

    if error_page || error_lines.present?
      Rails.logger.info { "PDA purchase error: #{error_page}" } if error_page
      flash[:error] = html_paragraphs(*error_lines) if error_lines.present?
      if in_popup?
        render_flash_only(error_page)
      else
        redirect(doc_id ? catalog_path(doc_id) : root_path)
      end
    end

  end

end
