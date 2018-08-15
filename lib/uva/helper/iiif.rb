# lib/uva/helper/iiif.rb

require 'uva'

module UVA::Helper

  # UVA::Helper::Iiif
  #
  module Iiif

    include UVA
    include UVA::Accessibility

    THUMBNAIL_ALT = 'Preview of the page of digitized material.'.freeze

    PDF_REQUEST      = 'Download PDF'.freeze
    PDF_REQUEST_TIP  = 'The PDF will be generated from the scanned images ' \
                       'for this item.'.freeze
    PDF_REQUEST_MSG  = 'This PDF has already been downloaded.'.freeze

    PDF_PREP         = '(preparing PDF)'.freeze
    PDF_PREP_TIP     = 'An external service is generating the PDF...'.freeze

    PDF_ERROR        = 'Error preparing PDF'.freeze
    PDF_ERROR_TIP    = 'Click here to retry.'.freeze

    PDF_RETRIEVE     = 'Receive PDF'.freeze
    PDF_RETRIEVE_TIP = 'Click here to receive the PDF download.'.freeze

    DND_URL      = 'http://xxx.virginia.edu'.freeze
    DND_ALT      = 'IIIF Drag-n-drop'.freeze
    DND_LABEL    = 'Click on this icon or drag into a IIIF viewer.'.freeze
    DND_MORE     = '(Learn more)'.freeze
    DND_MORE_URL = 'http://iiif.io/community/faq/'.freeze

    # =========================================================================
    # :section:
    # =========================================================================

    public

    # Hidden element with the data needed for the embedded IIIF viewer and
    # associated JavaScript functions.
    #
    # @param [UVA::IndexDoc] doc
    # @param [Hash]          opt
    #
    # @return [ActiveSupport::SafeBuffer]
    #
    def iiif_data(doc, opt = nil)
      html_opt = {
        id:            'iiif-data',
        'data-info' => doc.get_iiif_array.to_json,
        'data-pdf'  => doc.values_for(:pdf_url_display).first || '',
        ARIA_HIDDEN => true
      }
      html_opt.merge!(opt) if opt.is_a?(Hash)
      content_tag(:div, '', html_opt)
    end

    # iiif_thumbnail_gallery
    #
    # @param [UVA::IndexDoc] doc
    # @param [Hash, nil]     opt       @see self#iiif_thumbnail
    #
    # @return [ActiveSupport::SafeBuffer]
    #
    def iiif_thumbnail_gallery(doc, opt = nil)
      html_opt = {
        class:   'streaming-thumbnail',
        pdf_url: doc.values_for(:pdf_url_display).first,
        link:    (doc.get_iiif_array.size > 1)
      }
      html_opt.merge!(opt) if opt.is_a?(Hash)
      content_tag(:div, class: 'streaming-thumbnail-container') do
        doc.get_iiif_array.map { |iiif|
          iiif_thumbnail(iiif, html_opt)
        }.join("\n").html_safe
      end
    end

    # iiif_thumbnail
    #
    # @param [Hash] iiif
    # @param [Hash] opt
    #
    # @option opt [String]  :anchor
    # @option opt [String]  :pdf_url   Default: `doc[:pdf_url_display].first`
    # @option opt [Boolean] :link      If true show "Open in Viewer".
    #
    # @return [ActiveSupport::SafeBuffer]
    #
    def iiif_thumbnail(iiif, opt = nil)
      pid = iiif['pid']
      html_opt = { id: pid }
      html_opt.merge!(opt) if opt.is_a?(Hash)
      anchor  = html_opt.delete(:anchor)
      pdf_url = html_opt.delete(:pdf_url)
      link    = html_opt.delete(:link)

      thumbnail = image_tag(iiif['thumbnail'], alt: THUMBNAIL_ALT)

      url_opt = { id: pid }
      url_opt[:anchor] = anchor if anchor.present?
      viewer_url = portal_show_path(url_opt)

      open_in_viewer =
        link && link_to('Open in Viewer', viewer_url, class: 'open-iiif-link')
      open_in_viewer ||= ''.html_safe

      content_tag(:div, html_opt) do
        link_to(thumbnail, viewer_url, ARIA_HIDDEN => true, tabindex: -1) +
          content_tag(:div, iiif['call_number'], class: 'image-caption') +
          open_in_viewer +
          iiif_pdf_download(pid, pdf_url) +
          iiif_drag_and_drop(pid, iiif)
      end
    end

    # iiif_pdf_download
    #
    # @param [String] pid
    # @param [String] pdf_url
    #
    # @return [ActiveSupport::SafeBuffer]
    #
    def iiif_pdf_download(pid, pdf_url)
      return ''.html_safe unless pid.present? && pdf_url.present?

      request_url  = "#{pdf_url}/#{pid}"
      retrieve_url = "#{request_url}/download"
      hidden = { style: 'display: none' }

      content_tag(:div, class: 'pdf-container') do
        link_to(
          PDF_REQUEST,
          request_url,
          class: 'request', title: PDF_REQUEST_TIP, tabindex: 0,
          'data-msg' => PDF_REQUEST_MSG
        ) +
        content_tag(
          :span,
          PDF_PREP,
          hidden.merge(class: 'prep', title: PDF_PREP_TIP)
        ) +
        link_to(
          PDF_ERROR,
          request_url,
          hidden.merge(class: 'error', title: PDF_ERROR_TIP, tabindex: 0)
        ) +
        out_link(
          PDF_RETRIEVE,
          retrieve_url,
          hidden.merge(class: 'retrieve', title: PDF_RETRIEVE_TIP, tabindex: 0)
        )
      end
    end

    # iiif_drag_and_drop
    #
    # @param [String] pid
    # @param [Hash]   iiif
    #
    # @return [ActiveSupport::SafeBuffer]
    #
    # === Implementation Notes
    # Oddly, Mirador will not accept the "pid" parameter value wrapped in
    # double-quotes (although it's OK with that for the other parameters).
    #
    def iiif_drag_and_drop(pid, iiif)
      return ''.html_safe unless pid.present? && iiif.present?

      dnd_icon = image_tag('catalog/iiif-drag-icon.png', alt: DND_ALT)
      dnd_url  = "#{DND_URL}?pid=#{pid}&"
      dnd_url << {
        manifest: iiif_manifest_url(id: pid),
        canvas:   iiif['first_canvas_id'],
      }.map { |k, v| %Q(#{k}="#{v}") }.join('&')
      dnd_opt = { class: 'iiif-icon', title: false, ARIA_LABEL => DND_ALT }

      content_tag(:div, class: 'dnd-container') do
        out_link(dnd_icon, dnd_url, dnd_opt) +
          content_tag(:span, class: 'description') do
            ERB::Util.h(DND_LABEL) + out_link(DND_MORE, DND_MORE_URL)
          end
      end
    end

  end

end
