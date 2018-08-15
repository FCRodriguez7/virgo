# lib/uva/helper/constraints.rb

require 'uva'

module UVA::Helper

  # UVA::Helper::Constraints
  #
  module Constraints

    include UVA
    include UVA::Helper::Facets
    include UVA::Helper::Articles

    # =========================================================================
    # :section:
    # =========================================================================

    public

    SHOW_IGNORED_FACETS = false

    # Fields of `params` which are not included when creating parameters for a
    # facet link.
    FACET_IGNORED_KEYS = UVA::Helper::Facets::FACET_IGNORED_KEYS

    # The marker displayed for removing a search filter.
    REMOVE_FILTER_LABEL = 'x'.freeze

    START_OVER_LABEL = 'Start&nbsp;over'.html_safe.freeze

    REMOVE_QUERY_TIP  = 'Remove this search term.'.freeze
    REMOVE_FILTER_TIP = 'Remove this search limiter.'.freeze

    # Translate Solr sorting choices to the equivalent EBSCO choices.
    #
    # TODO: This should be maintained in a YAML file or other external config.
    #
    SOLR_TO_EBSCO_SORT = {
      'received'    => 'articles_date',
      'published'   => 'articles_date',
      'published_a' => 'articles_date',
      nil           => 'articles_relevancy'
    }.deep_freeze

    # Translate EBSCO sorting choices to the equivalent Solr choices.
    #
    # TODO: This should be maintained in a YAML file or other external config.
    #
    EBSCO_TO_SOLR_SORT = {
      'articles_date'      => 'received',
      'articles_relevancy' => 'relevancy',
      nil                  => 'relevancy'
    }.deep_freeze

    # Translate Solr facets to the equivalent EBSCO facets.
    # (Unlisted facets should be discarded in translation.)
    #
    # TODO: This should be maintained in a YAML file or other external config.
    #
    SOLR_TO_EBSCO_FACETS = {
      format_facet:     :SourceType,
      language_facet:   :Language,
      region_facet:     :SubjectGeographic,
      subject_facet:    :SubjectEDS,
      year_multisort_i: :PublicationYear,
    }.freeze

    # Translate EBSCO facets to the equivalent Solr facets.
    #
    # TODO: This should be maintained in a YAML file or other external config.
    #
    EBSCO_TO_SOLR_FACETS = SOLR_TO_EBSCO_FACETS.invert.freeze

    # Translate Solr :format_facet values to the equivalent EBSCO :SourceType
    # values.
    #
    # Because EBSCO EDS will balk if presented with an unexpected source type,
    # a default (nil)_entry is provided for self#translate_facets!.
    #
    # TODO: This should be maintained in a YAML file or other external config.
    #
    SOLR_FORMAT_TO_EBSCO_SOURCE_TYPE = {
      'Article'             => 'Academic Journals',
      'Book'                => 'Books',
      'Broadside'           => 'Primary Source Documents',
      'CD'                  => 'Audio',
      'Cartridge'           => 'Audio',
      'Cassette'            => 'Audio',
      'Coin'                => 'Non-Print Resources',
      'Computer Media'      => 'Electronic Resources',
      'Computer Resource'   => 'Electronic Resources',
      'Conference Paper'    => 'Conference Materials',
      'Cylinder'            => 'Audio',
      'Document'            => 'Primary Source Documents',
      'EBook'               => 'Books',
      'Government Document' => 'Reports',
      'Journal/Magazine'    => 'Academic Journals',
      'LP'                  => 'Audio',
      'Large Print'         => 'Books',
      'Looseleaf'           => 'Primary Source Documents',
      'Manuscript'          => 'Primary Source Documents',
      'Manuscript/Archive'  => 'Primary Source Documents',
      'Newspaper'           => 'News',
      'Periodical'          => 'Magazines',
      'Photographs'         => 'Non-Print Resources',
      'Physical Object'     => 'Non-Print Resources',
      'Sound Recording'     => 'Audio',
      'Streaming Audio'     => 'Audio',
      'Tape Reel'           => 'Audio',
      'Technical Report'    => 'Reports',
      'Thesis/Dissertation' => 'Dissertations',
      'Visual Materials'    => 'Non-Print Resources',
      'eText'               => 'Books',
      nil                   => 'Non-Print Resources',
    }.deep_freeze

    # Translate EBSCO :SourceType values to the equivalent Solr :format_facet
    # values. (Unlisted values should be discarded in translation.)
    #
    # TODO: This should be maintained in a YAML file or other external config.
    #
    EBSCO_SOURCE_TYPE_TO_SOLR_FORMAT = {
      # rubocop:disable Metrics/LineLength
      'Academic Journals'         => %w(Article Journal/Magazine),
      'Magazines'                 => %w(Periodical Journal/Magazine),
      'News'                      => %w(Newspaper Periodical),
      'Reviews'                   => %w(Periodical Journal/Magazine),
      'Reports'                   => ['Technical Report', 'Government Document'],
      'Conference Materials'      => 'Conference Paper',
      'Books'                     => %w(Book EBook eText),
      'Biographies'               => %w(Book EBook eText),
      'Primary Source Documents'  => %w(Broadside Document Looseleaf Manuscript/Archive),
      'Electronic Resources'      => ['Computer Media', 'Computer Resource'],
      'Non-Print Resources'       => ['Coin', 'Photographs', 'Physical Object', 'Visual Materials'],
      'Dissertations'             => 'Thesis/Dissertation',
      'Audio'                     => ['CD', 'Cartridge', 'Cassette', 'Cylinder', 'LP', 'Sound Recording', 'Streaming Audio', 'Tape Reel'],
      nil                         => 'Journal/Magazine',
      # rubocop:enable Metrics/LineLength
    }.deep_freeze

    # Translate Solr :language_facet values to the equivalent EBSCO :Language
    # values. (Unlisted values should be passed directly in translation.)
    #
    # TODO: This should be maintained in a YAML file or other external config.
    #
    SOLR_LANGUAGE_TO_EBSCO_LANGUAGE = {
      # rubocop:disable Metrics/LineLength
      'Abkhaz'                                        => 'Abkhazian',
      'Aragonese Spanish'                             => 'Aragonese',
      'Austronesian'                                  => 'Austronesian Languages',
      'Berber (Other)'                                => 'Berber Languages',
      'Catalan'                                       => 'Catalan; Valencian',
      'Central American Indian (Other)'               => 'Central American Indian Languages',
      'Creoles and Pidgins (Other)'                   => 'Creole',
      'Creoles and Pidgins, English-based (Other)'    => 'Creole',
      'Creoles and Pidgins, French-based (Other)'     => 'Haitian Creole',
      'Creoles and Pidgins, Portuguese-based (Other)' => 'Creole',
      'Croatian'                                      => ['Croatian', 'Serbo-Croatian', 'Serbo-Croation', 'Serbo-Croatian (Cyrillic)', 'Serbocroatian', 'Serbo-Croatian (Roman)'],
      'Dutch'                                         => ['Dutch; Flemish', 'Dutch/Flemish'],
      'English subtitles'                             => 'English',
      'Eskimo languages'                              => 'Eskimo',
      'French, Old (ca. 842-1400)'                    => 'French, Middle (Ca.1400-1600)',
      'Fula'                                          => 'Fulah',
      'German, Middle High (ca. 1050-1500)'           => 'Germanic (Other)',
      'German, Old High (ca. 750-1050)'               => 'Germanic (Other)',
      'Greek, Modern (1453- )'                        => ['Greek, Modern (1453-)', 'Greek, Modern (1453- )', 'Modern Greek'],
      'Haitian French Creole'                         => 'Haitian Creole',
      'Iranian (Other)'                               => 'Iranian Languages',
      'Irish, Middle (ca. 1100-1550)'                 => 'Irish Gaelic',
      'Irish, Old (to 1100)'                          => 'Irish Gaelic',
      'Moldavian'                                     => 'Romanian; Moldavian; Moldovan',
      'Ndebele (Zimbabwe)'                            => 'Ndebele, North',
      'Norwegian (Bokmal)'                            => ['Bokmal, Norwegian; Norwegian Bokmal', 'Norwegian Bokmal'],
      'Norwegian (Nynorsk)'                           => 'Norwegian Nynorsk; Nynorsk, Norwegian',
      'Occitan (post-1500)'                           => 'Occitan (Post 1500)',
      'Persian'                                       => %w(Farsi Persian),
      'Philippine (Other)'                            => 'Filipino',
      'Romance (Other)'                               => 'Romance Languages',
      'Romani'                                        => 'Romany',
      'Romanian'                                      => %w(Romanian Rumanian),
      'Samaritan Aramaic'                             => 'Aramaic',
      'Sami'                                          => 'Northern Sami',
      'Scottish Gaelic'                               => 'Gaelic',
      'Serbian'                                       => ['Croatian', 'Serbo-Croatian', 'Serbo-Croation', 'Serbo-Croatian (Cyrillic)', 'Serbocroatian', 'Serbo-Croatian (Roman)'],
      'Sino-Tibetan (Other)'                          => 'Tibetan',
      'Sotho'                                         => ['Northern Sotho', 'Southern Sotho'],
      'Tatar'                                         => 'Crimean Tatar',
      'Tonga (Nyasa)'                                 => ['Tonga', 'Tonga (Tonga Islands)'],
      'Tongan'                                        => ['Tonga', 'Tonga (Tonga Islands)'],
      'Turkish, Ottoman'                              => 'Turkish',
      # rubocop:enable Metrics/LineLength
    }

    # Translate EBSCO :Language values to the equivalent Solr :language_facet
    # values. (Unlisted values should be passed directly in translation.)
    #
    # TODO: This should be maintained in a YAML file or other external config.
    #
    EBSCO_LANGUAGE_TO_SOLR_LANGUAGE = {
      # rubocop:disable Metrics/LineLength
      'Abkhazian'                             => 'Abkhaz',
      'Aragonese'                             => 'Aragonese Spanish',
      'Austronesian Languages'                => 'Austronesian',
      'Berber Languages'                      => 'Berber (Other)',
      'Bokmal, Norwegian; Norwegian Bokmal'   => 'Norwegian (Bokmal)',
      'Catalan; Valencian'                    => 'Catalan',
      'Central American Indian Languages'     => 'Central American Indian (Other)',
      'Creole'                                => ['Creoles and Pidgins (Other)', 'Sango (Ubangi Creole)'],
      'Crimean Tatar'                         => ['Crimean Tatar', 'Tatar'],
      'Dutch/Flemish'                         => 'Dutch',
      'Dutch; Flemish'                        => 'Dutch',
      'Eskimo'                                => 'Eskimo languages',
      'Farsi'                                 => 'Persian',
      'Filipino'                              => 'Philippine (Other)',
      'Fulah'                                 => 'Fula',
      'Gaelic'                                => 'Scottish Gaelic',
      'Greek, Modern (1453- )'                => 'Greek, Modern (1453- )',
      'Greek, Modern (1453-)'                 => 'Greek, Modern (1453- )',
      'Hatian Creole'                         => 'Haitian French Creole',
      'Iranian Languages'                     => 'Iranian (Other)',
      'Irish Gaelic'                          => ['Irish, Middle (ca. 1100-1550)', 'Irish, Old (to 1100)'],
      'Modern Greek'                          => 'Greek, Modern (1453- )',
      'Ndebele, North'                        => ['Ndebele (Zimbabwe)', 'Ndebele (South Africa)'],
      'Northern Sami'                         => 'Sami',
      'Norwegian Bokmal'                      => 'Norwegian (Bokmal)',
      'Norwegian Nynorsk; Nynorsk, Norwegian' => 'Norwegian (Nynorsk)',
      'Occitan (Post 1500)'                   => 'Occitan (post-1500)',
      'Romanian; Moldavian; Moldovan'         => 'Moldavian',
      'Romany'                                => 'Romani',
      'Rumanian'                              => 'Romanian',
      'Serbo-Croatian (Cyrillic)'             => %w(Croatian Serbian),
      'Serbo-Croatian (Roman)'                => %w(Croatian Serbian),
      'Serbo-Croatian'                        => %w(Croatian Serbian),
      'Serbo-Croation'                        => %w(Croatian Serbian),
      'Serbocroatian'                         => %w(Croatian Serbian),
      'Spanish; Castilian'                    => 'Spanish',
      'Tonga (Tonga Islands)'                 => ['Tonga (Nyasa)', 'Tongan'],
      'Tonga'                                 => ['Tonga (Nyasa)', 'Tongan'],
      'Turkish'                               => ['Turkish', 'Turkish, Ottoman'],
      # rubocop:enable Metrics/LineLength
    }

    # Translate Solr facet values to the equivalent EBSCO values.
    # (Unlisted facets should be discarded in translation.)
    #
    # TODO: More facets and values...
    # TODO: This should be maintained in a YAML file or other external config.
    #
    SOLR_TO_EBSCO_VALUES = {
      format_facet:   SOLR_FORMAT_TO_EBSCO_SOURCE_TYPE,
      language_facet: SOLR_LANGUAGE_TO_EBSCO_LANGUAGE,
    }.deep_freeze

    # Translate EBSCO facet values to the equivalent Solr values.
    # (Unlisted facets should be discarded in translation.)
    #
    # TODO: More facets and values...
    # TODO: This should be maintained in a YAML file or other external config.
    #
    EBSCO_TO_SOLR_VALUES = {
      SourceType: EBSCO_SOURCE_TYPE_TO_SOLR_FORMAT,
      Language:   EBSCO_LANGUAGE_TO_SOLR_LANGUAGE,
    }.deep_freeze

    # =========================================================================
    # :section: Links
    # =========================================================================

    public

    # Indicates whether constraints should be displayed.
    #
    # Note that this method will return *true* except for a handful of special
    # situations, so it should only be used in page templates where constraints
    # would expected to be seen.
    #
    def show_constraints?
      !combined_search_results? &&
        !home_page? && !music_home_page? && !video_home_page?
    end

    # Create the appropriate "start over" link.
    #
    # @param [Array<String>] args
    # - The first (non-hash) argument from *args* is used as the link label;
    #   if no argument is present, self#START_OVER_LABEL is used.
    # - If no options are present in *args* then the link is created with
    #   { class: 'start-over-link' }
    #
    # @return [ActiveSupport::SafeBuffer]
    #
    def start_over_link(*args)
      html_opt = {
        class:  'start-over-link',
        role:   'button',
        title:  'Clear search terms and ' \
                "begin a new #{portal_search_label} search."
      }
      html_opt.merge!(args.pop) if args.last.is_a?(Hash)

      link_label   = args.first
      link_label &&= ERB::Util.h(link_label)
      link_label ||= START_OVER_LABEL

      link_path = (search_context == :all) ? root_path : portal_start_over_path

      link_to(link_label, link_path, html_opt)
    end

    # Express each value as a link to a search for that facet value.
    #
    # @param [Symbol] facet           The search facet which will be the basis
    #                                   of the search link.
    #
    # @param [Array<UVA::IndexDoc, String, Array<String>>] values
    # * If [String] or [Array<String>] then these are the value(s) for which
    #   facet search links will be generated.
    # * If [UVA::IndexDoc] then the values to use will be acquired via that
    #   object's #values_for method.  (If there are additional *values* beyond
    #   this one then they are appended to the results of that call.)
    #
    # @return [Array<ActiveSupport::SafeBuffer>]  Zero or more <a> elements.
    #
    def facet_search_links(facet, *values)
      html_options = values.last.is_a?(Hash) ? values.pop.rdup : {}
      html_options[:controller] ||= portal_controller
      html_options[:action] = 'index'
      html_options.delete(:id)
      values.flat_map { |value|
        value.is_a?(UVA::IndexDoc) ? value.evaluate(facet) : value
      }.reject(&:blank?).clean_uniq.map do |value|
        add_facet_link(facet, value, html_options)
      end
    end

    # Presents the appropriate links for changing search scope.
    #
    # @return [ActiveSupport::SafeBuffer]
    #
    # @see self#get_search_link
    #
    def switch_search_scope_links
      this_portal = portal_controller
      result = content_tag(:legend, 'Switch to:', class: 'search-switch-label')
      result <<
        PORTAL.map { |k, v|
          next if v[:controller] == this_portal
          next unless v[:enabled] && v[:search_scope]
          name  = v[:search_label]
          label = "#{name}"
          label << ' Results' unless classic_lens?
          path  = get_search_link(k)
          opt   = { class: "#{name.downcase.sub(/\s*\+\s*/, '-')}-search" }
          link_to(label, path, opt)
        }.compact.join(scope_separator)
      result.html_safe
    end

    # Presents appropriate links for changing search scope.
    #
    # @return [ActiveSupport::SafeBuffer]
    #
    # @see self#get_search_link
    #
    def search_elsewhere_links
      this_portal = portal_controller
      result =
        PORTAL.map { |k, v|
          next if v[:controller] == this_portal
          next unless v[:enabled] && v[:search_elsewhere]
          name  = (k == :all) ? 'everything' : k.to_s
          label = "Search #{name}"
          path  = get_search_link(k)
          opt   = {}
          link_to(label, path, opt)
        }.compact
      result << link_to(START_OVER_LABEL, portal_start_over_path(params))
      result.map { |link| content_tag(:li, link) }.join.html_safe
    end

    # Used on combined view to view more results.
    #
    # @param [Array<String>] css_class
    #
    # @return [ActiveSupport::SafeBuffer]
    #
    # @see self#get_search_link
    #
    def see_all_results(*css_class)
      portal = articles_lens? ? articles_portal : catalog_portal
      search = portal_search_label(portal).downcase
      label  = "See all #{search} results &rarr;".html_safe
      path   = get_search_link(portal)
      opt    = { class: css_class.join(SPACE) }
      link_to(label, path, opt)
    end

    # Catalog items and articles paginate differently.
    #
    # @param [RSolr::Ext::Response::Base, UVA::ArticleDoc::Response] response
    # @param [Hash] opt
    #
    # @return [ActiveSupport::SafeBuffer]
    #
    # @see Kaminari::ActionViewExtension#paginate
    #
    def pagination_links(response, opt = nil)
      opt = opt ? opt.dup : {}
      opt[:params] ||= params.rdup
      scope =
        if response.respond_to?(:paginate_values)
          response.paginate_values
        else
          paginate_params(response)
        end
      paginate(scope, opt)
    end

    # =========================================================================
    # :section: Links
    # =========================================================================

    protected

    # scope_separator
    #
    # @param [String] label           Default: '|'.
    # @param [String] css_class       Default: 'divider'.
    #
    # @return [ActiveSupport::SafeBuffer]
    #
    def scope_separator(label = '|', css_class = 'divider')
      span(label, class: css_class)
    end

    # get_search_link
    #
    # @param [Symbol] portal          One of `UVA::Portal#PORTAL.keys`.
    # @param [Hash]   url_params      Default: `params`.
    #
    # @return [String]                Relative URL path with options.
    #
    def get_search_link(portal, url_params = nil)

      url_params =
        search_session(portal).except(*SEARCH_SESSION_IGNORED).presence ||
        make_search_params(portal, url_params)
      url_params.delete_if { |_, v| v.blank? }

      # Adjust :catalog_select.
      all = PORTAL[:all][:catalog_select]
      if portal.to_s == all
        url_params[:catalog_select] = all
      else
        url_params.delete(:catalog_select)
      end

      # Generate the search path.
      if url_params.present?
        index_path(portal, url_params)
      else
        all_path(portal)
      end

    end

    # make_search_params
    #
    # @param [Symbol] portal          One of `UVA::Portal#PORTAL.keys`.
    # @param [Hash]   url_params      Default: `params`.
    #
    # @return [ActiveSupport::HashWithIndifferentAccess]
    #
    def make_search_params(portal, url_params = nil)

      url_params ||= params
      url_params = url_params.except(*FACET_IGNORED_KEYS).rdup

      from_controller     = url_params[:controller]
      from_article_search = (from_controller == articles_portal)
      from_music_search   = (from_controller == music_portal)

      to_controller       = portal_controller(portal)
      to_article_search   = (to_controller == articles_portal)
      to_music_search     = (to_controller == music_portal)

      if from_article_search && to_article_search
        from_article_search = to_article_search = false
      end
      if from_music_search && to_music_search
        from_music_search = to_music_search = false
      end

      # Adjust search field if necessary.
      old_search_field = url_params[:search_field]
      if old_search_field == 'advanced'
        if to_music_search
          q = url_params.delete(:keyword)
          url_params[:music] ||= q if q.present?
        elsif from_music_search
          q = url_params.delete(:music)
          url_params[:keyword] ||= q if q.present?
        end
      else
        new_search_field =
          if to_music_search && (old_search_field == 'keyword')
            'music'
          elsif from_music_search && (old_search_field == 'music')
            'keyword'
          end
        url_params[:search_field] = new_search_field if new_search_field
      end

      # Translate advanced search date range values from article search to Solr
      # search.  Article search may have years and months but Solr search can
      # have only years.
      if from_article_search
        [:publication_date_start, :publication_date_end].each do |f|
          value = url_params[f]
          next unless value.present?
          value = value.to_s.sub(/^.*(\d{4}).*$/, '\1')
          if value.present?
            url_params[f] = value
          else
            url_params.delete(f)
          end
        end
      elsif (f = url_params[:f]) && (era = f.delete(:published_date_facet))
        url_params[:publication_date] = publication_era_range(era)
      end

      # Translate facets if possible; otherwise, only keep the ones that are
      # defined for this portal.
      facet_map, value_map =
        if to_article_search
          [SOLR_TO_EBSCO_FACETS, SOLR_TO_EBSCO_VALUES]
        elsif from_article_search
          [EBSCO_TO_SOLR_FACETS, EBSCO_TO_SOLR_VALUES]
        end
      [:f_inclusive, :f].each do |field|
        # The order is significant: One-to-many mappings of :f facets by
        # #translate_facets! may create :f_inclusive facet entries (which would
        # be undone if :f_inclusive were processed afterwards).
        facets = url_params[field]
        if facets.blank?
          url_params.delete(field)
        elsif facet_map || value_map
          translate_facets!(url_params, field, facet_map, value_map)
        else
          to_controller ||= portal_controller(catalog_portal)
          facets.keep_if do |src_facet, _|
            facet_fields_config(to_controller).include?(src_facet.to_s)
          end
        end
      end

      # Preserve sort if possible.
      sort_key = url_params[:sort_key]
      if sort_key.present?
        new_sort_key =
          if to_article_search
            SOLR_TO_EBSCO_SORT[sort_key] || SOLR_TO_EBSCO_SORT[nil]
          elsif from_article_search
            EBSCO_TO_SOLR_SORT[sort_key] || EBSCO_TO_SOLR_SORT[nil]
          end
        url_params[:sort_key] = new_sort_key if new_sort_key
      end

      # Adjust for article search and return the new parameters.
      if to_article_search
        adjust_tlevel!(url_params)
        url_params.except!(*extended_search_fields)
      end
      url_params.with_indifferent_access

    end

    # translate_facets
    #
    # @param [Hash]                 url_params
    # @param [String, Symbol]       field         Either :f or :f_inclusive
    # @param [Hash{Symbol=>Symbol}] facet_map
    # @param [Hash{Symbol=>Hash}]   value_map
    #
    # @return [void]
    #
    # === Usage Notes
    # - Either *facet_map* and *value_map* may be *nil* (but not both).
    # - If *facet_map* is *nil*, the result will have the same facet parameter
    #     but with translated values; note that if there is no explicit
    #     translation, the original facet value will simply be removed.
    # - If *value_map* is *nil*, the result will have a translated facet
    #     parameter containing the same facet values as the original facet.
    #
    def translate_facets!(url_params, field, facet_map, value_map)

      url_params ||= params
      field  = field.to_s.to_sym
      facets = url_params[field]
      return unless facets.present?

      facets.keys.each do |src_facet|

        src_facet  = src_facet.to_sym
        src_values = facets.delete(src_facet)
        dst_facet  = facet_map ? facet_map[src_facet] : src_facet
        dst_map    = value_map && value_map[src_facet]
        next unless dst_facet.present? && src_values.present?

        # Hashes from the URL always have a "value" of "1" -- it's the "keys"
        # that hold the facet selection(s).
        src_values = src_values.keys if src_values.is_a?(Hash)

        # Translate the one or more source facet selection values.
        Array(src_values).each do |src_value|
          next unless src_value.present?
          dst_value   = dst_map && (dst_map[src_value] || dst_map[nil])
          dst_value ||= src_value
          # Simplify if possible.
          if dst_value.is_a?(Array) && dst_value.size == 1
            dst_value = dst_value.first
          end
          # Mapping from one-to-many facet values means that the destination
          # facet must be within :f_inclusive.  If *field* is :f, this means
          # that the destination cannot be *facets*.
          if dst_value.is_a?(Array)
            if field == :f
              url_params[:f_inclusive] ||= {}
              dst_value.each do |dv|
                url_params[:f_inclusive][dst_facet] ||= {}
                url_params[:f_inclusive][dst_facet][dv] = 1
              end
            else
              dst_value.each do |dv|
                facets[dst_facet] ||= {}
                facets[dst_facet][dv] = 1
              end
            end
          elsif field == :f_inclusive
            facets[dst_facet] ||= {}
            facets[dst_facet][dst_value] = 1
          else
            facets[dst_facet] = dst_value
          end
        end

      end

    end

    # remove_filter_link
    #
    # @param [String] tooltip
    # @param [Hash]   url_params
    # @param [Hash]   opt               HTML options for the link
    #
    # @option opt [String] :label       Override 'x'.
    # @option opt [String] :class       Override 'remove-filter'.
    #
    def remove_filter_link(tooltip, url_params, opt = nil)
      html_opt = {
        class: 'remove-filter',
        title: tooltip,
        label: REMOVE_FILTER_LABEL
      }
      html_opt.merge!(opt) if opt.present?
      label = html_opt.delete(:label)
      link_path =
        if url_params.is_a?(String)
          url_params
        elsif classic_browse_results?(url_params)
          url_params
        elsif combined_search_results?(url_params)
          portal_home_path(url_params.except(:q))
        else
          portal_index_path(url_params)
        end
      action_link(label, link_path, html_opt)
    end

    # =========================================================================
    # :section: Query search terms
    # =========================================================================

    public

    # show_queries
    #
    # @return [ActiveSupport::SafeBuffer]
    #
    def show_queries
      queries = [show_keyword_query, show_advanced_query].reject(&:blank?)
      queries << show_no_query if queries.blank? && facetless?
      span(*queries, class: 'applied-query-set')
    end

    # show_keyword_query
    #
    # @param [String] css_class       Default: "applied-query"
    #
    # @return [ActiveSupport::SafeBuffer]
    # @return [nil]
    #
    def show_keyword_query(css_class = 'applied-query')
      query_term = params[:q]
      return if null_search_term?(query_term)
      value = ERB::Util.h(query_term)
      query_constraint(nil, value, css_class)
    end

    # show_advanced_query
    #
    # @param [String] css_class       Default: "applied-query"
    #
    # @return [ActiveSupport::SafeBuffer]
    # @return [nil]
    #
    def show_advanced_query(css_class = 'applied-query')
      return unless (advanced_queries = advanced_search_values).present?
      advanced_queries.map { |field, value|

        # Determine if this is a query that is supported in the current lens.
        # If not, it will not be displayed in the constraints.
        case field.to_s
          when /_nostem/
            value = nil if classic_lens?
          when 'publication_date'
            this = Date.today
            separator = ' - '
            parts = range_value(field).values
            start_date, end_date =
              parts.map do |part|
                if %w(0 now today present).include?(part.downcase)
                  nil
                elsif part.start_with?('0-')
                  nil
                elsif part =~ /^\d{4}$/
                  part unless part.to_i == this.year
                elsif !(date = Date.parse(part.tr('-', '/')) rescue nil)
                  part
                elsif !((date.year == this.year) && (date.month >= this.month))
                  date.strftime('%b %Y')
                end
              end
            start_date ||= ''
            end_date   ||= 'present'
            value = [start_date, end_date].join(separator)
        end

        query_constraint(field, value, css_class) if value.present?

      }.compact.join("\n").html_safe
    end

    # show_no_query
    #
    # @param [String] label
    # @param [String] css_class       Default: "applied-query no-keywords"
    #
    # @return [ActiveSupport::SafeBuffer]
    #
    def show_no_query(label = nil, css_class = 'applied-query no-keywords')
      label ||= span('No Keywords')
      span(label, class: css_class)
    end

    # =========================================================================
    # :section: Query search terms
    # =========================================================================

    protected

    # query_term
    #
    # @param [String]                name
    # @param [String]                value
    # @param [String, Array<String>] state      Default: *nil*
    #
    # @return [ActiveSupport::SafeBuffer]
    #
    def query_term(name, value, state = nil)
      value = value.gsub(/(?<= )OR(?: )/, or_connector)
      filter_term(name, value, state, 'query')
    end

    # query_constraint
    #
    # @param [Symbol, String] field
    # @param [String]         value
    # @param [String]         css_class
    #
    # @return [ActiveSupport::SafeBuffer]
    #
    def query_constraint(field, value, css_class = 'applied-query')

      # Search query type and user-supplied search term(s).
      label =
        if field
          extended_search_labels(field) || label_for_search_field(field)
        else
          search_field_label(params)
        end
      filter = query_term(label, value)

      # "Remove filter" button.
      if classic_lens?
        url_params = classic_home_path
      elsif field
        url_params = remove_advanced_search_field(field)
      else
        url_params =
          params.slice(:controller, :f, :format, :sort_key, :search_field)
        advanced_queries = advanced_search_values
        if advanced_queries.present?
          url_params.merge!(advanced_queries)
        elsif params[:f].blank? && params[:f_inclusive].blank?
          url_params[:q] = FACET_ONLY_SEARCH
        end
      end
      if combined_search_results?
        url_params[:catalog_select] = params[:catalog_select]
      end
      remove_filter = remove_filter_link(REMOVE_QUERY_TIP, url_params)

      # Element showing the query terms.
      constraint_element(filter, remove_filter, css_class)
    end

    # =========================================================================
    # :section: Facet filters
    # =========================================================================

    public

    # show_facets
    #
    # @return [ActiveSupport::SafeBuffer]
    # @return [nil]
    #
    def show_facets
      facets = [show_exclusive_facets, show_advanced_facets].reject(&:blank?)
      facets.join.html_safe if facets.present?
    end

    # show_exclusive_facets
    #
    # @param [String] css_class       Default: "applied-filter"
    #
    # @return [ActiveSupport::SafeBuffer]
    # @return [nil]
    #
    def show_exclusive_facets(css_class = 'applied-filter')

      # Only display values for facets that are supported in the current lens.
      facets =
        (params[:f] || {}).map { |facet, values|
          label = facet_field_labels[facet]
          next unless label.present? || SHOW_IGNORED_FACETS
          values = Array(values).reject(&:blank?)
          next unless values.present?
          [facet, values]
        }.compact.to_h
      return unless facets.present?

      content_tag(:span, class: 'applied-filter-set') do
        facets.flat_map { |facet, values|

          # If showing unsupported facets, provide a generic label.
          label = facet_field_labels[facet]
          state = ('link-disabled' if label.blank?)
          label = 'N/A' if label.blank?

          # Generate a constraint element for each facet value.
          values.map do |value|
            facet_constraint(false, facet, label, value, css_class, state)
          end

        }.compact.join("\n").html_safe
      end
    end

    # show_advanced_facets
    #
    # @param [String] css_class       Default: "applied-filter"
    #
    # @return [ActiveSupport::SafeBuffer]
    # @return [nil]
    #
    def show_advanced_facets(css_class = 'applied-filter')

      # Only display values for facets that are supported in the current lens.
      facets =
        (params[:f_inclusive] || {}).map { |facet, values|
          label = facet_field_labels[facet]
          next unless label.present? || SHOW_IGNORED_FACETS
          values = Array(values).map { |v| Array(v).first }.reject(&:blank?)
          next unless values.present?
          [facet, values]
        }.compact.to_h
      return unless facets.present?

      content_tag(:span, class: 'applied-filter-set') do
        facets.map { |facet, values|

          # If showing unsupported facets, provide a generic label.
          label = facet_field_labels[facet]
          state = ('link-disabled' if label.blank?)
          label = 'N/A' if label.blank?

          # Generate a compound constraint element for each set of facet values
          # which are 'OR'ed together.
          if values.size == 1
            value = values.first
            facet_constraint(true, facet, label, value, css_class, state)
          else
            label = facet_term(label, nil, state)
            filter_css = "#{css_class} inner"
            filter_set =
              values.map { |value|
                facet_constraint(true, facet, nil, value, filter_css, state)
              }.compact.join(or_connector).html_safe
            constraint_element(label, filter_set, css_class)
          end

        }.compact.join("\n").html_safe
      end
    end

    # =========================================================================
    # :section:
    # =========================================================================

    protected

    # facet_term
    #
    # @param [String]                name
    # @param [String]                value
    # @param [String, Array<String>] state      Default: *nil*
    #
    # @return [ActiveSupport::SafeBuffer]
    #
    def facet_term(name, value, state = nil)
      filter_term(name, value, state)
    end

    # facet_constraint
    #
    # @param [Boolean]               advanced
    # @param [Symbol, String]        facet
    # @param [String]                label
    # @param [FacetItem, String]     value
    # @param [String]                css_class
    # @param [String, Array<String>] state
    #
    # @return [ActiveSupport::SafeBuffer]
    #
    def facet_constraint(advanced, facet, label, value, css_class, state = nil)

      # Facet name and value.
      display = facet_display_value(facet, value)
      filter  = facet_term(label, display, state)

      # "Remove filter" button.
      url_params =
        if classic_lens?
          classic_home_path
        elsif advanced
          remove_advanced_facet(facet, value)
        else
          remove_facet(facet, value)
        end
      if searchless?(url_params) && facetless?(url_params)
        url_params[:q] = FACET_ONLY_SEARCH
      end
      if (facet.to_s == 'tlevel') && (value == 'peer_reviewed')
        url_params[:peer_reviewed] = 'false'
      end
      remove_filter = remove_filter_link(REMOVE_FILTER_TIP, url_params)

      # Element showing the applied facet filter.
      constraint_element(filter, remove_filter, css_class)

    end

    # =========================================================================
    # :section:
    # =========================================================================

    protected

    # filter_term
    #
    # @param [String]                name
    # @param [String]                value
    # @param [String, Array<String>] state      Default: *nil*
    # @param [String]                css_base   Default: 'filter'
    #
    # @return [ActiveSupport::SafeBuffer]
    #
    def filter_term(name, value, state = nil, css_base = 'filter')
      state = state.presence
      state = state.join(' ') if state.is_a?(Array)
      state = " #{state}"     if state.is_a?(String) && !state.start_with?(' ')
      name  &&= span(name,  class: "#{css_base}-name#{state}")
      value &&= span(value, class: "#{css_base}-value#{state}")
      span(name, sr_only(': '), value, class: 'name-and-value')
    end

    # constraint_element
    #
    # @param [ActiveSupport::SafeBuffer] filter
    # @param [ActiveSupport::SafeBuffer] remove_filter
    # @param [String]                    css_class
    #
    # @return [ActiveSupport::SafeBuffer]
    #
    # === Usage Notes
    # If *css_class* includes "inner" then an extra `<span class="wrapper">`
    # is used so that the pair of items can be managed together while allowing
    # the styling of *css_class* to remain consistent.
    #
    def constraint_element(filter, remove_filter, css_class)
      if css_class.to_s.split(' ').include?('inner')
        span(span(filter, remove_filter, class: 'wrapper'), class: css_class)
      else
        span(filter, remove_filter, class: css_class)
      end
    end

    # or_connector
    #
    # @param [String] css_class       Default: 'connector'.
    #
    # @return [ActiveSupport::SafeBuffer]
    #
    def or_connector(css_class = 'connector')
      span('OR', class: css_class)
    end

    # span
    #
    # @param [Array<String>] args
    #
    # @return [ActiveSupport::SafeBuffer]
    #
    def span(*args)
      opt = args.last.is_a?(Hash) ? args.pop.reject { |_, v| v.blank? } : {}
      parts = args.reject(&:blank?).join
      content_tag(:span, parts.html_safe, opt) if parts.present?
    end

  end

end
