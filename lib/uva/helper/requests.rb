# lib/uva/helper/requests.rb

require 'uva'

module UVA::Helper

  # UVA::Helper::Requests
  #
  module Requests

    include UVA
    include UVA::Helper::Layout
    include UVA::Helper::SemesterAtSea

    DEFAULT_LABEL = 'Request this item'.freeze

    RECALL_REQ_LABEL =
      'Request Item'.freeze
    RECALL_REQ_TOOLTIP =
      'Request that an unavailable item be held or recalled for you.'.freeze

    IVY_REQ_LABEL =
      'Request from Ivy'.freeze
    IVY_REQ_TOOLTIP =
      'Request that an item be retrieved from Ivy Stacks for you.'.freeze

    LEO_REQ_LABEL =
      'Request LEO delivery'.freeze
    LEO_REQ_TOOLTIP =
      'For faculty or members of SCPS, request that an item be delivered to ' \
      'you by the Library Express On-Grounds service.'.freeze

    ILINK_LABEL =
      'Access in Virgo Classic'.freeze
    ILINK_BASE_URL =
      (URL::SIRSI_ROOT + '/uhtbin/cgisirsi/uva/0/0/5').freeze

    ILL_REQ_LABEL      = 'ILL/LEO Requests'.freeze
    ILL_LABEL          = 'Interlibrary Loan'.freeze
    ILLIAD_LABEL       = 'ILLiad main page'.freeze
    ILLIAD_RESET_LABEL = 'Change selected system for ILL/LEO requests'.freeze

    # =========================================================================
    # :section:
    # =========================================================================

    public

    # Returns a link through which a recall can be requested if the target item
    # can be recalled.
    #
    # @param [UVA::IndexDoc] doc      Subject of the request link.
    # @param [Array]         args     - The first optional argument, if it is a
    #                                 String, is used as the link label.
    #                                 - The last optional argument, if it is a
    #                                 Hash, is passed as link options.
    #
    # @option args [Boolean] :request_popup   If *false*, the link will not
    #                                           open a Colorbox popup.
    #
    # @return [ActiveSupport::SafeBuffer]
    #
    # @see self#leo_and_recall_links
    #
    # === Implementation Notes
    # The tooltip for the button is placed on the label rather than the link to
    # prevent Colorbox from picking up the :title attribute to show as the
    # caption at the bottom of the popup.
    #
    def link_to_recall(doc, *args)
      return unless display_recall_link?(doc)
      html_opt = args.last.is_a?(Hash) ? args.pop.dup : {}
      label = html_opt.delete(:label) || args.shift || RECALL_REQ_LABEL
      html_opt[ARIA_LABEL] ||= ERB::Util.h(label)
      label = content_tag(:span, label, title: RECALL_REQ_TOOLTIP)
      request_link(label, html_opt) do |path_opt|
        start_hold_account_request_path(doc.doc_id, path_opt)
      end
    end

    # Returns a link through which LEO delivery can be requested if the target
    # item is eligible for delivery.
    #
    # @param [UVA::IndexDoc] doc      Subject of the request link
    # @param [Array]         args     - The first optional argument, if it is a
    #                                 String, is used as the link label.
    #                                 - The last optional argument, if it is a
    #                                 Hash, is passed as link options.
    #
    # @return [ActiveSupport::SafeBuffer]
    #
    # @see self#leo_and_recall_links
    #
    def link_to_leo(doc, *args)
      return unless display_leo_link?(doc)
      html_opt = { title: LEO_REQ_TOOLTIP }
      html_opt.merge!(args.pop) if args.last.is_a?(Hash)
      label = args.shift || LEO_REQ_LABEL
      path  = ill_leo_path(doc.doc_id)
      request_out_link(label, path, html_opt)
    end

    # Returns a link to request from Ivy Stacks if the target item is eligible.
    #
    # @param [UVA::IndexDoc] doc      Subject of the request link
    # @param [Array]         args     - The first optional argument, if it is a
    #                                 String, is used as the link label.
    #                                 - The last optional argument, if it is a
    #                                 Hash, is passed as link options.
    #
    # @return [ActiveSupport::SafeBuffer]
    #
    # @see self#leo_and_recall_links
    #
    def link_to_ivy(doc, *args)
      return unless display_ivy_link?(doc)
      html_opt = { title: IVY_REQ_TOOLTIP }
      html_opt.merge!(args.pop) if args.last.is_a?(Hash)
      label = args.shift || IVY_REQ_LABEL
      path  = ill_ivy_path(doc.doc_id)
      request_out_link(label, path, html_opt)
    end

    # Returns a link to the ILLiad main form in a new browser tab.
    #
    # @param [Array] args             - The first optional argument, if it is a
    #                                 String, is used as the link label.
    #                                 - The last optional argument, if it is a
    #                                 Hash, is passed as link options.
    #
    # @return [ActiveSupport::SafeBuffer]
    #
    def link_to_illiad_main(*args)
      html_opt = (args.pop if args.last.is_a?(Hash))
      label    = args.shift || ILLIAD_LABEL
      path     = ill_main_path
      request_out_link(label, path, html_opt)
    end

    # Returns a link to the ILLiad form displaying pending requests in a new
    # browser tab.
    #
    # @param [Array] args             - The first optional argument, if it is a
    #                                 String, is used as the link label.
    #                                 - The last optional argument, if it is a
    #                                 Hash, is passed as link options.
    #
    # @return [ActiveSupport::SafeBuffer]
    #
    def link_to_illiad_requests(*args)
      html_opt = (args.pop if args.last.is_a?(Hash))
      label    = args.shift || ILL_REQ_LABEL
      path     = ill_requests_path
      request_out_link(label, path, html_opt)
    end

    # If an ILLiad has been previously selected, remove it and then link to the
    # ILLiad main page to trigger a new ILLiad selection.
    #
    # @param [Array] args             - The first optional argument, if it is a
    #                                 String, is used as the link label.
    #                                 - The last optional argument, if it is a
    #                                 Hash, is passed as link options.
    #
    # @return [ActiveSupport::SafeBuffer]
    #
    def link_to_illiad_reset(*args)
      html_opt = (args.pop if args.last.is_a?(Hash))
      label    = args.shift || ILLIAD_RESET_LABEL
      path     = ill_reset_path
      request_out_link(label, path, html_opt)
    end

    # Returns a link to the route by which a filled-in ILLiad form is generated
    # in a new browser tab.
    #
    # @param [String] path            ILLiad request
    # @param [Array]  args            - The first optional argument, if it is a
    #                                 String, is used as the link label.
    #                                 - The last optional argument, if it is a
    #                                 Hash, is passed as link options.
    #
    # @return [ActiveSupport::SafeBuffer]
    #
    # @see self#link_to_illiad_main
    # @see self#link_to_illiad_requests
    # @see self#link_to_illiad_reset
    # @see self#link_to_ivy
    # @see self#link_to_leo
    #
    def link_to_illiad_form(path, *args)
      return if path.blank?
      html_opt = (args.pop if args.last.is_a?(Hash))
      label    = args.shift || ILL_LABEL
      request_out_link(label, path, html_opt)
    end

    # Creates a link to the Sirsi iLink record.
    #
    # @param [UVA::IndexDoc] doc      Subject of the link
    # @param [Array]         args     - The first optional argument, if it is a
    #                                 String, is used as the link label.
    #                                 - The last optional argument, if it is a
    #                                 Hash, is passed as link options.
    #
    # @return [ActiveSupport::SafeBuffer]
    #
    def link_to_ilink_record(doc, *args)
      availability = doc && doc.availability
      return unless availability && availability.linkable_to_ilink?
      html_opt = (args.pop if args.last.is_a?(Hash))
      label    = args.shift || ILINK_LABEL
      path     = "#{ILINK_BASE_URL}?searchdata1=#{doc.ckey}{CKEY}"
      request_out_link(label, path, html_opt)
    end

    # Returns links for recall and ILLiad requests for an item.
    #
    # @param [UVA::IndexDoc] doc      Subject of the request link
    # @param [Hash]          opt
    #
    # @option opt [Boolean] :request_popup  If *false*, links will not open as
    #                                         Colorbox popups.
    #
    # @option opt [Boolean] :button   If *false*, links are returned.
    #
    # @option opt [Object]  :style    - For buttons, this is taken as the CSS
    #                                 class for the button <div>.
    #                                 - For links, this is the spacer between
    #                                 links (use empty string for no spacer).
    #
    # @return [ActiveSupport::SafeBuffer]
    # @return [nil]
    #
    def leo_and_recall_links(doc, opt = nil)

      # Skip request links for items that can't be delivered by LEO.
      return unless doc && doc.deliverable? && !special_collections_lens?
      html_opt = {
        class:  'recall',
        button: true,
        style:  nil
      }
      html_opt.merge!(opt) if opt.present?
      button = html_opt.delete(:button)
      style  = html_opt.delete(:style)
      if button
        html_opt[:class] += ' ' + (style || 'btn')
        spacer = ''
      else
        spacer = style || link_spacer
      end

      # Get a list of all links to display; links that are not applicable will
      # be null or blank.
      methods = [:link_to_recall, :link_to_ivy, :link_to_leo, :sas_only_text]
      content_tag(:div, class: 'request-buttons') do
        methods.map { |link_method|
          send(link_method, doc, html_opt)
        }.reject(&:blank?).join(spacer).html_safe
      end

    end

    # =========================================================================
    # :section:
    # =========================================================================

    protected

    # Generate a request link to an internal route.
    #
    # @param [String] label
    # @param [Array]  args            - The first optional argument, if it is a
    #                                     String, is used as the path.
    #                                 - The last optional argument, if it is a
    #                                     Hash, is passed as link options.
    #
    # @return [ActiveSupport::SafeBuffer]
    #
    # === Usage Notes
    # Note that if a Hash is passed in as the last argument, it will be
    # modified to remove internal options so that what remains are only valid
    # HTML options.
    #
    def request_link(label, *args)
      opt = (args.pop if args.last.is_a?(Hash))
      html_opt = dialog_button_opts(opt)
      no_popup = false_value?(html_opt.delete(:request_popup))

      label = html_opt.delete(:label) || label || DEFAULT_LABEL
      html_opt[ARIA_LABEL] ||= ERB::Util.h(label)

      # Note that popup *is* used here so that the result uses the popup layout
      # instead of the standard page layout.
      path = args.shift
      if block_given?
        path_opt = { popup: true }
        path_opt[:redirect] = false if no_popup
        path = yield(path_opt)
      end

      classes = Array(html_opt[:class])
      classes << 'initiate-request'
      classes << 'no-popup' if no_popup
      html_opt[:class] = classes.reject(&:blank?).uniq.join(SPACE)

      link_to(label, path, html_opt)
    end

    # Generate a request link to an external service.
    #
    # @param [String] label
    # @param [String] path
    # @param [Hash]   opt
    #
    # @return [ActiveSupport::SafeBuffer]
    #
    def request_out_link(label, path, opt = nil)
      html_opt = { role: 'button' }
      html_opt.merge!(opt) if opt.present?
      html_opt.delete(:popup)
      html_opt.delete(:request_popup)
      label = html_opt.delete(:label) if html_opt.key?(:label)
      label ||= DEFAULT_LABEL
      html_opt[ARIA_LABEL] ||= ERB::Util.h(label)
      external_link(label, path, html_opt)
    end

    # =========================================================================
    # :section: Holds and Recalls
    # =========================================================================

    public

    # Indicate whether a recall request link should be displayed for the item.
    #
    # @param [UVA::IndexDoc] doc
    #
    # @see self#link_to_recall
    #
    def display_recall_link?(doc)
      doc && doc.availability && doc.availability.might_be_holdable?
    end

    # =========================================================================
    # :section: ILL
    # =========================================================================

    public

    # Indicate whether a LEO request link should be displayed for the item.
    #
    # @param [UVA::IndexDoc] doc
    #
    # @return [Boolean]
    #
    # @see self#link_to_leo
    #
    def display_leo_link?(doc)
      doc && doc.availability && doc.availability.leoable?
    end

    # Determines if a there should be an IVY delivery link.
    #
    # @param [UVA::IndexDoc] doc
    #
    # @see self#link_to_ivy
    #
    def display_ivy_link?(doc)
      # Make sure that the title has at least one available Ivy holding.
      availability = doc && doc.availability
      holdings     = availability ? availability.holdings : []
      ivy_holdings, non_ivy_holdings = holdings.partition(&:has_ivy_holdings?)
      return false if ivy_holdings.sum(&:available_copies).zero?

      # If the title has holdings with different call numbers, at least one of
      # the holdings will only be available from Ivy.
      call_numbers = holdings.map { |h| h.call_number.to_s.delete(' ') }.uniq
      return true if call_numbers.size > 1

      # Show the link if only Ivy holdings have available copies.
      non_ivy_holdings.none? do |holding|
        holding.copies.any?(&:available?) if holding.library.deliverable?
      end
    end

  end

end
