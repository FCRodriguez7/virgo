# lib/uva/helper/layout.rb

require 'uva'

module UVA::Helper

  # UVA::Helper::Layout
  #
  module Layout

    include UVA
    include UVA::Scope
    include UVA::Helper::FeaturedItems
    include UVA::Helper::Links

    include ActionView::Helpers::TagHelper
    include ActionView::Context

    # =========================================================================
    # :section:
    # =========================================================================

    public

    # Default HTML used to separate links on the same line.
    DEFAULT_LINK_SPACER = '&nbsp;&nbsp;&bullet;&nbsp;&nbsp;'.html_safe.freeze

    # If *true*, insert HTML comments identifying the template being used.
    ALLOW_TEMPLATE_COMMENTS = true

    EXTERNAL_FONTS = %w(
      //fonts.googleapis.com/css?family=Cardo:400,700
      //maxcdn.bootstrapcdn.com/font-awesome/4.7.0/css/font-awesome.min.css
    ).deep_freeze

    DEFAULT_JQUERY =
      '//ajax.googleapis.com/ajax/libs/jquery/2.1.4/jquery.min.js'.freeze

    EXTERNAL_SCRIPTS = %W(
      //use.typekit.com/dcu6kro.js
      #{Piwik.script}
    ).reject(&:blank?).deep_freeze

    EXTERNAL_ASSETS =
      [*EXTERNAL_FONTS, DEFAULT_JQUERY, *EXTERNAL_SCRIPTS].deep_freeze

    META_TAG_SEPARATOR = "\n  ".freeze

    # This script is being added as part of a UVA effort to analyze and improve
    # accessibility.
    #
    # @see https://levelaccess.com
    #
    ACCESS_ANALYTICS = %q(
      <script
        src="https://cdn.levelaccess.net/accessjs/YW1wX3V2YTExMDA/access.js"
        type="text/javascript"
      ></script>
    ).squish.freeze

    # Indicate whether the accessibility analytics script should be suppressed
    # in situations where it would normally be included.
    #
    # @see self#suppress_access_analytics?
    #
    SUPPRESS_ACCESS_ANALYTICS = false

    # For testing purposes, indicate whether accessibility analytics script
    # should be included unconditionally.
    #
    # @see self#suppress_access_analytics?
    #
    FORCE_ACCESS_ANALYTICS = false

    # =========================================================================
    # :section: Page head
    # =========================================================================

    public

    # default_page_title
    #
    # @return [String]
    #
    # @see self#show_page_title
    #
    def default_page_title
      "UVA Library | #{application_name}"
    end

    # show_page_title
    #
    # Version number added if this is not a production environment.
    #
    # @param [String, ActiveSupport::SafeBuffer] title
    #
    # @return [ActiveSupport::SafeBuffer]
    #
    def show_page_title(title)
      result = []
      result << "#{title} | "       if title.present?
      result << default_page_title
      result << " - #{APP_VERSION}" unless Virgo.production?
      html_escape(result.join)
    end

    # =========================================================================
    # :section: Page layout
    # =========================================================================

    public

    # HTML used to separate links on the same line.
    #
    # @return [ActiveSupport::SafeBuffer]
    #
    def link_spacer
      DEFAULT_LINK_SPACER
    end

    # Prep one or more strings to be displayed as paragraphs.
    #
    # @param [Array<String>] args
    #
    # @option args [String,Symbol] :tag
    #
    def html_paragraphs(*args)
      opt = args.last.is_a?(Hash) ? args.pop.dup : {}
      tag = opt.delete(:tag) || :p
      args.map { |arg|
        content_tag(tag, arg.html_safe, opt) if arg.present?
      }.compact.join(NEWLINE).html_safe
    end

    # Creates an HTML unordered list element (<ul>) containing a list item
    # element (<li>) for each value.
    #
    # @param [Array<String, Array<String>>] values
    #
    # @option values[-1] [Boolean] :force  If *true* then the method will
    #                                        generate a <ul> even if there is
    #                                        only a single value.
    #
    # Any options at the end of the argument list will become HTML attributes
    # for each list item element.
    #
    # @return [ActiveSupport::SafeBuffer]
    # @return [nil]                        If there were no non-blank values.
    #
    def ul_list(*values)
      html_opt = { force: false }
      html_opt.merge!(values.pop) if values.last.is_a?(Hash)
      force  = html_opt.delete(:force)
      values = values.flatten.reject(&:blank?).uniq
      return if values.blank?
      if force || (values.size > 1)
        values.map! { |value| content_tag(:li, value, html_opt) }
        content_tag(:ul, values.join(SP).html_safe)
      elsif html_opt.present?
        content_tag(:span, values.first, html_opt)
      else
        ERB::Util.h(values.first)
      end
    end

    # Used to inject an HTML comment identifying a template file.
    #
    # @param [UVA::IndexDoc] doc
    # @param [String]        file
    #
    # @return [ActiveSupport::SafeBuffer]
    # @return [nil]                        If self#ALLOW_TEMPLATE_COMMENTS is
    #                                        *false*.
    #
    def template_comment(doc, file)
      return unless ALLOW_TEMPLATE_COMMENTS
      comment = [
        (doc && doc.doc_type),
        (doc && doc.doc_sub_type),
        file.to_s.sub(/(\.[^.]+)?\.erb$/, '').sub(%r{^#{Rails.root}/}, ''),
      ].reject(&:blank?).join(', ')
      "<!-- #{comment} -->".html_safe
    end

    # =========================================================================
    # :section: Page head
    # =========================================================================

    public

    # Get the current favicon.
    #
    # @return [String]
    # @return [nil]
    #
    # @see self#show_meta_tags
    #
    def favicon
      defined?(@favicon) ? @favicon : set_favicon(:default)
    end

    # Set the current favicon.
    #
    # @param [String, Symbol] path    The path to a favicon resource; if given
    #                                   as :default then the default favicon
    #                                   will be restored; if *nil* then no
    #                                   favicon will be used.
    #
    # @return [String]
    # @return [nil]                   If *path* was set to *nil*.
    #
    # @see self#show_meta_tags
    #
    def set_favicon(path)
      path = '/images/favicon.ico' if path == :default
      @favicon = path
    end

    # Get the canonical path for the given document.
    #
    # If no *doc* is provided then the result defaults to `root_url`.
    #
    # @param [UVA::IndexDoc] doc
    # @param [String]        host
    #
    # @return [String]
    #
    def canonical_url(doc = nil, host = nil)
      host ||= request && request.host
      opt = {}
      opt[:host] = host if host.present?
      if !doc.is_a?(UVA::IndexDoc)
        root_url(opt)
      elsif doc.doc_type == :article
        articles_article_url(opt.merge(id: doc.doc_id))
      else
        catalog_url(doc.doc_id, opt)
      end
    end

    # Add/replace the meta tags for the page.
    #
    # @param [Array<UVA::IndexDoc>] args  Either zero or one document followed
    #                                       by an options hash.
    #
    # === Options
    # @option args [String] :author       Taken from the document argument if
    #                                       not explicitly set.
    #
    # @option args [String] :keywords     Taken from the document argument if
    #                                       not explicitly set.
    #
    # @option args [String] :description  Taken from the document argument if
    #                                       not explicitly set.
    #
    # @option args [String] :robots       A *false* setting results in
    #                                       'noindex'.
    #
    # @option args [String] :canonical    Override the generated value for the
    #                                       rel=canonical link.
    #
    # @option args [String] :favicon      If provided, a temporary override of
    #                                       the current value of self#favicon.
    #
    # @return [void]
    #
    # @see self#show_meta_tags
    #
    def set_meta_tags(*args)

      opt = args.last.is_a?(Hash) ? args.pop : {}
      @meta_tags ||= {}

      # Check the arguments for a single document.
      doc = args.first
      if doc.is_a?(Array)
        doc = (doc.size == 1) ? doc.first : nil
      end

      # If a document was provided, use its metadata in the <meta> tags.  If no
      # document was provided then, by definition, this is a non-content page
      # and should not be indexed by robots.
      if doc.is_a?(UVA::IndexDoc)
        @meta_tags[:canonical] = canonical_url(doc)
        @meta_tags[:robots]    = true
        @meta_tags.merge!(doc.get_meta_tags)
      elsif doc
        logger.warn { "#{__method__}: ignored non-doc arg: #{doc.inspect}" }
      elsif request.path == root_path
        @meta_tags[:canonical] = canonical_url
        @meta_tags[:robots]    = true
      end

      # Allow optional arguments to override values that may have been set by
      # by *get_meta_tags*.
      @meta_tags.merge!(opt)

      # For special cases, modify the head title so that the browser tab for
      # this view is distinguishable from the originating browser tab.
      @meta_tags[:title] = "[print] #{@meta_tags[:title]}" if print_view?
    end

    # Set meta tags for a search results page with special handling for the
    # Video lens and Music lens home pages.
    #
    # @param [void] args
    #
    # @return [void]
    #
    # @see self#set_meta_tags
    #
    def set_search_meta_tags(*args)
      opt = args.last.is_a?(Hash) ? args.pop.dup : {}
      opt[:title] ||=
        if (terms = extended_query_terms).present?
          quote  = terms.first.start_with?(SQUOTE, DQUOTE) ? '' : DQUOTE
          terms  = terms.join(LIST_SEPARATOR)
          search = search_result_label
          "#{search} results for #{quote}#{terms}#{quote}".squeeze(SPACE)
        elsif !facetless?
          "#{search_result_label} facet results"
        elsif home_page?
          'Home'
        elsif video_home_page? || music_home_page?
          featured_title
        else
          "#{search_result_label} results"
        end
      opt[:description] ||= opt[:title]
      set_meta_tags(opt)
    end

    # Used in the HTML <head> to emit the <meta> tags appropriate for the
    # current document.
    #
    # @return [ActiveSupport::SafeBuffer]
    #
    # @see self#set_meta_tags
    # @see self#set_search_meta_tags
    #
    # === Implementation Notes
    # Although Rails has a `tag` method for generating empty HTML elements,
    # this was not used to produce <meta> and <link> tags to control the
    # ordering of the tag attributes.  (The `tag` method produces them in
    # sorted order only.)
    #
    def show_meta_tags

      # The <title> meta-tag and <link rel="canonical"> are handled separately.
      @meta_tags ||= {}
      page_title = @meta_tags.delete(:title)
      canonical  = @meta_tags.delete(:canonical)
      icon       = @meta_tags.delete(:favicon) || favicon

      # Supply defaults for missing tags.
      @meta_tags[:author] ||=
        'University of Virginia Library'
      @meta_tags[:description] ||=
        'Virgo, the online catalog of University of Virginia Library. ' \
        'Books, articles, maps, digital materials, and more.'

      # An explicit setting for :robots will be honored, but if a canonical URL
      # was provided then no "robots" meta tag will be added (effectively the
      # same as adding `<meta name="robots" content="index, follow"`).
      #
      unless @meta_tags[:robots].is_a?(String)
        if canonical || @meta_tags[:robots].is_a?(TrueClass)
          @meta_tags.delete(:robots)
        else
          @meta_tags[:robots] = 'noindex'
        end
      end

      # Generate the HTML to be included in the <head> section.  If :title is
      # included it is used as the <title> element.
      #
      # In order to have the <meta> tag appear with the *name* attribute first,
      # `tag('meta', name: name, content: content)` was avoided because it
      # sorts the attributes by name.
      #
      result = []
      result << content_tag(:title, show_page_title(page_title))
      result +=
        @meta_tags.map do |name, value|
          value = html_escape(value)
          %Q(<meta name="#{name}" content="#{value}" />)
        end

      # Add the canonical link if provided.
      if canonical
        canonical = html_escape(canonical)
        result << %Q(<link rel="canonical" href="#{canonical}" />)
      end

      # Add the favicon unless it has been intentionally eliminated.
      result << favicon_link_tag(icon) if icon

      # Per request, the Access Analytics script will be inserted early;
      # putting it after the <meta> tags will bring it in before any other
      # scripts.
      result << ACCESS_ANALYTICS unless suppress_access_analytics?

      # Return with a line for each meta tag.
      result.uniq.join(META_TAG_SEPARATOR).html_safe
    end

    # Content to be included at the end of the HTML <head> section.
    #
    # @return [Array<ActiveSupport::SafeBuffer>]
    #
    def html_head
      @html_head ||= []
    end

    # Used in the HTML <head> to emit accumulated <meta> tags.
    #
    # @param [Array<String>] initial_entries
    #
    # @return [ActiveSupport::SafeBuffer]
    #
    # === Usage Notes
    # If *initial_entries* is provided, it is assumed that stylesheets come
    # first followed by a jQuery reference, followed by other scripts.
    #
    # @see self#EXTERNAL_ASSETS
    #
    def show_html_head(*initial_entries)

      initial_entries = EXTERNAL_ASSETS + initial_entries

      initial_jquery,   initial_entries   = jquery_partition(initial_entries)
      html_head_jquery, html_head_entries = jquery_partition(html_head)

      # If a jQuery override was provided use that; otherwise use the default
      # (which should have been included in EXTERNAL_ASSETS).
      [initial_jquery, html_head_jquery].each do |jq|
        next unless jq.size > 1
        logger.warn { "Multiple jQuery versions specified: #{jq.inspect}" }
      end
      jquery = make_meta_tag(html_head_jquery.last || initial_jquery.last)

      # Replace each name entry with the inferred meta tag.
      stylesheets, scripts =
        (initial_entries + html_head_entries)
          .map { |entry| make_meta_tag(entry) }
          .compact
          .uniq
          .partition { |tag| tag =~ %r{\srel=['"]stylesheet['"][\s/]} }

      # Emit entries with stylesheets first followed by scripts.
      (stylesheets + [jquery] + scripts).join(META_TAG_SEPARATOR).html_safe
    end

    # =========================================================================
    # :section: Page head
    # =========================================================================

    protected

    # Split an array into an array that matches the form of jQuery plugin names
    # and an array with the remainder.
    #
    # @param [Array<String>] array
    #
    # @return [Array<(Array<String>,Array<String>)>]
    #
    def jquery_partition(array)
      (array || [])
        .flatten
        .select    { |elem| elem.is_a?(String) && elem.present? }
        .partition { |elem| elem =~ /(\/jquery\..*|jquery-[0-9].*)\.js$/ }
    end

    # Unless the entry already appears to be a tag, create the proper tag based
    # on the entry name.
    #
    # @param [String] entry
    #
    # @return [String]
    # @return [nil]
    #
    def make_meta_tag(entry)
      entry = entry.to_s.strip
      case entry
        when /^</                      then entry
        when /\.js$/                   then javascript_include_tag(entry)
        when /\.s?css$/, /\/font.*css/ then stylesheet_link_tag(entry)
        else
          logger.warn {
            %Q(#{__method__}: skipping "#{entry}" - not a .js, .css, or tag)
          }
          nil
      end
    end

    # Indicate whether the accessibility analytics script should not be
    # included on the web page.
    #
    # This may be overridden via `ENV['ACCESS_ANALYTICS']`.
    #
    # @see self#SUPPRESS_ACCESS_ANALYTICS
    # @see self#FORCE_ACCESS_ANALYTICS
    #
    def suppress_access_analytics?
      env_setting = ENV['ACCESS_ANALYTICS']
      if true_value?(env_setting)
        false
      elsif false_value?(env_setting)
        true
      elsif FORCE_ACCESS_ANALYTICS
        false
      elsif SUPPRESS_ACCESS_ANALYTICS
        true
      else
        !Virgo.deployed?
      end
    end

    # =========================================================================
    # :section: Page refresh
    # =========================================================================

    public

    # Called from a display template to ensure that the page will be refreshed
    # when reloaded from cache by setting @cache_refresh.
    #
    # @param [Boolean] setting
    #
    # @return [Boolean]
    #
    # @see self#show_cache_refresh
    #
    def set_cache_refresh(setting = true)
      @cache_refresh = setting
    end

    # Insert a hidden element to indicate whether the page should be refreshed
    # when reloaded from cache as determined by the onload() function in
    # app/assets/javascripts/application.
    #
    # @param [Boolean] force          If *true*, the element is produced
    #                                   regardless of the value of
    #                                   @cache_refresh.
    #
    # @return [ActiveSupport::SafeBuffer]   If set for the page.
    # @return [nil]                         If not set for the page.
    #
    # === Usage Notes
    # Placed on app/views/layouts/*.html.erb templates.
    #
    # @see self#set_cache_refresh
    # @see app/assets/javascripts/shared/session
    #
    def show_cache_refresh(force = false)
      @cache_refresh ||= nil
      return unless @cache_refresh || force
      tag(:input, type: 'hidden', id: 'needs-refresh', value: 'no')
    end

    # =========================================================================
    # :section: Page properties
    # =========================================================================

    public

    # Placed in show page templates to inject a hidden element which contains
    # the search context counter for the item.
    #
    # @param [Hash] opt
    #
    # @return [ActiveSupport::SafeBuffer]
    #
    # @see app/assets/javascripts/shared/session
    #
    def hidden_item_properties(opt = nil)
      html_opt = { class: 'item-properties' }
      html_opt.merge!(opt) if opt.present?
      data = {
        search_context: search_context,
        counter:        get_search_counter,
        total:          search_session[:total],
      }
      hidden_properties(data, html_opt)
    end

    # Placed in the template for '/articles/index' to inject a hidden element
    # which contains information about the current session.
    #
    # @param [Hash] opt
    #
    # @option opt [Symbol] :portal
    #
    # @return [ActiveSupport::SafeBuffer]
    # @return [nil]
    #
    # === Usage Notes
    # On the combined search results page, article results are acquired
    # asynchronously via JavaScript.  Because web browsers disallow all
    # 'Set-Cookie' requests from responses acquired through XMLHttpRequest,
    # the session updates made due to article search results in this situation
    # are lost because they never make it back to the browser.
    #
    # Without this information in the session, article details show pages would
    # not be able to show the "previous", "next", and "return to search" links.
    # This method provides a way to pass the session information so that it can
    # be added into the article details show page links by the JavaScript
    # which sets up search context information in those links.
    #
    # @see self#extract_search_properties!
    # @see app/assets/javascripts/feature/search-context
    #
    def hidden_search_properties(opt = nil)
      search = session[:search]
      return unless search.present?

      html_opt = { class: 'search-properties' }
      html_opt.merge!(opt) if opt.present?

      portal = html_opt.delete(:portal)
      portal ||= portal_controller
      portal ||= articles_lens? ? :articles : :catalog
      url_params = search_session(portal).except(*SEARCH_SESSION_IGNORED)
      url_params = url_params.presence && url_for(url_params).sub(/^.*\?/, '')

      data = {
        search:        marshal(search),
        search_params: url_params,
      }
      hidden_properties(data, html_opt)
    end

    # Run from '/articles/update' to extract the search properties returned
    # Update `params` by removing the
    #
    # @params [Hash] url_params       Default: `params`.
    #
    # @return [Hash]                  The extracted parameters.
    #
    # @see self#hidden_search_properties
    #
    def extract_search_properties!(url_params = nil)
      url_params ||= params
      keys = %w(search).map(&:to_sym)
      properties = url_params.extract!(*keys)
      context = unmarshal(properties[:search])
      if context.present?
        session[:search] ||= empty_session_hash
        session[:search].merge!(context)
      end
      properties
    end

    # =========================================================================
    # :section: Page properties
    # =========================================================================

    protected

    # Create a hidden HTML element with data properties.
    #
    # @param [Hash] data
    # @param [Hash] opt
    #
    # @return [ActiveSupport::SafeBuffer]
    #
    def hidden_properties(data, opt = nil)
      html_opt = {}
      data.each_pair do |attr, value|
        next unless value.present?
        attr = attr.to_s.tr('_', '-')
        html_opt["data-#{attr}"] = value
      end
      html_opt.merge!(opt) if opt.present?
      classes = html_opt[:class].to_s.squeeze.split(' ')
      html_opt[:class] = (classes << 'hidden').uniq.join(' ')
      content_tag(:div, nil, html_opt)
    end

    # Store an object in a form that is safe to use in a URL or as an HTML
    # data attribute.
    #
    # @param [Object] obj
    #
    # @return [String]
    # @return [nil]                   If *obj* is blank.
    #
    # @see self#unmarshal
    #
    # Compare with:
    # @see Rack::Session::Cookie::Base64::Marshal#encode
    # @see Rack::Session::Cookie#set_session
    #
    def marshal(obj)
      return unless obj.present?
      str = Marshal.dump(obj)
      str = Zlib.deflate(str)
      Base64.urlsafe_encode64(str)
    end

    # Restore an object stored with `marshal`.
    #
    # @param [String] str
    #
    # @return [Object]
    # @return [nil]                   If *str* is blank.
    #
    # @see self#marshal
    #
    # Compare with:
    # @see Rack::Session::Cookie::Base64::Marshal#decode
    # @see Rack::Session::Cookie#load_session
    #
    def unmarshal(str)
      return unless str.present?
      str = Base64.urlsafe_decode64(str)
      str = Zlib.inflate(str)
      Marshal.load(str)
    end

    # =========================================================================
    # :section: Skip navigation
    # =========================================================================

    public

    # Content for the hidden main '.skip-nav' navigation menu.
    #
    # @return [Array<ActiveSupport::SafeBuffer>]
    #
    def skip_nav
      @skip_nav ||= []
    end

    # Emit the "skip navigation" menu for screen-readers.  If no links have
    # been contributed by any template then no skip menu is produced.
    #
    # @return [ActiveSupport::SafeBuffer]
    # @return [nil]
    #
    def show_skip_nav
      skip_nav.map { |entry|
        case entry
          when String
            ERB::Util.h(entry)
          when Array
            opt = entry.last.is_a?(Hash) ? entry.pop.dup : {}
            case entry.size
              when 0
                label = opt.delete(:label)
                path  = opt.delete(:url)
              when 1
                label = nil
                path  = entry.first
              else
                label = entry.shift
                path  = entry.shift
                aria  = entry.shift
                opt[ARIA_LABEL] = aria if aria
            end
            label ||= path
            link_to(label, path, opt)
          when Hash
            label = entry.first
            if entry.last.is_a?(Array)
              opt  = entry.last.last.is_a?(Hash) ? entry.last.last : {}
              path = entry.last.first
            else
              opt  = {}
              path = entry.last
            end
            link_to(label, path, opt)
        end
      }.compact.uniq.map { |link|
        content_tag(:li, link)
      }.join("\n").html_safe
    end

    # Keyboard-accessible navigation back to the top of the page.
    #
    # @return [Array<ActiveSupport::SafeBuffer>]
    #
    def to_top_skip_nav
      link_to('Skip back to top', '#top', target: '_top', tabindex: 0)
    end

    # =========================================================================
    # :section: Page mode
    # =========================================================================

    public

    # Used in code that changes its behavior if `popup=true` is given as a
    # parameter.
    #
    def in_popup?
      true_value?(safe_params[:popup])
    end

    # Used in code that changes its behavior if `aside=true` is given as a
    # parameter.
    #
    def in_aside?
      true_value?(safe_params[:aside])
    end

    # Used in code that that does not perform a redirect if `redirect=false` is
    # given as a parameter.
    #
    def no_redirects?
      false_value?(safe_params[:redirect])
    end

    # =========================================================================
    # :section: Page mode
    # =========================================================================

    protected

    def safe_params
      (defined?(params) && params) || {}
    end

  end

end
