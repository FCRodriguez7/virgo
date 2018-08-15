# lib/uva/article/ebsco.rb

require 'unicode'
require 'net/https'
require 'xml/mapping'
require 'uva'

# Some articles are complex enough that the default limit is not enough.
REXML.entity_expansion_text_limit *= 2

module UVA::Article

  # Support for using EBSCO Discovery Service as an article search provider.
  #
  module Ebsco

    include UVA
    include UVA::Article

    extend UVA::Util::Json
    extend UVA::Article::Engine

    # =========================================================================
    # :section:
    # =========================================================================

    public

    EBSCO_EDS_PATH = '/edsapi/rest'.freeze
    EBSCO_USERNAME = 'xxx'.freeze
    # EBSCO_PASSWORD     = 'xxx'.freeze
    # EBSCO_INTERFACE_ID = 'uva_api'.freeze

    # Default amount of time to wait before considering an EBSCO request to
    # have failed.
    REQUEST_TIMEOUT = 10.seconds

    # Text to display in place of the article title if the record is one that
    # is limited to UVA-only.
    PLEASE_SIGN_IN = 'Please sign in to Virgo to see this information'.freeze

    # Maps the Blacklight field name to the FieldCode used in queries to EBSCO.
    SEARCH_FIELD_MAP = {
      'keyword'          => 'TX',
      'author'           => 'AU',
      'title'            => 'TI',
      'journal'          => 'SO',
      'publication_date' => 'DT1',
      'subject'          => 'SU',
      'issn'             => 'IS',
      'isbn'             => 'IB',
    }.deep_freeze

    DEFAULT_SEARCH_FIELD = 'TX'.freeze

    # EBSCO data fields associated with "title".
    #
    # NOTE: Of these, only "Title" is currently used.
    # * "TitleAlt" appears to have the same use as "linked title" does for
    # SolrDocument -- frequently the English version of the actual title.
    # * "TitleEng" seems to be similar, although some publishers appear to use
    # this exclusively (making it impossible to distinguish the actual title
    # from the translated title).
    #
    TITLE_TYPES = %w(Title TitleAlt TitleEng).deep_freeze

    # EBSCO data fields associated with "subject".
    #
    # NOTE: Of these, only "Subject" is currently used.
    # * "SubjectGeographic" could be used for "Related Places".
    # * "SubjectMESH" appears to be medical terminology.
    # * "Keyword" appears to be used as a substitute for "Subject".
    # All of these have XML structure and would need to be parsed to be usable.
    # Presence of any particular subset of these fields seems to be highly
    # dependent on the publisher/distributor.
    #
    SUBJECT_TYPES = %w(
      Subject
      SubjectGeographic
      SubjectMESH
      SubjectPerson
      SubjectThesaurus
      Keyword
      CodeClass
    ).deep_freeze

    # EBSCO data fields associated with "publication" information.
    #
    # NOTE: Most of these are not currently used.
    #
    PUB_TYPES = %w(DatePub PlacePub).deep_freeze

    # EBSCO data fields associated with "notes" or other information.
    #
    # NOTE: None of these are currently used.
    #
    NOTE_TYPES = %w(PhysDesc).deep_freeze

    # EBSCO data fields associated with "abstract" or other description.
    #
    ABSTRACT_TYPES =
      %w(Abstract AbstractNonEng AbstractSuppliedCopyright).deep_freeze

    # =========================================================================
    # :section: Data items
    # =========================================================================

    public

    # @see UVA::Article::FacetItem
    #
    # Compare with:
    # @see UVA::Article::Primo::Item
    # @see UVA::Article::Ebsco::Item
    # @see UVA::Article::Summon::Item
    #
    class Item < UVA::Article::FacetItem

      include XML::Mapping

      text_node    :value, 'Value'
      numeric_node :hits,  'Count'

    end

    # @see UVA::Article::FacetField
    #
    # Compare with:
    # @see UVA::Article::Primo::Facet
    # @see UVA::Article::Ebsco::Facet
    # @see UVA::Article::Summon::Facet
    #
    class Facet < UVA::Article::FacetField

      include XML::Mapping

      # rubocop:disable Metrics/LineLength

      text_node  :name,  'Id'
      array_node :items, 'AvailableFacetValues', 'AvailableFacetValue', class: Item

      # rubocop:enable Metrics/LineLength

    end

    # UVA::Article::Ebsco::Title
    #
    # @attr [String] type
    # @attr [String] value
    #
    class Title

      include XML::Mapping

      text_node :type,  'Type'
      text_node :value, 'TitleFull'

    end

    # UVA::Article::Ebsco::Number
    #
    # @attr [String] number_type
    # @attr [String] value
    #
    class Number

      include XML::Mapping

      text_node :number_type, 'Type'
      text_node :value,       'Value'

    end

    # UVA::Article::Ebsco::DateDMY
    #
    # @attr [String] date_type
    # @attr [String] text
    # @attr [String] day
    # @attr [String] month
    # @attr [String] year
    #
    class DateDMY

      include XML::Mapping

      text_node :date_type, 'Type', default_value: ''
      text_node :text,      'Text', default_value: ''
      text_node :day,       'D',    default_value: ''
      text_node :month,     'M',    default_value: ''
      text_node :year,      'Y',    default_value: ''

    end

    # UVA::Article::Ebsco::Identifier
    #
    # @attr [String] identifier_type
    # @attr [String] value
    #
    class Identifier

      include XML::Mapping

      text_node :identifier_type, 'Type'
      text_node :value,           'Value'

      #--
      # The following are visible in JSON output but not currently used:
      #++

      text_node :scope, 'Scope', default_value: nil

    end

    #--
    # Forward reference.
    #++
    class PhysicalDescription; end

    #--
    # Forward reference.
    #++
    class Subject; end

    #--
    # Forward reference.
    #++
    class Language; end

    # UVA::Article::Ebsco::BibEntity2
    #
    # @attr [Array<DateDMY>]    dates
    # @attr [Array<Identifier>] identifiers
    # @attr [Array<Number>]     numbering
    # @attr [Array<Title>]      titles
    #
    class BibEntity2

      include XML::Mapping

      # rubocop:disable Metrics/LineLength

      array_node :titles,      'Titles',      'Title',      class: Title,      default_value: []
      array_node :numbering,   'Numbering',   'Number',     class: Number,     default_value: []
      array_node :dates,       'Dates',       'Date',       class: DateDMY,    default_value: []
      array_node :identifiers, 'Identifiers', 'Identifier', class: Identifier, default_value: []

      #--
      # The following are visible in JSON output but not currently used:
      #++

      text_node :entity_id,   'Id',   default_value: nil
      text_node :entity_type, 'Type', default_value: nil

      object_node :physical_description, 'PhysicalDescription',               class: PhysicalDescription, default_value: nil
      array_node  :subjects,             'Subjects',            'Subject',    class: Subject,             default_value: []
      array_node  :languages,            'Languages',           'Language',   class: Language,            default_value: []

      # rubocop:enable Metrics/LineLength

    end

    # UVA::Article::Ebsco::IsPartOf
    #
    # @attr [BibEntity2] bib_entity
    #
    class IsPartOf

      include XML::Mapping

      # rubocop:disable Metrics/LineLength

      object_node :bib_entity, 'BibEntity', class: BibEntity2, default_value: nil

      # rubocop:enable Metrics/LineLength

    end

    # UVA::Article::Ebsco::Name
    #
    # @attr [String] nameFull
    #
    class Name

      include XML::Mapping

      text_node :nameFull, 'NameFull', default_value: nil

    end

    # UVA::Article::Ebsco::PersonEntity
    #
    # @attr [Name] name
    #
    class PersonEntity

      include XML::Mapping

      object_node :name, 'Name', class: Name

    end

    # UVA::Article::Ebsco::HasContributor
    #
    # @attr [PersonEntity] person_entity
    #
    class HasContributor

      include XML::Mapping

      object_node :person_entity, 'PersonEntity', class: PersonEntity

    end

    # UVA::Article::Ebsco::Pagination
    #
    # @attr [String] page_count
    # @attr [String] start_page
    #
    class Pagination

      include XML::Mapping

      text_node :start_page, 'StartPage', default_value: '0'
      text_node :page_count, 'PageCount', default_value: ''

    end

    # UVA::Article::Ebsco::PhysicalDescription
    #
    # @attr [Pagination] pagination
    #
    class PhysicalDescription

      include XML::Mapping

      # rubocop:disable Metrics/LineLength

      object_node :pagination, 'Pagination', class: Pagination, default_value: nil

      # rubocop:enable Metrics/LineLength

    end

    # UVA::Article::Ebsco::Subject
    #
    # @attr [String] subject_full
    #
    class Subject

      include XML::Mapping

      text_node :subject_full, 'SubjectFull'

      #--
      # The following are visible in JSON output but not currently used:
      #++

      text_node :type,      'Type',      default_value: nil
      text_node :authority, 'Authority', default_value: nil

    end

    # UVA::Article::Ebsco::Language
    #
    # @attr [String] language
    #
    class Language

      include XML::Mapping

      text_node :language, 'Text', default_value: nil

      #--
      # The following are visible in JSON output but not currently used:
      #++

      text_node :code, 'Code', default_value: nil

    end

    # UVA::Article::Ebsco::BibEntity1
    #
    # @attr [Array<Language>]     languages
    # @attr [PhysicalDescription] physical_description
    # @attr [Array<Subject>]      subjects
    # @attr [Array<Identifier>]   identifiers
    #
    class BibEntity1

      include XML::Mapping

      # rubocop:disable Metrics/LineLength
      # rubocop:disable Style/ExtraSpacing

      array_node  :identifiers,          'Identifiers',         'Identifier', class: Identifier,          default_value: []
      object_node :physical_description, 'PhysicalDescription',               class: PhysicalDescription, default_value: nil
      array_node  :subjects,             'Subjects',            'Subject',    class: Subject,             default_value: []
      array_node  :languages,            'Languages',           'Language',   class: Language,            default_value: []

      #--
      # The following are visible in JSON output but not currently used:
      #++

      text_node :entity_id,   'Id',   default_value: nil
      text_node :entity_type, 'Type', default_value: nil

      array_node :titles,      'Titles',      'Title',      class: Title,      default_value: []
      array_node :numbering,   'Numbering',   'Number',     class: Number,     default_value: []
      array_node :dates,       'Dates',       'Date',       class: DateDMY,    default_value: []

      # rubocop:enable Metrics/LineLength
      # rubocop:enable Style/ExtraSpacing

    end

    # UVA::Article::Ebsco::BibRelationships
    #
    # @attr [Array<HasContributor>] contributors
    # @attr [Array<IsPartOf>]       is_part_of_relationships
    #
    class BibRelationships

      include XML::Mapping

      # rubocop:disable Metrics/LineLength

      array_node :contributors,             'HasContributorRelationships', 'HasContributor', class: HasContributor, default_value: nil
      array_node :is_part_of_relationships, 'IsPartOfRelationships',       'IsPartOf',       class: IsPartOf,       default_value: nil

      # rubocop:enable Metrics/LineLength

    end

    # UVA::Article::Ebsco::BibRecord
    #
    # @attr [BibEntity1]       bib_entity
    # @attr [BibRelationships] bib_relationships
    #
    class BibRecord

      include XML::Mapping

      # rubocop:disable Metrics/LineLength

      object_node :bib_entity,        'BibEntity',        class: BibEntity1,       default_value: nil
      object_node :bib_relationships, 'BibRelationships', class: BibRelationships, default_value: nil

      # rubocop:enable Metrics/LineLength

    end

    # UVA::Article::Ebsco::RecordInfo
    #
    # @attr [BibRecord] bib_record
    #
    class RecordInfo

      include XML::Mapping

      # rubocop:disable Metrics/LineLength

      object_node :bib_record, 'BibRecord', class: BibRecord, default_value: nil

      # rubocop:enable Metrics/LineLength

    end

    # UVA::Article::Ebsco::DownloadText
    #
    # @attr [String] availability
    # @attr [String] value
    #
    class DownloadText

      include XML::Mapping

      numeric_node :availability, 'Availability', default_value: 0
      text_node    :value,        'Value',        default_value: nil

    end

    # UVA::Article::Ebsco::DownloadLink
    #
    # @attr [String] url
    # @attr [String] type
    #
    class DownloadLink

      include XML::Mapping

      text_node :url,  'Url',  default_value: nil
      text_node :type, 'Type', default_value: nil

      # =======================================================================
      # :section:
      # =======================================================================

      public

      # Return the type in a form suitable for display.
      #
      # @return [String]
      # @return [nil]                 If :type is *nil*.
      #
      def format
        case type
          when nil      then nil
          when /^pdf/i  then 'PDF'
          when /^epub/i then 'ePub'
          else               'Text'
        end
      end

      # The typical format for downloads.
      #
      # @return [String]
      #
      def self.default_format
        'PDF'
      end

    end

    # UVA::Article::Ebsco::CustomLink
    #
    # @attr [String] url
    # @attr [String] text
    # @attr [String] name
    # @attr [String] icon_url
    #
    class CustomLink

      include XML::Mapping

      text_node :text,     'Text', default_value: ''
      text_node :name,     'Name', default_value: ''
      text_node :url,      'Url',  default_value: ''
      text_node :icon_url, 'Icon', default_value: ''

      #--
      # The following are visible in JSON output but not currently used:
      #++

      text_node :category,   'Category',      default_value: nil
      text_node :hover_text, 'MouseOverText', default_value: nil

    end

    # UVA::Article::Ebsco::Header
    #
    # @attr [String] dbid        EBSCO database.
    # @attr [String] an          Article number (within that database)..
    #
    class Header

      include XML::Mapping

      text_node :dbid, 'DbId'
      text_node :an,   'An'

      #--
      # The following are visible in JSON output but not currently used:
      #++

      text_node :dblabel,      'DbLabel',        default_value: nil
      text_node :score,        'RelevancyScore', default_value: nil
      text_node :access_level, 'AccessLevel',    default_value: nil
      text_node :pub_type,     'PubType',        default_value: nil
      text_node :pub_type_id,  'PubTypeId',      default_value: nil

    end

    # UVA::Article::Ebsco::DisplayElement
    #
    # @attr [String] key
    # @attr [String] value
    #
    class DisplayElement

      include XML::Mapping

      text_node :key,   'Name'
      text_node :value, 'Data'

      #--
      # The following are visible in JSON output but not currently used:
      #++

      text_node :label, 'Label', default_value: nil
      text_node :group, 'Group', default_value: nil

    end

    # UVA::Article::Ebsco::FullText
    #
    # @attr [Array<CustomLink>] custom_links
    #
    class FullText

      include XML::Mapping

      # rubocop:disable Metrics/LineLength

      object_node :text,           'Text',                      class: DownloadText, default_value: nil
      array_node  :download_links, 'Links',       'Link',       class: DownloadLink, default_value: []
      array_node  :custom_links,   'CustomLinks', 'CustomLink', class: CustomLink,   default_value: []

      # rubocop:enable Metrics/LineLength

    end

    # UVA::Article::Ebsco::ArticleId
    #
    # Helper class to encapsulate the EBSCO article ID which we are declaring
    # to be the database id (DbId) and accession number (An) of the article
    # with a colon separator, like this: edsmzh:1993066095
    #
    # This info is in the <Header> portion of the XML <Record> element of each
    # article's metadata returned from an EBSCO request.
    #
    class ArticleId

      # @return [String]
      attr_reader :dbid

      # @return [String]
      attr_reader :an

      # @return [String]
      attr_reader :encoded

      # =======================================================================
      # :section:
      # =======================================================================

      public

      # Initialize this self instance.
      #
      # @param [String,ArticleId] dbid
      # @param [String,nil]       an
      #
      def initialize(dbid = nil, an = nil)
        @dbid = @an = @encoded = nil
        case dbid
          when ArticleId
            @dbid = dbid.dbid
            @an   = dbid.an
          when /:/ # Raw ID string
            parts = dbid.split(':')
            @dbid = parts.shift
            @an   = parts.join(':')
          when /%/ # Encoded ID string
            parts = dbid.split(/%3A/i)
            @dbid = decode(parts.shift)
            @an   = decode(parts.join('%3A'))
            @encoded = dbid.dup
        end
        @dbid    ||= dbid || '0'
        @an      ||= an   || '0'
        @encoded ||= encode(inspect)
      end

      # Return the un-encoded version of the ID string.
      #
      # @return [String]
      #
      def decoded
        decode(@encoded)
      end

      # Override #to_s to generate an article ID string based on the EBSCO
      # database and accession number, but encoded for use within a URL.
      #
      # @return [String]
      #
      def to_s
        inspect
      end

      # Override #inspect to display an article ID of the form database ID and
      # accession number separated by a colon; e.g.: "edsmzh:1993066095".
      #
      # @return [String]
      #
      def inspect
        "#{@dbid}:#{@an}"
      end

      # =======================================================================
      # :section:
      # =======================================================================

      protected

      # Encode for use within a URL.
      #
      # This is almost identical to ERB::Util#url_encode except that it also
      # encodes '.'.
      #
      # @param [String] s
      #
      # @return [String]
      #
      # Compare with:
      # @see ERB::Util#url_encode
      #
      def encode(s)
        s.to_s.dup.force_encoding('ASCII-8BIT').gsub(/[^a-zA-Z0-9_\-]/n) do
          sprintf('%%%02X', $&.unpack('C')[0])
        end
      end

      # Decode an encoded ID.
      #
      # @param [String] s
      #
      # @return [String]
      #
      # @see CGI#unescape
      #
      def decode(s)
        CGI.unescape(s)
      end

    end

    # =========================================================================
    # :section: ArticleDoc implementation
    # =========================================================================

    public

    # UVA::Article::Ebsco::Document
    #
    # @attr [Array<DisplayElement>] display_elements
    # @attr [Array<CustomLink>]     custom_links
    # @attr [String]                plink
    # @attr [RecordInfo]            record_info
    # @attr [Header]                header
    # @attr [FullText]              full_text
    #
    # Compare with:
    # @see UVA::Article::Primo::Document
    # @see UVA::Article::Ebsco::Document
    # @see UVA::Article::Summon::Document
    #
    class Document

      include XML::Mapping
      include UVA
      include UVA::Util::HtmlMethods
      include UVA::ArticleDoc

      # The article document instance variables that are included when
      # serializing the item.
      #
      INSTANCE_VARIABLES = [
        :header, :display_elements, :full_text, :custom_links, :plink,
        :record_info
      ].freeze

      #--
      # rubocop:disable Metrics/LineLength
      # rubocop:disable Style/ExtraSpacing
      #++

      # Member data parsed directly from xml via the XML::Mapping.
      object_node :header,           'Header',                    class: Header,         default_value: nil
      array_node  :display_elements, 'Items',       'Item',       class: DisplayElement, default_value: []
      object_node :full_text,        'FullText',                  class: FullText,       default_value: nil
      array_node  :custom_links,     'CustomLinks', 'CustomLink', class: CustomLink,     default_value: []
      text_node   :plink,            'PLink',                                            default_value: nil
      object_node :record_info,      'RecordInfo',                class: RecordInfo,     default_value: nil

      #--
      # The following are visible in JSON output but not currently used:
      #++

      text_node :result_id, 'ResultId', default_value: nil

      #--
      # rubocop:enable Metrics/LineLength
      # rubocop:enable Style/ExtraSpacing
      #++

      # @return [Array<String>]
      attr_accessor :authors

      # @return [Array<Link>]
      attr_accessor :download_links

      # @return [String]
      attr_accessor :download_text

      # Initialize a self instance.
      #
      # @param [Array] args             Passed to the super initializer.
      #
      def initialize(*args)
        super(*args)
        @display         = Display.new
        @additional_data = AdditionalData.new
        @search          = Search.new
        @authors         = []
        @doc_sub_type    = nil
        @download_links  = []
        @download_text   = nil
        @login_needed    = nil
      end

      # =======================================================================
      # :section: RSolr::Ext::Model interface
      # =======================================================================

      public

      # @see UVA::IndexDoc#id
      #
      # @return [ArticleId]
      #
      def id
        @id ||= ArticleId.new(header.dbid, header.an).to_s
      end

      # =======================================================================
      # :section: Blacklight::Solr::Document::MarcExport interface
      # =======================================================================

      protected

      # @see UVA::IndexDoc#get_author_list
      #
      # Each name is in bibliographic order but the surname may not begin with
      # a capital letter, e.g. "de la Croix, Jean".
      #
      def get_author_list(*)
        authors
      end

      # =======================================================================
      # :section: Document properties (core)
      # =======================================================================

      public

      # Some content providers specify the type of the item; if this is not
      # available, :article is used as the default.
      #
      # @return [Symbol]
      #
      # @see UVA::IndexDoc#doc_sub_type
      #
      # === Notes
      # This is an on-going list of observed sub types:
      #   article
      #   Article
      #   Book Chapter
      #   Book Review
      #   Column
      #   Conference; Serial
      #   Journal; Serial
      #   Journal; Microform; Serial
      #   Journal Articles; Reports - Research
      #   notes
      #   rapid communication
      #   Review
      #   Short Story
      #   Speech
      #
      def doc_sub_type
        @doc_sub_type ||=
          case display.type.downcase
            when /review/       then :review      # Review / Book Review
            when /report/       then :report      # Reports - Research
            when /story/        then :story       # Short Story
            when /speech/       then :speech      # Speech
            when /notes/        then :notes       # notes
            when /journal/      then :journal     # Journal
            when /chapter/      then :chapter     # Book Chapter
            when /conference/   then :proceedings # Conference
            when /column/       then :column      # Column
            else                     :article     # article / Article
          end
      end

      # =======================================================================
      # :section: Document values (Bibliographic information)
      # =======================================================================

      public

      # @see UVA::IndexDoc#get_authors
      #
      # Each name is in bibliographic order with the surname capitalized, e.g.
      # "De la Croix, Jean".
      #
      def get_authors
        capitalize(authors)
      end

      # =======================================================================
      # :section: Serialization support
      # =======================================================================

      public

      # @see UVA::IndexDoc#to_xml
      #
      # @param [Boolean] formatted    If *true* produce indented results
      #                                 separated by newlines.
      #
      # @return [String]
      #
      def to_xml(formatted = false)
        result = ''
        if formatted
          REXML::Formatters::Pretty.new.write(save_to_xml, result)
        else
          REXML::Formatters::Default.new.write(save_to_xml, result)
        end
        result
      end

      # @see UVA::IndexDoc#as_json
      #
      # Override which allows control over how the instance is represented in
      # JSON output.
      #
      # NOTE: For now, this method is limiting JSON output to the actual data
      # received from EBSCO and without the derived data extracted via
      # #map_xml_to_fields.
      #
      # @return [Hash]
      #
      def as_json(*)
        INSTANCE_VARIABLES.map { |name|
          symbol = "@#{name}".to_sym
          next unless instance_variables.include?(symbol)
          [name, instance_variable_get(symbol).as_json]
        }.compact.to_h
      end

      # Parse the XML contents of full-text.
      #
      # @param [Boolean] formatted    If *true* produce indented results
      #                                 separated by newlines.
      #
      # @return [String]
      #
      def download_text_to_xml(formatted = false)
        result = ''
        if download_text.present?
          xml = REXML::Document.new("<full_text>#{download_text}</full_text>")
          if formatted
            REXML::Formatters::Pretty.new.write(xml, result)
          else
            REXML::Formatters::Default.new.write(xml, result)
          end
        end
        result
      end

      # =======================================================================
      # :section: HTML support methods
      # =======================================================================

      public

      # @see UVA::ArticleDoc#all_links
      #
      def all_links
        download_links + links
      end

      # =======================================================================
      # :section:
      # =======================================================================

      public

      # Indicate whether this item requires non-"guest" access to EBSCO EDS.
      #
      def login_needed?
        @login_needed
      end

      # Indicate whether this item has full-text content available.
      #
      # If this document was created from a search then `full_text.text.value`
      # will be empty -- the only indicator is the value of
      # `full_text.text.availability`.
      #
      def full_text?
        text = full_text && full_text.text
        text && (text.value.present? || !text.availability.zero?)
      end

      # Indicate the format(s) in which this item can be downloaded.
      #
      # @return [Array<String>]
      #
      def download_formats
        full_text ? full_text.download_links.map(&:format).compact : []
      end

      # Sets the values for the attributes of this class as well as member data
      # not already set from parsing the XML.
      #
      # @return [void]
      #
      def map_xml_to_fields
        set_bib_data
        set_authors
        set_languages
        set_identifiers
        set_subjects
        set_item_access_data
        set_page_numbers
        set_journal
        set_volume_issue
        set_creation_date
      end

      # =======================================================================
      # :section:
      # =======================================================================

      protected

      # Set the @display description, title, is_part_of, and type fields.
      #
      # @param [Array<DisplayElement>] src
      #
      # @return [void]
      #
      # === Implementation Notes
      # Note that 'NumberOther' is not the same as 'Number Other'.
      # If "TypeDocument" is not included, @display.type will default to
      # "Article".
      #
      def set_bib_data(src = nil)
        # If display_elements is empty, this is a sign that the item required
        # non-"guest" access.
        unless src
          src = display_elements
          if src.blank?
            @login_needed = true
            return
          end
        end
        description_part = {}

        src.each do |element|
          value = element && element.value
          next if value.blank?
          key = element.key
          case key

            when 'Title'
              value = strip_html(value)
              value.gsub!(%r{\s*/\s*}, ' / ')
              # Remove extraneous text added by some publishers/distributors:
              value.gsub!(/^\s*(full)\s+(length)\s+(article:)\s*/i, '')
              titleize!(value)
              value.sub!(PHRASE_END, '')
              @display.title = value

            when 'TitleSource'
              # TODO: This is often XML content and really should be parsed
              # rather than simply stripped of XML elements.
              value = value.sub(/^In </, '<')
              value = strip_html(value)
              value.gsub!(%r{(?<!\w)([a-z][a-z/.-]+)(\d+)(?!\w)}i, '\1 \2')
              titleize!(value, force: true)
              # Fix over-capitalization of page numbers:
              value.gsub!(/(?<!\w)pp(?!\w)/i,    'pp')
              value.gsub!(/(?<!\w)P(\.?\d+|\.)/, 'p\1')
              value.gsub!(/(?<!\w)(\d+)P(?!\w)/, '\1p')
              value.sub!(PHRASE_END, '')
              @display.is_part_of = value

            when 'TypeDocument'
              value = strip_html(value)
              titleize!(value)
              @display.type = value

            when 'DOI'
              value = value.gsub(%r{<br\s*/>}, "\n")
              value = strip_html(value).squeeze(' ').strip
              dois.concat(value.split("\n"))

            when 'ISSN'
              value = value.gsub(%r{<br\s*/>}, "\n")
              value = strip_html(value).squeeze(' ').strip
              issns.concat(value.split("\n"))

            when 'Number Other'
              value = strip_html(value)
              call_numbers << value

            else
              if ABSTRACT_TYPES.include?(key)
                # Some limited HTML formatting elements are allowed for the
                # abstract (bold, italic, superscript, subscript, etc).
                # Some of the content has <subscript> instead of <sub> and
                # <superscript> instead of <sup> so those are translated here.
                if value.include?('script>')
                  value = value.dup
                  value.gsub!(%r{<(/?sub)script>},   '<\1>')
                  value.gsub!(%r{<(/?sup)erscript>}, '<\1>')
                end
                description_part[key] ||= []
                description_part[key] << sanitize_html(value)
              else
                Rails.logger.debug {
                  "ARTICLES - ignoring data item #{key.inspect}"
                }
              end

          end
        end

        # Eliminate duplication call numbers (if any).  Resolution of `dois`
        # and `issns` is deferred to #set_identifiers.
        call_numbers.uniq!

        # Ensure that the description begins with standard language abstract
        # entries, followed by other abstract entries, and ending with
        # copyright information.
        description_part.sort.each { |pair| @display.description += pair.last }
        @display.description.uniq!
      end

      # Set the @display creator field and @authors array.
      #
      # @param [Array<HasContributor>] src
      #
      # @return [void]
      #
      # === Implementation Notes
      # If the name is all uppercase or lowercase then it is titleized; if it
      # is mixed case then it is assumed to be correct.  The desired format is
      # "family_name, given_name [middle_name]"; the method will attempt to put
      # it in that form if it is not already that way.
      #
      def set_authors(src = nil)
        src ||=
          begin
            bib_record = record_info && record_info.bib_record
            rels       = bib_record  && bib_record.bib_relationships
            rels && rels.contributors
          end
        return if src.blank?
        author_list =
          src.map { |contributor|
            value   = contributor.person_entity
            value &&= value.name
            value &&= value.nameFull
            next unless value.present?
            value.sub!(/\s*[,;:]\s*author$/i, '')
            monocase = (value.downcase == value) || (value.upcase == value)
            monocase ? titleize(value, names: true) : value
          }.compact.uniq
        @authors = author_list.map { |author| bib_order(author) }
        reading_order = author_list.map { |author| name_reverse(author) }
        @display.creator = strip_html(reading_order.join(ITEM_SEPARATOR))
      end

      # Set the @display language field.
      #
      # @param [Array<Language>] src
      #
      # @return [void]
      #
      def set_languages(src = nil)
        src ||=
          begin
            bib_record = record_info && record_info.bib_record
            bib_entity = bib_record  && bib_record.bib_entity
            bib_entity && bib_entity.languages
          end
        return if src.blank?
        languages = src.reject(&:blank?).map(&:language).uniq
        @display.language = strip_html(languages.join(LIST_SEPARATOR))
      end

      # Set the @dois and @issns attributes, and the @display identifier field.
      #
      # Because single records may have these values in @display_elements and
      # not in @record_info, @dois and/or @issns may already contain values
      # coming in to this method.
      #
      # @param [Array<IsPartOf>] src
      #
      # @return [void]
      #
      def set_identifiers(src = nil)

        bib_record = record_info && record_info.bib_record
        src ||=
          bib_record &&
          bib_record.bib_relationships &&
          bib_record.bib_relationships.is_part_of_relationships
        identifiers =
          Array(src).flat_map do |ispartof|
            ispartof && ispartof.bib_entity && ispartof.bib_entity.identifiers
          end

        bib_entity = bib_record && bib_record.bib_entity
        identifiers += bib_entity.identifiers if bib_entity.present?

        identifiers.each do |identifier|
          next if identifier.blank?
          id_value = identifier.value.to_s.strip
          id_type  = identifier.identifier_type.to_s.strip
          # Ignore the EBSCO identifiers which indicate the EBSCO database.
          next if id_type.casecmp('issn-locals').zero?
          type, _, modifier = id_type.partition('-')
          id_value << " (#{modifier})" if modifier.present?
          case type.upcase
            when 'DOI'
              dois << id_value
            when 'ISSN'
              id_value.insert(4, '-') unless id_value[4] == '-'
              issns << id_value
          end
        end

        # Finalize `dois` and `issns` values accumulated from #set_bib_data and
        # from this method.
        current = {
          'DOI'  => dois.uniq,
          'ISSN' => issns.uniq
        }
        final = current.map { |type, _| [type, []] }.to_h
        @display.identifier =
          current.flat_map { |type, values|
            values.map do |value|
              number_only = value.to_s.sub(/\s.*/, '')
              next if number_only.blank?
              next if final[type].include?(number_only)
              next if final[type].include?(value)
              final[type] << number_only
              "#{type} #{value}"
            end
          }.compact.join(ITEM_SEPARATOR)
        @dois  = final['DOI'].uniq
        @issns = final['ISSN'].uniq

      end

      # Set the @display subject and @search subject_facet fields.
      #
      # @param [Array<String>] src
      #
      # @return [void]
      #
      def set_subjects(src = nil)
        src ||=
          begin
            bib_record = record_info && record_info.bib_record
            bib_entity = bib_record  && bib_record.bib_entity
            bib_entity && bib_entity.subjects
          end
        return if src.blank?
        subjects =
          src.map { |subject|
            value = subject && subject.subject_full
            titleize(strip_html(value), force: true) if value.present?
          }.compact.uniq
        @search.subject_facet = subjects
        @display.subject      = subjects.join(ITEM_SEPARATOR)
      end

      # Get any available item access data: full-text content (@download_text),
      # PDF download links (@download_links), and/or online access links
      # (@links).
      #
      # If this is a retrieved document, then get any available item access
      # data: full-text content, PDF download links, and/or online access
      # links.  (If the user is not logged in, EBSCO will withhold some or
      # all of this metadata depending on publisher licensing agreements.)
      #
      # If this is a document from search results, none of this data will be
      # available.  (Only indicators that full-text content and/or download
      # is available.)
      #
      # @return [void]
      #
      # === Examples
      # @example Both full-text content and PDF download
      #   /articles/article?id=eft:527588351
      #
      # @example Full-text content with no PDF download
      #   /articles/article?id=f5h:119050046
      #
      # @example PDF download with no full-text content
      #   /articles/article?id=f5h:119297604
      #
      def set_item_access_data
        # Full-text content.
        @download_text = get_download_text

        # Download links.
        @download_links += get_download_links
        if @download_links.empty?
          text = DownloadLink.default_format
          name =
            if download_formats.blank?
              'Download not provided by this journal/publisher'
            else
              PLEASE_SIGN_IN
            end
          @download_links << Link.new(nil, text, name)
        end

        # Custom links.
        @links += get_online_links

        # Use the PLink as the final (fallback) link.
        default_url = URL::UVA_PROXY_PREFIX + plink
        @links.delete_if { |link| link.url == default_url }
        text = 'EBSCO'
        name = 'Online via <strong>EBSCO Discovery Service</strong>'.html_safe
        @links << Link.new(default_url, text, name)
      end

      # Set the @additional_data start_page and end_page fields, allowing for
      # page numbers that might include non-digit characters.
      #
      # @param [Blacklight::Solr::FacetPaginator] pagination
      #
      # @return [void]
      #
      def set_page_numbers(pagination = nil)
        start_page = end_page = nil
        pagination ||=
          begin
            bib_record = record_info && record_info.bib_record
            bib_entity = bib_record  && bib_record.bib_entity
            phys_desc  = bib_entity  && bib_entity.physical_description
            phys_desc && phys_desc.pagination
          end
        return if pagination.blank?
        prefix = postfix = nil
        start_page = pagination.start_page.to_s.strip
        sp = start_page.to_i
        unless start_page == sp.to_s
          start_page.match(/^([^\d]*)(\d+)(.*)$/)
          prefix   = $1
          sp       = $2.to_i
          postfix  = $3
        end
        pages = pagination.page_count.to_i
        end_page = (sp + pages - 1) unless pages.zero?
        end_page = "#{prefix}#{end_page}#{postfix}" if end_page
        @additional_data.start_page = start_page.to_s
        @additional_data.end_page   = end_page.to_s
      end

      # Set the @additional_data journal field.
      #
      # @param [Array<IsPartOf>] src
      #
      # @return [void]
      #
      def set_journal(src = nil)
        src ||=
          begin
            bib_record = record_info && record_info.bib_record
            rels       = bib_record  && bib_record.bib_relationships
            rels && rels.is_part_of_relationships
          end
        return if src.blank?
        journal =
          src.flat_map { |ispartof|
            next unless ispartof && ispartof.bib_entity
            ispartof.bib_entity.titles.map do |title|
              value = title && title.value
              titleize(strip_html(value)) if value.present?
            end
          }.compact.uniq
        @additional_data.journal = journal.join(ITEM_SEPARATOR)
      end

      # Set the @additional_data volume and issue fields.
      #
      # @param [Array<IsPartOf>] src
      #
      # @return [void]
      #
      def set_volume_issue(src = nil)
        src ||=
          begin
            bib_record = record_info && record_info.bib_record
            rels       = bib_record  && bib_record.bib_relationships
            rels && rels.is_part_of_relationships
          end
        return if src.blank?
        src.each do |ispartof|
          next unless ispartof && ispartof.bib_entity
          ispartof.bib_entity.numbering.each do |element|
            case element.number_type
              when 'volume' then @additional_data.volume = element.value
              when 'issue'  then @additional_data.issue  = element.value
            end
          end
        end
      end

      # Set the @search creation date field.
      #
      # @param [Array<IsPartOf>] src
      #
      # @return [void]
      #
      def set_creation_date(src = nil)
        src ||=
          begin
            bib_record = record_info && record_info.bib_record
            rels       = bib_record  && bib_record.bib_relationships
            rels && rels.is_part_of_relationships
          end
        return if src.blank?
        src.each do |ispartof|
          next unless ispartof && ispartof.bib_entity
          ispartof.bib_entity.dates.each do |date|
            next unless date.date_type == 'published'
            y = date.year.blank?  ? nil : date.year.to_i
            m = date.month.blank? ? nil : date.month.to_i
            d = date.day.blank?   ? nil : date.day.to_i
            @search.creation_date =
              if y && m && d
                Date.new(y, m, d).strftime('%Y/%B/%-d')
              elsif y && m
                Date.new(y, m).strftime('%Y/%B')
              elsif y
                Date.new(y).strftime('%Y')
              else
                date.text
              end
          end
        end
      end

      # =======================================================================
      # :section:
      # =======================================================================

      protected

      # Regular expressions matching XML tags paired with the HTML tags to
      # which they are translated.
      #
      # E.g., { 'ulink' => 'a' } results in the 2-element array:
      #
      #   [ /<(\/?)ulink(\s+[^>]*)?>/ , '<\1a\2>' ]
      #
      # which will support the substitutions:
      #
      #   "<ulink href='...'>" -> "<a href='...'>"
      #   "</ulink>"           -> "</a>"
      #
      FULL_TEXT_TAG_TRANSLATIONS = {
          'ulink'       => 'a',
          'bold'        => 'b',
          'italic'      => 'i',
          'item'        => 'li',
          'olist'       => 'ol',
          'ulist'       => 'ul',
          'superscript' => 'sup',
          'subscript'   => 'sub',
          'sups'        => 'sup',
          'subs'        => 'sub',
          'title'       => 'atitle',
        }.map { |tag, new_tag|
          [%r{<(/?)#{tag}(\s+[^>]*)?>}, "<\\1#{new_tag}\\2>"]
        }.deep_freeze

      # Pattern fragment for matching footnote reference optional left-hand
      # brackets/spaces.
      LB = '\s*[\[(]?'.freeze

      # Pattern fragment for matching footnote reference optional right-hand
      # brackets/spaces.
      RB = '\s*[\])]?'.freeze

      # Regular expression for matching linefeeds.
      CRLF = /(\r\n|\r|\n)/.freeze

      # Pairs of regular expressions and their substitutions.
      #
      FULL_TEXT_OTHER_TRANSLATIONS = [

        # Ignore certain spacing characters:
        [/[\u0085\u00a0]/, ''],

        # Normalize footnote labels for <reflink> and <bibl>.
        [/#{LB}<(reflink|bibl)(.*?)>#{LB}[a-z]*([\d-]+)\.?#{RB}(<.*?>)#{RB}/,
          '<\1\2>[\3]\4'],

        # Footnote reference <reflink> - link to <bibl> entry.
        [/<(reflink)(.*?)(idref=")([^"]+)(.*?)>(.*?)(<.*?>)/,
          '<\1\2\3\4\5><a href="#\4" title="Jump to note \6">\6</a>\7'],

        # Footnote <bibl> entry - link back to referring <reflink>.
        [/<(bibl)(.*?)(idref=")([^"]+)(.*?)>(.*?)(<.*?>)/,
          '<\1\2\3\4\5><a href="#\4" title="Jump back to text">\6</a>\7'],

        # Image <img> link to source.
        [/<(img)(.*?)(src=")([^"]+)(.*?)>/,
          '<a href="\4" target="_blank"><\1\2\3\4\5></a>'],

        # Found in <ephtml> tables; e.g. "[sub 2]" or "[sup -9]":
        [/\[(sub|sup)(\s*[0-9\s][^\]]*)\]/, '<\1>\2</\1>'],

        # Don't maintain newlines because they will be translated into HTML
        # breaks by UVA::Util::HtmlMethods#sanitize_html.
        [CRLF, SPACE],

      ].deep_freeze

      # Pairs of regular expressions and their substitutions.
      #
      FULL_TEXT_TRANSLATIONS =
        (FULL_TEXT_TAG_TRANSLATIONS + FULL_TEXT_OTHER_TRANSLATIONS).freeze

      # HTML element tags allowed to make it through sanitization in addition
      # to UVA::Util::HtmlMethods#ALLOWED_TAGS.
      #
      # These tags have been observed in various full-text content (in roughly
      # the order given).  Those whose function has been identified have been
      # given appropriate styles in app/assets/stylesheets/virgo.css.scss under
      # the "article-full-text" CSS class.
      #
      #   <anid>      Article ID and other information.
      #   <jsection>  Journal section.
      #   <et>        Extended title?
      #   <title>     Article title (transformed into "<atitle>").
      #   <sbt>       Article subtitle or tagline.
      #   <hd>        Section heading.
      #   <hd1>       Sub-section heading.
      #   <img>       Image.
      #   <olist>     Ordered list (transformed into "<ol>").
      #   <ulist>     Unordered list (transformed into "<ul>").
      #   <item>      List item (transformed into "<li>").
      #   <blist>     Bibliography list.
      #   <bibtext>   Bibliography list entry.
      #   <ct>        Character table? (Essentially like a "<pre>" block.)
      #   <rj>        ?
      #   <aug>       By-line / responsibility section.
      #   <reflink>   Footnote reference (linkage through "idref" attribute).
      #   <bibl>      Footnote number (linkage through "idref" attribute).
      #   <nolink>    Empty tag with attributes indicating bad footnote links.
      #   <ref>       A "references" section that may enclose a bibliography.
      #
      FULL_TEXT_TAGS = %w(
        anid jsection atitle sbt aug
        hd hd1 img
        ol ul li
        ephtml table thead tbody tfoot col colgroup tr th td
        et ct rj
        reflink blist bibtext bibl ref
      ).deep_freeze

      # HTML element attributes allowed to make it through sanitization in
      # addition to UVA::Util::HtmlMethods#ALLOWED_ATTRS.
      #
      FULL_TEXT_ATTRS = {
        'atitle'  => %w(id),
        'hd'      => %w(id),
        'img'     => %w(src alt title),
        'table'   => %w(sortable),
        'col'     => %w(span),
        'th'      => %w(colspan rowspan scope),
        'td'      => %w(colspan rowspan align valign),
        'ct'      => %w(id),
        'reflink' => %w(id idref),
        'bibl'    => %w(id idref),
        'ref'     => %w(id),
      }.deep_freeze

      # Options to UVA::Util::HtmlMethods#sanitize_html.
      #
      FULL_TEXT_SANITIZE_OPTS = {
        elements:   FULL_TEXT_TAGS,
        attributes: FULL_TEXT_ATTRS,
        translate:  FULL_TEXT_TRANSLATIONS
      }.freeze

      # get_download_text
      #
      # @param [String] text
      #
      # @return [String]              New value for @download_text.
      # @return [nil]                 If there was no `full_text.text.value`.
      #
      # === Implementation Notes
      # Translates "XML" tags into HTML equivalents.
      #
      # === Examples
      # @example Typical (with <anid>, <title>, <sbt>, <hd>, <aug>)
      #   /articles/article?id=eft:527588351
      #
      # @example With <jsection>
      #   /articles/article?id=a9h:119405770
      #
      # @example With <ulist>, <hd1>, <ephtml>, <blist>, <bibtext>
      #   /articles/article?id=ehh:119126750
      #
      # @example With <olist>
      #   /articles/article?id=eft:527588340
      #
      # @example With <ct>
      #   /articles/article?id=edsgao:edsgcl.20494595
      #
      # @example With <img>
      #   /articles/article?id=f5h:32045913
      #
      # @example With <et>, <rj>
      #   /articles/article?id=f5h:118200455
      #
      def get_download_text(text = nil)
        text ||= full_text && full_text.text && full_text.text.value
        return if text.blank?

        # Special pre-processing to preserve newlines inside <ct> blocks.
        has_ct  = text.include?('<ct')
        newline = '@PRESERVED_NEWLINE@'
        if has_ct
          text =
            text.gsub(%r{<ct[^>]*>.*?</ct>}m) do
              ERB::Util.h(
                $&.to_s
                  .gsub(CRLF, newline)
                  .sub(%r{(<ct[^>]*?>)(#{newline})+}, '\1')
              )
            end
        end

        result = sanitize_html(text, FULL_TEXT_SANITIZE_OPTS)

        # Special post-processing to restore newlines inside <ct> blocks and to
        # eliminate line breaks that somehow crop up inside <ephtml> blocks.
        result.gsub!(newline, '<br/>') if has_ct
        if result.include?('<ephtml')
          result.gsub!(%r{<ephtml[^>]*>.*?</ephtml>}m) do
            $&.to_s.gsub(%r{<br */>}, '')
          end
        end
        result
      end

      # get_download_links
      #
      # @param [Array<DownloadLink>] link_array
      #
      # @return [Array<Link>]
      #
      def get_download_links(link_array = nil)
        link_array ||= full_text ? full_text.download_links : []
        link_array.map { |download_link|
          url  = download_link && download_link.url
          next if url.blank?
          text = download_link.format
          name = "<strong>Download</strong> in #{text} format".html_safe
          Link.new(url, text, name)
        }.compact
      end

      # get_online_links
      #
      # @param [Array<DownloadLink>] link_array
      #
      # @return [Array<Link>]
      #
      def get_online_links(link_array = nil)
        first_link  = nil
        link_array ||= []
        link_array += full_text.custom_links if full_text
        link_array += custom_links
        link_array.map { |custom_link|
          url  = custom_link && custom_link.url
          next if url.blank?
          text = strip_html(custom_link.text)
          name = strip_html(custom_link.name)
          icon = custom_link.icon_url
          link = Link.new(url, text, name, icon)
          # Ensure that the "Find@UVa" link is at the top of the list.
          if link.name =~ /Serials Solutions/
            first_link = link
            next
          end
          link
        }.unshift(first_link).compact
      end

    end

    # =========================================================================
    # :section: Messages
    # =========================================================================

    public

    # UVA::Article::Ebsco::Statistics
    #
    # @attr [String] totalHits
    #
    # Compare with:
    # @see UVA::Article::Primo::Counts
    # @see UVA::Article::Ebsco::Statistics
    #
    class Statistics

      include XML::Mapping

      text_node :totalHits, 'TotalHits', default_value: '0'

    end

    # UVA::Article::Ebsco::EbscoData
    #
    # @attr [Array<Document>] docs
    #
    class EbscoData

      include XML::Mapping

      array_node :docs, 'Records', 'Record', class: Document, default_value: []

    end

    # UVA::Article::Ebsco::SearchResult -- Top level nodes of EBSCO XML results.
    #
    # @attr [Statistics]   statistics
    # @attr [EbscoData]    data
    # @attr [Array<Facet>] facets
    #
    class SearchResult

      include XML::Mapping

      # rubocop:disable Metrics/LineLength

      object_node :statistics, 'Statistics',                        class: Statistics
      object_node :data,       'Data',                              class: EbscoData
      array_node  :facets,     'AvailableFacets', 'AvailableFacet', class: Facet, default_value: []

      # rubocop:enable Metrics/LineLength

    end

    # UVA::Article::Ebsco::SearchResponseMessage
    #
    # @attr [SearchResult] searchResults
    #
    class SearchResponseMessage

      include XML::Mapping

      object_node :searchResults, 'SearchResult', class: SearchResult

    end

    # UVA::Article::Ebsco::RetrieveResponseMessage
    #
    # @attr [Document] doc
    #
    class RetrieveResponseMessage

      include XML::Mapping

      object_node :doc, 'Record', class: Document, default_value: nil

    end

    # UVA::Article::Ebsco::APIErrorMessage
    #
    # @attr [String] detailed_error_description
    # @attr [String] error_description
    # @attr [Fixnum] error_number
    #
    class APIErrorMessage

      include XML::Mapping

      # rubocop:disable Metrics/LineLength

      text_node    :detailed_error_description, 'DetailedErrorDescription', default_value: ''
      text_node    :error_description,          'ErrorDescription',         default_value: ''
      numeric_node :error_number,               'ErrorNumber',              default_value: 0

      # rubocop:enable Metrics/LineLength

    end

    # =========================================================================
    # :section: Common article data classes
    # =========================================================================

    public

    # UVA::Article::Ebsco::Display
    #
    class Display < UVA::ArticleDoc::Display

      # Initialize a new self instance.
      #
      def initialize
        super
        @title = PLEASE_SIGN_IN
      end

    end

    # UVA::Article::Ebsco::AdditionalData
    #
    class AdditionalData < UVA::ArticleDoc::AdditionalData
    end

    # UVA::Article::Ebsco::Search
    #
    class Search < UVA::ArticleDoc::Search
    end

    # UVA::Article::Ebsco::Link
    #
    class Link < UVA::ArticleDoc::Link

      # @see UVA::ArticleDoc::Link#default_text
      #
      def default_text
        Ebsco.label
      end

    end

    # UVA::Article::Ebsco::Response -- response used by Virgo.
    #
    # EBSCO results are converted to this class for use by Virgo.
    #
    # Compare with:
    # @see UVA::Article::Primo::Response
    # @see UVA::Article::Ebsco::Response
    # @see UVA::Article::Summon::Response
    #
    class Response < UVA::ArticleDoc::Response

      # @return [Fixnum]
      attr_accessor :counts

      # @return [Array<Facet>]
      attr_accessor :facets

      # @return [Array<Document>]
      attr_accessor :docs

      # =======================================================================
      # :section:
      # =======================================================================

      public

      # Initialize a new self instance.
      #
      def initialize
        super(UVA::Article::EBSCO)
        @counts = 0
        @facets = []
        @docs   = []
      end

      # Wipe data and set an error code.
      #
      # @param [Fixnum] code
      #
      def reset(code = nil)
        super(code)
        @counts = 0
        @facets = []
        @docs   = []
      end

      # total
      #
      # (For Kaminari)
      #
      # @return [Fixnum]
      #
      def total
        @counts
      end

      # =======================================================================
      # :section: Class Methods
      # =======================================================================

      public

      class << self
        include UVA
      end

      # Currently, the only limiter we will use is the peer reviewed limiter
      # (RV).  And peer reviewed will always be one of the EBSCO 'facets'.
      #
      # @return [Array<Facet>]
      #
      # Identical to:
      # @see UVA::Article::Summon::Response#limiters
      #
      def self.limiters
        @limiters ||=
          begin
            new_facet_item = Item.new
            new_facet_item.value = 'peer_reviewed'
            new_facet_item.hits  = 1

            new_facet = Facet.new
            new_facet.name = 'tlevel'
            new_facet.items ||= []
            new_facet.items << new_facet_item

            [new_facet]
          end
      end

      # custom_parse
      #
      # @param [String] content
      # @param [Hash]   search_params
      #
      # @return [Response]
      #
      # Compare with:
      # @see UVA::Article::Primo::Response#custom_parse
      # @see UVA::Article::Ebsco::Response#custom_parse
      # @see UVA::Article::Summon::Response#custom_parse
      #
      def self.custom_parse(content, search_params)

        # Create the Response to fill in; error_code will be set to 0 if no
        # exception is raised.
        response = Response.new

        # XML parsing.
        content.force_encoding(Encoding.default_external)
        content = Unicode.nfc(content)
        xml     = REXML::Document.new(content).root
        parsed  = SearchResponseMessage.load_from_xml(xml)
        response.counts = parsed.searchResults.statistics.totalHits.to_i
        response.docs   = parsed.searchResults.data.docs

        # Capitalize the words in facet values that arrive in all lower case.
        response.facets =
          parsed.searchResults.facets.each do |facet|
            facet_name = facet && facet.name.to_s
            next if facet_name.blank? || (facet_name == 'tlevel')
            facet.items.each do |item|
              value = item && item.value
              titleize!(value) if value.present?
            end
          end

        # EBSCO changes the total returned number of results by de-duping while
        # paging, so we have to do a check and a fix-up here in case the user
        # has clicked on a page which EBSCO will lop off because they are going
        # to de-dupe and never return results for that page.
        #
        # If the page number indicated in the controller params is higher than
        # what could be referenced in the results returned (because of that
        # de-duping EBSCO does on the fly), then set the page number to the
        # last possible page for the returned results.
        response.per_page     = Response.per_page(search_params)
        response.current_page = Response.page(search_params)
        if (response.current_page * response.per_page) > response.total
          response.current_page = (response.total / response.per_page).ceil + 1
        end

        # Hacking this object to look like Solr responses.
        response.response = { 'numFound' => response.total }
        start_num = response.per_page * (response.current_page - 1)
        response.params = { start: start_num }

        # For EBSCO, the limiters will appear as 'facets' in our UI.
        response.facets += limiters

        # Now for each document/record of an article, set the remaining member
        # data from the info parsed from XML.
        response.docs.each(&:map_xml_to_fields)
        response.error_code = 0

      rescue SocketError, EOFError
        response.reset
        raise # Handled by ApplicationController

      rescue => e
        response.reset
        Ebsco.log_error(__method__, e, (parsed || xml || content))

      ensure
        return response

      end

    end

    # =========================================================================
    # :section: Module methods
    # =========================================================================

    public

    # @see UVA::Article::Engine#provider
    #
    def self.provider
      UVA::Article::EBSCO
    end

    # Start an EBSCO session.
    #
    # @see UVA::Article::Engine#start_session
    # @see self#open_session
    #
    def self.start_session(is_guest)
      session_token = open_session(is_guest)
      return if session_token.blank?
      { 'Accept' => 'application/xml', 'x-sessionToken' => session_token }
    end

    # Stop the current EBSCO session.
    #
    # @see UVA::Article::Engine#stop_session
    # @see self#close_session
    #
    def self.stop_session(current_headers)
      close_session(current_headers)
    end

    # =========================================================================
    # :section: Module methods
    # =========================================================================

    protected

    # Send a request to EBSCO.
    #
    # @param [String] path
    # @param [Hash]   headers
    # @param [Fixnum] timeout         Request timeout in seconds (default:
    #                                   self#REQUEST_TIMEOUT).  Disabled if
    #                                   given as *false* or *nil*.
    #
    # @raise [Timeout::Error]         If no reply was received.
    # @raise [RequestError]           If the reply was not `Net::HTTPSuccess`.
    # @raise [ResponseError]          If the reply was good but empty.
    # @raise [InternalError]          If *headers* had no session token.
    #
    # @return [Net::HTTPResponse]
    #
    def self.send_request(path, headers, timeout = nil)

      # As a convenience, the original session parameters are passed in then
      # the headers will be extracted from them.
      if headers.is_a?(Hash) && headers.key?(:headers)
        headers = headers[:headers]
      end
      raise InternalError, 'missing headers' unless headers
      if %w(createsession endsession).none? { |v| path.start_with?(v) }
        token = headers['x-sessionToken']
        raise InternalError, 'missing x-sessionToken' unless token
      end
      timeout = timeout.is_a?(TrueClass) ? REQUEST_TIMEOUT : timeout.to_i
      path = "#{EBSCO_EDS_PATH}/#{path}"
      Rails.logger.info { "ARTICLES - EBSCO request: #{path.inspect}" }

      http = Net::HTTP.new(URL::EBSCO_EDS_HOST)
      http.read_timeout = timeout unless timeout.zero?

      http.request_get(path, headers).tap do |resp|
        raise RequestError, resp unless resp.is_a?(Net::HTTPSuccess)
        raise ResponseError if resp.nil? || resp.body.blank?
      end
    end

    # EBSCO searches require a session token.
    #
    # @param [Boolean] as_guest
    #
    # @return [String]                The new EBSCO session token.
    # @return [nil]                   A token could not be acquired.
    #
    def self.open_session(as_guest)

      as_guest = as_guest ? 'y' : 'n'
      path     = "xxx"
      headers  = { 'Accept' => 'application/json' }

      http   = send_request(path, headers)
      result = json_parse(http.body)
      raise ParseError, http.body if result.blank?

      result['SessionToken']

    rescue SocketError, EOFError
      raise # Handled by ApplicationController

    rescue => e
      log_error(__method__, e)

    end

    # EBSCO sessions must be closed after being opened.
    #
    # @param [Hash] headers           From `params[:headers]`.
    #
    # @return [String]                Return from EBSCO in JSON format.
    # @return [nil]                   If there was a problem
    #
    def self.close_session(headers)

      # Get the session token from the current headers so that it
      # can be used to construct a JSON header for closing the session.
      session_token = headers && headers['x-sessionToken']
      raise InternalError, 'missing x-sessionToken' unless session_token
      path = 'endsession?sessiontoken=' + CGI.escape(session_token)
      headers = {
        'Accept'             => 'application/json',
        'SessionTokenHeader' => session_token
      }

      # Send to EBSCO and return the reply.
      send_request(path, headers).body

    rescue SocketError, EOFError
      raise # Handled by ApplicationController

    rescue => e
      log_error(__method__, e)

    end

    # =========================================================================
    # :section: Module methods - Search and access
    # =========================================================================

    public

    # Lookup a specific article using an article id composed of the database
    # identifier (DbId) and accession number (An) separated by a colon; e.g.:
    # "edsmzh:1993066095".
    #
    # @see UVA::Article::Engine#get_article_by_id
    #
    def self.get_article_by_id(article_id, search_params)
      request_by_dbid_an(article_id, search_params)
    end

    # Perform an article search via the article provider.
    #
    # @see UVA::Article::Engine#get_article_search_results
    #
    def self.get_article_search_results(search_params)

      # Make the request to EBSCO and process the response.
      response = Response.new
      query    = build_search_query(search_params)
      http     = send_request("search?#{query}", search_params)
      response = Response.custom_parse(http.body, search_params)

    rescue SocketError, EOFError
      response.reset
      raise # Handled by ApplicationController

    rescue => e
      response.reset
      log_error(__method__, e)

    ensure
      return response, (response.docs if response.ok?)

    end

    # Translate a search field name (as configured in ArticlesController)
    # into a facet value specific to the article provider.
    #
    # @param [String] name
    #
    # @return [String]
    #
    # @see UVA::Article::Engine#search_field
    #
    def self.search_field(name)
      SEARCH_FIELD_MAP[name] || DEFAULT_SEARCH_FIELD
    end

    # Translate a date into the form required for queries to the article
    # provider.
    #
    # @param [Array<String>] args     First argument is the original date; if
    #                                   a second is provided it is used as the
    #                                   month number which is appended if a
    #                                   month was not specified in the original
    #                                   date string.
    #
    # @return [String]
    #
    # @see UVA::Article::Engine#date_format
    #
    def self.date_format(*args)
      str   = args.shift.to_s.squeeze(' ').strip.tr(' -', '/')
      month = args.shift
      case month
        when :start then month = 1
        when :end   then month = 12
        else             month = 1
      end
      month = '%02d' % month                 if month.is_a?(Numeric)
      str.prepend(Date.today.strftime('%C')) if str =~ /^\d{2}$/
      str << "/#{month}"                     if str =~ /^\d{4}$/
      date = Date.parse(str)
      '%04d-%02d' % [date.year, date.month]
    rescue
      "0-#{month}"
    end

    # =========================================================================
    # :section: Module methods - Search and access
    # =========================================================================

    protected

    # Retrieves the detailed article info for the given article_id.
    #
    # The article_id consists of the article's database identifier (DbId) and
    # accession number (An) separated by a colon; e.g.: "edsmzh:1993066095".
    #
    # NOTE: Authentication with EBSCO and establishment of a session must
    # already have been completed and that info packaged in the headers
    # parameter to this method.
    #
    # @param [String, ArticleId] article_id
    # @param [Hash]              headers
    #
    # @return [Array<(Response, Document)>]
    # @return [Array<(Response, nil)>]
    #
    # Compare with:
    # @see UVA::Article::Primo#search_request
    # @see UVA::Article::Ebsco#request_by_dbid_an
    # @see UVA::Article::Summon#search_request
    #
    def self.request_by_dbid_an(article_id, headers)

      response = Response.new

      # Construct the request path to the EBSCO service.
      id   = ArticleId.new(article_id)
      path = "retrieve?dbid=#{id.dbid}&an=#{id.an}"

      # Make request to EBSCO and parse the response.
      http    = send_request(path, headers)
      content = http.body.force_encoding(Encoding.default_external)
      content = Unicode.nfc(content)
      xml     = REXML::Document.new(content).root
      parsed  = xml    && RetrieveResponseMessage.load_from_xml(xml)
      doc     = parsed && parsed.doc
      raise ParseError, (parsed || xml || content) if doc.blank?

      # Finalize the document.
      doc.map_xml_to_fields
      response.error_code = 0
      response.counts = 1
      response.docs = [doc]

    rescue SocketError, EOFError
      response.reset
      raise # Handled by ApplicationController

    rescue => e
      response.reset
      log_error(__method__, e)

    ensure
      return response, (doc if response.ok?)

    end

    # Construct query parameters for the request to the article provider.
    #
    # @param [Hash] search_params
    #
    # @return [String]
    #
    # Compare with:
    # @see UVA::Article::Primo#build_search_query
    # @see UVA::Article::Ebsco#build_search_query
    # @see UVA::Article::Summon#build_search_query
    #
    def self.build_search_query(search_params = {})
      if search_params[:EDS_direct]
        skip = [:controller, :action, :id, :catalog_select, :counter, :total]
        skip += [:q, :headers, :EDS_direct]
        search_params.except(*skip).reject { |_, v| v.blank? }.to_query
      else
        ParamParts.setup(search_params)
        [
          ParamParts.advanced_queries(search_params),
          ParamParts.query(search_params),
          ParamParts.fulltext(search_params),
          'searchmode=all',
          'view=detailed',
          'includefacets=y',
          ParamParts.get_paging(search_params),
          ParamParts.remove_highlighting(search_params),
          ParamParts.sort(search_params),
          ParamParts.facets_and_limiters(search_params),
        ].flatten.reject(&:blank?).join('&')
      end
    end

    # =========================================================================
    # :section: Module methods - Search and access
    # =========================================================================

    public

    # UVA::Article::Ebsco::ParamParts
    #
    # Methods for making EBSCO key-value pairs to build a search request URL.
    #
    # Compare with:
    # @see UVA::Article::Ebsco::ParamParts
    # @see UVA::Article::Summon::ParamParts
    #
    module ParamParts

      class << self
        include UVA::Helper::Facets
      end

      # Escape standard ASCII chars which are considered special by EBSCO:
      # NOTE: This is defunct (no longer used by #scrubbed_query).
      # QUERY_TRANSLATION_MAP = {
      #   '&' => '%26',
      #   ':' => '%5C%3A',
      #   ',' => '%5C%2C',
      #   # '(' => '%5C%28',
      #   # ')' => '%5C%29'
      # }.deep_freeze

      # =======================================================================
      # :section:
      # =======================================================================

      public

      # A copy of `session` extracted from search params which satisfies
      # Blacklight configuration interface methods called from this module.
      #
      # @return [Hash]
      #
      # @see self#setup
      #
      mattr_accessor :session

      # Copy of `params` extracted from search params which satisfies
      # Blacklight configuration interface methods called from this module.
      #
      # @return [Hash]
      #
      # @see self#setup
      #
      mattr_accessor :params

      # Initialize copies of `params` and `session` extracted from search
      # params for use within Blacklight configuration interface methods.
      #
      # @return [nil]
      #
      def self.setup(search_params = {})
        @@params  = search_params.delete(:params) || {}
        @@session = search_params.delete(:session) || {}
        nil
      end

      # Extract params[:q].
      #
      # @param [Hash] search_params
      #
      # @return [String]
      # @return [nil]
      #
      # Compare with:
      # @see UVA::Article::Primo#get_query
      # @see UVA::Article::Ebsco::ParamParts#query
      # @see UVA::Article::Summon::ParamParts#query
      #
      def self.query(search_params = {})
        query = search_params[:q]
        return if query.blank?
        search_field = Ebsco.search_field(search_params[:search_field].to_s)
        "query-1=AND,#{search_field}:#{scrubbed_query(query)}"
      end

      # EBSCO's filters for fulltext-only
      # also, do a fulltext search
      #
      # @param [Hash] _search_params  Currently unused.
      #
      # @return [String]
      #
      def self.fulltext(_search_params = nil)
        'expander=fulltext'
      end

      # Set the number of results per page.
      #
      # @param [Hash] search_params
      #
      # @return [String]
      #
      def self.per_page(search_params = {})
        "resultsperpage=#{Response.per_page(search_params)}"
      end

      # Set which page to get.
      #
      # @param [Hash] search_params
      #
      # @return [String]
      #
      def self.page(search_params = {})
        "pagenumber=#{Response.page(search_params)}"
      end

      # Extract start index and per page and make URL piece.
      #
      # @param [Hash] search_params
      #
      # @return [Array<String>]
      #
      # Compare with:
      # @see UVA::Article::Primo#get_paging
      # @see UVA::Article::Ebsco::ParamParts#get_paging
      # @see UVA::Article::Summon::ParamParts#get_paging
      #
      def self.get_paging(search_params = {})
        if search_params.key?(:index)
          my_per_page = 1
          my_page     = search_params[:index].to_i
        else
          my_per_page = Response.per_page(search_params)
          my_page     = Response.page(search_params)
        end
        return "resultsperpage=#{my_per_page}", "action-0=GoToPage(#{my_page})"
      end

      # Turn off highlighting.
      #
      # @param [Hash] _search_params  Currently unused.
      #
      # @return [String]
      #
      def self.remove_highlighting(_search_params = {})
        'highlight=n'
      end

      # Add facets and limiters.
      #
      # @param [Hash] search_params
      #
      # @return [Array<String>]
      #
      # Compare with:
      # @see UVA::Article::Primo#get_facets
      # @see UVA::Article::Ebsco::ParamParts#facets_and_limiters
      # @see UVA::Article::Summon::ParamParts#facets_and_filters
      #
      def self.facets_and_limiters(search_params = {})
        index = -1
        result =
          Array(search_params[:f]).flat_map do |facet_field, values|
            Array(values).map do |value|
              next if value.blank?
              if facet_field.to_sym == :tlevel
                'limiter=RV:Y'
              else
                index += 1
                value = scrubbed_query(value, true)
                "facetfilter=#{index},#{facet_field}:#{value}"
              end
            end
          end
        result +=
          Array(search_params[:f_inclusive]).flat_map do |facet_field, values|
            next unless values.present?
            index += 1
            values.keys.map do |value|
              next if value.blank?
              value = scrubbed_query(value, true)
              "facetfilter=#{index},#{facet_field}:#{value}"
            end
          end
        result.compact
      end

      # Get sort
      #
      # @param [Hash] search_params
      #
      # @return [Array<String>]
      #
      # Compare with:
      # @see UVA::Article::Primo#get_sort
      # @see UVA::Article::Ebsco::ParamParts#sort
      # @see UVA::Article::Summon::ParamParts#sort
      #
      def self.sort(search_params = {})
        result = []
        sort =
          if (sort_key = get_current_sort_key(search_params)).present?
            sort_fields_config(ArticlesController).find do |value, entry|
              break value if sort_key == entry.sort_key
            end
          end
        result << "sort=#{sort}" if sort.present?
        result
      end

      # Extract populated advanced search fields and make URL pieces.
      #
      # @param [Hash] search_params
      #
      # @return [Array<String>]
      #
      # Compare with:
      # @see UVA::Article::Primo#get_advanced_search_queries
      # @see UVA::Article::Ebsco::ParamParts#advanced_queries
      # @see UVA::Article::Summon::ParamParts#advanced_queries
      #
      def self.advanced_queries(search_params = {})
        index = 1
        advanced_search_fields.map { |key, field_def|
          field = Ebsco.search_field(key.to_s)
          if true_value?(field_def.range)
            # We are going to make the assumption here that this is the
            # 'published in' range which is the DT1 limiter in EBSCO and must
            # be formatted like this:  YYYY-MM/YYYY-MM.
            #
            # Since we do not permit entry of month, we must package the year
            # range like this for the EBSCO EDS API:  YYYY-01/YYYY-12
            # This is a safe assumption as long as the articles_controller.rb
            # Blacklight definitions of config.add_search_field only contain
            # one definition with field.range = 'true'.
            value = range_value(key, search_params)
            start_date = value[:start]
            end_date   = value[:end]
            if start_date.present? || end_date.present?
              start_date = Ebsco.date_format(start_date, 1)
              end_date   = Ebsco.date_format(end_date, 12)
              "limiter=#{field}:#{start_date}/#{end_date}"
            end
          else
            value = search_params[key.to_sym]
            # Add a query term.
            if value.present?
              index += 1
              "query-#{index}=AND,#{field}:#{scrubbed_query(value)}"
            end
          end
        }.reject(&:blank?)
      end

      # =======================================================================
      # :section:
      # =======================================================================

      protected

      # scrubbed_query
      #
      # @param [String]  query
      # @param [Boolean] facet        If *true* then prefix only ':' and ','
      #                                 with a backslash; otherwise, also
      #                                 prefix '(' and ')' with a backslash.
      #
      # @return [String]
      #
      # Compare with:
      # @see UVA::Article::Primo#scrubbed_query
      # @see UVA::Article::Ebsco::ParamParts#scrubbed_query
      # @see UVA::Article::Summon::ParamParts#scrubbed_query
      #
      def self.scrubbed_query(query, facet = nil)
        characters_to_escape = facet ? /[:,]/ : /[:,()]/
        query = query.gsub(characters_to_escape, '\\\\\&')
        CGI.escape(query)
      end

    end

    # =========================================================================
    # :section: Logging
    # =========================================================================

    protected

    # No need to get detailed information about session tokens.
    #
    # @param [Net::HTTPResponse] http_response
    #
    # @return [Boolean]
    #
    # @see UVA::Article::Engine#ignorable_error
    #
    def self.ignorable_error(http_response)
      http_response.is_a?(Net::HTTPBadRequest) &&
      (ebsco_error(http_response) == 109) # Session Token Invalid
    end

    # Extract the EBSCO error number from the response message.
    #
    # @param [Net::HTTPResponse] http_response
    #
    # @return [Fixnum]
    # @return [nil]
    #
    def self.ebsco_error(http_response)
      case http_response.header['content-type']
        when /json/
          hash = json_parse(http_response.body, raise: true)
          hash['ErrorNumber'].to_i
        when /xml/
          xml = REXML::Document.new(http_response.body).root
          msg = APIErrorMessage.load_from_xml(xml)
          msg.error_number
      end
    rescue JSON::JSONError => e
      Rails.logger.debug { "#{__method__}: JSON parsing: #{e.message}" }
      nil
    rescue REXML::ParseException, REXML::Validation::ValidationException => e
      Rails.logger.debug { "#{__method__}: REXML parsing: #{e} #{e.message}" }
      nil
    rescue => e
      Rails.logger.warn {
        bar = '-------------------------------------------------------------'
        "#{__method__}: " \
          'unexpected exception parsing HTTPBadRequest payload: ' \
          "#{e}: #{e.message}\n" \
          "#{bar}\n#{http_response.body}\n#{bar}"
      }
      nil
    end

  end

end
