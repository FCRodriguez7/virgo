# lib/uva/helper/kluge_ruhe.rb

require 'uva'

module UVA::Helper

  # UVA::Helper::KlugeRuhe
  #
  module KlugeRuhe

    include UVA

    # Document types to which this module applies.
    UNIQUE_SITE = {
      kluge: {
        label: 'Kluge-Ruhe Study Center',
        url:   'http://www.kluge-ruhe.org/publications/study-center',
        name:  nil, # same as label
        site:  'Kluge-Ruhe Aboriginal Art Collection of the University of Virginia'
      },
      cnhi: {
        label: 'Bjoring Center for Nursing Historical Inquiry',
        url:   'https://xxx.virginia.edu/xxx/',
        name:  'Eleanor Crowder Bjoring Center for Nursing Historical Inquiry',
        site:  'University of Virginia School of Nursing, McLeod Hall #1010'
      }
    }.deep_freeze

    # =========================================================================
    # :section:
    # =========================================================================

    public

    # Indicate whether the given document or type symbol is associated with a
    # unique site to be handled like Kluge-Ruhe entries.
    #
    # @param [UVA::IndexDoc, Symbol] doc   The document type as a symbol or the
    #                                        the document itself.
    #
    # @return [Symbol]
    # @return [nil]
    #
    def unique_site_type(doc)
      doc_type =
        if doc.is_a?(Symbol)
          doc
        elsif doc.is_a?(UVA::IndexDoc)
          doc.has?(:doc_type_facet, 'cnhi') ? :cnhi : doc.doc_type
        end
      doc_type if UNIQUE_SITE.has_key?(doc_type)
    end

    # A notice about Kluge-Ruhe items or Center for Nursing Historical Inquiry
    # that is included near the bottom of availability information.
    #
    # @param [UVA::IndexDoc, Symbol] doc   The document type as a symbol or the
    #                                        the document itself.
    #
    # @return [ActiveSupport::SafeBuffer]  Content to display.
    # @return [nil]                        If *doc* does not have one of the
    #                                        types in `self#UNIQUE_SITE.keys`.
    #
    def about_kluge_ruhe(doc)

      # Document type may be overridden by :doc_type_facet.
      doc_type = unique_site_type(doc)
      return unless doc_type
      doc = nil if doc.is_a?(Symbol)

      # Use text if provided by the index record, otherwise construct from the
      # information in this module.
      text = []
      text += doc.values_for(:availability_display) if doc
      if text.blank?
        type  = UNIQUE_SITE[doc_type]
        url   = type[:url]
        label = type[:label] || url
        name  = type[:name]  || label
        site  = type[:site]
        link  = external_link(label, url)
        text << %Q(
          This item is available for use only in the #{name},
          housed within the #{site}.
          For information on viewing this item,
          please visit the #{link} web page.
        )
      end

      content_tag(:div, class: 'holdings policy-explanation') do
        text.join(SPACE).squish.html_safe
      end
    end

  end

end
