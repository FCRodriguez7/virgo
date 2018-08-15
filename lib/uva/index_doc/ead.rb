# lib/uva/index_doc/ead.rb

require 'uva'

module UVA

  # Encoded Archival Description (EAD).
  #
  # @see https://www.loc.gov/ead
  #
  module Ead

    # Actions taken when this module is included.
    #
    # @param [Module] base            The including module or class.
    #
    # @return [void]
    #
    def self.included(base) # :nodoc:
      [Interface].each do |mod|
        base.send(:include, mod) unless base.include?(mod)
      end
    end

  end

  # ===========================================================================
  # :section: EAD parsing
  # ===========================================================================

  public

  module Ead::Xml

    require 'xml/mapping'

    include UVA

    # Base class for EAD XML elements.
    #
    class Element
    end

    # Common methods for Component and Collection.
    #
    module Container

      # p_count
      #
      # @return [Fixnum]
      #
      def p_count
        if scope_content.blank? || scope_content.p.blank?
          0
        else
          scope_content.p_count
        end
      end

    end

    # =========================================================================
    # :section: Components
    # =========================================================================

    public

    # UVA::Ead::Xml::NamedValue
    #
    # @attr [String] head
    # @attr [String] value
    #
    class NamedValue < Element

      include XML::Mapping
      include UVA

      text_node :head,  'head',  default_value: ''
      text_node :value, 'value', default_value: ''

    end

    # UVA::Ead::Xml::Section
    #
    # @attr [String] head
    # @attr [Array<NamedValue>] fields
    #
    class Section < Element

      include XML::Mapping
      include UVA

      text_node  :head,   'head',  default_value: 'Administrative Information'
      array_node :fields, 'field', class: NamedValue, default_value: nil

    end

    # UVA::Ead::Xml::MultiParagraphTextSection
    #
    # @attr [Fixnum] p_count
    # @attr [String] head
    # @attr [Array<String>] p
    #
    class MultiParagraphTextSection < Element

      include XML::Mapping
      include UVA

      numeric_node :p_count, 'p_count', default_value: 0
      text_node    :head,    'head',    default_value: ''
      array_node   :p,       'p',       class: String, default_value: []

    end

    # UVA::Ead::Xml::Component
    #
    # @attr [String] component_id
    # @attr [String] component_type
    # @attr [String] type
    # @attr [String] head
    # @attr [String] unit_title
    # @attr [String] short_unit_title
    # @attr [MultiParagraphTextSection] scope_content
    # @attr [Fixnum] component_count
    # @attr [Array<Component>] components
    #
    class Component < Element

      include XML::Mapping
      include UVA
      include Container

      #--
      # rubocop:disable Metrics/LineLength
      #++

      text_node    :component_id,     'id',               default_value: ''
      text_node    :component_type,   'type',             default_value: ''
      text_node    :type,             'type',             default_value: ''
      text_node    :head,             'head',             default_value: ''
      text_node    :unit_title,       'unittitle',        default_value: '[untitled]'
      text_node    :short_unit_title, 'shortunittitle',   default_value: '[untitled]'
      object_node  :scope_content,    'scopecontent',     class: MultiParagraphTextSection, default_value: nil
      numeric_node :component_count,  'component_count',  default_value: 0
      array_node   :components,       'component',        class: Component, default_value: []

      #--
      # rubocop:enable Metrics/LineLength
      #++

      # Combine head and unit title.
      #
      # @return [String]
      #
      def head_unit_title
        result = ''
        result << "#{head} : " if head.present?
        result << (unit_title || 'Untitled')
      end

      # Pluralize the component type.
      #
      # @return [String]
      #
      def types
        component_type.pluralize
      end

    end

    # UVA::Ead::Xml::Collection
    #
    # @attr [String] title
    # @attr [String] short_title
    # @attr [Section] summary
    # @attr [Section] admin_info
    # @attr [MultiParagraphTextSection] biog_hist
    # @attr [MultiParagraphTextSection] scope_content
    # @attr [Fixnum] component_count
    # @attr [Array<Component>] components
    #
    class Collection < Element

      include XML::Mapping
      include UVA
      include Container

      #--
      # rubocop:disable Metrics/LineLength
      #++

      text_node    :title,           'title',           default_value: ''
      text_node    :short_title,     'shorttitle',      default_value: ''
      object_node  :summary,         'descsummary',     class: Section, default_value: nil
      object_node  :admin_info,      'admininfo',       class: Section, default_value: nil
      object_node  :biog_hist,       'bioghist',        class: MultiParagraphTextSection, default_value: nil
      object_node  :scope_content,   'scopecontent',    class: MultiParagraphTextSection, default_value: nil
      numeric_node :component_count, 'component_count', default_value: 0
      array_node   :components,      'component',       class: Component, default_value: []

      #--
      # rubocop:enable Metrics/LineLength
      #++

    end

    # UVA::Ead::Xml::Ancestor
    #
    # @attr [String] ancestor_id
    # @attr [String] title
    #
    class Ancestor < Element

      include XML::Mapping
      include UVA

      text_node :ancestor_id, 'id'
      text_node :title,       'title'

    end

    # UVA::Ead::Xml::Breadcrumbs
    #
    # @attr [Array<Ancestor>] ancestors
    #
    class Breadcrumbs < Element

      include XML::Mapping
      include UVA

      array_node :ancestors, 'ancestor', class: Ancestor, default_value: []

      # contains_ancestor_with_id?
      #
      # @param [String] id
      #
      def has_ancestor?(id)
        ancestors.find { |x| x.ancestor_id == id }
      end

    end

    # UVA::Ead::Xml::MarcRecord
    #
    # @attr [String] catalog_key
    # @attr [Array<String>] barcodes
    #
    class MarcRecord < Element

      include XML::Mapping
      include UVA

      text_node  :catalog_key, 'catalogKey', default_value: ''
      array_node :barcodes,    'barcode',    class: String, default_value: []

      # Sirsi catalog item number.
      #
      # @return [String]
      #
      def ckey
        "u#{catalog_key}"
      end

    end

    # UVA::Ead::Xml::Records
    #
    # @attr [Array<MarcRecord>] marc_records
    #
    class Records < Element

      include XML::Mapping
      include UVA

      array_node :marc_records, 'marc', class: MarcRecord, default_value: []

    end

    # =========================================================================
    # :section:
    # =========================================================================

    public

    # component_types
    #
    # @param [Array<Component>] components
    #
    # @return [String]
    #
    def component_types(components)
      components.map(&:types).uniq.join('/')
    end

    # parse_breadcrumbs
    #
    # @param [REXML::Document, String, IO] breadcrumbs
    #
    # @return [Breadcrumbs]
    # @return [nil]                   If argument was blank.
    #
    # @raise [REXML::ParseException]
    # @raise [REXML::Validation::ValidationException]
    #
    def parse_breadcrumbs(breadcrumbs)
      return if breadcrumbs.blank?
      Breadcrumbs.load_from_xml(REXML::Document.new(breadcrumbs).root)
    rescue => e
      Rails.logger.debug { "#{__method__}: #{e}: #{e.message}" }
      raise e
    end

    # parse_collection
    #
    # @param [REXML::Document, String, IO] collection
    #
    # @return [Collection]
    # @return [nil]                   If argument was blank.
    #
    # @raise [REXML::ParseException]
    # @raise [REXML::Validation::ValidationException]
    #
    def parse_collection(collection)
      return if collection.blank?
      Collection.load_from_xml(REXML::Document.new(collection).root)
    end

    # parse_component
    #
    # @param [REXML::Document, String, IO] series
    #
    # @return [Component]
    # @return [nil]                   If argument was blank.
    #
    # @raise [REXML::ParseException]
    # @raise [REXML::Validation::ValidationException]
    #
    def parse_component(series)
      return if series.blank?
      Component.load_from_xml(REXML::Document.new(series).root)
    end

    # parse_description
    #
    # @param [REXML::Document, String, IO] desc
    #
    # @return [MultiParagraphTextSection]
    # @return [nil]                   If argument was blank.
    #
    # @raise [REXML::ParseException]
    # @raise [REXML::Validation::ValidationException]
    #
    def parse_description(desc)
      return if desc.blank?
      MultiParagraphTextSection.load_from_xml(REXML::Document.new(desc).root)
    end

    # parse_barcodes
    #
    # @param [REXML::Document, String, IO] container
    #
    # @return [Records]
    # @return [nil]                   If argument was blank.
    #
    # @raise [REXML::ParseException]
    # @raise [REXML::Validation::ValidationException]
    #
    def parse_barcodes(container)
      return if container.blank?
      Records.load_from_xml(REXML::Document.new(container).root)
    end

    # Parse XML to generate an EAD.
    #
    # @param [String] xml
    #
    # @return [ActiveSupport::SafeBuffer]
    # @return [nil]                   If *doc* did not have EAD data.
    #
    def parse_ead(xml)
      Xsl.apply_xslt(:ead, xml)
    end

  end

  # ===========================================================================
  # :section: EAD IndexDoc extension
  # ===========================================================================

  public

  module Ead::Interface

    include UVA

    # =========================================================================
    # :section: Document properties
    # =========================================================================

    public

    # Get the XML for the raw EAD.
    #
    # @return [String]
    # @return [nil]
    #
    def raw_ead_display(*)
    end

    # Get the XML for the breadcrumbs.
    #
    # @return [String]
    # @return [nil]
    #
    def breadcrumbs_display(*)
    end

    # Get the XML for the hierarchy.
    #
    # @return [String]
    # @return [nil]
    #
    def hierarchy_display(*)
    end

    # Get the XML for the scope content.
    #
    # @return [String]
    # @return [nil]
    #
    def scope_content_display(*)
    end

    # Get the XML for the hierarchy level.
    #
    # @return [Array<String>]
    #
    def hierarchy_levels(*)
      []
    end

    # =========================================================================
    # :section: Document methods
    # =========================================================================

    public

    # Indicate whether the current document has EAD data.
    #
    def is_ead?(*)
      UVA::Ead::Extension::SOLR_FIELDS.any? { |field| has?(field) }
    end

    # is_collection?
    #
    def is_collection?(*)
      hierarchy_levels.include?('collection')
    end

    # has_collection_nav?
    #
    def has_collection_nav?(*)
      breadcrumbs_display.present?
    end

    # =========================================================================
    # :section: Document values
    # =========================================================================

    public

    # Extract the breadcrumbs object.
    #
    # @return [Breadcrumbs]
    # @return [nil]
    #
    def breadcrumbs(*)
    end

    # Extract the ancestor object(s).
    #
    # @return [Array<Ancestor>]
    #
    def ancestors(*)
      []
    end

    # The collection id for the EAD component.
    #
    # @return [String]
    # @return [nil]
    #
    def ead_collection_id(*)
    end

    # The EAD component object.
    #
    # @return [Collection]
    # @return [Component]
    # @return [nil]
    #
    def ead_component(*)
    end

    # Get the EAD content associated with the document.
    #
    # @return [ActiveSupport::SafeBuffer]
    # @return [nil]                   If *doc* did not have EAD data.
    #
    def ead(*)
    end

  end

  # ===========================================================================
  # :section: EAD Blacklight (SolrDocument) extension
  # ===========================================================================

  public

  module Ead::Extension

    include UVA
    include UVA::Ead::Interface
    include UVA::Ead::Xml

    # Solr fields associated with this content type.
    SOLR_FIELDS = [
      :raw_ead_display,
      :breadcrumbs_display,
      :hierarchy_display,
      :full_hierarchy_display,
      :scope_content_display,
      :hierarchy_level_display,
    ]

    # =========================================================================
    # :section: Document properties
    # =========================================================================

    public

    # @see Interface#raw_ead_display
    #
    def raw_ead_display
      values_for(:raw_ead_display).first
    end

    # @see Interface#breadcrumbs_display
    #
    def breadcrumbs_display
      values_for(:breadcrumbs_display).first
    end

    # @see Interface#hierarchy_display
    #
    def hierarchy_display
      values_for(:hierarchy_display).first
    end

    # @see Interface#scope_content_display
    #
    def scope_content_display
      values_for(:scope_content_display).first
    end

    # @see Interface#hierarchy_levels
    #
    def hierarchy_levels
      values_for(:hierarchy_level_display)
    end

    # =========================================================================
    # :section: Document methods
    # =========================================================================

    public

    # @see Interface#is_ead?
    #
    def is_ead?
      true
    end

    # =========================================================================
    # :section: Document values
    # =========================================================================

    public

    # @see Interface#breadcrumbs
    #
    def breadcrumbs
      parse_breadcrumbs(breadcrumbs_display)
    end

    # @see Interface#ancestors
    #
    def ancestors
      (b = breadcrumbs) ? b.ancestors : []
    end

    # @see Interface#ead_collection_id
    #
    def ead_collection_id
      if is_collection?
        doc_id
      elsif (parent = ancestors.first)
        parent.ancestor_id
      end
    end

    # @see Interface#ead_component
    #
    # @param [Symbol] switch          One of :self or :collection; if *nil* or
    #                                   missing, :collection is assumed if
    #                                   applicable.
    #
    def ead_component(switch = nil)
      if (switch == :self) || !is_collection?
        parse_component(hierarchy_display)
      else
        parse_collection(hierarchy_display)
      end
    end

    # @see Interface#ead
    #
    def ead
      parse_ead(raw_ead_display).html_safe
    rescue SocketError, EOFError
      raise # Handled by ApplicationController
    rescue => e
      Rails.logger.debug { "#{__method__}: #{e}: #{e.message}" }
      '<div>EAD inaccessible.</div>'.html_safe
    end

    # =========================================================================
    # :section: Module methods
    # =========================================================================

    public

    # Actions taken when this module is included.
    #
    # @param [Module] base            The including module or class.
    #
    # @return [void]
    #
    def self.included(base) # :nodoc:
      Rails.logger.debug { "#{base}: included extension UVA::Ead" }
      [Xml].each do |mod|
        base.send(:include, mod) unless base.include?(mod)
      end
    end

  end

end
