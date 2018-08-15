# lib/uva/portal.rb

require 'uva'

module UVA

  # UVA::Portal
  #
  module Portal

    include UVA

    # =========================================================================
    # :section:
    # =========================================================================

    public

    # Values associated with the "portals" or "lenses".
    #
    # @see UVA::Helper::Links#switch_search_scope_links
    # @see UVA::Helper::Links#search_elsewhere_links
    #
    PORTAL = {
      all: {
        controller:       nil,
        catalog_select:   'all',
        enabled:          true,
        button_label:     'Catalog + Article',
        search_label:     'Catalog + Article',
        search_scope:     true,
        search_elsewhere: true,
        search_title:     'Search All Sources',
        placeholder:      %q(
          Search for books, articles, digital materials and more.
        ).squish,
        portal_tooltip:   %q(
          See results from catalog search and article search side-by-side.
        ).squish
      },
      catalog: {
        controller:       'catalog',
        catalog_select:   nil,
        enabled:          true,
        button_label:     'Catalog',
        search_label:     'Catalog',
        search_scope:     true,
        search_elsewhere: true,
        search_title:     'Search Catalog',
        placeholder:      %q(
          Search for books, maps, DVDs, and other catalog materials.
        ).squish,
        portal_tooltip:   %q(
          Explore items in the UVA catalog and repositories.
        ).squish
      },
      articles: {
        controller:       'articles',
        catalog_select:   'articles',
        enabled:          true,
        button_label:     'Articles',
        search_label:     'Article',
        search_scope:     true,
        search_elsewhere: true,
        search_title:     'Search Articles',
        placeholder:      %q(
          Search for articles from subscription journal databases.
        ).squish,
        portal_tooltip:   %q(
          Explore articles from UVA-owned journals and magazines.
        ).squish
      },
      music: {
        controller:       'music',
        catalog_select:   nil,
        enabled:          true,
        button_label:     'Music',
        search_label:     'Music',
        search_scope:     true,
        search_elsewhere: false,
        search_title:     'Search Music',
        placeholder:      %q(
          Search for audio, LPs, CDs, sheet music and music-related books.
        ).squish,
        portal_tooltip:   %q(
          See recent additions and search for music topics.
        ).squish
      },
      video: {
        controller:       'video',
        catalog_select:   nil,
        enabled:          true,
        button_label:     'Video',
        search_label:     'Video',
        search_scope:     true,
        search_elsewhere: false,
        search_title:     'Search Video',
        placeholder:      %q(
          Search for online video, DVDs, and Blu-Rays.
        ).squish,
        portal_tooltip:   %q(
          See new arrivals and search for Blu-Ray, DVD and online video.
        ).squish
      },
      classic: {
        controller:       'classic',
        catalog_select:   nil,
        enabled:          !UVA::Classic.feature_suppressed?,
        button_label:     'Expert',
        search_label:     'Expert',
        search_scope:     false,
        search_elsewhere: false,
        search_title:     'Search Catalog Only',
        placeholder:      %q(
          Search for books, maps, DVDs, and other catalog materials.
        ).squish,
        portal_tooltip:   %q(
          Search the catalog with a minimalist interface.
        ).squish
      },
    }.deep_freeze

    # @see app/assets/javascripts/feature/search-toggle.js

    ALL_PLACEHOLDER      = PORTAL[:all][:placeholder]
    CATALOG_PLACEHOLDER  = PORTAL[:catalog][:placeholder]
    ARTICLES_PLACEHOLDER = PORTAL[:articles][:placeholder]

    # =========================================================================
    # :section:
    # =========================================================================

    public

    # The current portal key or *nil* if not within a lens.
    #
    # @return [Symbol]
    # @return [nil]
    #
    def current_portal_key(url_params = nil)
      portal_key(nil, url_params)
    end

    # All portal controllers
    #
    # @return [Array<String>]
    #
    def portal_controllers
      PORTAL.values.map { |entry|
        entry[:controller] if entry[:enabled]
      }.compact
    end

    # The current portal controller (if any).
    #
    # @param [Symbol, String] portal        Default: `*opt*[:controller]`
    # @param [Hash]           url_params    Default: `params`
    #
    # @return [String]
    # @return [nil]
    #
    def portal_controller(portal = nil, url_params = nil)
      portal = portal_key(portal, url_params)
      entry  = portal && PORTAL[portal]
      entry && entry[:controller]
    end

    # The controller name for the "catalog lens".
    #
    # @return [String]
    #
    def catalog_portal
      PORTAL[:catalog][:controller]
    end

    # The controller name for the "article lens".
    #
    # @return [String]
    #
    def articles_portal
      PORTAL[:articles][:controller]
    end

    # The controller name for the "music lens".
    #
    # @return [String]
    #
    def music_portal
      PORTAL[:music][:controller]
    end

    # The controller name for the "video lens".
    #
    # @return [String]
    #
    def video_portal
      PORTAL[:video][:controller]
    end

    # The controller name for the "'Virgo Classic' lens".
    #
    # @return [String]
    #
    def classic_portal
      PORTAL[:classic][:controller]
    end

    # =========================================================================
    # :section:
    # =========================================================================

    public

    # Indicate whether the current page is search results or item details which
    # resulted from catalog search (but not viewed through either the
    # "music lens" or the "video lens").
    #
    # @param [Hash] url_params        Default: `params`
    #
    # If specifically limiting to search results pages:
    # @see self#catalog_search_results?
    #
    def catalog_lens?(url_params = nil)
      url_params ||= params
      url_params[:controller].to_s == catalog_portal
    end

    # Indicate whether the current page is search results or item details which
    # resulted from article search.
    #
    # @param [Hash] url_params        Default: `params`
    #
    # If specifically limiting to search results pages:
    # @see self#articles_search_results?
    #
    def articles_lens?(url_params = nil)
      url_params ||= params
      url_params[:controller].to_s == articles_portal
    end

    # Indicate whether the current page is search results or item details that
    # is being viewed through the "music lens".
    #
    # @param [Hash] url_params        Default: `params`
    #
    # If specifically limiting to search results pages:
    # @see self#music_search_results?
    #
    def music_lens?(url_params = nil)
      url_params ||= params
      url_params[:controller].to_s == music_portal
    end

    # Indicate whether the current page is search results or item details that
    # is being viewed through the "video lens".
    #
    # @param [Hash] url_params        Default: `params`
    #
    # If specifically limiting to search results pages:
    # @see self#video_search_results?
    #
    def video_lens?(url_params = nil)
      url_params ||= params
      url_params[:controller].to_s == video_portal
    end

    # Indicate whether the current page is search results or item details that
    # is being viewed through the "'Virgo Classic' lens".
    #
    # @param [Hash] url_params        Default: `params`
    #
    # If specifically limiting to search results pages:
    # @see self#classic_search_results?
    #
    def classic_lens?(url_params = nil)
      url_params ||= params
      url_params[:controller].to_s == classic_portal
    end

    # Indicate whether the current page is being viewed through the
    # "Special Collections lens".
    #
    def special_collections_lens?
      defined?(session) && session[:special_collections]
    end

    # =========================================================================
    # :section:
    # =========================================================================

    public

    # Indicate whether the current page is the combined search results page.
    #
    # @param [Hash] url_params        Default: `params`
    #
    def combined_search_results?(url_params = nil)
      url_params ||= params
      url_params[:catalog_select].to_s == PORTAL[:all][:catalog_select]
    end

    # Indicate whether the current (index) page resulted from a catalog search.
    #
    # @param [Hash] url_params        Default: `params`
    #
    def catalog_search_results?(url_params = nil)
      url_params ||= params
      catalog_lens?(url_params) && index_page?(url_params)
    end

    # Indicate whether the current (index) page resulted from article search.
    #
    # @param [Hash] url_params        Default: `params`
    #
    def articles_search_results?(url_params = nil)
      url_params ||= params
      articles_lens?(url_params) && index_page?(url_params)
    end

    # Indicate whether the current (index) page was generated within the
    # "music lens".
    #
    # @param [Hash] url_params        Default: `params`
    #
    def music_search_results?(url_params = nil)
      url_params ||= params
      music_lens?(url_params) && index_page?(url_params)
    end

    # Indicate whether the current (index) page was generated within the
    # "video lens".
    #
    # @param [Hash] url_params        Default: `params`
    #
    def video_search_results?(url_params = nil)
      url_params ||= params
      video_lens?(url_params) && index_page?(url_params)
    end

    # Indicate whether the current (index) page was generated within the
    # "'Virgo Classic' lens".
    #
    # @param [Hash] url_params        Default: `params`
    #
    def classic_search_results?(url_params = nil)
      url_params ||= params
      classic_lens?(url_params) && index_page?(url_params)
    end

    # Indicate whether the current page is a 'Virgo Classic' lens browse-by
    # search results page.
    #
    # @param [Hash] url_params        Default: `params`
    #
    def classic_browse_results?(url_params = nil)
      url_params ||= params
      classic_lens?(url_params) && browse_page?(url_params)
    end

    # =========================================================================
    # :section:
    # =========================================================================

    public

    # Indicate whether the current page is the root page of the web site.
    #
    def home_page?
      request.path == root_path
    end

    # Indicate whether the current page is the main "Catalog" page.
    #
    def catalog_home_page?
      if (request.path != root_path) && portal_home_page?
        catalog_search_results? || (request.path == catalog_home_path)
      end
    end

    # Indicate whether the current page is the main "Articles" page.
    #
    def articles_home_page?
      articles_search_results? && portal_home_page?
    end

    # Indicate whether the current page is the main "Music lens" page.
    #
    def music_home_page?
      music_search_results? && portal_home_page?
    end

    # Indicate whether the current page is the main "Video lens" page.
    #
    def video_home_page?
      video_search_results? && portal_home_page?
    end

    # Indicate whether the current page is the main "'Virgo Classic' lens"
    # page.
    #
    # @param [Hash] url_params        Default: `params`
    #
    def classic_home_page?(url_params = nil)
      url_params ||= params
      classic_lens?(url_params) && (url_params[:action].to_s == 'home')
    end

    # =========================================================================
    # :section:
    # =========================================================================

    public

    # Indicate whether the current page is a search results page.
    #
    # @param [Hash] url_params        Default: `params`
    #
    def index_page?(url_params = nil)
      url_params ||= params
      url_params[:action].to_s == 'index'
    end

    # Indicate whether the current page is an item details show page.
    #
    # @param [Hash] url_params        Default: `params`
    #
    def show_page?(url_params = nil)
      url_params ||= params
      url_params[:action].to_s == 'show'
    end

    # document_page?
    #
    # @param [Hash] url_params        Default: `params`
    #
    def document_page?(url_params = nil)
      url_params ||= params
      portal_controller(nil, url_params) && show_page?(url_params)
    end

    # Indicate whether the current page is a browse-by results page.
    #
    # @param [Hash] url_params        Default: `params`
    #
    def browse_page?(url_params = nil)
      url_params ||= params
      url_params[:action].to_s == 'browse'
    end

    # =========================================================================
    # :section:
    # =========================================================================

    public

    # portal_key
    #
    # @param [Symbol, String] portal        If *nil*, *url_params* is checked.
    # @param [Hash]           url_params    Default: `params`
    #
    # @return [Symbol]
    # @return [nil]
    #
    def portal_key(portal = nil, url_params = nil)
      portal ||=
        if combined_search_results?(url_params ||= params)
          url_params[:catalog_select]
        else
          url_params[:controller]
        end
      portal &&= portal.to_sym
      portal if PORTAL[portal]
    end

    # portal_entry
    #
    # @param [Symbol, String] portal        If *nil*, *url_params* is checked.
    # @param [Hash]           url_params    Default: `params`
    #
    # @return [Hash]                  If the arguments do not indicate a valid
    #                                   portal then the :catalog entry will be
    #                                   returned.
    #
    def portal_entry(portal = nil, url_params = nil)
      key = portal_key(portal, url_params) || :catalog
      PORTAL[key]
    end

    # portal_search_label
    #
    # @param [Symbol, String] portal        If *nil*, *url_params* is checked.
    # @param [Hash]           url_params    Default: `params`
    #
    # @return [String]
    #
    def portal_search_label(portal = nil, url_params = nil)
      portal_entry(portal, url_params)[:search_label]
    end

    # portal_button_label
    #
    # @param [Symbol, String] portal        If *nil*, *url_params* is checked.
    # @param [Hash]           url_params    Default: `params`
    #
    # @return [String]
    #
    def portal_button_label(portal = nil, url_params = nil)
      portal_entry(portal, url_params)[:button_label]
    end

    # portal_tooltip
    #
    # @param [Symbol, String] portal        If *nil*, *url_params* is checked.
    # @param [Hash]           url_params    Default: `params`
    #
    # @return [String]
    #
    def portal_tooltip(portal = nil, url_params = nil)
      portal_entry(portal, url_params)[:portal_tooltip]
    end

    # portal_search_title
    #
    # @param [Symbol, String] portal        If *nil*, *url_params* is checked.
    # @param [Hash]           url_params    Default: `params`
    #
    # @return [String]
    #
    def portal_search_title(portal = nil, url_params = nil)
      portal_entry(portal, url_params)[:search_title]
    end

    # portal_search_placeholder
    #
    # @param [Symbol, String] portal        If *nil*, *url_params* is checked.
    # @param [Hash]           url_params    Default: `params`
    #
    # @return [String]
    #
    def portal_search_placeholder(portal = nil, url_params = nil)
      portal_entry(portal, url_params)[:placeholder]
    end

    # The portal home route.
    #
    # @param [Symbol, String] portal        If *nil*, *url_params* is checked.
    # @param [Hash]           url_params    Default: `params`
    #
    # @return [String]
    #
    def home_path(portal, url_params = nil)
      opt = portal_params(url_params)
      case portal_key(portal, url_params)
        when :articles then articles_home_path(opt)
        when :video    then video_home_path(opt)
        when :music    then music_home_path(opt)
        when :classic  then classic_home_path(opt)
        else                catalog_home_path(opt)
      end
    end

    # The portal route which results in a "null search" showing all items.
    #
    # @param [Symbol, String] portal        If *nil*, *url_params* is checked.
    # @param [Hash]           url_params    Default: `params`
    #
    # @return [String]
    #
    def all_path(portal, url_params = nil)
      opt = portal_params(url_params)
      case portal_key(portal, url_params)
        when :articles then articles_all_path(opt)
        when :video    then video_all_path(opt)
        when :music    then music_all_path(opt)
        when :classic  then classic_all_path(opt)
        else                catalog_all_path(opt)
      end
    end

    # index_path
    #
    # @param [Symbol, String] portal        If *nil*, *url_params* is checked.
    # @param [Hash]           url_params    Default: `params`
    #
    # @return [String]
    #
    def index_path(portal, url_params = nil)
      opt = portal_params(url_params)
      case portal_key(portal, url_params)
        when :articles then articles_path(opt)
        when :video    then video_index_path(opt)
        when :music    then music_index_path(opt)
        when :classic  then classic_index_path(opt)
        else                catalog_index_path(opt)
      end
    end

    # facet_path
    #
    # @param [Symbol, String] portal        If *nil*, *url_params* is checked.
    # @param [Hash]           url_params    Default: `params`
    #
    # @return [String]
    #
    def facet_path(portal, url_params = nil)
      opt = portal_params(url_params)
      case portal_key(portal, url_params)
        when :articles then facet_articles_path(opt)
        when :video    then video_facet_path(opt)
        when :music    then music_facet_path(opt)
        when :classic  then classic_facet_path(opt)
        else                catalog_facet_path(opt)
      end
    end

    # advanced_path
    #
    # @param [Symbol, String] portal        If *nil*, *url_params* is checked.
    # @param [Hash]           url_params    Default: `params`
    #
    # @return [String]
    #
    def advanced_path(portal, url_params = nil)
      opt = portal_params(url_params)
      case portal_key(portal, url_params)
        when :articles then articles_advanced_path(opt)
        when :video    then video_advanced_path(opt)
        when :music    then music_advanced_path(opt)
        when :classic  then classic_advanced_path(opt)
        else                catalog_advanced_path(opt)
      end
    end

    # start_over_path
    #
    # @param [Symbol, String] portal        If *nil*, *url_params* is checked.
    # @param [Hash]           url_params    Default: `params`
    #
    # @return [String]
    #
    def start_over_path(portal, url_params = nil)
      opt = portal_params(url_params)
      case portal_key(portal, url_params)
        when :articles then articles_all_path(opt)
        when :video    then video_all_path(opt)
        when :music    then music_all_path(opt)
        when :classic  then classic_home_path(opt)
        else                catalog_all_path(opt)
      end
    end

    # show_path
    #
    # @param [Symbol, String] portal        If *nil*, *url_params* is checked.
    # @param [String]         id            If *nil*, *url_params* is checked.
    # @param [Hash]           url_params    Default: `params`
    #
    # @return [String]
    #
    def show_path(portal, id = nil, url_params = nil)
      if id.is_a?(Hash)
        url_params = id
        id = nil
      end
      id ||= (url_params || params)[:id]
      opt = portal_params(url_params)
      case portal_key(portal, url_params)
        when :articles then articles_article_path(opt.merge(id: id))
        when :video    then video_path(id, opt)
        when :music    then music_path(id, opt)
        when :classic  then classic_path(id, opt)
        else                catalog_path(id, opt)
      end
    end

    # update_path
    #
    # @param [Symbol, String] portal        If *nil*, *url_params* is checked.
    # @param [String]         id            If *nil*, *url_params* is checked.
    # @param [Hash]           url_params    Default: `params`
    #
    # @return [String]
    #
    def update_path(portal, id = nil, url_params = nil)
      if id.is_a?(Hash)
        url_params = id
        id = nil
      end
      id ||= (url_params || params)[:id]
      opt = portal_params(url_params)
      case portal_key(portal, url_params)
        when :articles then articles_update_path(opt.merge(id: id))
        when :video    then video_update_path(id, opt)
        when :music    then music_update_path(id, opt)
        when :classic  then classic_update_path(id, opt)
        else                catalog_update_path(id, opt)
      end
    end

    # portal_home_path
    #
    # @param [Hash] url_params        Default: `params`
    #
    # @return [String]
    #
    def portal_home_path(url_params = nil)
      home_path(nil, url_params)
    end

    # portal_all_path
    #
    # @param [Hash] url_params        Default: `params`
    #
    # @return [String]
    #
    def portal_all_path(url_params = nil)
      all_path(nil, url_params)
    end

    # portal_index_path
    #
    # @param [Hash] url_params        Default: `params`
    #
    # @return [String]
    #
    def portal_index_path(url_params = nil)
      index_path(nil, url_params)
    end

    # portal_facet_path
    #
    # @param [Hash] url_params        Default: `params`
    #
    # @return [String]
    #
    def portal_facet_path(url_params = nil)
      facet_path(nil, url_params)
    end

    # portal_advanced_path
    #
    # @param [Hash] url_params        Default: `params`
    #
    # @return [String]
    #
    def portal_advanced_path(url_params = nil)
      advanced_path(nil, url_params)
    end

    # portal_start_over_path
    #
    # @param [Hash] url_params        Default: `params`
    #
    # @return [String]
    #
    def portal_start_over_path(url_params = nil)
      start_over_path(nil, url_params)
    end

    # portal_show_path
    #
    # @param [String] id              If *nil*, *url_params* is checked.
    # @param [Hash]   url_params      Default: `params`
    #
    # @return [String]
    #
    def portal_show_path(id = nil, url_params = nil)
      show_path(nil, id, url_params)
    end

    # portal_update_path
    #
    # @param [String] id              If *nil*, *url_params* is checked.
    # @param [Hash]   url_params      Default: `params`
    #
    # @return [String]
    #
    def portal_update_path(id = nil, url_params = nil)
      update_path(nil, id, url_params)
    end

    # =========================================================================
    # :section:
    # =========================================================================

    protected

    # portal_params
    #
    # @param [Hash] url_params
    #
    # @return [Hash]
    #
    def portal_params(url_params = nil)
      url_params ? url_params.except(:controller, :action) : {}
    end


  end

end
