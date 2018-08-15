# lib/uva/advanced_search/range_query_parser.rb

require 'uva'

module UVA::AdvancedSearch

  # UVA::AdvancedSearch::RangeQueryParser
  #
  module RangeQueryParser

    include UVA

    class << self
      include UVA::AdvancedSearch::AdvancedSearchFields
    end

    # =========================================================================
    # :section:
    # =========================================================================

    public

    # Construct a Solr query.
    #
    # @param [String]                  key
    # @param [Array<(String, String)>] ranges
    #
    # @return [String]
    #
    # @example range.length == 1
    #
    #   _query_:"{!lucene}year_multisort_i:1800"
    #
    # @example range.length == 2
    #
    #   _query_:"{!lucene}year_multisort_i:[1800 TO 1860]"
    #
    def self.parse(key, ranges)
      field_def = advanced_search_fields[key]
      return if field_def.blank?
      query_expression =
        case ranges.length
          when 1 then ranges.first.to_s
          when 2 then "[#{ranges.first} TO #{ranges.last}]"
          else        return
        end
      "_query_:\"{!lucene}#{field_def.solr_field}:#{query_expression}\""
    end

  end

end
