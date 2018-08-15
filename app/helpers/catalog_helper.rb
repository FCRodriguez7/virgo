# app/helpers/catalog_helper.rb

require 'uva'

# Definitions to support */app/views/catalog/**.erb* view templates.
#
# @see CatalogController
# @see app/assets/javascripts/feature/see-more
#
module CatalogHelper

  # Bring in Blacklight includes first so that UVA::Helper modules can override
  include Blacklight::CatalogHelperBehavior
  include BlacklightAdvancedSearch::CatalogHelperOverride
  include BlacklightAdvancedSearch::RenderConstraintsOverride

  # This is _almost_ all of the UVA::Helper::* modules; however, definitions
  # applicable to all contexts go in ApplicationHelper.
  include UVA
  include UVA::BlacklightOverride
  include UVA::Helper::Accessibility
  include UVA::Helper::ActionResponses
  include UVA::Helper::AdvancedSearch
  include UVA::Helper::Articles
  include UVA::Helper::Availability
  include UVA::Helper::CallNumber
  include UVA::Helper::Constraints
  include UVA::Helper::Copyright
  include UVA::Helper::CourseReserve
  include UVA::Helper::CoverImage
  include UVA::Helper::Ead
  include UVA::Helper::Export
  include UVA::Helper::Facets
  include UVA::Helper::FeaturedItems
  include UVA::Helper::Fedora
  include UVA::Helper::GooglePreview
  include UVA::Helper::Iiif
  include UVA::Helper::KlugeRuhe
  include UVA::Helper::Links
  include UVA::Helper::LoginSession
  include UVA::Helper::Pda
  include UVA::Helper::Requests
  include UVA::Helper::SemesterAtSea
  include UVA::Helper::ShelfBrowse
  include UVA::Helper::SpecialCollections
  include UVA::Helper::StacksMaps
  include UVA::Helper::StarredItems
  include UVA::Helper::VideoSearch
  include UVA::Helper::Vocabulary
  include UVA::Helper::Wsls
  include UVA::Helper::Xtf

  # ===========================================================================
  # :section:
  # ===========================================================================

  public

  # The number of item details fields that appear "above the fold" (that is,
  # before the "See more" control).
  INITIAL_DETAILS = 4

  # The CSS class for the "See more" control container.
  CSS_SHOW_DETAILS = 'show-details'.freeze

  # The CSS class for the "See more"/"See less" controls.
  CSS_SEE_MORE_CONTROL = 'see-more-label'.freeze

  # The marker for the "See more" control.
  CSS_SEE_MORE = 'details-closed'.freeze

  # The marker for the "See more" control.
  CSS_SEE_LESS = 'details-opened'.freeze

  # The CSS class used to mark fields that are to be displayed "above the
  # fold" unconditionally.
  CSS_ADD_TO_INITIAL = 'always-show'.freeze

  # This hash can be used as a convenience for marking fields that are to be
  # display "above the fold".
  ALWAYS_SHOW = { class: CSS_ADD_TO_INITIAL }.freeze

  # If *true*, add a "Date Indexed" field to the item details show page.
  DEBUG_DATE_INDEXED = false

  # ===========================================================================
  # :section: Search results (index page)
  # ===========================================================================

  public

  # Displays the "showing X through Y of N" message - used in place of the
  # #page_entries_info method from Kaminari or WillPaginate.
  #
  # @param [RSolr::Ext::Response::Base] response
  # @param [Hash] opt
  #
  # @option opt [String] :entry_name    Default: "entry".
  #
  # @return [ActiveSupport::SafeBuffer]
  #
  # Compare with:
  # @see Kaminari::ActionViewExtension#page_entries_info
  #
  def virgo_page_entries_info(response, opt = {})
    hits = hit_count(response)
    if hits.nonzero?
      count   = content_tag(:strong, format_num(hits))
      query   = extended_query_terms.present?
      results = query ? 'result' : 'entry'
      results = results.pluralize unless hits == 1
      sort    = ('relevancy' if query && combined_search_results?)

      info = "#{count} #{results}".html_safe
      info << " sorted by #{sort}" if sort && (hits > 1)
      info_opt = {}
      info_opt[:title] = 'This number is only approximate.' if articles_lens?
      content_tag(:div, info, info_opt)

    elsif classic_browse_results?
      count   = content_tag(:strong, format_num(hits))
      query   = extended_query_terms.present?
      results = (query ? 'result' : 'entry').pluralize
      info    = "#{count} #{results}".html_safe
      content_tag(:div, info)

    elsif response
      entries = (opt[:entry_name] || 'entry').pluralize
      content_tag(:div, class: 'no-items-extended-message') do
        "No #{entries} found.<br/>" \
        "Continue your search by using one of the Library's<br/>" \
        "#{specialized_databases} or #{ask_a_librarian} for help.".html_safe
      end

    else
      content_tag(:div, class: 'flash-message static', role: 'alert') do
        content_tag(:div, class: 'dialog ui-state-error error') do
          'We were not able to retrieve the results of your search. ' \
          'Please try again.'
        end
      end

    end
  end

  # Number of hits on the current search.
  #
  # @param [RSolr::Ext::Response::Base] response
  # @param [String, Symbol]             browse_mode
  #
  # @return [Fixnum]
  #
  def hit_count(response = nil, browse_mode = nil)
    result = nil
    if (response ||= @response)
      browse_mode ||= params[:browse_mode]
      if %w(author journal subject series).include?(browse_mode)
        field  = UVA::Classic.browse_mode_facet(browse_mode)
        values = response.facet_fields[field]
        result = values.size / 2 if values.present?
      end
      result ||= response.total if response.docs.present?
    end
    result || 0
  end

  # ===========================================================================
  # :section: Item details (show page)
  # ===========================================================================

  public

  # show_page_thumbnail
  #
  # @param [UVA::IndexDoc] doc
  # @param [Hash]          link_opts
  #
  # @return [ActiveSupport::SafeBuffer]
  # @return [nil]
  #
  # === Accessibility Notes
  # Generates an element with aria-hidden="true" since this element is a
  # redundant link.
  #
  def show_page_thumbnail(doc, link_opts = nil)

    id           = doc.doc_id
    doc_type     = doc.doc_type
    doc_sub_type = doc.doc_sub_type

    return if (doc_type == :dl_wsls_video) || doc.has_feature?('has_hierarchy')

    content_opts = { ARIA_HIDDEN => true }
    image_opts   = { class: :photo, alt: id, title: doc.title }
    link_opts    = { tabindex: -1 }.merge(link_opts || {})

    thumbnail   = doc.values_for(:thumbnail_url_display).first
    thumbnail ||= doc.values_for(:thumb_obv_display).first

    if thumbnail
      content_tag(:div, content_opts.merge(class: 'preview-thumbnail')) do
        image_tag(thumbnail, image_opts)
      end

    elsif doc.has_feature?('has_djatoka_image')
      jp2k      = doc.values_for(:digitized_item_pid_display).first
      image_url = doc.dl_jp2k_preview(jp2k)
      thumbnail = image_tag(image_url, image_opts)
      link_url  = doc.dl_jp2k_viewer_applet
      content_tag(:span, content_opts.merge(class: 'jp2k-preview')) do
        out_link(thumbnail, link_url, link_opts)
      end

    elsif (doc_type == :dl_book) || (doc_sub_type == :dl_book)
      exemplar  = get_exemplar(doc.fedora_url, id)
      image_url = doc.dl_jp2k_preview(exemplar)
      thumbnail = image_tag(image_url, image_opts)
      if access_restricted(doc).first
        content_tag(:div, thumbnail, content_opts)
      else
        link_url = doc.dl_jp2k_viewer_applet
        content_tag(:span, content_opts.merge(class: 'jp2k-preview')) do
          out_link(thumbnail, link_url, link_opts)
        end
      end

    elsif (first_image = doc.dl_image_preview_src)
      thumbnail = image_tag(first_image, image_opts)
      link_url  = doc.dl_image_full_src
      link_opts[:title]        ||= get_image_title(doc, 0)
      link_opts[:'data-group'] ||= id
      link_opts.delete(:target)
      content_tag(:div, content_opts.merge(class: 'preview-thumbnail')) do
        link_to(thumbnail, link_url, link_opts)
      end

    else
      # Anything else is assumed to be an item that could have a cover image.
      link_to_document_from_cover(doc, link_opts.merge(content_opts))
    end
  end

  # Return the Solr indexing date for *doc*
  #
  # @param [SolrDocument] doc
  #
  # @return [String]
  # @return [nil]                     If self#DEBUG_DATE_INDEXED is *false* or
  #                                     *doc* is not from the Solr index.
  #
  def show_date_indexed(doc)
    doc.date_indexed if DEBUG_DATE_INDEXED && doc.is_a?(SolrDocument)
  end

  # The toggle and contents of the "librarian view" table of MARC metadata for
  # the current item.
  #
  # @param [UVA::IndexDoc] doc        Default: current @document
  #
  # @return [ActiveSupport::SafeBuffer]
  #
  # @see app/views/catalog/_marc_view.html.erb
  #
  def marc_view(doc = nil)
    doc ||= @document
    opt     = dialog_button_opts(class: 'marc-view-switch')
    button  = link_to('Staff View', '#', opt)
    display =
      content_tag(:div, class: 'marc-view-container') do
        render 'catalog/marc_view', document: doc
      end
    button + display
  end

  # A convenience for marking item show page fields that are to be displayed
  # "above the fold".
  #
  # @param [Hash] opt
  #
  # @return [Hash]
  #
  # === Usage Notes
  # If *opt* is provided it is merged with #ALWAYS_SHOW; in either case the
  # result is a copy and may be overwritten by the caller as needed.
  #
  def always_show(opt = nil)
    ALWAYS_SHOW.merge(opt || {})
  end

  # The button for reducing metadata items shown to just the "above the fold"
  # items.
  #
  # @param [Hash, nil] opt
  #
  # @return [ActiveSupport::SafeBuffer]
  #
  def see_more_control(opt = nil)
    see_more(true, opt)
  end

  # The button for reducing metadata items shown to just the "above the fold"
  # items.
  #
  # @param [Hash, nil] opt
  #
  # @return [ActiveSupport::SafeBuffer]
  #
  def see_less_control(opt = nil)
    see_more(false, opt)
  end

  # always_show_full_record
  #
  # @param [TrueClass, FalseClass, nil] full_view
  # @param [String, nil]                path
  # @param [Hash, nil]                  opt
  #
  # @return [ActiveSupport::SafeBuffer]
  #
  def always_show_full_record(full_view = nil, path = nil, opt = nil)
    html_opt = {
      class: 'button-label',
      role:  'button'
    }
    html_opt.merge!(opt) if opt.is_a?(Hash)
    path ||= request.original_url
    full_view = session[:full_view] if full_view.nil?
    set_full_view = !full_view

    path   = path.gsub(/(?<=[?&])full_view=[^&]+&?/, '')
    path << (path.include?('?') ? '&' : '?') unless path.end_with?('?', '&')
    path << "full_view=#{set_full_view}"

    if set_full_view
      label   = %q(Always show full record)
      tooltip = %q(Make future records show all fields automatically.)
    else
      label   = %q(Don't always show full record)
      tooltip = %q(Make future records show only important fields at first.)
      html_opt[:class] += ' active'
    end
    html_opt[:title] = tooltip

    content_tag(:div, class: 'always-show-link') do
      link_to(label, path, html_opt)
    end
  end

  # ===========================================================================
  # :section: Item details (show page)
  # ===========================================================================

  protected

  # The buttons controlling the state of display of "below the fold" metadata
  # item lines.
  #
  # @param [TrueClass, FalseClass] closed
  # @param [Hash, nil]             opt
  #
  # @return [ActiveSupport::SafeBuffer]
  #
  def see_more(closed, opt = nil)
    html_opt = dialog_button_opts(class: CSS_SEE_MORE_CONTROL)
    html_opt.merge!(opt) if opt.is_a?(Hash)
    text   = closed ? '&dtrif;See more' : '&utrif;See less'
    marker = closed ? CSS_SEE_MORE      : CSS_SEE_LESS
    html_opt[:class] = [*html_opt[:class], marker].reject(&:blank?).join(' ')
    content_tag(:div, text.html_safe, html_opt)
  end

end
