# app/models/record_mailer.rb

require 'uva'

# For sending messages.
#
# Overrides:
# @see "#{Blacklight.models_dir}/record_mailer.rb"
#
# === Usage Notes
# For these methods, *mail_options* is expected to be provided by running
# EmailConcern#mail_properties in the context of a controller route method.
#
class RecordMailer < ActionMailer::Base

  helper :application

  include EmailConcern

  # The subject line for SMS text messages.
  #
  # If a subject is provided, it is displayed in parentheses before the start
  # of the message text (and presumably counts against the 160-character limit
  # for that text message).
  #
  # Values:
  #   ''            No subject.
  #   *nil*, true   Default subject line: "(Sms record)".
  #   String        Replacement subject line.
  #
  SMS_SUBJECT = ''.freeze

  # ===========================================================================
  # :section: Blacklight overrides
  # ===========================================================================

  public

  # Overriding from Blacklight plugin so that we can add availability data and
  # allow for multiple docs.
  #
  # @param [Array<SolrDocument>]    documents
  # @param [Array<UVA::ArticleDoc>] articles
  # @param [String]                 message
  # @param [String, Boolean]        full_record
  # @param [Hash]                   mail_options
  #
  # @return [void]
  #
  def email_record(documents, articles, message, full_record, mail_options)

    unless mail_options[:to].present?
      Rails.logger.warn { "#{__method__}: missing recipient (:to)" }
      return
    end

    @documents   = documents || []
    @articles    = articles  || []
    @message     = message
    @full_record = true_value?(full_record)
    @host        = mail_options.delete(:host)

    mail_options[:subject] ||=
      'Your Virgo item'.tap do |subject|
        total_items = @documents.size + @articles.size
        subject <<
          if total_items == 1
            item = @documents.first || @articles.first
            ": \"#{item.export_title}\""
          else
            " list (#{total_items})"
          end
      end

    mail(mail_options)

  end

  # Send one or more documents as SMS text messages.
  #
  # @param [Array<SolrDocument>]    documents
  # @param [Array<UVA::ArticleDoc>] articles
  # @param [String]                 carrier
  # @param [Hash]                   mail_options
  #
  # @return [void]
  #
  def sms_record(documents, articles, carrier, mail_options)

    unless mail_options[:to].present?
      Rails.logger.warn { "#{__method__}: missing recipient (:to)" }
      return
    end

    @documents  = documents || []
    @articles   = articles  || []
    @host       = mail_options.delete(:host)

    sms_gateway = sms_mapping[carrier]
    if sms_gateway.blank?
      raise "invalid wireless carrier #{carrier.inspect}"
    else
      to = Array(mail_options[:to])
      to.map! { |addr| addr.include?('@') ? addr : "#{addr}@#{sms_gateway}" }
      to = to.first if to.size == 1
      mail_options[:to] = to
    end

    if SMS_SUBJECT && !mail_options[:subject]
      mail_options[:subject] =
        if SMS_SUBJECT.is_a?(String)
          SMS_SUBJECT
        else
          'Your Virgo Item'.tap do |subject|
            subject << 's' unless (@documents.size + @articles.size) == 1
          end
        end
    end

    encoding = SMS_ENCODING
    not_utf8 = (encoding != 'UTF-8')
    if not_utf8
      mail_options[:charset] = encoding
      mail_options[:content_transfer_encoding] = 'quoted-printable'
    end

    ActiveSupport::SafeBuffer.disable_force_utf8 = true  if not_utf8
    mail(mail_options)
    ActiveSupport::SafeBuffer.disable_force_utf8 = false if not_utf8

  end

  # ===========================================================================
  # :section:
  # ===========================================================================

  public

  # email_reserves
  #
  # @param [ReserveRequest] reserve_request
  # @param [Hash]           mail_options
  #
  # @return [void]
  #
  def email_reserves(reserve_request, mail_options)

    from = mail_options[:from]
    unless from.present?
      Rails.logger.warn { "#{__method__}: missing sender (:from)" }
      return
    end

    @reserve_request     = reserve_request
    @coordinator_address = mail_options[:to]
    @host                = mail_options.delete(:host)

    # Check the code of the reserve library on first item in reserve_request.
    # (All other requested items are guaranteed to be same reserve library as
    # a result of [VIRGO-92].)
    # If it is the Law Library code, then add the email of the person doing the
    # reserving to the list of recipients.  This is because the Law Library
    # does not participate in the JIRA Service Desk process for reserves.  All
    # other libraries DO use the JIRA Service Desk for reserves.
    if @reserve_request.reserve_items.first.law_library?
      mail_options[:to] = [*mail_options[:to], from].reject(&:blank?).uniq
    end

    # Subject line of email should have form of <instructor name>: <course ID>
    # If instructor name is empty, use name of person making reserve.
    mail_options[:subject] ||=
      ''.tap do |subject|
        subject << @reserve_request.instructor_name
        subject << @reserve_request.name if subject.blank?
        subject << ": #{@reserve_request.course_id}"
        subject << ' [TEST REQUEST]' unless Virgo.deployed_production?
      end

    mail(mail_options)

  end

  # email_purchase
  #
  # @param [SolrDocument] doc
  # @param [Hash]         mail_options
  #
  # @return [void]
  #
  def email_purchase(doc, mail_options)

    unless mail_options[:to].present?
      Rails.logger.warn { "#{__method__}: missing recipient (:to)" }
      return
    end

    @documents   = [doc]
    @full_record = true
    @host        = mail_options.delete(:host)

    mail_options[:subject] ||=
      'Library Purchase Request'.tap do |subject|
        catkey = doc && doc.pda_catkey_display
        subject << " (u#{catkey})" if catkey.present?
      end

    mail(mail_options)

  end

  # ===========================================================================
  # :section: Blacklight overrides
  # ===========================================================================

  protected

  # Mapping of SMS carrier name to host.
  #
  # @return [Hash{String=>String}]
  #
  def sms_mapping
    SMS_GATEWAY
  end

  # ===========================================================================
  # :section: Class methods
  # ===========================================================================

  public

  # Mapping of SMS carrier name to host.
  #
  # @return [Hash{String=>String}]
  #
  def self.sms_mapping
    SMS_GATEWAY
  end

  # ===========================================================================
  # :section:
  # ===========================================================================

  protected

  # For ApplicationHelper methods that expect "params".
  #
  # @return [Hash]
  #
  def params
    {}
  end

end
