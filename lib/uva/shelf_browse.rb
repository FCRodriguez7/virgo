# lib/uva/shelf_browse.rb

require 'uva'

module UVA

  # Methods to support virtual shelf browse.
  #
  # @see UVA::Lcc
  # @see UVA::SolrBrowseNearby
  # @see UVA::Helper::ShelfBrowse
  #
  # === Library of Congress call numbers
  #
  # Comprised of
  #   - An optional location (e.g. "Ref." for "reference room")
  #   - The "class", one or two capital letters which indicate the subject.
  #   - The "subclass", a whole or floating-point number.
  #   - The "cutter", which has the form /\.([A-Z][0-9]+)+/.
  #   - An optional annotation which may include a combination of:
  #       Year (e.g. "1999")
  #       Volume number (e.g. "v.1")
  #       Copy number (e.g. "c.2")
  #       Other (e.g. "plates")
  #
  # === References
  # @see https://www.amnh.org/our-research/research-library/library-catalog/library-of-congress-call-numbers/
  #
  module ShelfBrowse

    include UVA
    include UVA::Lcc

    # =========================================================================
    # :section: Feature properties
    # =========================================================================

    public

    class << self

      # If *true*, eliminates modifications that support "virtual shelf browse"
      # functionality.
      FEATURE_DISABLED = false

      # Name of this feature for display purposes.
      DEFAULT_TITLE = 'Virgo Virtual Shelf'.freeze

      # Icon for shelf browse button.
      LINK_ICON = 'shelf-browse/bookshelf_small.png'.freeze

      # Tooltip for shelf browse button.
      LINK_TOOLTIP =
        'Browse the virtual shelf for related items near this title.'.freeze

      # === Behavioral options
      #
      # sc_supported          If *true*, virtual shelf browse can be used from
      #                       the Special Collections lens.
      #
      # sc_netbadge           If *true*, the feature is only visible to UVA
      #                       users (if *sc_supported* is *true*).
      #
      # extra_metadata_popup  If *true*, additional information about an item
      #                       is visible via popup.
      #
      # extra_metadata_page   If *true*, additional information about an item
      #                       is visible via web page.
      #
      OPTION = {
        sc_supported:         true,
        sc_netbadge:          true,
        extra_metadata_popup: false,
        extra_metadata_page:  true,
      }.deep_freeze

      # =======================================================================
      # :section: Module methods
      # =======================================================================

      public

      # Indicate whether the "virtual shelf browse" should be present.
      #
      # @see self#FEATURE_DISABLED
      #
      def feature_enabled?
        !defined?(FEATURE_DISABLED) || !FEATURE_DISABLED
      end

      # Indicate whether "virtual shelf browse" should be unavailable to the
      # current session.
      #
      # @return [Boolean]             The suppression state or *false* if
      #                                 self#feature_enabled? is false.
      #
      def feature_suppressed?
        @feature_suppressed = false unless defined?(@feature_suppressed)
        @feature_suppressed || !feature_enabled?
      end

      # Define whether "virtual shelf browse" should be unavailable to the
      # current session.
      #
      # @param [Boolean] state        Set/unset suppression of the feature.
      #
      # @return [Boolean]             The suppression state or *false* if
      #                                 self#feature_enabled? is false.
      #
      def feature_suppressed(state)
        @feature_suppressed = !!state
        feature_suppressed?
      end

      # default_title
      #
      # @return [String]
      #
      def default_title
        DEFAULT_TITLE
      end

      # link_icon
      #
      # @return [String]
      #
      def link_icon
        LINK_ICON
      end

      # link_tooltip
      #
      # @return [String]
      #
      def link_tooltip
        LINK_TOOLTIP
      end

      # option
      #
      # @return [Hash]
      #
      def option
        OPTION
      end

    end

    # =========================================================================
    # :section:
    # =========================================================================

    public

    # All of the documents being displayed on the virtual shelf.
    #
    # @param [Array<Object>] docs
    #
    # @return [Array<UVA::IndexDoc>]
    #
    def shelf_browse_documents(docs = nil)
      docs ||= @document_list || []
      docs.select { |v| v.is_a?(UVA::IndexDoc) }
    end

    # Return the document call number which matches its :shelfkey.
    #
    # NOTE: It remains to be seen whether this is satisfactory.
    #
    # @param [UVA::IndexDoc] doc
    # @param [Boolean]       lc_only
    #
    # @return [String]
    # @return [nil]                   If *doc* is not a UVA::IndexDoc.
    #
    def shelf_browse_number(doc = nil, lc_only = false)
      shelf_browse_numbers(doc, lc_only).first
    end

    # Return the document call number which matches its :shelfkey followed by
    # any other call numbers associated with the document.
    #
    # @param [UVA::IndexDoc] doc
    # @param [Boolean]       lc_only
    #
    # @return [Array<String>]
    #
    # === Usage Notes
    # Use this rather than SolrDocument#get_shelf_numbers wherever the list of
    # call numbers might be compared against #shelf_browse_number.
    #
    def shelf_browse_numbers(doc = nil, lc_only = false)
      doc ||= @document
      doc.is_a?(UVA::IndexDoc) ? doc.get_call_numbers : []
    end

  end

end
