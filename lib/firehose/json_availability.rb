# lib/firehose/json_availability.rb

require 'firehose/api'

# Firehose::Availability
#
class Firehose::JsonAvailability < Firehose::Availability

  include UVA::Util::Json

  # ===========================================================================
  # :section: Overrides of Firehose::Availability
  # ===========================================================================

  protected

  # Initialize a new self instance.
  #
  # The only place where a self instance is created is by the "find" class
  # method
  #
  # @param [SolrDocument]               doc
  # @param [Firehose::CatalogItem, nil] catalog_item
  #
  # This method overrides:
  # @see Firehose::Availability#initialize
  #
  def initialize(doc, catalog_item = nil)
    catalog_item ||= Firehose::CatalogItem.new
    catalog_item.holdings    ||= []
    catalog_item.holdability ||= Firehose::Holdability.new
    super(doc, catalog_item)
  end

  # Parse the Solr record for summary holdings -
  # build into: Library => HomeLocations => Summaries
  #
  # @return [Array<Firehose::Holding>]
  #
  # This method overrides:
  # @see Firehose::Availability#set_holdings
  #
  def set_holdings
    @_catalog_item.holdings =
      holdings_json.map do |val|
        # create copy and placeholders
        copy = Firehose::Copy.new
        holding = Firehose::Holding.new
        holding.copies = []

        # Get library.
        d_library = val['library']
        library = @_summary_libraries.find { |lib| lib.name == d_library }
        unless library
          library = Firehose::HomeLibrary.new
          library.name = d_library
          library.code = 'SPEC-COLL'
          #@_summary_libraries << library
          holding.library = library
        end

        # Get location.
        d_location = val['location']
        summary_locations = library.summary_locations
        location = summary_locations.find { |loc| loc.name == d_location }
        unless location
          location = Firehose::HomeLocation.new
          location.name = d_location
          location.code = 'STACKS'
          library.summary_locations << location
          copy.current_location = location
          copy.home_location = location
          copy.circulate = 'Y'
        end

        # Add summary.
        d_call_num = val['call_number']
        #location.summaries <<
        #  Firehose::Summary.new('', @_catalog_item, d_call_num)

        # Assemble catalog item.
        copy.barcode = val['barcode'] || d_call_num
        holding.copies << copy
        holding.call_number = d_call_num
        holding
      end
  end

  # holdings_json
  #
  # @param [Array<String>, String, nil] src
  #
  # @return [Array<Hash>]
  #
  def holdings_json(src = nil)
    src ||= @document.values_for(:special_collections_holding_display)
    src = src.first if src.is_a?(Array)
    json_parse((src || ''), default: []).tap do |result|
      Rails.logger.warn {
        "#{__method__}: bad JSON: #{@document.id}: #{src.inspect}"
      } if result.blank?
    end
  end

end
