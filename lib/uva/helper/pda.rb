# lib/uva/helper/pda.rb

require 'uva'
require 'firehose'

module UVA::Helper

  # UVA::Helper::Pda
  #
  module Pda

    include UVA
    include UVA::Helper::Requests

    include Firehose
    include Firehose::Patron

    extend UVA::Accessibility

    # Default options for PDA link.
    #
    # @see self#about_pda_link
    # @see URL#ABOUT_PDA
    #
    PDA_LINK_OPTS = {
      label: 'Available to Order',
      url:   URL::ABOUT_PDA,
      style: 'text-decoration: underline;'
    }.deep_freeze

    # Default options for PDA button.
    #
    # @see self#pda_purchase_link
    #
    PDA_BUTTON_OPTS =
      dialog_button_opts(label: 'Order this Item', class: 'btn').deep_freeze

    # =========================================================================
    # :section:
    # =========================================================================

    public

    # PDA label for use in situations where a link is not necessary.
    #
    # @return [String]
    #
    def pda_label
      PDA_LINK_OPTS[:label]
    end

    # PDA "about" link.
    #
    # @param [Hash] opt
    #
    # @option opt [String] :label     Label for the link.
    # @option opt [String] :url       URL for the link.
    #
    # @return [ActiveSupport::SafeBuffer]
    #
    # @see self#PDA_LINK_OPTS
    # @see UVA::Helper::Links#out_link
    #
    def about_pda_link(opt = nil)
      html_opt = PDA_LINK_OPTS.dup
      html_opt.merge!(opt) if opt.present?
      label = html_opt.delete(:label)
      path  = html_opt.delete(:url)
      out_link(label, path, html_opt)
    end

    # A link through which an order can be placed for the physical item.
    #
    # @param [UVA::IndexDoc] doc      Subject of the request link
    # @param [Hash]          opt
    #
    # @option opt [String]  :label          Label for the link.
    #
    # @option opt [Boolean] :request_popup  If *false*, the link will not
    #                                         open a Colorbox popup.
    #
    # @return [ActiveSupport::SafeBuffer]
    #
    # @see self#PDA_BUTTON_OPTS
    # @see UVA::Helper::Requests#request_link
    #
    def pda_purchase_link(doc, opt = nil)
      html_opt = PDA_BUTTON_OPTS.merge(opt || {})
      label = html_opt.delete(:label)
      request_link(label, html_opt) do |path_opt|
        confirm_pda_path(doc.doc_id, path_opt)
      end
    end

    # =========================================================================
    # :section:
    # =========================================================================

    public

    # Conditionally generate the availability button for purchasing an item
    # through patron-driven acquisitions.
    #
    # @param [UVA::IndexDoc] doc
    # @param [Hash]          opt      Passed on to #pda_purchase_link.
    #
    # @return [ActiveSupport::SafeBuffer]
    # @return [nil]
    #
    # @see self#pda_purchase_link
    #
    def pda_purchase(doc, opt = nil)
      return unless display_purchase_link?(doc)
      content_tag(:div, class: 'pda-purchase') do
        pda_purchase_link(doc, opt)
      end
    end

    # Conditionally generate the availability link to the About page for
    # patron-driven acquisitions.
    #
    # @param [UVA::IndexDoc] doc
    #
    # @return [ActiveSupport::SafeBuffer]
    # @return [nil]
    #
    # @see self#about_pda_link
    #
    def about_pda(doc)
      return unless display_purchase_link?(doc)
      content_tag(:div, class: 'pda-about') do
        "Learn more about #{about_pda_link} items.".html_safe
      end
    end

    # =========================================================================
    # :section: PDA
    # =========================================================================

    public

    # Indicate whether the item should be treated as Available-to-Order.
    #
    # @param [UVA::IndexDoc] doc
    #
    def is_pda?(doc)
      doc && doc.has_feature?('pda_print')
    end

    # Indicate whether a purchasing link should be displayed for the item.
    #
    # @param [UVA::IndexDoc] doc
    #
    def display_purchase_link?(doc)
      is_pda?(doc) && doc.availability.present?
    end

    # Determine if the user is authenticated and authorized to purchase print
    # items.
    #
    # Check the account status to make sure that the logged-in user is still
    # permitted to perform the intended request.
    #
    # @param [::User] user            If *nil*, the `current_user` is checked.
    #
    def user_can_purchase?(user = nil)
      user ||= current_user
      account = user && get_patron(user.login)
      account && !account.barred? && permitted_to_buy?(account)
    end

    # The classifications of users who are permitted to buy print books.
    #
    # @param [Firehose::User] acct    Patron user account.
    #
    def permitted_to_buy?(acct)
      acct.faculty? || acct.instructor? || acct.staff? ||
        acct.graduate? || acct.undergraduate?
    end

  end

end
