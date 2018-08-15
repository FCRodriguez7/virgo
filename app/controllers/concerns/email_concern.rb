# app/controllers/concerns/email_concern.rb

require 'active_support/concern'
require 'uva'

# Basic support for sending messages via e-mail.
#
module EmailConcern

  extend ActiveSupport::Concern

  include ApplicationHelper
  include UVA::Helper::Email
  include UVA::Helper::TextMessages

  # ===========================================================================
  # :section:
  # ===========================================================================

  protected

  COMMON_PORTS = [URI::HTTP::DEFAULT_PORT, URI::HTTPS::DEFAULT_PORT].freeze

  # ===========================================================================
  # :section:
  # ===========================================================================

  public

  # Return mail options based on the current request.
  #
  # @param [Hash] opt
  #
  # @option opt [String] :from        If missing, only the host is returned.
  #
  # @return [Hash]
  #
  def mail_properties(opt = nil)
    opt ||= {}
    req  = opt[:request].presence || request
    host = opt[:host].presence    || req.host
    port = opt[:port].presence    || req.port
    from = opt[:from]
    if from.blank?
      from = "no-reply@#{host}"
    elsif !from.include?('@')
      from = "#{from}@#{host}"
    end
    host = "#{host}:#{port}" unless port.blank? || COMMON_PORTS.include?(port)
    opt
      .except(:request)
      .merge(from: from, host: host)
      .reject { |_, v| v.blank? }
  end

end
