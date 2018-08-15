# lib/uva/helper/google_preview.rb

require 'uva'

module UVA::Helper

  # UVA::Helper::GooglePreview
  #
  module GooglePreview

    include UVA
    include UVA::Helper::Layout

    # =========================================================================
    # :section:
    # =========================================================================

    public

    class << self

      HOST = 'books.google.com'.freeze

      # Google Preview root.
      #
      # @return [String]
      #
      # === Implementation Notes
      # If/when Google redirects, it redirects to HTTPS so make sure that the
      # initial request starts as HTTPS.
      #
      def root
        "https://#{HOST}"
      end

      # Path to Google Preview script.
      #
      # @return [String]
      #
      def base_path
        "#{root}/books"
      end

      # Path to Google Preview icon resource.
      #
      # @return [String]
      #
      def icon_path
        "//#{HOST}/intl/en/googlebooks/images/gbs_preview_button1.gif"
      end

    end

    # =========================================================================
    # :section:
    # =========================================================================

    public

    # Google Preview icon with empty alt text since the image is "decorative"
    # and announcing the alt text would not be helpful.
    #
    # @return [ActiveSupport::SafeBuffer]
    #
    def google_preview_icon(path = nil)
      path ||= GooglePreview.icon_path
      image_tag(path, style: 'border:0;', alt: '')
    end

    # Google Preview control.
    #
    # The control starts out hidden (by including CSS class 'hide'); if the
    # controlling JavaScript receives a valid preview URL from Google it will
    # remove the 'hide' class to uncover the control.
    #
    # @param [UVA::IndexDoc] doc
    # @param [Hash]          opt
    #
    # @return [ActiveSupport::SafeBuffer]
    # @return [nil]
    #
    # @see app/assets/javascripts/feature/google-preview
    #
    def google_preview_control(doc, opt = nil)

      return unless doc.is_a?(UVA::IndexDoc)
      html_opt = {
        title: ((doc.doc_type == :kluge) ? 'Read Online' : 'Google Preview'),
        class: 'holding google-preview'
      }
      html_opt.merge!(opt) if opt.present?

      # Provide the link with data items that will be used when requesting the
      # data from Google Books.
      data_items = {
        'isbn'     => doc.isbns,
        'oclc'     => doc.oclcs,
        'lccn'     => doc.lccns,
      }.select { |item, value|
        html_opt["data-#{item}".to_sym] ||= value.join(',').presence
      }
      return if data_items.blank?

      # JavaScript will use the data items from the control to query Google for
      # data to update the href of the link.
      title = html_opt.delete(:title)
      html_opt[:class] += ' hide' # hidden initially
      content_tag(:div, html_opt) do
        content_tag(:h3, title) +
        external_link(google_preview_icon, '#', ARIA_LABEL => title)
      end
    end

  end

end
