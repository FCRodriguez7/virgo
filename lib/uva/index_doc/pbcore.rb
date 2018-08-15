# lib/uva/index_doc/pbcore.rb

require 'uva'

module UVA

  # Public Broadcasting Metadata Dictionary (PBCore)
  #
  # @see http://pbcore.org
  #
  module PBCore

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
  # :section: PBCore parsing
  # ===========================================================================

  public

  module PBCore::Xml

    require 'xml/mapping'

    include UVA

    # Base class for PBCore XML elements.
    #
    class Element
    end

    # UVA::PBCore::Xml::Instantiation
    #
    # @attr [String] location
    # @attr [String] duration
    # @attr [String] color
    # @attr [String] annotation
    #
    class Instantiation < Element

      include XML::Mapping
      include UVA

      text_node :location,   'instantiationLocation',   default_value: nil
      text_node :duration,   'instantiationDuration',   default_value: nil
      text_node :color,      'instantiationColors',     default_value: nil
      text_node :annotation, 'instantiationAnnotation', default_value: nil

      # =======================================================================
      # :section:
      # =======================================================================

      public

      # pretty_print_duration
      #
      # @return [String]
      #
      def pretty_print_duration
        return if duration.nil?
        split = duration.split(':')
        if split.size == 2
          min, sec = split
          if min.to_i.zero?
            "#{sec} seconds"
          else
            "#{min} min., #{sec} sec."
          end
        else
          duration
        end
      end
    end

    # UVA::PBCore::Xml::DescriptionDocument
    #
    # @attr [String] date
    # @attr [String] identifier
    # @attr [String] title
    # @attr [String] abstract
    #
    # @attr [Array]  topic
    # @attr [Array]  place
    # @attr [Array]  entity
    #
    # @attr [Instantiation] instantiation
    #
    class DescriptionDocument < Element

      include XML::Mapping
      include UVA

      #--
      # rubocop:disable Metrics/LineLength
      #++

      text_node :date,       'pbcoreAssetDate',   default_value: nil
      text_node :identifier, 'pbcoreIdentifier',  default_value: nil
      text_node :title,      'pbcoreTitle',       default_value: ''
      text_node :abstract,   'pbcoreDescription', default_value: nil

      array_node :topic,  "pbcoreSubject[@subjectType='Topic']",  class: String, default_value: []
      array_node :place,  "pbcoreSubject[@subjectType='Place']",  class: String, default_value: []
      array_node :entity, "pbcoreSubject[@subjectType='Entity']", class: String, default_value: []

      object_node :instantiation, 'pbcoreInstantiation', class: Instantiation, default_value: nil

      #--
      # rubocop:enable Metrics/LineLength
      #++

    end

    # =========================================================================
    # :section:
    # =========================================================================

    public

    # parse_pbcore
    #
    # @param [String] xml
    #
    # @return [DescriptionDocument]
    #
    def parse_pbcore(xml)
      DescriptionDocument.load_from_xml(REXML::Document.new(xml).root)
    end

  end

  # ===========================================================================
  # :section: PBCore IndexDoc extension
  # ===========================================================================

  public

  module PBCore::Interface

    include UVA

    # =========================================================================
    # :section: Document properties
    # =========================================================================

    public

    # Get the URL for the PBCore document source.
    #
    # @return [String]
    # @return [nil]
    #
    def pbcore_display(*)
    end

    # =========================================================================
    # :section: Document methods
    # =========================================================================

    public

    # Indicate whether the current document has PBCore data.
    #
    def is_pbcore?(*)
      UVA::PBCore::Extension::SOLR_FIELDS.any? { |field| has?(field) }
    end

    # Get the PBCore object associated with the document.
    #
    # @return [UVA::PBCore::Xml::DescriptionDocument]
    # @return [nil]                   If *doc* did not have PBCore data.
    #
    def pbcore(*)
    end

  end

  # ===========================================================================
  # :section: PBCore Blacklight (SolrDocument) extension
  # ===========================================================================

  public

  module PBCore::Extension

    include UVA
    include UVA::PBCore::Interface
    include UVA::PBCore::Xml

    # Solr fields associated with this content type.
    SOLR_FIELDS = [
      :pbcore_display,
    ]

    # =========================================================================
    # :section: Document properties
    # =========================================================================

    public

    # @see Interface#pbcore_display
    #
    def pbcore_display
      values_for(:pbcore_display).first
    end

    # =========================================================================
    # :section: Document methods
    # =========================================================================

    public

    # @see Interface#is_pbcore?
    #
    def is_pbcore?(*)
      true
    end

    # @see Interface#pbcore
    #
    def pbcore
      parse_pbcore(pbcore_display)
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
      Rails.logger.debug { "#{base}: included extension UVA::PBCore" }
      [Xml].each do |mod|
        base.send(:include, mod) unless base.include?(mod)
      end
    end

  end

end
