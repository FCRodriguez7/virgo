# lib/uva/advanced_search/expression_parser_override.rb

require 'parsing_nesting/tree'
require 'uva'

module UVA::AdvancedSearch

  # UVA::AdvancedSearch::ExpressionParserOverride
  #
  # This is basically a hack monkey patch where we accept module behavior but
  # patch an embedded class definition.
  #
  class ExpressionParserOverride # :nodoc:

    # Take this behavior.
    extend ParsingNesting::Tree

    include UVA

    # Delegate to the original behavior.
    #
    # @param [String] string
    #
    # @return [ParsingNesting::Tree::Node]
    #
    def self.parse(string)
      ParsingNesting::Tree.parse(string)
    end

    # This is the class to monkey patch.
    # We want all OR queries to be delivered as multiple dismax statements.
    #
    class ParsingNesting::Tree::OrList # :nodoc:

      # to_query
      #
      # @param [Hash] local_params
      #
      # @return [String]
      #
      def to_query(local_params)
        to_multi_queries(local_params)
      end

    end

  end

end
