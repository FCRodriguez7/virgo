# app/models/notifier.rb

require 'uva'

# For sending feedback emails.
#
class Notifier < ActionMailer::Base

  include EmailConcern

  # ===========================================================================
  # :section:
  # ===========================================================================

  public

  # Generate a Virgo feedback e-mail message.
  #
  # @param [String] name
  # @param [String] email
  # @param [String] message
  # @param [String] referrer
  # @param [Hash]   mail_options
  #
  def feedback(name, email, message, referrer, mail_options)
    mail_options = {
      to:      FEEDBACK_RECIPIENTS,
      from:    FEEDBACK_FROM,
      subject: FEEDBACK_SUBJECT,
      body:    <<-EOS.gsub(/^\s*\|/, '')
        |VIRGO USER FEEDBACK
        |
        |SENDER NAME: #{name}
        |
        |SENDER EMAIL: #{email}
        |
        |SENDER MESSAGE:
        |#{message}
        |
        |REFERRING URL:
        |#{referrer}
      EOS
    }.merge(mail_options)
    mail_options = mail_properties(mail_options)
    mail(mail_options)
  end

end
