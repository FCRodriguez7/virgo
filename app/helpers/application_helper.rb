# app/helpers/application_helper.rb

require 'socket'
require 'uva'

# Definitions to support all */app/views/**.erb* view templates.
#
# @see ApplicationController
#
module ApplicationHelper

  include UVA
  include UVA::BlacklightOverride
  include UVA::Helper::Accessibility
  include UVA::Helper::Development
  include UVA::Helper::Layout
  include UVA::Util::HtmlMethods

  # ===========================================================================
  # :section:
  # ===========================================================================

  public

  VCARD = {
    org:   'University of Virginia Library',
    adr:   'PO Box 400113, Charlottesville, VA 22904-4113',
    tel:   '434-924-3021',
    fax:   '434-924-1431',
    email: 'xxx@virginia.edu',
  }.deep_freeze

  PRINT_VIEW_LABEL       = ''.freeze
  PRINT_VIEW_TIP         = 'Print View'.freeze

  CLOSE_PRINT_VIEW_LABEL = 'CLOSE'.freeze
  CLOSE_PRINT_VIEW_TIP   = 'Close this print view and return to Virgo'.freeze

  PRINT_VIEW_BACK_LABEL  = 'BACK'.freeze
  PRINT_VIEW_BACK_TIP    = 'Go back to the previous print view'.freeze

  PRINT_WINDOW_LABEL     = 'PRINT'.freeze
  PRINT_WINDOW_TIP       = 'Send to the printer'.freeze

  # Printing tips displayed within the on-screen control area.
  PRINT_TEXT = {
    table: 'click on table headers to sort by category',
    index: 'click on titles for a print view of individual items',
  }.deep_freeze

  IGNORE_FOR_PRINT_VIEW = %w(
    counter
    facet.limit
    index
    total
  ).map(&:to_sym).freeze

  # ===========================================================================
  # :section:
  # ===========================================================================

  public

  # Library identity links used in the footer and the home page.
  #
  #   :org    Organization name
  #   :adr    Mailing address
  #   :tel    Telephone number
  #   :fax    Fax number
  #   :email  E-mail address
  #
  # @param [Hash] opt
  #
  # @return [Hash]
  #
  def vcard_links(opt = nil)
    opt ||= {}
    {
      org:   external_link(VCARD[:org], URL::LIBRARY, opt),
      adr:   VCARD[:adr],
      tel:   link_to(VCARD[:tel],   "tel:+1-#{VCARD[:tel]}",   opt),
      fax:   link_to(VCARD[:fax],   "tel:+1-#{VCARD[:fax]}",   opt),
      email: link_to(VCARD[:email], "mailto:#{VCARD[:email]}", opt)
    }
  end

  # Virgo logo link for the display header.
  #
  # @param [Hash] opt
  #
  # @option opt [String] :label       Default: #application_name.
  #
  # @return [ActionSupport::SafeBuffer]
  #
  def application_logo(opt = nil)
    html_opt = {
      class: 'virgo-logo-link',
      label: application_name,
    }
    html_opt.merge!(opt) if opt.present?
    label = html_opt.delete(:label)
    if in_aside?
      html_opt[:title] ||= 'Click to close this side window and return.'
      path  = window_close_path(in_popup?)
    else
      label = ERB::Util.h(label) + sr_only(' Home')
      path  = special_collections_lens? ? catalog_index_path : root_path
    end
    link_to(label, path, html_opt)
  end

  # The set of buttons leading to the home page of each portal ("lens") that
  # is represented on the main home page.
  #
  # @param [Hash] opt
  #
  # @option opt [String, Symbol, Array] :except
  #
  # @return [ActionSupport::SafeBuffer]
  #
  def show_portal_buttons(opt = nil)
    html_opt = {}
    html_opt.merge!(opt) if opt.present?
    html_opt[:class] ||= 'portal-button-container'

    exception = html_opt.delete(:except)
    exception = Array(exception).compact.map(&:to_s)

    content_tag(:div, html_opt) do
      portal_controllers.map { |portal|
        next if exception.include?(portal)
        label = portal_button_label(portal).html_safe
        url   = home_path(portal)
        tip   = portal_tooltip(portal)
        link_opt = { class: 'portal-button' }
        link_opt[:title] = tip if tip.present?
        link_to(label, url, link_opt)
      }.join(SPACE).html_safe
    end
  end

  # ===========================================================================
  # :section:
  # ===========================================================================

  public

  # Icon button which opens a print view of the current page.
  #
  # @param [Array] args
  #
  # @option args [String] :label      Default: self#PRINT_VIEW_LABEL.
  # @option args [String] :path       Default: generated from :params.
  # @option args [Hash]   :params     Default: `params`.
  # @option args [String] :class      Default: 'print-view-button'.
  # @option args [String] :title      Default: self#PRINT_VIEW_TIP.
  #
  # @return [ActiveSupport::SafeBuffer]
  #
  def print_view_link(*args)
    html_opt = {
      class:  'print-view-button',
      role:   'button',
      label:  PRINT_VIEW_LABEL,
      title:  PRINT_VIEW_TIP,
      params: params
    }
    html_opt.merge!(args.pop) if args.last.is_a?(Hash)
    label = html_opt.delete(:label)
    label = args.shift if args.present?
    path  = html_opt.delete(:params)
    path  = html_opt.delete(:path) if html_opt.key?(:path)
    if path.is_a?(Hash)
      path = path.except(*IGNORE_FOR_PRINT_VIEW).merge(view: :print)
    elsif !path.include?('view=print')
      path += path.include?('?') ? '&' : '?'
      path << 'view=print'
    end
    title = args.shift
    html_opt[:title] = strip_html(title) if title.present?
    out_link(label, path, html_opt)
  end

  # Controls displayed in the on-screen version of print view.
  #
  # @param [Array] args
  #
  # @option args.last [String] :tip   Text to display beside the buttons.
  #
  # @return [ActiveSupport::SafeBuffer]
  #
  def print_view_controls(*args)
    html_opt = {
      class: 'print-controls'
    }
    html_opt.merge!(args.pop) if args.last.is_a?(Hash)
    table_view = (params[:controller] == 'folder')
    index_view = index_page? || browse_page?
    index_view &&= table_view || current_portal_key.present?
    back_link = (print_view_back_link(*args) unless index_view)
    print_opt = {}
    unless back_link
      print_opt = {
        title:    PRINT_WINDOW_TIP + ' and return to Virgo',
        path:     window_print_and_close_path,
        tabindex: 0
      }
    end
    text = []
    text << html_opt.delete(:tip) if html_opt.key?(:tip)
    text << PRINT_TEXT[:table]    if table_view
    text << PRINT_TEXT[:index]    if index_view
    tip = ('TIP: ' << text.join('; ').capitalize << '.' if text.present?)
    content_tag(:div, html_opt) do
      result = []
      result << print_window_button(*args, print_opt)
      result << close_print_view_link(*args)
      result << back_link
      result << content_tag(:span, tip, class: 'tip') if tip
      result.join.html_safe
    end
  end

  # A link which causes the browser to print the current browser tab.
  #
  # @param [Array] args
  #
  # @option args [String] :label      Default: self#PRINT_WINDOW_LABEL.
  # @option args [String] :class      Default: 'print-window-button'.
  # @option args [String] :title      Default: self#PRINT_WINDOW_TIP.
  #
  # @return [ActiveSupport::SafeBuffer]
  #
  def print_window_button(*args)
    html_opt = {
      class: 'print-window-button btn small',
      title: PRINT_WINDOW_TIP,
      label: PRINT_WINDOW_LABEL,
      path:  window_print_path
    }
    html_opt.merge!(args.pop) if args.last.is_a?(Hash)
    label = html_opt.delete(:label)
    path  = html_opt.delete(:path)
    action_link(label, path, html_opt)
  end

  # A link to be used from a print view to close it's browser tab.
  #
  # @param [Array] args
  #
  # @option args [String] :label      Default: self#CLOSE_PRINT_VIEW_LABEL.
  # @option args [String] :class      Default: 'close-print-view-button'.
  # @option args [String] :title      Default: self#CLOSE_PRINT_VIEW_TIP.
  #
  # @return [ActiveSupport::SafeBuffer]
  #
  def close_print_view_link(*args)
    html_opt = {
      class: 'close-print-view-button btn small',
      title: CLOSE_PRINT_VIEW_TIP,
      label: CLOSE_PRINT_VIEW_LABEL,
    }
    html_opt.merge!(args.pop) if args.last.is_a?(Hash)
    window_close_link(in_popup?, html_opt)
  end

  # A link to be used from a print view to go back to the previous print view
  # screen.
  #
  # If the previous page does not contain "&view=print" then *nil* is returned.
  #
  # @param [Array] args
  #
  # @option args [String] :label      Default: self#PRINT_VIEW_BACK_LABEL.
  # @option args [String] :class      Default: 'close-print-view-button'.
  # @option args [String] :title      Default: self#PRINT_VIEW_BACK_TIP.
  #
  # @return [ActiveSupport::SafeBuffer]
  # @return [nil]
  #
  def print_view_back_link(*args)
    return unless request.referrer.to_s.include?('view=print')
    html_opt = {
      class: 'close-print-view-button btn small',
      label: PRINT_VIEW_BACK_LABEL,
      title: PRINT_VIEW_BACK_TIP,
    }
    html_opt.merge!(args.pop) if args.last.is_a?(Hash)
    browser_back_link(in_popup?, html_opt)
  end

  # ===========================================================================
  # :section:
  # ===========================================================================

  public

  # Used with a hidden element in the footer so that we can tell what node
  # served up the content.
  #
  # @return [String]
  #
  def host_server
    Socket.gethostname
  end

end
