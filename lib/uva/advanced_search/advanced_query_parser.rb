# lib/uva/advanced_search/advanced_query_parser.rb

require 'uva'

module UVA::AdvancedSearch

  # UVA::AdvancedSearch::QueryParser
  #
  class QueryParser < BlacklightAdvancedSearch::QueryParser

    include UVA
    include UVA::Util

    # =========================================================================
    # :section:
    # =========================================================================

    public

    # range_queries
    #
    # @return [Hash]
    #
    def range_queries
      @range_queries ||=
        if @params[:search_field] == @config.advanced_search[:url_key]
          @config.search_fields.map { |key, field_def|
            next unless true_value?(field_def.range)
            p_start   = @params["#{key}_start"]
            p_start &&= (p_start.to_sym if p_start.to_s =~ /^(-)?\d+$/)
            p_end     = @params["#{key}_end"]
            p_end   &&= (p_end.to_sym   if p_end.to_s =~ /^(-)?\d+$/)
            value =
              if p_start && p_end
                [p_start, p_end]
              elsif p_start
                [p_start, Time.current.year.to_s]
              elsif p_end
                ['*', p_end]
              end
            [key, value] if value.present?
          }.compact.to_h
        else
          {}
        end
    end

    # =========================================================================
    # :section: BlacklightAdvancedSearch overrides
    # =========================================================================

    public

    # keyword_queries
    #
    # @return [Hash]
    #
    # Compare with:
    # @see BlacklightAdvancedSearch::QueryParser#keyword_queries
    #
    def keyword_queries
      @keyword_queries ||=
        if @params[:search_field] == @config.advanced_search[:url_key]
          @config.search_fields.map { |key, _field_def|
            value = @params[key]
            [key, value] if value.present?
          }.compact.to_h
        else
          {}
        end
    end

    # to_solr
    #
    # @return [Hash{Symbol=>String}]
    #
    # Compare with:
    # @see BlacklightAdvancedSearch::QueryParser#to_solr
    #
    def to_solr
      @to_solr ||= {
        q:  process_query(params, config),
        fq: generate_solr_fq
      }
    end

    # Overriding from plugin to include range_queries.
    #
    # @param [Hash]                      _params  Currently unused.
    # @param [Blacklight::Configuration] config
    #
    # Compare with:
    # @see BlacklightAdvancedSearch::ParsingNestingParser#process_query
    #
    def process_query(_params, config)
      queries =
        keyword_queries.map do |field, query|
          query = balance_double_quotes(query)
          lph = local_param_hash(field, config)
          ExpressionParserOverride.parse(query).to_query(lph)
        end
      queries +=
        range_queries.map do |key, ranges|
          RangeQueryParser.parse(key, ranges)
        end
      queries.join(" #{keyword_op} ")
    end

  end

end
