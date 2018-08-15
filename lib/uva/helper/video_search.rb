# lib/uva/helper/video_search.rb

require 'uva'

module UVA::Helper

  # UVA::Helper::VideoSearch
  #
  module VideoSearch

    include UVA
    include UVA::Helper::CallNumber
    include UVA::Helper::Links

    # The static list of video categories.
    VIDEO_GENRES ||= %w(
      Action/Adventure
      Animation
      Biography
      Children/Family
      Comedy
      Crime/Mystery
      Documentary
      Drama
      Experimental
      Film\ Noir
      Historical
      Horror
      Music/Musical
      Romance
      SciFi/Fantasy
      Television
      War
      Western
    ).deep_freeze

    # The description of a video in the popup details display is limited to
    # this number of characters.
    VIDEO_SUMMARY_MAX_LENGTH = 800

    # If the description of a video is truncated, this string is appended to
    # its display.
    VIDEO_SUMMARY_OMISSION = ' [...]'.freeze

    # Formats to avoid showing in video lens results.
    VIDEO_SKIP_FORMATS = [
      /Computer/i,
      /Government/i,
      /Script/i,
      /Sound/i,
      /^Video$/i,
      /^Visual Materials$/i,
    ].freeze

    # =========================================================================
    # :section:
    # =========================================================================

    public

    # A list of matching values for the :video_genre Solr facet.
    #
    # @param [String, Regexp] selector  If *nil*, all values are returned.
    #
    # @return [Array<String>]
    #
    def video_genres(selector = nil)
      case selector
        when String then VIDEO_GENRES.select { |v| v.include?(selector) }
        when Regexp then VIDEO_GENRES.select { |v| v =~ selector }
        else             VIDEO_GENRES
      end
    end

    # Strips out "Video" from format list for video materials and wraps in a
    # <span>.
    #
    # @param [UVA::IndexDoc] doc
    #
    # @return [ActiveSupport::SafeBuffer]
    #
    def video_format(doc)
      doc.get_format.map { |format|
        # Normalize certain formats.
        format = format.sub(/^(Online)\s+.*$/i, '\1')
        format = format.sub(/^Streaming\s+.*$/i, 'Online')
        # Create CSS class name (replacing slash-separated values with
        # hyphen-separated ones).
        class_name = format.downcase.tr('/', '-').tr(' ', '_')
        # Don't show "video" as a format because it confuses users.
        next if match_any(class_name, VIDEO_SKIP_FORMATS)
        # Add a space before and after slashes in format names to prevent
        # line-clobbering lengths.
        format_name = format.gsub(%r{/}, "#{HAIR_SP}/#{HAIR_SP}").html_safe
        # Wrap the value in an HTML <span>.
        content_tag(:span, format_name, class: "format-value #{class_name}")
      }.compact.uniq.join.html_safe
    end

    # Makes a list of run time(s) associated with the document annotated with
    # a time unit.
    #
    # @param [UVA::IndexDoc] doc
    # @param [String]        time_unit  Default "min."; none if set to *nil*.
    #
    # @return [ActiveSupport::SafeBuffer]
    # @return [nil]                     If *doc* did not have an run times.
    #
    def video_run_time(doc, time_unit = 'min.')
      values = doc.values_for(:video_run_time_display)
      values.map! { |v| "#{v} #{time_unit}" if v.present? } if time_unit
      values.compact!
      values.join(LIST_SEPARATOR).html_safe if values.present?
    end

    # Strips out VIDEO, pt. nn, and parenthetical volume info from call number.
    #
    # @param [UVA::IndexDoc] doc
    # @param [Hash]          opt
    #
    # @return [ActiveSupport::SafeBuffer]
    # @return [nil]
    #
    # @see self#call_number_display
    #
    def video_call_number_display(doc, opt = {})
      call_number_display(doc, opt.merge(video: true))
    end

    # =========================================================================
    # :section:
    # =========================================================================

    public

    # video_details_popup
    #
    # @param [UVA::IndexDoc] doc
    # @param [Hash]          link_opts
    #
    # @return [ActiveSupport::SafeBuffer]
    #
    # @see app/assets/javascripts/feature/video-popup
    #
    # === Usage Notes
    # The <div class="more-info"> DOM element that this method creates must be
    # a sibling of a DOM element with class="see-more-info".  That element is
    # the one which responds to mouse hover events to show/hide this popup.
    #
    def video_details_popup(doc, link_opts = {})

      # === Item title
      video = (doc.medium =~ /video[ ,-]*recording/i)
      title_opt = video ? { except: [:medium] } : {}
      title = doc.show_full_title(title_opt)
      title = link_to_document(doc, link_opts.merge(label: title))

      # === Item thumbnail
      summary = doc.export_plot_summary
      thumbnail_class = 'cover-summary'
      thumbnail = []
      thumbnail << index_thumbnail(doc, link_opts)
      if summary.blank?
        thumbnail_class << ' cover-only'
      else
        thumbnail <<
          truncate(
            summary,
            length:   VIDEO_SUMMARY_MAX_LENGTH,
            omission: VIDEO_SUMMARY_OMISSION
          )
      end
      thumbnail = thumbnail.join(NEWLINE).html_safe

      # === Item metadata
      availability = []
      unless doc.online_only?
        availability << link_to('Check availability', catalog_path(doc.doc_id))
        availability << { value: { class: 'availability multiple-copies' } }
      end
      fields = UVA::View::FieldSet.new(
        'Director'     => doc.export_directors,
        'Release Date' => :release_date_facet,
        'Run Time'     => video_run_time(doc),
        'Availability' => availability,
      )
      metadata = fields.render(:index, doc)

      # Return with the <div> that contains all of the parts of the popup.
      content_tag(:div, class: 'more-info') do
        content_tag(:h2, title) +
          content_tag(:div, thumbnail, class: thumbnail_class) +
          content_tag(:dl, metadata, class: 'more-info-metadata')
      end

    end

  end

end
