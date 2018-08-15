# lib/uva/advanced_search/advanced_search_fields.rb

require 'uva'

module UVA::AdvancedSearch

  # UVA::AdvancedSearch::AdvancedSearchFields
  #
  module AdvancedSearchFields

    include UVA
    include UVA::Scope
    include UVA::Util

    # =========================================================================
    # :section:
    # =========================================================================

    public

    NOSTEM_FIELDS = {
      title_nostem:   'Title stemming',
      author_nostem:  'Author stemming',
      journal_nostem: 'Journal Title stemming',
      subject_nostem: 'Subject stemming',
      keyword_nostem: 'Keyword stemming',
    }.deep_freeze

    FULLTEXT_FIELDS = {
      keyword_full: 'Keyword full text',
    }.deep_freeze

    EXTENDED_FIELDS =
      NOSTEM_FIELDS
        .merge(FULLTEXT_FIELDS)
        .merge(undiscoverable: 'Search within collections')
        .deep_freeze

    # Because the the NOSTEM_FIELD labels are phrased as a positive, the value
    # for the selection in the search constraints needs to be a negative.
    # (I.e., no-stemming for XXX will display as "XXX stemming > Off").
    NOSTEM_CONSTRAINT_LABEL = 'Off'.freeze

    # The value for the selection in the search constraints when fulltext is
    # turned on for a field.  (Currently only applies to "keyword".)
    FULLTEXT_CONSTRAINT_LABEL = 'On'.freeze

    # =========================================================================
    # :section:
    # =========================================================================

    public

    # Get the nostem variant of *key*.
    #
    # @param [String, Symbol] key     Solr field.
    #
    # @return [String]                The nostem variant of *key*
    # @return [nil]                   If *key* does not have a nostem variant.
    #
    def nostem_field(key)
      key = key.to_s.downcase
      %W(#{key} #{key}_nostem).find do |nostem_key|
        return nostem_key if NOSTEM_FIELDS[nostem_key.to_sym]
      end
    end

    # Get the parameter value of the nostem variant of *key*.
    #
    # @param [String, Symbol] key     Solr field.
    #
    # @return [String]                The value from `params`.
    # @return [nil]                   If *key* does not have a nostem variant.
    #
    def nostem_param(key)
      key = nostem_field(key)
      params[key] if key.present?
    end

    # The value passed with the URL parameter which is also displayed as the
    # value in the search constraints.
    #
    # @return [String]
    #
    def nostem_selected_value
      NOSTEM_CONSTRAINT_LABEL
    end

    # Add the parameter which indicates the field should be unstemmed.
    #
    # @param [Hash]           hash    Hash to modify.
    # @param [String, Symbol] key     Solr field.
    #
    # @return [Hash]                  The modified hash.
    # @return [nil]                   If *key* was not valid.
    #
    def set_nostem!(hash, key)
      return unless (key = nostem_field(key))
      hash[key] = nostem_selected_value
      hash
    end

    # Remove the parameter which indicates the field should be unstemmed.
    #
    # @param [Hash]           hash    Hash to modify.
    # @param [String, Symbol] key     Solr field.
    #
    # @return [Hash]                  The modified hash.
    # @return [nil]                   If *key* was not valid.
    #
    def unset_nostem!(hash, key)
      return unless (key = nostem_field(key))
      hash.delete(key)
      hash
    end

    # Get the fulltext variant of *key*.
    #
    # @param [String, Symbol] key     Solr field.
    #
    # @return [String]                The fulltext variant of *key*
    # @return [nil]                   If *key* does not have a fulltext variant
    #
    def fulltext_field(key)
      key = key.to_s.downcase
      %W(#{key} #{key}_full).find do |fulltext_key|
        return fulltext_key if FULLTEXT_FIELDS[fulltext_key.to_sym]
      end
    end

    # Get the parameter value of the fulltext variant of *key*.
    #
    # @param [String, Symbol] key     Solr field.
    #
    # @return [String]                The value from `params`.
    # @return [nil]                   If *key* does not have a fulltext variant
    #
    def fulltext_param(key)
      key = fulltext_field(key)
      params[key] if key.present?
    end

    # The value passed with the URL parameter which is also displayed as the
    # value in the search constraints.
    #
    # @return [String]
    #
    def fulltext_selected_value
      FULLTEXT_CONSTRAINT_LABEL
    end

    # Return part or all of the extended search field names and labels.
    #
    # @param [Symbol, String, Regexp] term
    #   - If *nil* then all entries are returned.
    #   - If *String* or *Symbol* then *term* is compared with EXTENDED_FIELD
    #       keys; if it is found a Hash with one element is returned; otherwise
    #       an empty Hash is returned.
    #   - If *Regexp* then all EXTENDED_FIELD entries with keys matching the
    #       expression are returned.
    #
    # @return [Hash{Symbol=>String}]
    #
    def extended_search_fields(term = nil)
      term = term.downcase.to_sym if term.is_a?(String)
      case term
        when Symbol then EXTENDED_FIELDS.select { |k, _| k == term }
        when Regexp then EXTENDED_FIELDS.select { |k, _| k.to_s ~ term }
        else             EXTENDED_FIELDS
      end
    end

    # Return the label for the indicated extended search field key.
    #
    # @param [Symbol, String, Regexp] term
    #
    # @return [String]                If *term* matched an EXTENDED_FIELDS key.
    # @return [nil]                   If *term* did not match any key.
    #
    def extended_search_labels(term)
      extended_search_fields(term).values.first
    end

    # =========================================================================
    # :section:
    # =========================================================================

    public

    # The subset of facets which are part of the "LIMIT RESULTS BY" menus on
    # Articles Advanced Search.
    #
    # @return [Array<String>]
    # @return [nil]
    #
    def advanced_facets
      fsp = current_blacklight_config.advanced_search.presence
      fsp &&= fsp[:form_solr_parameters].presence
      fsp[:'facet.field'].map(&:to_s).presence if fsp
    end

    # =========================================================================
    # :section:
    # =========================================================================

    public

    # List of advanced search fields.
    #
    # @return [Hash{String=>Blacklight::Configuration::SearchField}]
    #
    def advanced_search_fields
      search_fields_config
    end

    # advanced_search_range_fields
    #
    # @return [Hash{String=>Blacklight::Configuration::SearchField}]
    #
    def advanced_search_range_fields
      advanced_search_fields.select do |_, field_def|
        true_value?(field_def.range)
      end
    end

    # Hash of populated advanced search fields.
    #
    # @param [Hash] url_params        Default: `params`
    #
    # @return [Hash]
    #
    #--
    # rubocop:disable Metrics/AbcSize # [52.92/45]
    # rubocop:disable Metrics/CyclomaticComplexity # [20/18]
    # rubocop:disable Metrics/PerceivedComplexity # [22/21]
    # rubocop:disable Metrics/MethodLength # [48/35]
    #++
    def advanced_search_values(url_params = nil)

      url_params ||= params
      fields = {}

      # Copy advanced search fields.
      advanced_search_fields.each_key do |field|
        value = balance_double_quotes(url_params[field]).presence
        value ||= search_session[field].presence
        fields[field] = value.rdup if value
      end

      # Copy special search fields.
      extended_search_fields.each_key do |field|
        value = url_params[field].presence || search_session[field].presence
        fields[field.to_s] = value.rdup if value
      end

      # Copy range fields.
      ranges = advanced_range_values(url_params)
      fields.merge(ranges)

      # rubocop:enable Metrics/AbcSize
      # rubocop:enable Metrics/CyclomaticComplexity
      # rubocop:enable Metrics/PerceivedComplexity
      # rubocop:enable Metrics/MethodLength
    end

    # Find range parameters in the URL parameters.
    #
    # Validation is performed on the values, however the original strings of
    # the range start and/or range end are returned.  This allows the
    # "Refine search" to re-populate the advanced search form with the original
    # strings that the user entered rather than the processed values.
    #
    # @param [Hash]  url_params       Default: `params`
    # @param [Array] errors           If provided, it will be filled with each
    #                                   validation error which can be displayed
    #                                   in a flash message to the user.
    #
    # @return [Hash]                  Valid range field values (may be empty).
    #
    def advanced_range_values(url_params = nil, errors = nil)

      url_params ||= params
      article = articles_lens?(url_params) && article_engine

      advanced_search_range_fields.keys.map { |field|

        # Look for the individual range component parameter(s) (there may only
        # be one).  If these are not present, look for the combined range
        # parameter (which would be a string of the form "START_VAL - END_VAL")
        p_start = url_params["#{field}_start"].to_s
        p_end   = url_params["#{field}_end"].to_s
        if p_start.blank? && p_end.blank?
          p_start, p_end = url_params[field].to_s.split(' - ')
        end
        next unless p_start.present? || p_end.present?

        case field.to_sym
          when :publication_date
            # Collect the individual value(s) in a form that can be validated.
            start_date =
              if article
                article.date_format(p_start, :start)
              elsif p_start =~ /^(-)?\d+$/
                p_start.to_i
              end
            end_date =
              if article
                article.date_format(p_end, :end)
              elsif p_end =~ /^(-)?\d+$/
                p_end.to_i
              elsif %w(0 now today present).include?(p_end.to_s.downcase)
                Date.today.year
              elsif p_end.blank? && start_date
                Date.today.year
              end
            # Validate the range value(s).
            problems = []
            problems << :bad_start if p_start.present? && !start_date
            problems << :bad_end   if p_end.present?   && !end_date
            if problems.empty? && start_date && end_date
              start_date = date_number(start_date, :start)
              end_date   = date_number(end_date,   :end)
              problems << :reversed if start_date > end_date
            end
            valid = problems.empty?
            # If an error array was supplied, list validation problems there.
            if errors
              unit = article ? 'date' : 'year'
              errors +=
                problems.map { |problem|
                  case problem
                    when :bad_start
                      "invalid starting #{unit} #{p_start.inspect}"
                    when :bad_end
                      "invalid ending #{unit} #{p_end.inspect}"
                    when :reversed
                      "start #{unit} cannot be after end #{unit}."
                    when String
                      problem
                  end
                }.compact
              if errors.empty? && article && end_date && (end_date < 1665)
                errors << 'No articles available prior to 1665.'
              end
            end
            # Emit the range if it is valid.
            if valid
              p_start = nil unless start_date
              p_end   = nil unless end_date
              [field.to_s, "#{p_start} - #{p_end}"]
            end
          else
            Rails.logger.error {
              "#{__method__}: " \
              "unexpected advanced search range #{field.inspect}"
            }
        end
      }.compact.to_h
    end

    # =========================================================================
    # :section:
    # =========================================================================

    private

    # Reduce a date value to a number for use in comparisons.
    #
    # @param [Numeric, String] v
    # @param [Symbol]          position
    #
    # @return [Numeric]
    #
    def date_number(v, position = nil)
      default = (position == :start) ? -100000 : Date.today.year
      case v
        when Numeric   then v
        when '0'       then default
        when /^0-/     then "#{default}.#{v.sub(/^0-/, '')}".to_f
        when /^\d{4}$/ then v.to_i
        when String    then v.sub(/^(\d+)\D(\d{2}).*/, '\1.\2').to_f
        else                default
      end
    end

  end

end
