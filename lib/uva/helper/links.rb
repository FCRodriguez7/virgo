# lib/uva/helper/links.rb

require 'uva'

module UVA::Helper

  # UVA::Helper::Links
  #
  module Links

    include UVA
    include UVA::AccessRestrictions
    include UVA::Scope
    include UVA::Util::HtmlMethods
    include UVA::Helper::Fedora
    include UVA::AdvancedSearch::AdvancedSearchFields

    # =========================================================================
    # :section:
    # =========================================================================

    public

    # If the links are within a "display:flex" container, don't use '<br/>'
    # here; it's harmless in Firefox but Webkit-based engines will treat it as
    # one of the elements to flex.
    DEFAULT_LINK_SEPARATOR = "\n".freeze

    ACTION_LINK_BUTTON_LABEL = 'Return'.freeze

    # Unique collection-level record mapped on to the Fedora PID used to
    # represent it as a thumbnail image.
    COLLECTION_THUMBNAIL = {
      'uva-lib:2528441' => 'uva-lib:2450079', # Our Mountain Work
      'uva-lib:2513789' => 'uva-lib:2369861', # Walter Reed Yellow Fever
      'uva-lib:2253857' => 'uva-lib:2242838', # Our Mountain Work in the Diocese of Virginia
      'uva-lib:2250968' => 'uva-lib:2209820', # Corks and Curls
      'uva-lib:2137307' => 'uva-lib:2672940', # Daily Progress Digitized Microfilm
    }.deep_freeze

    OTHER_RESOURCES_LINKS = {
      'Subject Guides'      => URL::RESEARCH,
      'Journal Finder'      => URL::JOURNAL_FINDER,
      'Databases A&ndash;Z' => URL::DATABASES,
    }.deep_freeze

    # Certain link labels need to be translated into something more useful;
    # this is a table of patterns (String or Regexp) matching link labels that
    # with the labels to use in their place.
    TRANSLATED_LINK_LABELS = {
      'Inhaltsverzeichnis' => 'Table of contents'
    }.deep_freeze

    # Certain link labels (usually from MARC 856$z fields) are unhelpful; this
    # is a list of patterns (String or Regexp) matching link labels that are
    # to be ignored.
    IGNORED_LINK_LABELS = [
      'PURL accesses',
      'Adobe Acrobat'
    ].deep_freeze

    # Parameters to discard when creating an RSS link from search parameters.
    IGNORE_FOR_RSS = [
      :action,
      :page,
      :catalog_select,
      :sort,
      :sort_key,
      :utf8
    ].freeze

    # JavaScript statements that can be combined for inline JavaScript within
    # an "href".
    JAVASCRIPT = {
      close_tab:      'close()',
      print_tab:      'window.print()',
      history_back:   'window.history.back()',
      close_colorbox: '$.fn.colorbox.close()',
      close_iframe:   'parent.$.fn.colorbox.close()',
    }.deep_freeze

    # =========================================================================
    # :section: Blacklight::BlacklightHelperBehavior overrides
    # =========================================================================

    public

    # link_to_document
    #
    # @param [UVA::IndexDoc] doc
    # @param [Hash]          opt
    #
    # @option opt [Boolean]        :no_link    Just set up the cover image.
    # @option opt [Boolean]        :path_only  Just return the URL, not HTML.
    # @option opt [Boolean]        :aside      Create link with "&aside=true".
    # @option opt [String, Symbol] :portal
    # @option opt [String]         :label
    # @option opt [Fixnum]         :counter
    # @option opt [String]         :class      If present, CSS class for label.
    # @option opt [String]         :title      If present, tooltip for label.
    # @option opt [String]         :link_class If present, CSS class for link.
    #
    # @yield []
    # @yieldreturn [String, ActiveSupport::SafeBuffer]
    # If a block is provided, its return value is used as a the text within the
    # <span> instead of the value of :label.
    #
    # @return [ActiveSupport::SafeBuffer]
    #
    # Compare with:
    # @see Blacklight::BlacklightHelperBehavior#link_to_document
    #
    def link_to_document(doc, opt = nil)

      # Collect HTML attribute and method option values.
      span_opt = link_opt = {}
      if opt.present?
        span_parts, html_parts =
          opt.partition do |key, _value|
            key = key.to_s
            (key == 'class') || key.start_with?('data-')
          end
        span_opt = Hash[span_parts]
        link_opt = Hash[html_parts]
      end

      # Extract options for this method.
      label      = link_opt.delete(:label)
      image_only = link_opt.delete(:no_link)
      path_only  = link_opt.delete(:path_only)
      portal     = link_opt.delete(:portal)
      counter    = link_opt.delete(:counter)
      aside      = link_opt.delete(:aside)
      link_class = link_opt.delete(:link_class)

      # HTML attributes.
      tooltip = link_opt[:title]
      span_opt[:title] = tooltip if image_only

      # Make the label.  If :label was provided in the options, preserve it
      # long enough for #render_document_index_label to use it.  Wrap the label
      # in a <span> if :class or :title is specified.
      label = yield if block_given?
      label = render_document_index_label(doc, link_opt) if label.blank?
      label = ERB::Util.h(label)
      label = content_tag(:span, label, span_opt) if span_opt.present?

      # If directed, bypass creating the link.
      if image_only
        raise 'only one of :no_link and :path_only allowed' if path_only
        return label
      end

      # Resolve remaining options.
      link_opt[:class] = link_class if link_class
      link_opt[:'data-counter'] = counter unless print_view?

      # Make the URL.
      portal ||= portal_controller
      id = doc.doc_id
      path_params = {}
      path_params[:view]  = 'print' if print_view?
      path_params[:aside] = aside   if aside
      url = show_path(portal, id, path_params)

      # Create the link element unless directed to return only the URL.
      if path_only
        url
      elsif aside || (link_opt[:target] == '_blank')
        out_link(label, url, link_opt)
      else
        link_to(label, url, link_opt)
      end

    end

    # =========================================================================
    # :section:
    # =========================================================================

    public

    # Create a cover image link to the document show page.
    #
    # @param [UVA::IndexDoc] doc
    # @param [Hash]          opt
    #
    # @option opt [Boolean] :no_link  Just set up the cover image.
    #
    # @option opt [String]  :label
    # @option opt [Fixnum]  :counter
    # @option opt [String]  :class    If present, CSS class for label.
    # @option opt [String]  :title    If present, tooltip for label.
    #
    # @return [ActiveSupport::SafeBuffer]
    #
    def link_to_document_from_cover(doc, opt = nil)
      opt = opt ? opt.dup : {}
      opt[:label] = ajax_loader_image
      opt[:class] = "cover-image #{opt[:class]}".strip
      opt[:title]   ||= doc.doc_id
      opt[:counter] ||= -1

      # Provide the link with data items that will be used when requesting the
      # image from the cover image server.
      data_items = {
        'doc-id'   => doc.doc_id,
        'doc-type' => ((doc.doc_type == :lib_album) ? 'music' : 'non_music'),
        'title'    => doc.title,
        'upc'      => doc.upcs,
        'issn'     => doc.issns.join(','),
        'isbn'     => doc.isbns.join(','),
        'oclc'     => doc.oclcs.join(','),
        'lccn'     => doc.lccns.join(','),
        'artist'   => doc.get_authors.first,
        'ht-id'    => doc.values_for(:hathi_id_display).first
      }
      data_items.each_pair do |item, value|
        opt["data-#{item}".to_sym] ||= value if value.present?
      end

      # Wrapping the link in a <div> is required to make the position of the
      # result adjustable.
      content_tag(:div) do
        link_to_document(doc, opt)
      end
    end

    # See comment on link_to_document_from_cover above.
    # Although no ajax loading of image is done here, we still use a span for
    # consistency with markup generated by link_to_document_from_cover.
    #
    # @param [UVA::IndexDoc] doc
    # @param [Hash]          opt
    #
    # @return [ActiveSupport::SafeBuffer]
    #
    def link_to_coin_from_image(doc, opt = nil)
      image_url = doc.values_for(:thumb_obv_display).first
      return unless image_url
      opt = opt ? opt.dup : {}
      opt[:title]   ||= 'Coin image of ' + doc.export_title
      opt[:alt]     ||= doc.id
      opt[:counter] ||= -1
      opt[:label]     = image_tag(image_url, opt)
      link_to_document(doc, opt)
    end

    # Creates HTML for the Solr document ":url_display" field.
    #
    # Parses :url_display, which has the format *url||label* (often label is
    # missing) and constructs a list of links in HTML. The default link
    # separator will be an HTML break, putting each link on a separate line
    # when there are multiple links.
    #
    # @param [UVA::IndexDoc] doc
    # @param [Hash]          opt
    #
    # @option opt [String] :label
    # @option opt [String] :separator
    # @option opt [Symbol] :solr_field
    #
    # @return [ActiveSupport::SafeBuffer]
    # @return [nil]
    #
    def link_to_online_access(doc, opt = nil)
      opt = opt ? opt.dup : {}
      separator  = DEFAULT_LINK_SEPARATOR
      separator  = opt.delete(:separator) if opt.key?(:separator)
      link_text  = opt.delete(:label)
      solr_field = opt.delete(:solr_field) || :url_display

      # Get the links from Solr.
      urls = doc.values_for(solr_field)
      return if urls.blank?
      copy = 0

      # Set the link text for single Hathi items.
      if (doc.doc_type == :hathi) && (urls.size == 1)
        link_text ||= 'View full text from Hathi Trust'
      end

      result =
        urls.map do |url_entry|
          url, url_label = url_entry.split('||')
          label =
            if link_text
              # Use the link_text specified in the arguments.
              link_text
            elsif (translated_label = translate_link_label(url_label))
              # Use the translated label.
              translated_label
            elsif !ignore_link_label?(url_label)
              # Use the label provided with the URL.
              url_label
            elsif doc.doc_type == :hathi
              # Create a generic label for links to HathiTrust items.
              "Copy #{copy += 1}"
            else
              # Create a generic label from the access verb.
              online_access_label(doc)
            end
          external_link(label, url)
        end
      result.join(separator).html_safe if result.present?
    end

    # Creates HTML for the Solr document :url_supp_display field.
    #
    # @param [UVA::IndexDoc] doc
    # @param [Hash]          opt
    #
    # @option opt [String] :label
    # @option opt [String] :separator
    # @option opt [Symbol] :solr_field
    #
    # @return [ActiveSupport::SafeBuffer]
    # @return [nil]
    #
    def link_to_related_resources(doc, opt = nil)
      opt ||= {}
      link_to_online_access(doc, opt.merge(solr_field: :url_supp_display))
    end

    # Display a Libra thumbnail from Solr.
    #
    # @param [UVA::IndexDoc] doc
    # @param [Hash, nil]     link_opts
    #
    # @return [ActiveSupport::SafeBuffer]
    # @return [nil]
    #
    # @see self#index_thumbnail
    #
    def libra_thumbnail(doc, link_opts = nil)
      indexed_thumbnail(doc, link_opts)
    end

    # Display a thumbnail from Solr.
    #
    # @param [UVA::IndexDoc] doc
    # @param [Hash, nil]     link_opts
    #
    # @option link_opts [Numeric] :width    Passed to image tag.
    #
    # @return [ActiveSupport::SafeBuffer]
    # @return [nil]
    #
    def indexed_thumbnail(doc, link_opts = nil)
      return unless doc.is_a?(UVA::IndexDoc)
      url = doc.values_for(:thumbnail_url_display).first
      if url.present?
        link_opts = { width: 80 }.merge(link_opts || {})
        width = link_opts.delete(:width)
        link_to_document(doc, link_opts) { image_tag(url, width: width) }
      end
    end

    # Return a URL to Kaltura.
    #
    # @param [String] kaltura_id
    # @param [Hash]   opt
    #
    # @option opt [Fixnum] :width
    # @option opt [Fixnum] :height
    # @option opt [Fixnum] :quality
    #
    # @return [String]
    #
    def kaltura_url(kaltura_id, opt = nil)
      opt ||= {}
      width   = opt[:width]   || 80
      height  = opt[:height]  || 80
      quality = opt[:quality] || 72
      'http://cdn.kaltura.com/p/0/thumbnail' \
      "/entry_id/#{kaltura_id}" \
      "/width/#{width}" \
      "/height/#{height}" \
      '/type/1' \
      "/quality/#{quality}"
    end

    # Creates links for Kaltura videos.
    #
    # @param [UVA::IndexDoc] doc
    # @param [Hash]          opt
    #
    # @option opt [String] :text
    # @option opt [Fixnum] :limit
    # @option opt [Fixnum] :width       Passed to #kaltura_url.
    # @option opt [Fixnum] :height      Passed to #kaltura_url.
    # @option opt [Fixnum] :quality     Passed to #kaltura_url.
    #
    # @return [ActiveSupport::SafeBuffer]
    #
    # @see self#online_access_label
    # @see self#link_to_document
    # @see self#kaltura_url
    #
    def show_streaming_thumbnails(doc, opt = nil)
      urls = doc.get_url
      return if urls.blank?
      opt = opt ? opt.dup : {}
      blocked   = access_restricted(doc).first
      link_text = opt.delete(:text).presence
      limit     = opt.delete(:limit).presence

      urls = urls.first(limit) if limit
      urls.map { |url_entry|
        url, url_label = url_entry.split('||')
        url_label = nil if url_label.blank?
        label = link_text || url_label || online_access_label(doc)
        kaltura_id = url.split('entry_id/')[1]
        image = image_tag(kaltura_url(kaltura_id, opt))
        content_tag(:div, class: 'streaming-thumbnail') do
          if blocked
            image
          else
            link_label =
              image + content_tag(:span, label, class: 'image-caption')
            if doc.doc_type == :dl_wsls_video
              link_to_document(doc, opt.merge(label: link_label))
            else
              external_link(link_label, url)
            end
          end
        end
      }.join(NEWLINE).html_safe
    end

    # show_wsls_thumbnail
    #
    # @param [UVA::IndexDoc] doc
    # @param [Hash, nil]     link_opts
    #
    # @return [ActiveSupport::SafeBuffer]
    # @return [nil]
    #
    # @see self#streaming_thumbnail_and_link
    #
    def show_wsls_thumbnail(doc, link_opts = nil)
      return unless doc.is_a?(UVA::IndexDoc) && doc.get_url.present?
      url = fedora_proxy_datastream(doc, 'thumbnail/content')
      link_opts = { url: url, restricted: true }.merge(link_opts || {})
      streaming_thumbnail_and_link(doc, link_opts)
    end

    # Presents a similar-appearing link for resources that can be viewed online
    # through an embedded viewer within a Virgo item details show page.
    #
    # @param [UVA::IndexDoc] doc
    # @param [Hash]          opt      Passed to #link_to_document except for
    #                                 the internal options given below.
    #
    # @option opt [Boolean] :restricted   If *true* check access restriction.
    # @option opt [Fixnum]  :width        Image width (default: 80 [pixels]).
    # @option opt [String]  :url          Override thumbnail URL.
    #
    # @return [ActiveSupport::SafeBuffer]
    #
    def streaming_thumbnail_and_link(doc, opt = nil)
      return unless doc.is_a?(UVA::IndexDoc)
      opt = opt ? opt.dup : {}

      # If a URL was not provided, check for an internally-specified thumbnail
      # and then for a thumbnail specified through the Solr record.
      url = opt.delete(:url)
      url ||= fedora_proxy_thumbnail(COLLECTION_THUMBNAIL[doc.doc_id])
      url ||= doc.values_for(:thumbnail_url_display).first.presence
      return unless url

      image = image_tag(url)
      blocked = opt.delete(:restricted) && access_restricted(doc).first
      content_tag(:div, class: 'streaming-thumbnail') do
        if blocked
          image
        else
          text  = online_access_label(doc)
          label = image + content_tag(:span, text, class: 'image-caption')
          link_to_document(doc, opt.merge(label: label.html_safe))
        end
      end
    end

    # viewer_thumbnail_and_link
    #
    # @param [UVA::IndexDoc] doc
    # @param [Hash]          opt
    #
    # @option opt [String] :url         Override viewer URL.
    #
    # @return [ActiveSupport::SafeBuffer]
    # @return [nil]
    #
    def viewer_thumbnail_and_link(doc, opt = nil)

      return unless doc.is_a?(UVA::IndexDoc)

      # Get the thumbnail image.
      pid = nil
      if doc.has_feature?('has_djatoka_image')
        pid ||= doc.values_for(:digitized_item_pid_display).first
      end
      if (doc.doc_type == :dl_book) || (doc.doc_sub_type == :dl_book)
        pid ||= doc.doc_id
      end
      exemplar  = get_exemplar(doc.fedora_url, pid)
      return if exemplar.blank?
      image_url = doc.dl_jp2k_preview(exemplar)
      image     = image_tag(image_url, class: :photo, alt: doc.doc_id)

      # Make the thumbnail image a link if access to the item is allowed.
      if access_restricted(doc).first
        image
      else
        opt = opt ? opt.dup : {}
        viewer_path = opt.delete(:url) || doc.dl_jp2k_viewer_applet
        out_link(image, viewer_path, opt)
      end
    end

    # view_online_link
    #
    # @param [UVA::IndexDoc] doc
    # @param [Hash]          opt
    #
    # @option opt [String] :blocked_label  Static text shown if access to the
    #                                        object is blocked.
    #
    # @option opt [String] :link_label     Text on link to viewer shown if
    #                                        access to the object is not
    #                                        blocked.
    #
    # @option opt [Boolean] :show_policy   If *false* do not append the access
    #                                        restriction policy after the link.
    #
    # @option opt [Boolean] :tooltip       If *false* do not include the policy
    #                                        description.  If :show_policy is
    #                                        *true* only the policy label text
    #                                        will be included.
    #
    # @option opt [String] :url            Override viewer URL.
    #
    # @return [ActiveSupport::SafeBuffer]
    # @return [nil]
    #
    def view_online_link(doc, opt = nil)
      return unless doc && (doc.doc_sub_type == :dl_book)

      # Extract options if provided.  Keys used to provide values to this
      # method are removed; any elements that remain are interpreted as link
      # options.
      opt = opt ? opt.dup : {}
      viewer_path   = opt.delete(:url)           || doc.dl_jp2k_viewer_applet
      blocked_label = opt.delete(:blocked_label) || 'Online Viewing:'
      link_label    = opt.delete(:link_label)    || 'View online'
      show_policy   = !opt.key?(:show_policy)    || opt.delete(:show_policy)
      tooltip       = !opt.key?(:tooltip)        || opt.delete(:tooltip)

      # Get access restrictions on the item.
      blocked, label, description = access_restricted(doc)

      # Include the link if access to the item is allowed.
      result =
        if blocked
          blocked_label
        else
          external_link(link_label, viewer_path, opt)
        end

      # Include the policy description.
      if show_policy && label.present?
        label = "(#{label})" unless blocked
        if !tooltip
          result << SPACE << label
        elsif description.present?
          result <<
            content_tag(:a, class: 'policy-tooltip') do
              label + content_tag(:span, description)
            end
        end
      end

      result.html_safe
    end

    # =========================================================================
    # :section:
    # =========================================================================

    public

    # Create an array of HTML links from URL strings.
    #
    # @param [Array<String, Array<String>>] urls
    #
    # Any options at the end of the argument list will become HTML attributes
    # for each link.
    #
    # @return [Array<ActiveSupport::SafeBuffer>]  Zero or more <a> elements.
    #
    def links_to(*urls)
      html_options = urls.last.is_a?(Hash) ? urls.pop : {}
      urls.flatten.map { |url|
        external_link(url, url, html_options) if url.present?
      }.compact
    end

    # Display a rights statement as an active link.
    #
    # @param [UVA::IndexDoc] doc
    #
    # @return [ActiveSupport::SafeBuffer]
    # @return [nil]
    #
    def rights_link(doc)
      label = doc.values_for(:rights_display).first
      url   = doc.values_for(:rights_url_display).first
      if url.present?
        external_link(label, url)
      elsif label.present?
        label
      end
    end

    # Display a DOI as an active link.
    #
    # @param [String] doi
    #
    # @return [ActiveSupport::SafeBuffer]
    #
    def doi_link(doi)
      external_link(doi, "https://doi.org/#{doi}") if doi.present?
    end

    # =========================================================================
    # :section: Blacklight Overrides
    # =========================================================================

    public

    # This Blacklight method is superseded by the local method which creates a
    # link that is appropriate for the current search context.
    #
    # @param [Hash] opt               @see self#link_back_to_search
    #
    # @return [ActiveSupport::SafeBuffer]
    #
    # Compare with:
    # @see Blacklight::BlacklightHelperBehavior#link_back_to_catalog
    #
    def link_back_to_catalog(opt = nil)
      link_back_to_search(opt)
    end

    # =========================================================================
    # :section:
    # =========================================================================

    public

    # Presents a link back to the originating search.
    #
    # For item show pages that were selected from combined search results, this
    # means that the "Return to search" link will go back to the original
    # combined search results page (even though the "previous" and "next" links
    # move through the search results of the specific search lens).
    #
    # @param [Hash] opt               Options passed to the link except for:
    #
    # @option opt [String]         :label   Used to set the link label text.
    # @option opt [String, Symbol] :portal  Specify the portal
    #
    # @return [ActiveSupport::SafeBuffer]
    #
    # === Usage Notes
    # This method should be used in preference to #link_back_to_catalog which
    # is present for Blacklight compatibility reasons.
    #
    def link_back_to_search(opt = nil)
      html_opt = {
        label: UVA::View::Constants::RETURN_TO_SEARCH,
      }
      html_opt.merge!(opt) if opt.present?
      label  = ERB::Util.h(html_opt.delete(:label))
      portal = html_opt.delete(:portal)
      portal &&= portal_key(portal)
      portal ||= active_search_portal
      # NOTE: When in the special collections lens, keep all query parameter
      # info since in that lens the user will navigate away from a page to make
      # a request then wish to rejoin the result list.
      ignored = ([:id, :counter, :total] unless special_collections_lens?)
      url_params = search_session(portal).except(*ignored)
      path = index_path(portal, url_params)
      link_to(label, path, html_opt)
    end

    # Picks appropriate label for the search results.
    #
    # @return [String]
    #
    def search_result_label
      portal_search_label
    end

    # index_thumbnail
    #
    # @param [UVA::IndexDoc] doc
    # @param [Hash]          link_opts
    #
    # @return [ActiveSupport::SafeBuffer]
    #
    def index_thumbnail(doc, link_opts = nil)

      # By default, the thumbnail image will be a redundant link to the show
      # page for the document so it does not need to be a tab stop.
      link_opts = { tabindex: -1 }.merge(link_opts || {})
      index = 0

      case doc.doc_type

        when :lib_coins
          indexed_thumbnail(doc, link_opts)

        when :dl_wsls_video
          show_wsls_thumbnail(doc, link_opts)

        when :dl_video
          link_opts.reverse_merge!(text: 'Watch', limit: 1)
          show_streaming_thumbnails(doc, link_opts)

        when :lib_technical_report, :dataverse
          libra_thumbnail(doc, link_opts)

        when :dl_image
          resource_ids ||= doc.values_for(:media_resource_id_display)
          resource_ids.map { |resource_id|
            preview_url = doc.dl_image_preview_src(resource_id)
            next unless image_url_exists?(preview_url)
            image = image_tag(preview_url, class: :photo, alt: doc.doc_id)
            full_size_url = doc.dl_image_full_src(resource_id)
            opts =
              link_opts.reverse_merge(
                title:           get_image_title(doc, index),
                :'data-group' => doc.doc_id
              )
            opts[:class] = "#{opts[:class]} hide".strip unless index.zero?
            index += 1
            content_tag(:div) do
              link_to(image, full_size_url, opts)
            end
          }.compact.join(NEWLINE).html_safe

        else
          # For all other doc types
          streaming_thumbnail_and_link(doc, link_opts) ||
            viewer_thumbnail_and_link(doc, link_opts)
      end || link_to_document_from_cover(doc, link_opts)
    end

    # =========================================================================
    # :section:
    # =========================================================================

    public

    # A GIF image shown as a placeholder element where asynchronous content
    # will appear.
    #
    # @param [Hash] opt
    #
    # @return [ActiveSupport::SafeBuffer]
    #
    def ajax_loader_image(opt = nil)
      opt = opt ? opt.dup : {}
      opt[:class] ||= 'ajax-loader'
      opt[:alt]   ||= 'Loading...'
      opt[:size]  ||= '16x16'
      image_url = opt.delete(:url) || image_path('ajax-loader.gif')
      image_tag(image_url, opt)
    end

    # Ask-A-Librarian link
    #
    # @param [Array<String>] args
    # - The first argument (if present) is used as the link label
    # - The second argument (if present) is used as the link url destination.
    #
    # @return [ActiveSupport::SafeBuffer]
    #
    def ask_a_librarian(*args)
      html_opt = { rel: 'nofollow' }
      html_opt.merge!(args.pop) if args.last.is_a?(Hash)
      html_opt[:style] ||= 'text-decoration:underline' unless html_opt[:class]
      label = args.shift || 'Ask a Librarian'
      url   = args.shift || URL::ASK_A_LIBRARIAN
      external_link(label, url, html_opt)
    end

    # Specialized databases ("Databases A-Z") link.
    #
    # @param [Array<String>] args
    # - The first argument (if present) is used as the link label
    # - The second argument (if present) is used as the link url destination.
    #
    # @return [ActiveSupport::SafeBuffer]
    #
    def specialized_databases(*args)
      html_opt = args.last.is_a?(Hash) ? args.pop.dup : {}
      html_opt[:style] ||= 'text-decoration:underline' unless html_opt[:class]
      label = args.shift || 'specialized databases'
      url   = args.shift || URL::DATABASES
      external_link(label, url, html_opt)
    end

    # Links to other Library resources and discovery services.
    #
    # @param [Hash] opt               Link options for each link.
    #
    # @return [ActiveSupport::SafeBuffer]  Each link wrapped in a <li> element.
    #
    # @see self#OTHER_RESOURCES_LINKS
    #
    def other_resources_links(opt = nil)
      OTHER_RESOURCES_LINKS.map { |label, url|
        next if url.blank?
        label = url if label.blank?
        link  = external_link(label.html_safe, url, opt)
        content_tag(:li, link)
      }.compact.join(NEWLINE).html_safe
    end

    # Produce an external link that changes behavior based on whether the
    # current page is a side window or not.  If `is_aside?` is *false* then
    # the external link will open a new browser tab; otherwise, the external
    # link will replace the current browser tab.
    #
    # @param [Array] args               Same as self#out_link.
    #
    # @option args.last [Boolean] :aside  If *true* then force the external
    #                                       link to replace the current browser
    #                                       tab; if *false* then force a new
    #                                       browser tab to be opened.
    #
    # @return [ActiveSupport::SafeBuffer]
    #
    # @see self#out_link
    #
    def external_link(*args, &block)
      html_opt = args.last.is_a?(Hash) ? args.pop.dup : {}
      aside =
        if html_opt.key?(:aside)
          !false_value?(html_opt.delete(:aside))
        else
          in_aside?
        end
      if aside
        html_opt[:target] = '' # Do not open a new browser tab.
        unless html_opt[:addendum].is_a?(FalseClass)
          html_opt[:addendum] ||= 'replaces the current window'
        end
      end
      out_link(*args, html_opt, &block)
    end

    # Produce a link that opens in a new browser tab.
    #
    # Used in place of `link_to(..., target: '_blank')` so that 'aria-label'
    # can set appropriately for screen readers.
    #
    # @param [Array] args               Same as #link_to.
    #
    # @option args.last [String, FalseClass]  :addendum
    # @option args.last [String, FalseClass]  :aria
    # @option args.last [Boolean]             :aside
    #
    # @return [ActiveSupport::SafeBuffer]
    #
    # @see ActionView::Helpers::UrlHelper#link_to
    #
    def out_link(*args)
      label    = block_given? ? yield : args.shift
      link_opt = args.shift
      html_opt = args.shift
      html_opt = html_opt.is_a?(Hash) ? html_opt.dup : {}
      html_opt[:target] ||= '_blank'

      aside = html_opt.delete(:aside)
      if aside
        if link_opt.is_a?(Hash)
          link_opt = link_opt.merge(aside: aside)
        else
          link_opt += link_opt.include?('?') ? '&' : '?'
          link_opt << "aside=#{aside}"
        end
      end

      addendum = html_opt.delete(:addendum)
      unless addendum.is_a?(FalseClass)
        addendum = 'opens in a new window' unless addendum.present?
        addendum = addendum.strip.gsub(/(^\(|\.$|\.?\)$)/, '')
        addendum = "(#{addendum.capitalize}.)"
      end

      title = html_opt[:title]
      tip   = strip_html(title || label).strip.presence
      unless title.is_a?(FalseClass)
        html_opt[:title] =
          if tip.blank?
            addendum
          elsif addendum && (tip !~ / window\.?\) *$/i)
            "#{tip}\n#{addendum}"
          else
            tip
          end
      end

      aria = html_opt[ARIA_LABEL]
      unless aria.is_a?(FalseClass)
        aria = aria.to_s.strip.presence || tip
        html_opt[ARIA_LABEL] = aria if aria
      end

      html_opt.keep_if { |_, v| v }
      link_to(label, link_opt, html_opt)
    end

    # =========================================================================
    # :section:
    # =========================================================================

    public

    # A text link that serves the role of an action button.
    #
    # @param [String] label
    # @param [String] return_path
    # @param [Hash]   opt               HTML options for the link
    #
    # @option opt [String]         :label  Override *label*.
    # @option opt [String,Boolean] :title  No tooltip if *false*.
    #
    # @return [ActiveSupport::SafeBuffer]
    #
    def action_link(label, return_path, opt = nil)
      html_opt = {
        role:     'button',
        label:    label || ACTION_LINK_BUTTON_LABEL,
        tabindex: 0
      }
      html_opt.merge!(opt) if opt.present?
      label = html_opt.delete(:label)
      tip   = html_opt.delete(:title)
      unless tip.is_a?(FalseClass)
        tip  = strip_html(tip || label)
        tip += '.' if tip.include?(' ') && !tip.end_with?('.')
        html_opt[:title] = tip
        html_opt[ARIA_LABEL] ||= tip
      end
      link_to(label, return_path, html_opt)
    end

    # Produce a link that will close the current aside (side browser tab).
    #
    # @param [Hash] opt
    #
    # @return [ActiveSupport::SafeBuffer]
    #
    def close_side_window(opt = nil)
      html_opt = {
        class: 'btn',
        label: 'CLOSE',
        title: 'Close this view and return.',
      }
      html_opt.merge!(opt) if opt.present?
      window_close_link(in_popup?, html_opt)
    end

    # Produce a link that will close the current context.
    #
    # @param [Boolean] in_popup
    # @param [Hash]    opt
    #
    # @return [ActiveSupport::SafeBuffer]
    #
    def window_close_link(in_popup = false, opt = nil)
      html_opt = {
        label: 'Close this window',
        path:  window_close_path(in_popup)
      }
      html_opt.merge!(opt) if opt.present?
      label = html_opt.delete(:label)
      path  = html_opt.delete(:path)
      action_link(label, path, html_opt)
    end

    # JavaScript that can be used to create a link that will close the current
    # context.
    #
    # @param [Boolean] in_popup
    #
    # @return [String]
    #
    def window_close_path(in_popup = false)
      in_popup ? colorbox_close : browser_tab_close
    end

    # JavaScript that can be used from within a Colorbox popup to create a link
    # that will close the popup.
    #
    # @return [String]
    #
    def colorbox_close(*)
      in_popup? ? javascript(:close_iframe) : javascript(:close_colorbox)
    end

    # JavaScript that can be used to create a link that will close the current
    # browser tab.
    #
    # @return [String]
    #
    def browser_tab_close(*)
      javascript(:close_tab)
    end

    # Produce a link to go back to the previous web page.
    #
    # @param [Boolean] in_popup
    # @param [Hash]    opt
    #
    # @return [ActiveSupport::SafeBuffer]
    #
    def browser_back_link(in_popup = false, opt = nil)
      html_opt = {
        label: 'Go back to the previous page',
        path:  browser_back_path(in_popup)
      }
      html_opt.merge!(opt) if opt.present?
      label = html_opt.delete(:label)
      path  = html_opt.delete(:path)
      action_link(label, path, html_opt)
    end

    # JavaScript that can be used to create a link to go back to the previous
    # web page.
    #
    # @param [Boolean] in_popup
    #
    # @return [String]
    #
    def browser_back_path(in_popup = false)
      return if in_popup
      browser_back
    end

    # JavaScript that can be used to go back to the previous web page.
    #
    # @return [String]
    #
    def browser_back(*)
      javascript(:history_back)
    end

    # JavaScript that can be used to create a link for printing the current
    # browser tab.
    #
    # @return [String]
    #
    def window_print_path(*)
      browser_tab_print
    end

    # JavaScript that can be used to create a link for printing the current
    # browser tab and going back to the previous page.
    #
    # @return [String]
    #
    def window_print_and_back_path(*)
      browser_tab_print_and_back
    end

    # JavaScript that can be used to create a link for printing the current
    # browser tab and then closing it.
    #
    # @param [Boolean] in_popup
    #
    # @return [String]
    #
    def window_print_and_close_path(in_popup = false)
      browser_tab_print_and_close(in_popup)
    end

    # JavaScript that can be used to print the current browser tab.
    #
    # @return [String]
    #
    def browser_tab_print
      javascript(:print_tab)
    end

    # JavaScript that can be used to print the current browser tab then go back
    # to the previous page.
    #
    # @return [String]
    #
    # NOTE: This doesn't seem to work with any browser family.
    #
    def browser_tab_print_and_back(*)
      javascript(:print_tab, :history_back)
    end

    # JavaScript that can be used to print the current browser tab and then
    # close it.
    #
    # @param [Boolean] in_popup
    #
    # @return [String]
    #
    def browser_tab_print_and_close(in_popup = false)
      javascript(:print_tab, window_close_path(in_popup))
    end

    # =========================================================================
    # :section:
    # =========================================================================

    protected

    # Produce an "href" string of JavaScript statement(s)
    #
    # @param [Array<Symbol, String>] args
    #
    # @return [String]
    #
    def javascript(*args)
      args.map! { |arg|
        if arg.is_a?(Symbol)
          JAVASCRIPT[arg]
        else
          arg.to_s.gsub(/javascript:/, '').sub(/(^;+|;+$)/, '').squeeze(';')
        end
      }
      'javascript:' << args.reject(&:blank?).join(';') << ';'
    end

    # =========================================================================
    # :section:
    # =========================================================================

    public

    # Determines which label to use for the "label number" field.
    #
    # @param [UVA::IndexDoc] doc
    #
    # @return [String]
    #
    def label_no_label(doc = nil)
      sub_type = doc && doc.doc_sub_type
      case sub_type
        when :musical_score     then 'Publisher/plate no.'
        when :musical_recording then 'Label no.'
        else                         'Publisher no.'
      end
    end

    # Determines which verb to use for accessing the document online.
    #
    # @param [UVA::IndexDoc] doc
    #
    # @return [String]
    #
    # @see UVA::IndexDoc#reference_type
    #
    def online_access_verb(doc = nil)
      case doc && doc.reference_type
        when :audio        then 'listen'
        when :video        then 'watch'
        when :image        then 'view'
        when :generic, nil then 'access'
        else                    'read'
      end
    end

    # online_access_label
    #
    # @param [UVA::IndexDoc] doc
    #
    # @return [String]
    #
    # @see self#online_access_verb
    #
    def online_access_label(doc = nil)
      access = online_access_verb(doc).capitalize
      "#{access} online"
    end

    # =========================================================================
    # :section:
    # =========================================================================

    public

    # Returns a string containing the title of an image for use in the @title
    # attribute of <a> elements.
    #
    # @param [UVA::IndexDoc] doc
    # @param [Fixnum]        index
    # @param [String]        default
    #
    # @return [String]
    #
    def get_image_title(doc, index, default = nil)
      # Use main_title_display + image description if available; otherwise
      # fall back to default value
      desc   = doc && doc.values_for(:media_description_display)[index]
      desc &&= desc.gsub(/<[^>]+>/, '').strip
      title  = (doc.export_title if desc.present?)
      if title.blank?
        default.to_s
      elsif desc.casecmp(title).zero?
        title
      else
        sep = title.end_with?(%w(. , ;)) ? ',' : ' -'
        "#{title}#{sep} #{desc}"
      end
    end

    # =========================================================================
    # :section:
    # =========================================================================

    public

    # Make a link for an RSS feed from search parameters.
    #
    # The RSS feed will always yield a list of items sorted by date received
    # in non-ascending time order (i.e. latest first), so sorting parameters
    # and the current search page are ignored.
    #
    # @param [String] path            Default: `request.path`
    # @param [Hash]   opt
    #
    # @return [ActiveSupport::SafeBuffer]
    #
    def rss_link(path = nil, opt = nil)

      html_opt = {
        class: 'rss-button',
        title: 'RSS feed for this Virgo search'
      }
      if path.is_a?(Hash)
        opt  = path
        path = nil
      end
      html_opt.merge!(opt) if opt.is_a?(Hash)

      # Setup query parameters, explicitly setting the date-received sort key
      # to ensure that the catalog search implied by the RSS link does not
      # actually result in a different sort order.
      ignored = IGNORE_FOR_RSS
      ignored += [:q] if null_search? && !music_lens? && !video_lens?
      url_params = params.except(*ignored)
      url_params[:sort_key] = date_received_sort_key

      path ||= request.path
      if path =~ %r{/index$}
        path += '.rss?' + url_params.to_param
      else
        path = portal_index_path(url_params.merge(format: :rss))
      end

      out_link(path, html_opt) do
        image_tag('browser-rss.png', size: '20x20')
      end
    end

    # =========================================================================
    # :section:
    # =========================================================================

    protected

    # Certain link labels need to be translated into something more useful.
    #
    # @param [String] label
    #
    # @return [String]
    # @return [nil]
    #
    def translate_link_label(label)
      return if label.blank?
      match =
        TRANSLATED_LINK_LABELS.find do |pattern, _|
          pattern.is_a?(Regexp) ? (label =~ pattern) : label.include?(pattern)
        end
      match && match.last
    end

    # Certain link labels (usually from MARC 856$z fields) are unhelpful and
    # should be ignored.
    #
    # @param [String] label
    #
    def ignore_link_label?(label)
      label.blank? ||
        IGNORED_LINK_LABELS.any? do |pattern|
          pattern.is_a?(Regexp) ? (label =~ pattern) : label.include?(pattern)
        end
    end

  end

end
