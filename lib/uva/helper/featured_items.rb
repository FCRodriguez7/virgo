# lib/uva/helper/featured_items.rb

require 'uva'

module UVA::Helper

  # Featured titles as displayed through VideoController and MusicController.
  #
  # @see FeaturedItemsConcern
  #
  module FeaturedItems

    include UVA
    include UVA::Portal

    FEATURED_LABEL = {
      music: 'Recently Added Items',
      video: 'Featured Titles'
    }.deep_freeze

    # =========================================================================
    # :section:
    # =========================================================================

    public

    # Slices the @featured_documents up into to arrays/"rows".
    # This makes it easy to do "rows" in the view.
    #
    # @param [Array<UVA::IndexDoc>] featured
    #
    # @return [Array<UVA::IndexDoc>]
    #
    def featured_documents_rows(featured = nil)
      featured ||= @featured_documents
      featured ? featured.compact.each_slice(4).to_a : []
    end

    # featured_label
    #
    # @return [String]
    # @return [nil]
    #
    def featured_label
      FEATURED_LABEL[featured_type]
    end

    # featured_title
    #
    # @return [String]
    # @return [nil]
    #
    def featured_title
      type = featured_type
      "#{type.to_s.capitalize} #{FEATURED_LABEL[type]}" if type.present?
    end

    # content_divider
    #
    # @param [Hash] opt
    #
    # @return [ActiveSupport::SafeBuffer]
    #
    def content_divider(opt = nil)
      html_opt = {
        class:         'divider',
        size:          '490x5',
        alt:           '',
        ARIA_HIDDEN => true
      }
      html_opt.merge!(opt) if opt.present?
      image_tag('content_divider.png', html_opt)
    end

    # =========================================================================
    # :section:
    # =========================================================================

    protected

    # featured_type
    #
    # @return [Symbol]
    # @return [nil]
    #
    def featured_type
      if video_lens?
        :video
      elsif music_lens?
        :music
      end
    end

  end

end
