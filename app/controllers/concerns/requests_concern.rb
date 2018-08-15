# app/controllers/concerns/requests_concern.rb

require 'active_support/concern'
require 'uva'

# Basic support for definitions that change the behavior of requests based on
# the URL parameters.
#
module RequestsConcern

  extend ActiveSupport::Concern

  include UVA
  include UVA::Helper::Layout

  # ===========================================================================
  # :section: Blacklight::Controller Overrides
  # ===========================================================================

  public

  # Overrides ApplicationController#layout_name so that if :popup was set in
  # the request parameters then app/views/layouts/popup.html.erb is used for
  # the layout instead of app/views/layouts/applications.html.erb.
  #
  # @return [String]
  #
  def layout_name
    in_popup? ? 'popup' : super
  end

  # ===========================================================================
  # :section:
  # ===========================================================================

  public

  # If the URL parameters include `redirect=false` then return with an error
  # page; otherwise redirect to the path as indicated.
  #
  # @param [Array] *args
  #
  # @return [false]
  #
  def redirect(*args)
    if no_redirects?
      render_flash_only
    else
      redirect_to(*args)
    end
    false
  end

  # Renders a page with only flash messages.
  #
  # @param [String] template          Instead of "account_requests/error".
  # @param [Hash]   opt               Passed to render
  #
  # @option opt [Object] :layout      Specify *false* for no layout.
  #
  def render_flash_only(template = nil, opt = nil)
    template ||= 'account_requests/error'
    render_opt = { layout: layout_name }
    render_opt.merge!(opt) if opt.present?
    render template, render_opt
  end

end
