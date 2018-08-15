# lib/uva/classic.rb

require 'uva'

module UVA

  # Methods to support the "Virgo Classic" lens.
  #
  module Classic

    include UVA
    include UVA::AdvancedSearch
    include UVA::Util

    # =========================================================================
    # :section: Feature properties
    # =========================================================================

    public

    class << self

      # If *true*, eliminates modifications supporting "Virgo Classic" lens
      # functionality.
      FEATURE_DISABLED = false

      # Indicate whether links to the "Virgo Classic" portal should be hidden.
      # (This is meaningful only if the feature is not suppressed.)
      FEATURE_HIDDEN = true

      # Name of this feature for display purposes.
      DEFAULT_TITLE = 'Expert Mode'.freeze

      # Icon for "Virgo Classic" button.
      LINK_ICON = 'classic/classic.png'.freeze # TODO: ???

      # Tooltip for "Virgo Classic" button.
      LINK_TOOLTIP = 'Enter Expert mode.'.freeze # TODO: ???

      # Behavioral options
      OPTION = {
        #sc_supported:         true,  # Can be used from Special Collections lens.
        #sc_netbadge:          true,  # Only visible to UVA users (if supported).
        #extra_metadata_popup: false, # Extra metadata visible via popup.
        #extra_metadata_page:  true,  # Extra metadata visible via web page.
      }.deep_freeze

      SEARCH_BUTTON_LABEL = 'Search'.freeze
      SEARCH_BUTTON_CLASS = 'adv-search-button'.freeze

      # Controls whether "See more" appears in "Virgo Classic" lens item
      # details.
      #
      # If *false* then all metadata fields are shown initially.
      # If *true* then the behavior is like the catalog item details show page:
      # A subset of metadata fields are show initially and the user must click
      # on the "see more" link to make the rest of them appear.
      #
      # @see fillDetailsDisplay() in app/assets/javascripts/feature/classic
      #
      SHOW_SEE_MORE = false

      # The number of fields that are displayed before "See more"
      # (if self#SHOW_SEE_MORE is *true*).
      #
      # @see fillDetailsDisplay() in app/assets/javascripts/feature/classic
      #
      SHOW_FIRST_FIELDS = 7

      # Character limit on search result titles and browse by entries.  Longer
      # entries are truncated with "[more]" appended.
      MAX_ENTRY_LENGTH = 250

      # Browse modes and associated labels.
      BROWSE_MODE = {
        author:       'Author',
        title:        'Title',
        journal:      'Journal Title',
        subject:      'Subject',
        series:       'Series',
        call_number:  'Call Number',
      }.deep_freeze

      # Browse modes and associated Solr facets.
      BROWSE_MODE_FACETS = {
        author:       'author_facet',
        title:        'title_facet', # TODO: nope
        journal:      'journal_title_facet',
        subject:      'subject_facet',
        series:       'series_title_facet',
        call_number:  'call_number_facet', # TODO: not really (for browsing anyway)
      }.deep_freeze

      # =======================================================================
      # :section:
      # =======================================================================

      public

      # Indicate whether the "Virgo Classic" lens should be present.
      #
      # @see self#FEATURE_DISABLED
      #
      def feature_enabled?
        !defined?(FEATURE_DISABLED) || !FEATURE_DISABLED
      end

      # Indicate whether links to the "Virgo Classic" portal should be hidden
      # (even if the feature itself is not suppressed).
      #
      def feature_hidden?
        FEATURE_HIDDEN || feature_suppressed?
      end

      # Indicate whether the "Virgo Classic" lens should be unavailable to the
      # current session.
      #
      # @return [Boolean]             The suppression state or *false* if
      #                                 self#feature_enabled? is false.
      #
      def feature_suppressed?
        @feature_suppressed = false unless defined?(@feature_suppressed)
        @feature_suppressed || !feature_enabled?
      end

      # Define whether the "Virgo Classic" lens should be unavailable to the
      # current session.
      #
      # @param [Boolean] state        Set/unset suppression of the feature.
      #
      # @return [Boolean]             The suppression state or *false* if
      #                                 self#feature_enabled? is false.
      #
      def feature_suppressed(state)
        @feature_suppressed = !!state
        feature_suppressed?
      end

      # default_title
      #
      # @return [String]
      #
      def default_title
        DEFAULT_TITLE
      end

      # link_icon
      #
      # @return [String]
      #
      def link_icon
        LINK_ICON
      end

      # link_tooltip
      #
      # @return [String]
      #
      def link_tooltip
        LINK_TOOLTIP
      end

      # =======================================================================
      # :section:
      # =======================================================================

      public

      def search_button_label
        SEARCH_BUTTON_LABEL
      end

      def search_button_class
        SEARCH_BUTTON_CLASS
      end

      # show_see_more
      #
      # @return [Boolean]
      #
      def show_see_more
        SHOW_SEE_MORE
      end

      # show_see_more
      #
      # @return [Fixnum]
      #
      def show_first_fields
        SHOW_FIRST_FIELDS
      end

      # max_entry_length
      #
      # @return [Fixnum]
      #
      def max_entry_length
        MAX_ENTRY_LENGTH
      end

      # browse_modes
      #
      # @return [Array<Symbol>]
      #
      def browse_modes
        BROWSE_MODE.keys
      end

      # browse_mode
      #
      # @param [String, Symbol] mode      Browse search mode.
      #
      # @return [String]
      # @return [Hash]
      #
      def browse_mode(mode)
        BROWSE_MODE[mode.to_sym] if mode
      end

      # browse_mode_label
      #
      # @param [String, Symbol] mode      Browse search mode.
      #
      # @return [String]
      # @return [nil]
      #
      def browse_mode_label(mode)
        BROWSE_MODE[mode.to_sym] if mode
      end

      # browse_mode_facets
      #
      # @return [Hash]
      #
      def browse_mode_facets
        BROWSE_MODE_FACETS
      end

      # browse_mode_facet
      #
      # @param [String, Symbol] mode      Browse search mode.
      #
      # @return [String]
      # @return [nil]
      #
      def browse_mode_facet(mode)
        BROWSE_MODE_FACETS[mode.to_sym] if mode
      end

    end

    # =========================================================================
    # :section:
    # =========================================================================

    private

    TOKEN_SEPARATOR = [' ', ',', ';', ':'].deep_freeze

    RE_SEPARATOR = /[#{TOKEN_SEPARATOR.join}]/

    PRESERVE_CHAR =
      begin
        index = 0
        TOKEN_SEPARATOR.map { |c|
          index += 1
          [c, index.chr]
        }.to_h.deep_freeze
      end

    RESTORE_CHAR = PRESERVE_CHAR.invert.deep_freeze

    # =========================================================================
    # :section:
    # =========================================================================

    public

    # Massage parameters to make this look like an advanced search.
    #
    # @param [Hash]           p       Default: `params`.
    # @param [String, Symbol] mode    Default: inferred from `params`.
    #
    # @return [Symbol]                The browse mode.
    # @return [nil]                   If no browse mode was determined.
    #
    def setup_browse_params(p = nil, mode = nil)

      p    ||= params
      mode ||= UVA::Classic.browse_modes.find { |key| p[key].present? }
      return unless mode

      # Normalize search terms.
      p[mode] = p[mode].to_s.gsub(',', ', ').squish
      p[mode] = balance_double_quotes(p[mode])
      return if p[mode].blank?

      # Clean up potential hangovers from previous searches and turn off
      # stemming.
      p.delete_if { |k, _| k.to_s.include?('nostem') }
      if mode == :call_number
        ##p[:sort_key] = 'call_number'
        #p[:sort] = 'score desc, call_number_sort_facet asc'
      else
        set_nostem!(p, mode)
      end
      p[:browse_mode]  = mode.to_s
      p[:search_field] = 'advanced'

      mode

    end

    # Modify *response* so that
    #
    # @param [RSolr::Ext::Response::Base] response
    # @param [String, Symbol]             browse_mode
    # @param [Hash]                       url_params
    #
    # @return [Array<(RSolr::Ext::Response::Base, Array<RSolr::Ext::Response::Facets::FacetItem>)]
    #
    def generate_facet_list(response, browse_mode, url_params)

      # Locate data for the facet in the response message.
      facet_field = UVA::Classic.browse_mode_facet(browse_mode)
      values_and_hits   = response.facet_fields.presence
      values_and_hits &&= values_and_hits[facet_field]
      values_and_hits ||= []

      # Locate any terms that would have been surrounded by quotes when entered
      # and would need to be surrounded by quotes when displayed.
      url_params ||= params
      terms = url_params[browse_mode]
      terms = tokenize_terms(terms, browse_mode).presence
      quoted, _unquoted, bare_terms, t_increment = nil
      if terms
=begin
        quoted, _unquoted = terms.partition { |v| v.include?(' ') }
        quoted = quoted.presence
=end
=begin
        bare_terms = terms.map { |term| term.gsub(/[[:punct:]]/, '') }
=end
=begin
        index = 0
        terms.map! { |term| [(index -= 1), term] }
=end
=begin
        v_increment = -terms.size
=end
        t_increment = -100
      end

      # Step through the vector of facet names and facet hit counts.
      items = []
      pairs = values_and_hits.dup
      width = 2
      max_pair = (pairs.size / width) - 1
      (0..max_pair).each do |number|

        # Get the data for the current window into the vector.
        index = number * width
        value, hits = pairs[index, width]

        # Analyze the facet value into individual terms, modifying the text to
        # quote strings which will need to be tokenized as a unit.
        if terms
          ranking = 0
          value_copy = value.tr(DQUOTE, ' ')
=begin
          quoted.each { |v| value_copy.gsub!(/\b(#{v})\b/i, '"\1"') } if quoted
=end
          value_terms = tokenize_terms(value_copy, browse_mode)
          value_bare = value_terms.map { |v| v.gsub(/[[:punct:]]/, '') }
          t_index = 0
          terms.each do |term|
            if term.include?(' ')
              # The parts of a quoted term must match a sequence of value_terms
              # tokens.
              t_parts = term.split(' ')
              t_first = t_parts.shift
              v_index = value_terms.find_index { |v_term| (v_term == t_first) }
              v_index ||=
                begin
                  t_bare = t_first.gsub(/[[:punct:]]/, '')
                  value_bare.find_index { |v_term| v_term.start_with?(t_bare) }
                end
              if v_index
                v_parts = value_terms[(v_index + 1), t_parts.size]
                v_index = nil unless t_parts == v_parts
              end
            else
              v_index = value_terms.find_index { |v_term| (v_term == term) }
              # E.g. term "Yalden" will match value "Yalden-Thompson"
              v_index ||=
                begin
                  t_bare = term.gsub(/[[:punct:]]/, '')
                  value_bare.find_index { |v_term| v_term.start_with?(t_bare) }
                end
            end
            # If a term couldn't be found then this value is a mismatch.
            break unless v_index
            t_index += 1
            ranking += (v_index * -t_index) + (t_index * t_increment)
          end
          # Unless all the terms matched this value will be discarded.
          ranking = 0 unless (t_index + 0) == terms.size
        else
          # If there are no terms then no value will be considered a mismatch.
          ranking = 1
        end

        # If all of the search terms could be found in the value terms then
        # this pair is included in the *items* array.  If not then this pair
        # pair will not be included and will also be removed from *response*.
        if ranking.zero?
          pairs[index, width] = [nil] * width
        else
          item = RSolr::Ext::Response::Facets::FacetItem.new(value, hits)
          items << [ranking, item]
        end

      end

      # Migrate closer matches to the top of the list.
      items.sort_by! { |item| -item.first } if terms
      items.map!(&:last)

      # Replace the facet vector with the modified vector.  (No point in
      # making this conditional at this time -- there will always be facet
      # values that will not be included in the result.)
      response.facet_fields[facet_field] = pairs.compact

      return response, items
    end

    # Turn one or more words and/or quoted phrases into an array of strings
    # without quotes.
    #
    # @param [String, Array<String>] terms      Search terms.
    # @param [Symbol, String]        mode       Browse mode.
    # @param [Hash]                  opt
    #
    # @option opt [Boolean] :downcase           Convert terms to lowercase.
    #
    # @return [Array<String>]
    #
    def tokenize_terms(terms, mode, opt = nil)
      option = { downcase: true }
      option.merge!(opt) if opt.present?
      mode = mode.to_s.to_sym
      Array(terms).flat_map { |term|
        if mode == :call_number
          term.tr(' ', '')
        else
          parts = []
          while term.present?
            unquoted, quoted, term = term.partition(/"[^"]*"/)
            parts << unquoted
            parts << quoted.squish.gsub(RE_SEPARATOR) { |c| PRESERVE_CHAR[c] }
          end
          parts = parts.join(' ').split(RE_SEPARATOR)
          parts.map { |s| s.gsub(RE_SEPARATOR) { |c| RESTORE_CHAR[c] } }
        end
      }.map { |term|
        term = term.tr('"', '').squish
        (option[:downcase] ? term.downcase : term) unless term.blank?
      }.reject(&:blank?).uniq
    end

    # Join one or more strings, surrounding strings with quotes if necessary.
    #
    # @param [String, Array<String>] terms
    #
    # @param [String]
    #
    def untokenize_terms(*terms)
      Array(terms).flatten.map { |term|
        (term.include?(' ') ? %Q("#{term}") : term) unless term.blank?
      }.compact.uniq.join(' ')
    end

  end

end
