# lib/uva/helper/wsls.rb

require 'uva'

module UVA::Helper

  # UVA::Helper::Wsls
  #
  module Wsls

    include UVA
    include UVA::Accessibility

    WSLS_FACET =
      'WSLS-TV (Roanoke, VA) News Film Collection, 1951 to 1971'.freeze

    WSLS_COPYRIGHT_URL =
      'https://xxx.virginia.edu/xxx/'.freeze

    WSLS_COPYRIGHT_NOTICE = %q(
      Each user of the WSLS materials must individually evaluate any copyright
      or privacy issues that might pertain to the intended uses of these
      materials, including fair use.
    ).squish.freeze

    # =========================================================================
    # :section:
    # =========================================================================

    public

    # copyright_notice_html
    #
    # @param [UVA::IndexDoc] doc
    #
    # @return [ActiveSupport::SafeBuffer]
    #
    def copyright_notice_html(doc)
      wsls_copyright_notice_html if doc.get_collection.include?(WSLS_FACET)
    end

    # wsls_copyright_notice_html
    #
    # @return [ActiveSupport::SafeBuffer]
    #
    # @see self#copyright_notice_html
    #
    def wsls_copyright_notice_html
      result =  "#{WSLS_COPYRIGHT_NOTICE}<br/>"
      result << out_link('Read more.', WSLS_COPYRIGHT_URL)
      result.html_safe
    end

    # anchor_script_summary
    #
    # @param [UVA::IndexDoc] doc
    #
    # @return [String]
    # @return [nil]
    #
    def anchor_script_summary(doc)
      script = doc.values_for(:anchor_script_display).join(ITEM_SEPARATOR)
      summarize_script_text(script) if script.present?
    end

    # summarize_script_text
    #
    # @param [String] text
    #
    # @return [String]
    # @return [nil]
    #
    # @see self#anchor_script_summary
    #
    def summarize_script_text(text)
      return nil if text.nil?
      match =
        /TELE[ ]?NEWS DAILY/.match(text) &&
          /\d+\.\t\d+\t\d+(\t\d+)?\t[^\t\n]*\t([^.\t\n]*[.\n])/.match(text)
      return match[2] if match
      match =
        # Some scripts are delimited with lines like LIVE.
        /\nLIVE\t((?:[[:upper:]]\w*)(?:[[:blank:]]+[a-zA-Z0-9_\-"'()]+,?){4,}(\n|\.))/.match(text) ||
          # Some scripts use tabs before meaningful lines, in those cases we should
          # exclude lines without tabs.
          /\t((?:[[:upper:]]\w*)(?:[[:blank:]]+[a-zA-Z0-9_\-"']+,?){4,}(\n|\.))/.match(text) ||
          /[[:space:]]((?:[[:upper:]]\w*)(?:[[:space:]]+\w+,?){4,}\.)/.match(text) ||
          # Try some cases that should only be considered if nothing else matches.
          /\nLIVE\t([^\n]*)\n/.match(text)
      match && match[1]
    end

    # show_anchor_script_thumbnails
    #
    # @param [UVA::IndexDoc] doc
    #
    # @return [ActiveSupport::SafeBuffer]
    #
    def show_anchor_script_thumbnails(doc)
      thumbnail_url = doc.values_for(:anchor_script_thumbnail_url_display).first
      pdf_url       = doc.values_for(:anchor_script_pdf_url_display).first
      return unless thumbnail_url && pdf_url

      caption_opts = { class: 'image-caption' }

      # Thumbnail link to PDF image.
      links = [image_tag(thumbnail_url, ARIA_HIDDEN => true)]

      # PDF image link.
      label = 'View anchor script image'
      links << content_tag(:div, out_link(label, pdf_url), caption_opts)

      # Text link.
      if (script = anchor_script_text_url(doc))
        label = 'View anchor script text'
        links << content_tag(:div, out_link(label, script), caption_opts)
      end

      content_tag(:div, class: 'streaming-thumbnail') do
        links.join(NEWLINE).html_safe
      end
    end

    # If the the Solr document doesn't contain a anchor_script_text_url_display
    # field, the anchor_script_pdf_url_display is altered to replace "PDF" with
    # "TXT" - this can be removed if we ensure that the request handler and
    # index both include that field.
    #
    # @param [UVA::IndexDoc] doc
    #
    # @return [String]
    # @return [nil]
    #
    # @see self#show_anchor_script_thumbnails
    #
    def anchor_script_text_url(doc)
      result = doc.values_for(:anchor_script_text_url_display).first
      if result.blank?
        result = doc.values_for(:anchor_script_pdf_url_display).first
        result = result.blank? ? nil : result.sub('PDF', 'TXT')
      end
      result
    end

  end

end
