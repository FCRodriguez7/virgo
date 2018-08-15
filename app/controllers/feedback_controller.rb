# app/controllers/feedback_controller.rb

require 'uva'

# This controller supports the generation of feedback e-mails from the current
# user.
#
# Feedback controller base class is included in the Blacklight plugin.
# Overriding from plugin to include reCaptcha validation.
#
# === Implementation Notes
# This definition extends/overrides Blacklight's FeedbackController; however,
# because *config/routes.rb* does not include :feedback in the argument to
# `Blacklight.add_routes`, route methods defined there are not necessarily
# supported by this controller definition.
#
# @see "#{Blacklight.controllers_dir}/feedback_controller.rb"
#
class FeedbackController < ApplicationController

  include EmailConcern
  include LoginSessionConcern

  # ===========================================================================
  # :section:
  # ===========================================================================

  public

  # Messages displayed to the user by this controller.
  MESSAGE = {
    email:     'A valid email address is required.',
    message:   'A message is required.',
    name:      'A valid name is required.',
    recaptcha: LoginSessionConcern::MESSAGE[:bad_recaptcha],
    not_sent:  'There was a problem sending the e-mail.'
  }.deep_freeze

  # ===========================================================================
  # :section:
  # ===========================================================================

  public

  # == GET /feedback
  # == POST /feedback
  #
  def show
    @errors ||= []
    name    = params[:name]    = params[:name].to_s.strip
    email   = params[:email]   = valid_email_address(params[:email])
    message = params[:message] = params[:message].to_s.strip
    referer = params[:referer] || params[:referrer] || request.referer
    return unless request.post? && validate
    mail_opt = { request: request }
    mail_message = Notifier.feedback(name, email, message, referer, mail_opt)
    if mail_message && mail_message.deliver
      redirect_to feedback_complete_path
    else
      flash[:error] = MESSAGE[:not_sent]
      redirect_to :back
    end
  end

  # == GET /feedback/complete
  #
  def complete
  end

  # ===========================================================================
  # :section:
  # ===========================================================================

  protected

  # Validates the incoming params.
  #
  # @return [Boolean]
  #
  def validate
    @errors ||= []
    @errors.clear
    @errors << MESSAGE[:recaptcha] unless user_verified?
    @errors << MESSAGE[:name]      if params[:name].blank?
    @errors << MESSAGE[:email]     if params[:email].blank?
    @errors << MESSAGE[:message]   if params[:message].blank?
    @errors.empty?
  end

end
