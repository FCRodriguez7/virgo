# app/helpers/account_helper.rb

require 'uva'
require 'firehose'

# Definitions to support */app/views/account/**.erb* view templates.
#
# @see AccountController
#
module AccountHelper

  include UVA
  include UVA::Helper::Accessibility
  include UVA::Helper::Export
  include UVA::Helper::Layout
  include UVA::Helper::StarredItems

  include Firehose

  # ===========================================================================
  # :section: Sidebar
  # ===========================================================================

  public

  # sidebar_links
  #
  # @param [Firehose::User] user
  #
  # @return [ActiveSupport::SafeBuffer]
  # @return [nil]                         If *user* is not valid.
  #
  def sidebar_links(user)
    return unless user.is_a?(Firehose::User)
    current_action  = params[:action].to_s
    disabled_marker = ' link-disabled'
    {
      index:        accounts_path,
      checkouts:    checkouts_accounts_path,
      notices:      notices_accounts_path,
      reserves:     user.can_make_reserves? && reserves_accounts_path,
      holds:        holds_accounts_path,
      ill_requests: link_to_illiad_requests,
      starred:      folders_path
    }.map { |action, link|
      next unless link
      current = (action.to_s == current_action)
      unless link.is_a?(ActiveSupport::SafeBuffer)
        count =
          case action
            when :checkouts then user.checkout_count
            when :holds     then user.hold_count
            when :reserves  then user.reserve_count
            when :notices   then user.overdue_count + user.recalled_count
            when :starred   then star_counter(no_hide: true)
          end
        label =
          case action
            when :index     then 'My Account'
            when :checkouts then "Checked-out Items (#{count})"
            when :holds     then "Requests (#{count})"
            when :reserves  then "Course Reserves (#{count})"
            when :notices   then "Notices (#{count})"
            when :starred   then "Starred Items #{count}".html_safe
          end
        opt  = current ? { class: disabled_marker.strip, tabindex: -1 } : {}
        link = link_to(label, link, opt)
      end
      li_css = (action == :index) ? 'account-home' : action.to_s.dasherize
      li_css += '-nav'
      li_css += disabled_marker if current
      content_tag(:li, link, class: li_css, role: 'menuitem')
    }.compact.join("\n").html_safe
  end

end
