# lib/uva/helper/call_number.rb

require 'uva'

module UVA::Helper

  # UVA::Helper::CallNumber
  #
  module CallNumber

    include UVA
    include UVA::Accessibility
    include UVA::ShelfBrowse

    # Regular expressions for the parts of a video call number to be removed
    # for display.
    VIDEO_REMOVALS = [
      /\s*VIDEO\s*\./i,
      /\s*d\.[0-9,\s]+/i,
      /\s*pt\.[0-9,\s]+/i,
      /\s*\([a-z0-9\s]+\)\s*/i,
      /\s*,.*$/, # NOTE: This compensates for a current Solr issue.
    ].deep_freeze

    # =========================================================================
    # :section:
    # =========================================================================

    public

    # Returns a list of the call numbers for a document, or
    # "Multiple call numbers" if there are more than 3.
    #
    # @param [UVA::IndexDoc] doc
    # @param [Hash]          opt
    #
    # === Options
    # @option opt [String] :sep
    # @option opt [Fixnum] :show_limit
    # @option opt [Fixnum] :max_length  Truncate display of call numbers longer
    #                                     than this value.
    # @option opt [Boolean] :sudoc      If *false*, do not use SuDoc numbers.
    #
    # @return [ActiveSupport::SafeBuffer]
    # @return [Array<ActiveSupport::SafeBuffer>]  If *sep* set to *nil*.
    # @return [nil]
    #
    def call_number_display(doc, opt = nil)

      return unless doc && !doc.online_only?
      return if doc.values_for(:library_facet).size > 1

      # Gather numbers to display.
      opt = opt ? opt.dup : {}
      sudoc_allowed = !opt.key?(:sudoc) || opt.delete(:sudoc)
      numbers = doc.shelf_numbers(sudoc: sudoc_allowed)
      return if numbers.blank?

      # Options used internally.
      sep        = opt.key?(:sep)        ? opt.delete(:sep)        : '<br/>'
      show_limit = opt.key?(:show_limit) ? opt.delete(:show_limit) : 3

      # Options passed to #single_call_number_display.
      opt[:max_length] = 40 unless opt.key?(:max_length)

      # If directed, limit the number of call numbers to show for this item.
      total   = numbers.size
      limited = show_limit && show_limit.nonzero? && (total > show_limit)
      numbers = numbers.take(show_limit) if limited

      # Process each call number value.  Shelf numbers are displayed as shelf
      # browse links.
      numbers.map! do |number|
        single_call_number_display(doc, number, opt)
      end

      if limited
        remaining = total - numbers.size
        numbers << "[#{remaining} more]"
      end
      if sep
        numbers.join(sep).html_safe
      else
        numbers.map(&:html_safe)
      end
    end

    # single_call_number_display
    #
    # @param [UVA::IndexDoc] doc
    # @param [String]        number
    # @param [Hash]          opt
    #
    # @option opt [Fixnum] :max_length  Truncate display of call numbers longer
    #                                     than this value.
    #
    # @return [ActiveSupport::SafeBuffer]
    #
    # @see UVA::Helper::ShelfBrowse#show_call_number
    #
    def single_call_number_display(doc, number = nil, opt = nil)
      if number
        return ERB::Util.h(number) if number.start_with?('XX')
        opt = opt ? opt.dup : {}
        opt[:origin] = number
      end
      if UVA::ShelfBrowse.feature_suppressed?
        show_call_number(doc, opt)
      else
        browse_call_number(doc, opt)
      end
    end

    # Produce a call number for display.
    #
    # @param [UVA::IndexDoc] doc
    # @param [Hash]          opt
    #
    # @return [ActiveSupport::SafeBuffer]
    # @return [nil]                   If no label and call number was given or
    #                                   can be determined.
    #
    # === Options
    #
    # @option opt [String]  :label    Explicit override of the link label,
    #                                   which would normally be the shelf
    #                                   number.
    #
    # @option opt [Boolean] :video    If *true*, removes video part numbers.
    #
    # @option opt [Fixnum] :max_label The maximum number of label characters to
    #                                   display.
    #
    # @option opt [String]  :origin Specify a call number string which
    #                                   takes precedence over any call numbers
    #                                   that could be extracted from *item*.
    #
    def show_call_number(doc, opt = nil)

      # Validate arguments.
      doc ||= @document
      return unless doc.is_a?(UVA::IndexDoc)
      opt ||= {}

      # Get the call number.
      number = opt[:origin] || doc.get_shelf_numbers
      number = number.first if number.is_a?(Array)

      # Clean video parts if requested.
      VIDEO_REMOVALS.each { |v| number.gsub!(v, '') } if number && opt[:video]

      # The link is labeled with the call number itself unless it's overridden
      # through *opt*.
      label = opt[:label] || number
      return if label.blank?
      label = label.truncate(opt[:max_label]) if opt[:max_label]
      ERB::Util.h(label)
    end

    # =========================================================================
    # :section: Shelf Browse
    # =========================================================================

    public

    # The HTML element for the shelf browse icon with an empty 'alt' tag since
    # this is a "decorative" image and announcing the alt text would not be
    # helpful.
    #
    # @return [ActiveSupport::SafeBuffer]
    #
    def shelf_browse_icon
      image_tag(UVA::ShelfBrowse.link_icon, alt: '')
    end

    # shelf_browse_button
    #
    # @param [UVA::IndexDoc] doc      The subject of the link; if *nil* then
    #                                   the current @document will be used.
    # @param [Hash]          opt      Execution options and/or 'html_options'
    #                                   for the resulting <div>.
    #
    # @return [ActiveSupport::SafeBuffer]
    # @return [nil]                   If :shelfkey is missing or invalid.
    #
    def shelf_browse_button(doc, opt = nil)

      doc ||= @document
      return unless doc.is_a?(UVA::IndexDoc)

      # Extract options which only apply to this method, leaving the ones that
      # are to be passed on as HTML options to <div>.  Don't show a shelf
      # browse button for an item with an unusable shelfkey.
      opt = opt ? opt.dup : {}
      shelfkey = opt.delete(:shelfkey) || doc.values_for(:shelfkey).first
      return if shelfkey.blank?
      label = opt.delete(:label)
      url   = opt.delete(:url)
      opt.delete(:origin)

      # Apply defaults for values not passed in through *opt*.
      label       ||= shelf_browse_icon
      url         ||= "/shelf_browse/#{doc.doc_id}"
      opt[:title] ||= UVA::ShelfBrowse.link_tooltip

      # Create an interior element for the tooltip so that it does not become
      # the Colorbox figure title.
      outer_opt =
        dialog_button_opts(:'data-path' => url, class: 'browse-button')
      content_tag(:div, outer_opt) do
        content_tag(:div, label.html_safe, opt)
      end

    end

    # browse_call_number
    #
    # @param [UVA::IndexDoc] doc      The subject of the link; if *nil* then
    #                                   the current @document will be used.
    # @param [Hash]          opt      Execution options and/or 'html_options'
    #                                   for the resulting #link_to.
    #
    # @option opt [Boolean] :lc_only  If *true* then return *nil* if the call
    #                                   number does not seem to be a Library
    #                                   of Congress call number.
    #
    # @option opt [Boolean] :number_only
    #                                 If *true* then only the call number will
    #                                 be included in the results.
    #
    # @option opt [Boolean] :button_only
    #                                 If *true* then only the shelf browse
    #                                 button will be included in the results.
    #
    # @return [ActiveSupport::SafeBuffer]
    # @return [nil]                   If no label and call number was given or
    #                                   can be determined.
    #
    def browse_call_number(doc, opt = nil)
      opt = opt ? opt.dup : {}
      lc_only     = opt.delete(:lc_only)
      number_only = opt.delete(:number_only)
      button_only = opt.delete(:button_only)

      call_number = show_call_number(doc, opt)
      return if call_number.blank?

      lc_format = LccNum.lc_format?(call_number)
      return if lc_only && !lc_format

      links = []
      links << call_number unless button_only
      links << shelf_browse_button(doc, opt) unless number_only || !lc_format
      links.delete_if(&:blank?)
      return if links.empty?

      content_tag(:div, class: 'shelf-browse links') do
        links.join.html_safe
      end
    end

  end

end
