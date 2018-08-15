# lib/uva/helper/availability.rb

require 'uva'

module UVA::Helper

  # UVA::Helper::Availability
  #
  module Availability

    include UVA
    include UVA::Accessibility
    include UVA::Helper::Library
    include UVA::Helper::Links
    include UVA::Helper::SemesterAtSea
    include UVA::Helper::Xtf

    # Online provider linkages.
    #
    # Each entry is a Hash that may contain the following fields:
    #
    #   :h2_title   The heading title for the availability box (default:
    #                 "Availability").
    #
    #   :h3_title   The name of the online source that appears on the left
    #                 within the availability listing area.
    #
    #   :h3_link    The home page (or other characteristic URL) for the source
    #                 of online content.
    #
    #   :h3_logo    The URL of a characteristic image for the source of online
    #                 content.
    #
    #   :h3_tip     The text of the tooltip to display when the mouse hovers
    #                 over the name of the online source.
    #
    #   :link_label The text for the hyperlink which leads to the online
    #                 version of the item.
    #
    # @see self#show_page_availability
    #
    ONLINE_SOURCE = {

      default: {
        h2_title:   'Availability',
      },

      article: {
        h2_title:   'Availability',
        h3_title:   :not_used
      },

      hathi: {
        h2_title:   'Access online',
        h3_title:   'HathiTrust',
        h3_link:    'https://www.hathitrust.org',
        h3_logo:    'https://www.hathitrust.org/sites/www.hathitrust.org' \
                    '/themes/hathitrust_unicorn/images/hathi' \
                    '/hathi_logo_light.jpg',
        h3_tip: %q(
          HathiTrust is a partnership of academic & research institutions,
          offering a collection of millions of titles digitized from libraries
          around the world.
        ).squish,
      },

      lib_coins: {
        h2_title:   'Full Numismatic Record',
        h3_title:   'UVA Art Museum',
        h3_link:    'https://xxx.virginia.edu',
        h3_logo:    'https://xxx.virginia.edu/xxx' \
                    '/artmuseum.virginia.edu/xxx',
        h3_tip:     'The Fralin Museum of Art at the University of Virginia.',
        link_label: 'View coin information online'
      },

      hsl_tutorial: {
        h2_title:   'Access online',
        h3_title:   'Bioconnector Tutorial',
        h3_link:    'https://xxx.virginia.edu',
        h3_logo:    'https://xxx.virginia.edu/xxx/' \
                    'favicon_0.ico',
        link_label: 'View tutorial page online',
      },

    }.deep_freeze

    # =========================================================================
    # :section:
    # =========================================================================

    public

    # Return "Available" or "Unavailable".
    #
    # @param [Firehose::Holding] holding
    # @param [Firehose::Copy]    copy
    #
    # @return [String]                    Non-blank result.
    #
    # @see UVA::Helper::Library#workflow_status_field
    #
    def availability_label(holding, copy)
      status = workflow_status_field(__method__, holding, copy)
      result = (status.join(SPACE) if status.present?)
      result ||= SAS_AVAILABILITY_SHORT if is_sas(holding)
      result ||= 'Available' if copy && copy.available?
      result ||= 'Unavailable'
      result << ' to Order' if copy && copy.not_ordered?
      result
    end

    # Style to be used for availability text.
    #
    # @param [Firehose::Holding] holding
    # @param [Firehose::Copy]    copy
    #
    # @return [String]                    Non-blank result.
    #
    # @see UVA::Helper::Library#workflow_status_field
    #
    def availability_mode(holding, copy)
      status = workflow_status_field(__method__, holding, copy)
      result = (status.join(SPACE) if status.present?)
      result ||= 'available' if copy && copy.available?
      result || 'unavailable'
    end

    # The availability indicator as a button.
    #
    # @param [Firehose::Holding] holding
    # @param [Firehose::Copy]    copy
    # @param [Hash]              opt      Passed to self#availability_link
    #
    # @return [ActiveSupport::SafeBuffer]
    #
    # @see self#availability_link
    # @see UVA::Helper::Library#workflow_status_field
    # @see app/assets/javascripts/feature/availability
    #
    def availability_button(holding, copy, opt = nil)
      opt ||= {}
      opt[:av_mode]  ||= availability_mode(holding, copy)
      opt[:av_label] ||= availability_label(holding, copy)
      availability_link(opt)
    end

    # The availability link.
    #
    # @param [Array] *args
    #
    # @return [ActiveSupport::SafeBuffer]
    #
    # @see self#availability_indicator
    #
    def availability_link(*args)
      html_opt =
        dialog_button_opts(
          title:    'Click for individual item status.',
          disabled: false
        )
      html_opt.merge!(args.extract_options!)
      html_opt.except!(:title, ARIA_ROLE, ARIA_HASPOPUP) if html_opt[:disabled]

      # If this method is being used outside of #availability_button then it's
      # likely that label and path have been passed in through the arguments.
      if args.present?
        html_opt[:class]  ||= ''
        html_opt[:av_mode]  = nil
        html_opt[:av_label] =
          if args.first.is_a?(ActiveSupport::SafeBuffer)
            args.first
          elsif args.size >= 2
            link_to(*args)
          else
            link_to('', *args)
          end
      else
        html_opt[:tabindex] ||= html_opt[:disabled] ? -1 : 0
      end

      # Strip out the options that will be attached to the surrounding <span>
      # rather than passed on to the underlying link.
      span_opt = {}
      tooltip = html_opt.delete(:title)
      span_opt[:title] = tooltip unless tooltip.is_a?(FalseClass)

      content_tag(:span, span_opt) do
        availability_indicator(html_opt)
      end
    end

    # The base availability indicator element.
    #
    # @param [Hash] opt
    #
    # @option opt [String] :av_mode
    # @option opt [String] :av_label
    # @option opt [String] :disabled
    #
    # @return [ActiveSupport::SafeBuffer]
    #
    def availability_indicator(opt = nil)
      html_opt = {
        av_mode:  'unavailable',
        class:    'availability-indicator',
        disabled: true
      }
      html_opt.merge!(opt) if opt.present?
      disabled = html_opt.delete(:disabled)
      av_mode  = html_opt.delete(:av_mode)
      av_label = html_opt.delete(:av_label)

      case av_label
        when false then av_label = ''
        when true  then av_label = nil
      end
      av_label ||= av_mode.to_s.capitalize

      css_class = Array.wrap(html_opt[:class])
      css_class << av_mode
      css_class << 'active' unless disabled
      html_opt[:class] = css_class.compact.join(' ')

      html_opt.except!(:tabindex, ARIA_EXPANDED) if disabled

      content_tag(:span, html_opt) do
        ERB::Util.h(av_label)
      end
    end

    # =========================================================================
    # :section:
    # =========================================================================

    public

    # Determines whether or not availability should display on search results.
    #
    # If there is a single copy, availability is show directly.  If there are
    # multiple copies the "View Locations and Availability" link is shown.
    #
    # @param [UVA::IndexDoc] doc
    #
    def availability_on_index?(doc)
      availability = doc.has_refresh_availability? && doc.availability
      return false unless availability
      return true  if classic_lens?
      barcodes = doc.values_for(:barcode_facet)
      total_copies = availability.existing_copies
      return true  if (barcodes.size <= 1) && (total_copies <= 1)
      return false if doc.values_for(:library_facet).size > 1
      availability.available_copies == total_copies
    end

    # Indicate whether the availability table should be shown.
    #
    # @param [UVA::IndexDoc] doc
    #
    def show_holdings?(doc)
      !doc.non_physical? || doc[:special_collections_holding_display].present?
    end

    # show_page_availability
    #
    # @param [UVA::IndexDoc] doc
    # @param [Hash]          link_opt
    #
    # @return [Array<(String, String, String, Array)>]
    #   - All strings are HTML-safe.
    #   - return[0] == h2_title
    #   - return[1] == h3_title
    #   - return[2] == link
    #   - return[3] == array of titles and links for articles
    #
    # @see self#ONLINE_SOURCE
    # @see /app/views/catalog/show/shared/_availability_box.html.erb
    #
    def show_page_availability(doc, link_opt = nil)

      type    = doc.doc_type
      subtype = doc.doc_sub_type
      if (subtype == :dl_book) || doc.has_feature?('has_djatoka_image')
        type = :dl_book
      end

      # Look up online source characteristics if present for the type.
      entry = ONLINE_SOURCE[type] || ONLINE_SOURCE[:default]
      h2_title   = entry[:h2_title]
      h3_title   = entry[:h3_title] || online_access_label(doc).titlecase
      h3_link    = entry[:h3_link]
      h3_logo    = entry[:h3_logo]
      h3_tip     = entry[:h3_tip]
      link_label = entry[:link_label]

      # Prepare section header.
      h2_title = ERB::Util.h(h2_title)

      # If additional information was provided for the online source label,
      # wrap it in a link element with added attributes.
      if h3_title.is_a?(Symbol)
        h3_title = nil
      elsif h3_logo || h3_link || h3_tip
        html_opt = { class: 'online-source' }
        html_opt[:title] = h3_tip if h3_tip
        h3_link ||= '#'
        h3_title =
          out_link(h3_link, html_opt) do
            entry = ''
            entry << image_tag(h3_logo, class: 'logo') if h3_logo
            entry << content_tag(:div, h3_title, class: 'source')
            entry.html_safe
          end
      end

      # Generate a link for the given document type unless it was explicitly
      # indicated as :none.
      link =
        case type
          when :hathi, :hsl_tutorial, :dataverse, :lib_technical_report
            nil
          when :dl_book, :dl_image
            link_url     = doc.dl_jp2k_viewer_applet
            link_label ||= "http://#{request.host_with_port}#{link_url}"
            out_link(link_label, link_url, link_opt)
          when :lib_coins
            link_url     = doc.get_url.first
            link_label ||= link_url
            out_link(link_label, link_url, link_opt)
          when :dl_text
            xtf_link(doc, link_opt)
          else
            :none unless doc.has_marc? && doc.get_url.first
        end
      link ||= link_to_online_access(doc, label: link_label)
      link = nil if link == :none

      # The link table is exclusively for articles.
      link_table = (doc.availability_links if type == :article)

      return h2_title, h3_title, link, link_table

    end

  end

end
