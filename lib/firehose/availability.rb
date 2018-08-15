# lib/firehose/availability.rb

require 'firehose/api'

# Firehose::Availability
#
class Firehose::Availability

  include UVA
  include UVA::Ead::Xml

  include Firehose::Common
  extend  Firehose::Common

  # ===========================================================================
  # :section:
  # ===========================================================================

  public

  # @return [SolrDocument]
  attr_reader :document

  # @return [String]
  attr_reader :_raw_xml

  # @return [Firehose::CatalogItem]
  attr_reader :_catalog_item

  # @return [Array<Firehose::HomeLibrary>]
  attr_reader :_summary_libraries

  # @return [Array<String>]
  attr_reader :_barcodes

  # @return [Hash{String=>String}]
  attr_reader :lost

  # ===========================================================================
  # :section:
  # ===========================================================================

  protected

  # Initialize a new self instance.
  #
  # The only place where a self instance is created is by the "find" class
  # method
  #
  # @param [SolrDocument]          doc
  # @param [Firehose::CatalogItem] catalog_item
  # @param [String]                raw_xml
  # @param [Array<String>]         barcodes
  #
  # @see self#find
  # @see Firehose::CatalogItem#initialize
  #
  def initialize(doc, catalog_item, raw_xml = nil, barcodes = nil)
    @document               = doc
    @_catalog_item          = catalog_item
    @_raw_xml               = raw_xml  || ''
    @_barcodes              = barcodes || extract_barcodes || []
    @_summary_libraries     = []
    @lost                   = {}
    @_catalog_item.document = @document
    set_summary_holdings
    weed_holdings
  end

  # ===========================================================================
  # :section:
  # ===========================================================================

  public

  # to_xml
  #
  # @return [String]
  #
  def to_xml
    @_raw_xml
  end

  # linkable_to_ilink?
  #
  def linkable_to_ilink?
    !@document.pda?
  end

  # ===========================================================================
  # :section: CatalogItem related methods
  # ===========================================================================

  public

  # The number of available copies of this item.
  #
  # @return [Fixnum]                  Range: from 0 to self#existing_copies.
  #
  # @see Firehose::CatalogItem#available_copies
  #
  def available_copies
    @_catalog_item.available_copies
  end

  # The number of copies of this item on course reserve.
  #
  # @return [Fixnum]                  Range: from 0 to self#existing_copies.
  #
  # @see Firehose::CatalogItem#reserve_copies
  #
  def reserve_copies
    @_catalog_item.reserve_copies
  end

  # The number of copies of this item that could be potentially
  # checked out.
  #
  # @return [Fixnum]                  Range: from 0 to self#existing_copies.
  #
  # @see Firehose::CatalogItem#circulating_copies
  #
  def circulating_copies
    @_catalog_item.circulating_copies
  end

  # The number of copies of this item that are in Special Collections.
  #
  # @return [Fixnum]                Range: from 0 to self#existing_copies.
  #
  # @see Firehose::CatalogItem#special_collections_copies
  #
  def special_collections_copies
    @_catalog_item.special_collections_copies
  end

  # The number of copies of this item that are accounted for.
  #
  # @return [Fixnum]
  #
  # @see Firehose::CatalogItem#existing_copies
  #
  def existing_copies
    @_catalog_item.existing_copies
  end

  # has_ivy_holdings?
  #
  # @see Firehose::CatalogItem#has_ivy_holdings?
  #
  def has_ivy_holdings?
    @_catalog_item.has_ivy_holdings?
  end

  # leoable?
  #
  # @see Firehose::CatalogItem#leoable?
  #
  def leoable?
    @_catalog_item.leoable?
  end

  # might_be_holdable?
  #
  # @see Firehose::CatalogItem#holdable?
  #
  def might_be_holdable?
    @_catalog_item.holdable?
  end

  # holdability_error
  #
  # @return [String]
  #
  # @see Firehose::CatalogItem#holdability_error
  #
  def holdability_error
    @_catalog_item.holdability_error
  end

  # has_holdable_holding?
  #
  # @param [String] call_number
  #
  # @see Firehose::CatalogItem#has_holdable_holding?
  #
  def has_holdable_holding?(call_number)
    @_catalog_item.has_holdable_holding?(call_number)
  end

  # holdable_call_numbers
  #
  # @return [Array<String>]
  #
  # @see Firehose::CatalogItem#holdable_call_numbers
  #
  def holdable_call_numbers
    @_catalog_item.holdable_call_numbers
  end

  # ===========================================================================
  # :section:
  # ===========================================================================

  public

  # Indicates whether the given user has this ckey and call number checked out.
  #
  # @param [Firehose::User] user
  # @param [String]         call_number
  #
  def user_has_checked_out?(user, call_number = nil)
    if call_number.blank?
      call_numbers = holdable_call_numbers
      call_number = call_numbers.first if call_numbers.size == 1
    end
    user.checkouts.any? do |checkout|
      next unless checkout.catalog_item.key == @_catalog_item.key
      checkout.catalog_item.holdings.any? do |holding|
        holding.call_number == call_number
      end
    end
  end

  # ===========================================================================
  # :section:
  # ===========================================================================

  public

  # Order the libraries.
  #
  # @return [Array<Library>]
  #
  def summary_libraries
    @summary_libraries ||=
      begin
        hold_map = empty_hold_map
        order =
          @_summary_libraries.map { |library|
            hlib = hold_library(library.name)
            if hlib
              hold_map[hlib] << library
              next
            end
            library
          }.compact.sort { |a, b| a.name <=> b.name }
        finalize_holdings(order, hold_map)
      end
  end

  # ===========================================================================
  # :section:
  # ===========================================================================

  public

  # holdings
  #
  # @return [Array<Firehose::Holding>]
  #
  def holdings
    @holdings ||= set_holdings
  end

  # special_collections_holdings
  #
  # @return [Array<Firehose::Holding>]
  #
  def special_collections_holdings
    holdings.select(&:is_special_collections?)
  end

  # holdings_by_library
  #
  # @return [Hash{String=>Fixnum}]
  #
  def holdings_by_library
    @holdings_by_library ||=
      Hash.new.tap do |result|
        holdings.map do |holding|
          library = holding.library.code
          result[library] = 0 unless result.has_key?(library)
          result[library] += holding.copies.size
        end
      end
  end

  # available_by_library
  #
  # @return [Hash{String=>Fixnum}]
  #
  def available_by_library
    @available_by_library ||=
      Hash.new.tap do |result|
        holdings.map do |holding|
          library = holding.library.code
          result[library] = 0 unless result.has_key?(library)
          result[library] += holding.available_copies
        end
      end
  end

  # ===========================================================================
  # :section:
  # ===========================================================================

  protected

  # Sort and finalize holdings.
  #
  # @return [Array<Firehose::Holding>]
  #
  def set_holdings
    hold_map = empty_hold_map
    order =
      @_catalog_item.holdings.map { |holding|
        hlib = hold_library(holding.library.code)
        if hlib
          hold_map[hlib] << holding
          next
        end
        holding
      }.compact

    # Sort by library and shelving key (reverse sort for journals).
    if @document.journal?
      order.sort! do |a, b|
        (a.library.name <=> b.library.name).nonzero? ||
          (b.shelving_key <=> a.shelving_key)
      end
      hold_map.each do |_library, holdings|
        holdings.sort! { |a, b| b.shelving_key <=> a.shelving_key }
      end
    else
      order.sort_by! { |a| [a.library.name, a.shelving_key] }
    end

    finalize_holdings(order, hold_map)
  end

  # Generate an empty hold map.
  #
  # @return [Hash{Symbol=>Array}]
  #
  def empty_hold_map
    hold_order.map { |hlib| [hlib, []] }.to_h
  end

  # finalize_holdings
  #
  # @param [Array<Firehose::Holding>] order
  # @param [Hash{Symbol=>Array}]      hold_map
  #
  # @return [Array<Firehose::Holding>]
  #
  def finalize_holdings(order, hold_map)
    order + hold_order.map { |hlib| hold_map[hlib] }.flatten.compact
  end

  # ===========================================================================
  # :section: Initialization
  # ===========================================================================

  protected

  # Get barcodes from the given document.
  #
  # @param [SolrDocument] doc
  #
  # @return [Array<String>]
  # @return [nil]                     If no barcodes were found.
  #
  def extract_barcodes(doc = nil)
    (doc ||= @document) &&
      (container = doc.values_for(:container_display).first) &&
      (records   = parse_barcodes(container)) &&
      (record    = records.marc_records.first) &&
      record.barcodes
  end

  # Parse the Solr record for summary holdings -
  # build into: Library => HomeLocations => Summaries
  #
  # @return [void]
  #
  def set_summary_holdings
    @document.values_for(:summary_holdings_display).each do |val|
      # summary_holdings_display comes out in this format:
      # library | location | text | note | optional label | call number info
      d_library, d_location, d_text, d_note, _d_label, d_call_num =
        val.split('|')

      # get library
      library = @_summary_libraries.find { |lib| lib.name == d_library }
      unless library
        library = Firehose::HomeLibrary.new
        library.name = d_library
        @_summary_libraries << library
      end

      # get location
      summary_locations = library.summary_locations
      location = summary_locations.find { |loc| loc.name == d_location }
      unless location
        location = Firehose::HomeLocation.new
        location.name = d_location
        library.summary_locations << location
      end

      # add summary
      location.summaries << Firehose::Summary.new(d_text, d_note, d_call_num)
    end
  end

  # Strip the the received catalog holdings information of hidden and shadowed
  # holdings.
  #
  # @return [void]
  #
  def weed_holdings
    barcodes = @_barcodes.presence
    @_catalog_item.holdings.tap do |holdings|

      # Discard shadowed holdings.
      holdings.delete_if do |holding|
        holding.shadowed? || holding.call_number.upcase.include?('VOID')
      end

      # Discard hidden copies.
      holdings.each do |holding|
        library = holding.library.name
        copies  = holding.copies
        copies.delete_if(&:shadowed?)
        copies.delete_if { |copy|
          (@lost[library] ||= []) << copy if copy.missing? || copy.lost?
        }
        copies.delete_if(&:hidden?)
        copies.keep_if { |copy| barcodes.include?(copy.barcode) } if barcodes
      end

      # Discard holdings with no unhidden copies.
      holdings.keep_if do |holding|
        holding.copies.present?
      end

      # Reduce notations of lost/missing copies.
      @lost.each_key do |library|
        if @lost[library].present?
          missing        = @lost[library].count(&:missing?)
          lost           = @lost[library].size - missing
          @lost[library] =
            if missing.nonzero? && lost.nonzero?
              "#{missing} missing; #{lost} lost"
            elsif missing > 1
              "#{missing} missing"
            elsif lost > 1
              "#{lost} lost"
            elsif missing
              'missing'
            elsif lost
              'lost'
            end
        else
          @lost.delete(library)
        end
      end

    end
  end

  # ===========================================================================
  # :section: Class Methods
  # ===========================================================================

  public

  # Get the availability information for the given item.
  #
  # This method is the only place where a Firehose::Availability instance is
  # created
  #
  # @param [SolrDocument, String] doc
  # @param [Array<String>]        barcodes
  # @param [Hash]                 opt       Options to cache #fetch.
  #
  # @return [Availability]
  # @return [nil]                     If availability information could not
  #                                     acquired.
  #
  def self.find(doc, barcodes = nil, opt = nil)
    return unless doc.is_a?(SolrDocument)
    opt ||= {}
    id  = ckey_converter(doc.doc_id)
    get_args = ['items', id, opt]
    xml = Firehose::API.get(*get_args)
    cat = Firehose::CatalogItem.parse(xml, single: true)
    Firehose::Availability.new(doc, cat, xml, barcodes)

  rescue SocketError, EOFError
    Firehose::API.discard(*get_args)
    raise # Handled by ApplicationController

  rescue => e
    Firehose::API.discard(*get_args)
    xml_ret =
      case xml
        when nil     then 'returned nil'
        when Numeric then 'FAILED'
        else              "returned #{xml.size} bytes"
      end
    Rails.logger.info { "FIREHOSE #{__method__} #{xml_ret}: #{e.message}" }
    Rails.logger.debug {
      "unable to construct availability from:\n#{xml.inspect}"
    }
    nil
  end

end
