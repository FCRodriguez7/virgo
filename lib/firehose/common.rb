# lib/firehose/common.rb

require 'happymapper'
require 'open-uri'
require 'uva'

# Firehose is the locally-created API service which interfaces with the
# Sirsi/Dynix Unicorn OPAC.
#
module Firehose

  # ===========================================================================
  # :section:
  # ===========================================================================

  private

  # Generate a list of String and/or Regexp against which a code value can be
  # matched.
  #
  # @param [Array<String, Regexp, Array>] args
  #
  # @return [Array<String, Regexp>]
  #
  def self.codes(*args)
    args.flatten.map { |arg|
      arg.is_a?(Regexp) ? Regexp.new(arg.source, Regexp::IGNORECASE) : arg.to_s
    }.reject(&:blank?).deep_freeze
  end

  # ===========================================================================
  # :section:
  # ===========================================================================

  public

  HOLD_LOCATIONS      = codes /HOLD/
  RESERVE_LOCATIONS   = codes /RESV/, /RSRV/, /RESERVE/
  REFERENCE_LOCATIONS = codes /REF/,  'FA-SLIDERF'
  DESK_LOCATIONS      = codes /DESK/, 'SERV-DSK'
  NON_CIRC_LOCATIONS  = (REFERENCE_LOCATIONS + DESK_LOCATIONS).deep_freeze
  HIDDEN_LOCATIONS =
    codes(/LOST/, <<-EOS.squish.split).deep_freeze
      UNKNOWN
      MISSING
      DISCARD
      WITHDRAWN
      BARRED
      BURSARED
      INTERNET
      ORD-CANCLD
    EOS
  UNAVAILABLE_LOCATIONS =
    codes(HOLD_LOCATIONS, HIDDEN_LOCATIONS, <<-EOS.squish.split).deep_freeze
      CHECKEDOUT
      ON-ORDER
      BINDERY
      INTRANSIT
      ILL
      CATALOGING
      PRESERVATN
      EXHIBIT
      GBP
    EOS

  REMOTE_LIBRARIES = codes %w(SPEC-COLL BLANDY MT-LAKE AT-SEA INTERNET)

  HOLD_LIBRARY = {
    ivy:      'Ivy Stacks',
    blandy:   'Blandy Experimental Farm',
    mt_lake:  'Mountain Lake',
    at_sea:   'Semester at Sea',
  }.deep_freeze

  # Firehose::Common
  #
  module Common

    include UVA

    # Remove the first character of the catalog key, which is a 'u'.
    # Also remove 'pda' if the catalog key is preceded by that string.
    #
    # @param [String] id
    #
    # @return [String]
    #
    def ckey_converter(id)
      id.sub(/^pda/, '').slice(1..-1)
    end

    # date_format
    #
    # @param [Date] date
    #
    # @return [String]
    #
    def date_format(date)
      result = date.strftime('%b %d, %Y')
      result = 'Never' if result == 'Jan 01, 1900'
      result
    end

    # hold_order
    #
    # @return [Array<Symbol>]
    #
    def hold_order
      HOLD_LIBRARY.keys
    end

    # hold_library
    #
    # @param [String] name_or_code
    #
    # @return [Symbol]
    # @return [nil]                     If this is not one of the #hold_order
    #                                     libraries.
    #
    def hold_library(name_or_code)
      HOLD_LIBRARY.find do |key, name|
        library_name_or_code = [key, name].map { |v| v.to_s.dasherize.upcase }
        return key if match?(name_or_code, library_name_or_code)
      end
    end

    # Produce an error message from an HTTP response.
    #
    # @param [Net::HTTPResponse] response
    # @param [Symbol,String]     method     For log messages.
    #
    # @return [String]
    #
    def get_error_message(response, method = nil)
      body = response && response.body
      error =
        if body.present?
          Firehose::Violation.parse(body,single: true)
        end
      error   = error.first if error.is_a?(Array)
      code    = error && error.code
      message = error && error.message
      if message.blank?
        message =
          if response.blank?
            'no HTTP result'
          elsif body.blank?
            'empty HTTP result body'
          elsif body.include?('Exception')
            'Firehose internal server error'
          else
            'unknown failure'
          end
        Rails.logger.warn {
          "FIREHOSE #{method}: #{message}; code #{code.inspect}"
        }
      else
        Rails.logger.info {
          log = ["FIREHOSE #{method}: #{message}"]
          log << "code #{code.inspect}"
          log << "body #{body}" if body.present?
          log.join('; ')
        }
      end
      message
    end

    # Find the table key whose value matches *message*.
    #
    # @param [String]               message
    # @param [Hash{Symbol=>Regexp}] key_table
    #
    # @return [Symbol]
    # @return [nil]
    #
    def key_lookup(message, key_table)
      key =
        key_table.find do |_, pattern|
          case pattern
            when nil    then true
            when String then message.include?(pattern)
            when Regexp then message =~ pattern
          end
        end
      key && key.first
    end

    # Match a library code or location code against one or more patterns.
    #
    # If *code* is a Symbol, it is translated; e.g. :mt_lake becomes 'MT-LAKE'.
    #
    # @param [String, Symbol]               code
    # @param [Array<String, Regexp, Array>] args
    #
    def match?(code, *args)
      code = code.to_s.dasherize.upcase
      args.flatten.any? { |arg| code.match?(arg) }
    end

  end

  # Firehose::LibraryMethods
  #
  module LibraryMethods

    include UVA
    include Firehose::Common

    # =========================================================================
    # :section:
    # =========================================================================

    public

    # deliverable?
    #
    def deliverable?
      deliverable
    end

    # leoable?
    #
    def leoable?
      !match?(code, REMOTE_LIBRARIES)
    end

    # is_sas?
    #
    def is_sas?
      match?(code, 'AT-SEA')
    end

    # is_special_collections?
    #
    def is_special_collections?
      match?(code, 'SPEC-COLL')
    end

    # is_ivy?
    #
    def is_ivy?
      match?(code, /IVY/)
    end

  end

  # Firehose::Library
  #
  # @attr [String]  id
  # @attr [String]  code
  #
  # @attr [String]  name
  # @attr [Boolean] deliverable
  #
  class Library

    include HappyMapper
    include LibraryMethods

    attribute :id,          String
    attribute :code,        String

    element   :name,        String
    element   :deliverable, Boolean
    element   :holdable,    Boolean

  end

  # Firehose::HomeLibrary
  #
  # @attr [String]  id
  # @attr [String]  code
  #
  # @attr [String]  name
  # @attr [Boolean] deliverable
  #
  # @attr [Array<Firehose::HomeLocation>] summary_locations
  #
  class HomeLibrary

    include HappyMapper
    include LibraryMethods

    tag 'library'

    attribute :id,          String
    attribute :code,        String

    element   :name,        String
    element   :deliverable, Boolean
    element   :holdable,    Boolean

    # @return [Array<Firehose::HomeLocation>]
    attr_accessor :summary_locations

    # Initialize a new self instance.
    #
    def initialize
      @summary_locations = []
    end

  end

  # Firehose::LibraryList
  #
  # @attr [Array<Firehose::Library>] libraries
  #
  class LibraryList

    include HappyMapper
    include UVA

    tag 'libraries'

    # @return [Array<Firehose::Library>]
    has_many :libraries, Firehose::Library, tag: 'library'

    # =========================================================================
    # :section:
    # =========================================================================

    public

    # name_and_ids
    #
    # @return [Array<Array<(String,String)>>]
    #
    def names_and_ids
      libraries.sort! { |a, b| a.name <=> b.name }
      libraries.map { |library|
        [library.name, library.id] if library.deliverable?
      }.compact
    end

  end

  # Firehose::Summary
  #
  # @attr [String] text
  # @attr [String] note
  # @attr [String] call_number_information
  #
  class Summary

    include UVA

    # @return [String]
    attr_accessor :text

    # @return [String]
    attr_accessor :note

    # @return [String]
    attr_accessor :call_number_information

    # Initialize a new self instance.
    #
    # @param [String] text
    # @param [String] note
    # @param [String] call_number_info
    #
    def initialize(text, note, call_number_info)
      @text = text.chomp(',')
      @note = note
      @call_number_information = call_number_info
    end

  end

  # Firehose::LocationMethods
  #
  module LocationMethods

    include UVA
    include Firehose::Common

    # =========================================================================
    # :section:
    # =========================================================================

    public

    # lost?
    #
    def lost?
      match?(code, /LOST/)
    end

    # missing?
    #
    def missing?
      match?(code, 'MISSING')
    end

    # suppressed?
    #
    def suppressed?
      match?(code, 'BARRED')
    end

    # hidden?
    #
    def hidden?
      match?(code, HIDDEN_LOCATIONS)
    end

    # =========================================================================
    # :section:
    # =========================================================================

    public

    # by_request?
    #
    # === Implementation Notes
    # This was an addition to the catalog locations that was introduced to deal
    # with Clemons items that were temporarily moved in the summer of 2018 so
    # they could be requested via the ILLiad IVY queue.
    #
    def by_request?
      match?(code, 'BY-REQUEST')
    end

    # is_ivy?
    #
    # @see self#by_request?
    #
    def is_ivy?
      match?(code, /IVY/)
    end

    # in_ivy?
    #
    # @see self#is_ivy?
    #
    def in_ivy?
      is_ivy? || by_request?
    end

    # sc_ivy?
    #
    def sc_ivy?
      match?(code, 'SC-IVY')
    end

    # not_ordered?
    #
    def not_ordered?
      match?(code, 'NOTORDERED')
    end

    # on_reserve?
    #
    def on_reserve?
      match?(code, RESERVE_LOCATIONS)
    end

    # pending?
    #
    def pending?
      match?(code, 'ON-ORDER', 'IN-PROCESS')
    end

    # in_process?
    #
    def in_process?
      match?(code, 'SC-IN-PROC', 'IN-PROCESS')
    end

    # in_transit?
    #
    def in_transit?
      match?(code, 'INTRANSIT')
    end

    # sc_exhibit?
    #
    def sc_exhibit?
      match?(code, 'DEC-IND-RM')
    end

  end

  # Firehose::Location
  #
  class Location

    include HappyMapper
    include LocationMethods

    tag 'location'

    attribute :id,   String
    attribute :code, String

    element   :name, String

  end

  # Firehose::HomeLocation
  #
  # @attr [String] id
  # @attr [String] code
  #
  # @attr [String] name
  #
  # @attr [Array<Firehose::Summary>] summaries
  #
  class HomeLocation

    include HappyMapper
    include LocationMethods

    tag 'homeLocation'

    attribute :id,   String
    attribute :code, String

    element   :name, String

    # @return [Array<Firehose::Summary>]
    attr_accessor :summaries

    # Initialize a new self instance.
    #
    def initialize
      @summaries = []
    end

  end

  # Firehose::CurrentLocation
  #
  # @attr [String] id
  # @attr [String] code
  #
  # @attr [String] name
  #
  class CurrentLocation

    include HappyMapper
    include LocationMethods

    tag 'currentLocation'

    attribute :id,   String
    attribute :code, String

    element   :name, String

  end

  # Firehose::LocationList
  #
  # @attr [Array<Firehose::Location>] locations
  #
  class LocationList

    include HappyMapper
    include UVA

    tag 'locations'

    # @return [Array<Firehose::Location>]
    has_many :locations, Firehose::Location, tag: 'location'

  end

  # Firehose::ItemType
  #
  # @attr [String] code
  #
  class ItemType

    include HappyMapper
    include UVA

    tag 'itemType'

    attribute :code, String

  end

  # Firehose::Copy
  #
  # @attr [Integer] copy_number
  # @attr [Boolean] shadowed
  # @attr [String]  barcode
  # @attr [Boolean] current_periodical
  #
  # @attr [Date]    last_checkout
  # @attr [String]  circulate
  #
  # @attr [Firehose::CurrentLocation] current_location
  # @attr [Firehose::HomeLocation]    home_location
  # @attr [Firehose::ItemType]        item_type
  #
  class Copy

    include HappyMapper
    include Firehose::LocationMethods

    tag 'copy'

    attribute :copy_number,         Integer,          tag: 'copyNumber'
    attribute :barcode,             String,           tag: 'barCode'
    attribute :shadowed,            Boolean
    attribute :current_periodical,  Boolean,          tag: 'currentPeriodical'

    element   :last_checkout,       Date,             tag: 'lastCheckout'
    element   :circulate,           String

    # @return [Firehose::CurrentLocation]
    has_one   :current_location,    Firehose::CurrentLocation,  tag: 'currentLocation'

    # @return [Firehose::HomeLocation]
    has_one   :home_location,       Firehose::HomeLocation,     tag: 'homeLocation'

    # @return [Firehose::ItemType]
    has_one   :item_type,           Firehose::ItemType,         tag: 'itemType'

    # =========================================================================
    # :section:
    # =========================================================================

    public

    # shadowed?
    #
    def shadowed?
      shadowed
    end

    # current_periodical?
    #
    def current_periodical?
      current_periodical
    end

    # last_checkout_f
    #
    def last_checkout_f
      date_format(last_checkout)
    end

    # circulates?
    #
    def circulates?
      circulate.match?(/[YM]/)
    end

    # =========================================================================
    # :section:
    # =========================================================================

    public

    # This definition exists so that LocationMethods are defined in terms of
    # the current_location code for this copy.
    #
    # @return [String]
    #
    def code
      current_location.code
    end

    # Indicate whether this is a copy that exists somewhere in the library
    # system (as opposed to a copy that could be ordered) and is not hidden.
    #
    def exists?
      !(shadowed? || not_ordered? || pending?)
    end

    # =========================================================================
    # :section:
    # =========================================================================

    public

    # IN-PROCESS items whose home is the special collections in Ivy should be
    # considered available.  IN-PROCESS items whose home location is anywhere
    # else should be considered unavailable.
    #
    def available?
      return if shadowed?
      unavailable = UNAVAILABLE_LOCATIONS
      unavailable += %w(IN-PROCESS) unless home_location.sc_ivy?
      !match?(current_location.code, unavailable)
    end

    # sc_requestable?
    #
    def sc_requestable?
      !current_location.sc_ivy? && !(home_location.sc_ivy? && in_process?)
    end

    # stacks_map
    #
    # @param [Firehose::Holding] holding
    #
    # @return [Map, nil]
    #
    def stacks_map(holding)
      Map.find_best_map(holding, self) if available?
    end

  end

  # Firehose::Holding
  #
  # @attr [Integer] call_sequence
  # @attr [String]  call_number
  # @attr [Boolean] holdable
  # @attr [Boolean] shadowed
  #
  # @attr [String]  shelving_key
  #
  # @attr [Array<Firehose::Copy>] copies
  # @attr [Firehose::Library]     library
  #
  class Holding

    include HappyMapper
    include UVA

    tag 'holding'

    attribute :call_sequence, Integer,  tag: 'callSequence'
    attribute :call_number,   String,   tag: 'callNumber'
    attribute :holdable,      Boolean
    attribute :shadowed,      Boolean

    element   :shelving_key,  String,   tag: 'shelvingKey'

    # @return [Array<Firehose::Copy>]
    has_many  :copies,        Firehose::Copy,     tag: 'copy'

    # @return [Firehose::HomeLibrary]
    has_one   :library,       Firehose::HomeLibrary

    # =========================================================================
    # :section:
    # =========================================================================

    public

    # shadowed?
    #
    def shadowed?
      shadowed
    end

    # holdable?
    #
    def holdable?
      holdable
    end

    # leoable?
    #
    def leoable?
      library && library.leoable?
    end

    # is_special_collections?
    #
    def is_special_collections?
      library && library.is_special_collections?
    end

    # has_ivy_holdings?
    #
    def has_ivy_holdings?
      (library && library.is_ivy?) ? copies.present? : copies.any?(&:in_ivy?)
    end

    # The number of available copies for this holding.
    #
    # @return [Fixnum]                Range: from 0 to self#existing_copies.
    #
    def available_copies
      copies.count(&:available?)
    end

    # The number of reserve copies for this holding.
    #
    # @return [Fixnum]                Range: from 0 to self#existing_copies.
    #
    def reserve_copies
      copies.count(&:on_reserve?)
    end

    # The number of circulating copies for this holding.
    #
    # @return [Fixnum]                Range: from 0 to self#existing_copies.
    #
    def circulating_copies
      copies.count(&:circulates?)
    end

    # The number of Special Collections copies for this holding.
    #
    # @return [Fixnum]                Range: from 0 to self#existing_copies.
    #
    def special_collections_copies
      is_special_collections? ? existing_copies : 0
    end

    # The number of copies for this holding that are accounted for.
    #
    # @return [Fixnum]
    #
    def existing_copies
      copies.count(&:exists?)
    end

  end

  # Firehose::Holdability
  #
  # @attr [String]  value
  #
  # @attr [String]  message
  #
  class Holdability

    include HappyMapper
    include UVA

    attribute :value,   String

    element   :message, String

    # =========================================================================
    # :section:
    # =========================================================================

    public

    # holdable?
    #
    def holdable?
      %w(yes maybe).include?(value.to_s.downcase)
    end

  end

  # Firehose::PickupLibrary
  #
  # @attr [String] id
  #
  # @attr [String] code
  # @attr [String] name
  #
  class PickupLibrary

    include HappyMapper
    include UVA

    tag 'pickupLibrary'

    attribute :id,    String
    attribute :code,  String

    element   :name,  String

  end

  # Firehose::CatalogItem
  #
  # In practice, an instance of this class is only created via Nokogiri when
  # parsing XML from Firehose, and this happens only within the method
  # Firehose::Availability.find.
  #
  # @attr [String]  key
  #
  # @attr [Integer] status
  #
  # @attr [Array<Firehose::Holding>] holdings
  # @attr [Firehose::Holdability]    holdability
  #
  class CatalogItem

    include HappyMapper
    include Blacklight::SolrHelper
    include UVA
    include UVA::Solr

    tag 'catalogItem'

    attribute :key,         String

    element   :status,      Integer

    # @return [Array<Firehose::Holding>]
    has_many  :holdings,    Firehose::Holding

    # @return [Firehose::Holdability]
    has_one   :holdability, Firehose::Holdability, tag: 'canHold'

    # Initialize a new self instance.
    #
    def initialize
      @document = nil
    end

    # =========================================================================
    # :section:
    # =========================================================================

    public

    # The Solr document assigned within the initializer for Availability.
    #
    # @return [SolrDocument]
    #
    # @see self#params
    #
    def document
      unless defined?(@document) && @document
        _response, @document = get_solr_response_for_doc_id("u#{key}")
      end
      @document
    end

    # Assignment of Solr document performed within the initializer for
    # Availability.
    #
    # To be called directly after creating a self instance by parsing XML.
    #
    # @param [SolrDocument] doc
    #
    # @return [SolrDocument]
    #
    def document=(doc)
      raise '@document should only be assigned once' if @document
      @document = doc
    end

    # The title of the requested item.
    #
    # @return [String]                '???' indicates either that there was no
    #                                   Solr document for the catalog item or
    #                                   that the item had no title.
    #
    def title
      result = document
      result &&= result.export_title
      result = '???' if result.blank?
      result
    end

    # The first author of the requested item.
    #
    # @return [String]                '???' indicates that there was no Solr
    #                                   document for the catalog item; if the
    #                                   item simply has no authors given then
    #                                   '' is returned.
    #
    def authors
      result = document
      result = result ? result.export_authors : '???'
      result = '' if result.blank?
      result
    end

    # =========================================================================
    # :section: Holding related methods
    # =========================================================================

    public

    # The number of available copies of this item.
    #
    # @return [Fixnum]                Range: from 0 to self#existing_copies.
    #
    def available_copies
      holdings.sum(&:available_copies)
    end

    # The number of copies of this item on course reserve.
    #
    # @return [Fixnum]                Range: from 0 to self#existing_copies.
    #
    def reserve_copies
      holdings.sum(&:reserve_copies)
    end

    # The number of copies of this item that could be potentially
    # checked out.
    #
    # @return [Fixnum]                Range: from 0 to self#existing_copies.
    #
    def circulating_copies
      holdings.sum(&:circulating_copies)
    end

    # The number of copies of this item that are in Special Collections.
    #
    # @return [Fixnum]                Range: from 0 to self#existing_copies.
    #
    def special_collections_copies
      holdings.sum(&:special_collections_copies)
    end

    # The number of copies of this item that are accounted for.
    #
    # @return [Fixnum]
    #
    def existing_copies
      holdings.sum(&:existing_copies)
    end

    # has_ivy_holdings?
    #
    def has_ivy_holdings?
      holdings.any?(&:has_ivy_holdings?)
    end

    # leoable?
    #
    def leoable?
      holdings.any?(&:leoable?)
    end

    # =========================================================================
    # :section: Holdability related methods
    # =========================================================================

    public

    # holdable?
    #
    def holdable?
      holdability.holdable?
    end

    # holdability_error
    #
    # @return [String]
    #
    def holdability_error
      holdability.message
    end

    # has_holdable_holding?
    #
    # @param [String] call_number
    #
    def has_holdable_holding?(call_number)
      return if call_number.blank?
      holdable_call_numbers.any? { |cn| cn == call_number }
    end

    # holdable_call_numbers
    #
    # @return [Array<String>]
    #
    def holdable_call_numbers
      holdings.map { |holding|
        holding.call_number if holding.holdable?
      }.compact.uniq
    end

    # =========================================================================
    # :section:
    # =========================================================================

    protected

    # The acquisition of @document from Solr is not done in the controller
    # context, however a number of support methods will attempt to check for
    # `params` by default.  This method satisfies that need by supplying a hash
    # with just enough information to allow the document to be acquired.
    #
    # @return [Hash]
    #
    def params
      { controller: 'catalog' }
    end

  end

  # Firehose::Hold
  #
  # @attr [String]  type
  # @attr [String]  level
  # @attr [Boolean] active
  #
  # @attr [String]  key
  # @attr [Integer] priority
  # @attr [Date]    date_placed
  # @attr [Date]    date_notified
  # @attr [Date]    date_recalled
  # @attr [String]  inactive_reason
  #
  # @attr [Firehose::CatalogItem]   catalog_item
  # @attr [Firehose::PickupLibrary] pickup_library
  #
  class Hold

    include HappyMapper
    include UVA
    include Firehose::Common

    tag 'hold'

    attribute :type,            String
    attribute :level,           String
    attribute :active,          Boolean

    element   :key,             String
    element   :priority,        Integer
    element   :date_placed,     Date,           tag: 'datePlaced'
    element   :date_notified,   Date,           tag: 'dateNotified'
    element   :date_recalled,   Date,           tag: 'dateRecalled'
    element   :inactive_reason, String,         tag: 'inactiveReason'

    # @return [Firehose::CatalogItem]
    has_one   :catalog_item,    Firehose::CatalogItem,    tag: 'catalogItem'

    # @return [Firehose::PickupLibrary]
    has_one   :pickup_library,  Firehose::PickupLibrary,  tag: 'pickupLibrary'

    # =========================================================================
    # :section:
    # =========================================================================

    public

    # date_placed_f
    #
    # @return [String]
    #
    def date_placed_f
      date_format(date_placed)
    end

    # date_notified_f
    #
    # @return [String]
    #
    def date_notified_f
      date_format(date_notified)
    end

    # date_recalled_f
    #
    # @return [String]
    #
    def date_recalled_f
      date_format(date_recalled)
    end

  end

  # Firehose::Reserve
  #
  # @attr [String]  key
  #
  # @attr [String]  active
  # @attr [String]  status
  # @attr [Integer] number_of_reserves
  # @attr [Boolean] keep_copies_at_desk
  # @attr [Boolean] automatically_select_copies
  #
  # @attr [Firehose::CatalogItem] catalog_item
  #
  class Reserve

    include HappyMapper
    include UVA

    tag 'reserve'

    #--
    # rubocop:disable Metrics/LineLength
    #++

    attribute :key,                         String

    element   :active,                      String
    element   :status,                      String
    element   :number_of_reserves,          Integer,     tag: 'numberOfReserves'
    element   :keep_copies_at_desk,         Boolean,     tag: 'keepCopiesAtDesk'
    element   :automatically_select_copies, Boolean,     tag: 'automaticallySelectCopies'

    # @return [Firehose::CatalogItem]
    has_one   :catalog_item,                Firehose::CatalogItem, tag: 'catalogItem'

    #--
    # rubocop:enable Metrics/LineLength
    #++

  end

  # Firehose::Course
  #
  # @attr [String]  key
  #
  # @attr [String]  code
  # @attr [String]  name
  # @attr [Integer] number_of_reserves
  # @attr [Integer] number_of_students
  # @attr [Integer] terms_offered
  #
  # @attr [Array<Firehose::Reserve>] reserves
  #
  class Course

    include HappyMapper
    include UVA

    tag 'course'

    attribute :key,                 String

    element   :code,                String
    element   :name,                String
    element   :number_of_reserves,  Integer, tag: 'numberOfReserves'
    element   :number_of_students,  Integer, tag: 'numberOfStudents'
    element   :terms_offered,       Integer, tag: 'termsOffered'

    # @return [Array<Firehose::Reserve>]
    has_many  :reserves,            Firehose::Reserve, tag: 'reserve'

    # =========================================================================
    # :section:
    # =========================================================================

    public

    # sorted_reserves
    #
    # @return [Array<Reserve>]
    #
    def sorted_reserves
      reserves.sort_by { |a| a.catalog_item.title }
    end

  end

  # Firehose::Renewability
  #
  # @attr [String]  code
  # @attr [String]  value
  #
  # @attr [String]  message
  #
  class Renewability

    include HappyMapper
    include UVA

    tag 'canRenew'

    attribute :code,    String
    attribute :value,   String

    element   :message, String

  end

  # Firehose::Checkout
  #
  # @attr [String]  key
  # @attr [Integer] status
  # @attr [Boolean] overdue
  # @attr [Integer] circulation_rule
  # @attr [Date]    date_charged
  # @attr [Date]    date_due
  # @attr [Date]    date_renewed
  # @attr [Date]    date_recalled
  # @attr [Integer] number_overdue_notices
  # @attr [Integer] number_recall_notices
  # @attr [Integer] number_renewals
  #
  # @attr [Firehose::CatalogItem]  catalog_item
  # @attr [Firehose::Renewability] renewability
  #
  class Checkout

    include HappyMapper
    include UVA
    include Firehose::Common

    tag 'checkout'

    element :key,                     String
    element :status,                  Integer
    element :overdue,                 Boolean,      tag: 'isOverdue'
    element :circulation_rule,        Integer,      tag: 'circulationRule'
    element :date_charged,            Date,         tag: 'dateCharged'
    element :date_due,                Date,         tag: 'dateDue'
    element :date_renewed,            Date,         tag: 'dateRenewed'
    element :date_recalled,           Date,         tag: 'dateRecalled'
    element :number_overdue_notices,  Integer,      tag: 'numberOverdueNotices'
    element :number_recall_notices,   Integer,      tag: 'numberRecallNotices'
    element :number_renewals,         Integer,      tag: 'numberRenewals'

    # @return [Firehose::CatalogItem]
    has_one :catalog_item,            Firehose::CatalogItem,  tag: 'catalogItem'

    # @return [Firehose::Renewability]
    has_one :renewability,            Firehose::Renewability, tag: 'canRenew'

    # =========================================================================
    # :section:
    # =========================================================================

    public

    # renewable?
    #
    def renewable?
      renewability.value == 'yes'
    end

    # overdue?
    #
    def overdue?
      overdue
    end

    # recalled?
    #
    def recalled?
      date_recalled_f != 'Never'
    end

    # date_charged_f
    #
    # @return [String]
    #
    def date_charged_f
      date_format(date_charged)
    end

    # date_due_f
    #
    # @return [String]
    #
    def date_due_f
      date_format(date_due)
    end

    # date_recalled_f
    #
    # @return [String]
    #
    def date_recalled_f
      date_format(date_recalled)
    end

    # date_renewed_f
    #
    # @return [String]
    #
    def date_renewed_f
      date_format(date_renewed)
    end

  end

  # Firehose::User
  #
  # @attr [String]  key
  # @attr [String]  sirsi_id
  # @attr [String]  computing_id
  #
  # @attr [Boolean] barred
  # @attr [Boolean] bursarred
  # @attr [Boolean] delinquent
  # @attr [String]  display_name
  # @attr [String]  email
  # @attr [Integer] library_group
  # @attr [String]  organizational_unit
  # @attr [Integer] preferred_language
  # @attr [String]  profile
  # @attr [Integer] checkout_count
  # @attr [Integer] hold_count
  # @attr [Integer] overdue_count
  # @attr [Integer] reserve_count
  # @attr [Integer] recalled_count
  # @attr [String]  physical_delivery
  # @attr [String]  description
  # @attr [String]  first_name
  # @attr [String]  middle_name
  # @attr [String]  last_name
  # @attr [Integer] status_id
  # @attr [String]  telephone
  # @attr [String]  title
  # @attr [String]  pin
  #
  # @attr [Array<String>]              groups
  # @attr [Array<Firehose::Hold>]      holds
  # @attr [Array<Firehose::Course>]    courses
  # @attr [Array<Firehose::Checkout>]  checkouts
  #
  class User

    include HappyMapper
    include UVA

    tag 'user'

    #--
    # rubocop:disable Style/ExtraSpacing
    #++

    attribute :key,                 String
    attribute :sirsi_id,            String,   tag: 'sirsiId'
    attribute :computing_id,        String,   tag: 'computingId'

    element   :barred,              Boolean
    element   :bursarred,           Boolean
    element   :delinquent,          Boolean
    element   :display_name,        String,   tag: 'displayName'
    element   :email,               String
    element   :library_group,       Integer,  tag: 'libraryGroup'
    element   :organizational_unit, String,   tag: 'organizationalUnit' # LDAP
    element   :preferred_language,  Integer,  tag: 'preferredlanguage'
    element   :profile,             String # ....................... from Sirsi
    element   :checkout_count,      Integer,  tag: 'totalCheckouts'
    element   :hold_count,          Integer,  tag: 'totalHolds'
    element   :overdue_count,       Integer,  tag: 'totalOverdue'
    element   :reserve_count,       Integer,  tag: 'totalReserves'
    element   :recalled_count,      Integer,  tag: 'totalRecalls'
    element   :physical_delivery,   String,   tag: 'physicalDelivery'
    element   :description,         String # ........................ from LDAP
    element   :first_name,          String,   tag: 'givenName'
    element   :middle_name,         String,   tag: 'initials'
    element   :last_name,           String,   tag: 'surName'
    element   :status_id,           Integer,  tag: 'statusId'
    element   :telephone,           String
    element   :title,               String
    element   :pin,                 String

    # @return [Array<String>]
    has_many  :groups,              String,             tag: 'group'

    # @return [Array<Firehose::Hold>]
    has_many  :holds,               Firehose::Hold,     tag: 'hold'

    # @return [Array<Firehose::Course>]
    has_many  :courses,             Firehose::Course,   tag: 'course'

    # @return [Array<Firehose::Checkout>]
    has_many  :checkouts,           Firehose::Checkout, tag: 'checkout'

    #--
    # rubocop:enable Style/ExtraSpacing
    #++

    # =========================================================================
    # :section:
    # =========================================================================

    public

    # sorted_holds
    #
    # @return [Array<Firehose::Hold>]
    #
    def sorted_holds
      holds.sort_by { |a| [a.date_placed, a.catalog_item.title] }
    end

    # sorted_courses
    #
    # @return [Array<Firehose::Course>]
    #
    def sorted_courses
      courses.sort_by(&:code)
    end

    # sorted_checkouts
    #
    # @return [Array<Firehose::Checkout>]
    #
    def sorted_checkouts
      checkouts.sort_by { |a| [a.date_charged, a.catalog_item.title] }
    end

    # faculty?
    #
    def faculty?
      profile.casecmp('Faculty').zero? || ldap_faculty?
    end

    # instructor?
    #
    def instructor?
      profile.casecmp('Instructor').zero? || ldap_instructor?
    end

    # staff?
    #
    def staff?
      profile.casecmp('Staff').zero? || ldap_staff?
    end

    # graduate?
    #
    def graduate?
      profile.casecmp('Graduate').zero? || ldap_graduate?
    end

    # undergraduate?
    #
    def undergraduate?
      profile.casecmp('Undergraduate').zero? || ldap_undergraduate?
    end

    # continuing_ed?
    #
    def continuing_ed?
      profile.casecmp('Continuing Education').zero? || ldap_continuing_ed?
    end

    # RESEARCHERS don't have a profile, but they shouldn't have a U.Va.
    # computing id.
    #
    def virginia_borrower?
      # @profile !~ /^[a-z]{2,3}([0-9][a-z]{1,2})?$/i
      profile.blank? ||
        profile.match?(/Virginia Borrower|Other VA Faculty|Alumn/i)
    end

    # barred?
    #
    def barred?
      barred
    end

    # can_use_leo?
    #
    def can_use_leo?
      faculty?
    end

    # can_use_ill?
    #
    def can_use_ill?
      !virginia_borrower?
    end

    # can_make_reserves?
    #
    def can_make_reserves?
      !undergraduate? && !virginia_borrower?
    end

    # can_request_purchase?
    #
    def can_request_purchase?
      true # TODO: Should this be !virginia_borrower? ?
    end

    # can_request_scanning?
    #
    def can_request_scanning?
      true # TODO: Should this be !virginia_borrower? ?
    end

    # ldap_faculty?
    #
    def ldap_faculty?
      description.casecmp('Faculty').zero?
    end

    # ldap_instructor?
    #
    def ldap_instructor?
      description.casecmp('Instructor').zero?
    end

    # ldap_staff?
    #
    def ldap_staff?
      description.casecmp('Staff').zero?
    end

    # ldap_graduate?
    #
    def ldap_graduate?
      description.casecmp('Graduate Student').zero?
    end

    # ldap_undergraduate?
    #
    def ldap_undergraduate?
      description.casecmp('Undergraduate Student').zero?
    end

    # ldap_continuing_ed?
    #
    def ldap_continuing_ed?
      description.casecmp('Continuing Education').zero?
    end

  end

  # Firehose::Violation
  #
  # @attr [String] code
  # @attr [String] message
  #
  class Violation

    include HappyMapper
    include UVA

    tag 'FirehoseViolation'

    element :code,    String
    element :message, String

    # Show the contents of self for logging/debugging.
    #
    # @return [String]
    #
    def to_s
      "#{code.inspect}: #{message.inspect}"
    end

  end

  # Firehose::HoldError
  #
  class HoldError < RuntimeError; end

  # Firehose::RenewError
  #
  class RenewError < RuntimeError; end

end
