# app/controllers/concerns/network_concern.rb

require 'active_support/concern'
require 'uva'

# NetworkConcern
#
module NetworkConcern

  extend ActiveSupport::Concern

  include UVA
  include UVA::Networks
  include UVA::Util::StringMethods

  # ===========================================================================
  # :section:
  # ===========================================================================

  public

  # Set `session[:forged_ip]` from *ip_addr*.  If *ip_addr* is *nil*, *false*,
  # or "false" then `session[:forged_ip]` is deleted.
  #
  # @param [String, Boolean] ip_addr
  #
  # @return [void]
  #
  def set_forged_ip(ip_addr)
    if ip_addr.blank? || false_value?(ip_addr)
      Rails.logger.info { 'Delete session[:forged_ip]' }
      session.delete(:forged_ip)
    else
      Rails.logger.info { "Set session[:forged_ip] = #{ip_addr.inspect}" }
      session[:forged_ip] = ip_addr
    end
  end

  # Delete `session[:forged_ip]`.
  #
  # @return [void]
  #
  def clear_forged_ip
    set_forged_ip(false)
  end

  # ===========================================================================
  # :section: Filters
  # ===========================================================================

  public

  # Extract the "forged_ip" URL parameter, if present.
  #
  def adjust_for_forged_ip
    return unless params.key?(:forged_ip)
    forged_ip = params.delete(:forged_ip)
    forged_ip = nil unless Virgo.development? || Virgo.desktop?
    set_forged_ip(forged_ip)
    params[:new_session] = true if articles_lens?
    redirect_to(params)
  end

end
