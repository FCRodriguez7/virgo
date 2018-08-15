# lib/uva/index_doc/tei.rb

require 'uva'

module UVA

  # Text Encoding Initiative (TEI).
  #
  # @see https://www.tei-c.org
  #
  module Tei

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
  # :section: TEI parsing
  # ===========================================================================

  public

  module Tei::Xml

    include UVA
    include UVA::Xsl

    # Parse XML to render the TEI in HTML format.
    #
    # @param [String] xml
    #
    # @return [String]
    # @return [nil]                   If *doc* did not have TEI data.
    #
    def parse_tei(xml)
      Xsl.apply_xslt(:tei, xml)
    end

  end

  # ===========================================================================
  # :section: TEI IndexDoc extension
  # ===========================================================================

  public

  module Tei::Interface

    include UVA

    # =========================================================================
    # :section: Document properties
    # =========================================================================

    public

    # Get the URL for the TEI document source.
    #
    # @return [String]
    # @return [nil]
    #
    def tei_url_display(*)
    end

    # =========================================================================
    # :section: Document methods
    # =========================================================================

    public

    # Indicate whether the current document has TEI data.
    #
    def is_tei?(*)
      UVA::Tei::Extension::SOLR_FIELDS.any? { |field| has?(field) }
    end

    # Get the TEI content associated with the document.
    #
    # @return [ActiveSupport::SafeBuffer]
    # @return [nil]                   If *doc* did not have TEI data.
    #
    def tei(*)
    end

  end

  # ===========================================================================
  # :section: TEI Blacklight (SolrDocument) extension
  # ===========================================================================

  public

  module Tei::Extension

    include UVA
    include UVA::Tei::Interface
    include UVA::Tei::Xml

    # Solr fields associated with this content type.
    SOLR_FIELDS = [
      :tei_url_display,
    ]

    # =========================================================================
    # :section: Document properties
    # =========================================================================

    public

    # @see Interface#tei_url_display
    #
    def tei_url_display
      values_for(:tei_url_display).first
    end

    # =========================================================================
    # :section: Document methods
    # =========================================================================

    public

    # @see Interface#is_tei?
    #
    def is_tei?
      true
    end

    # @see Interface#tei_url_display
    #
    # @raise [URI::InvalidURIError]
    #
    def tei
      url = tei_url_display
      return if url.blank?
      uri = URI.parse(url)
      xml = uri.read
      parse_tei(xml).html_safe
    rescue SocketError, EOFError
      raise # Handled by ApplicationController
    rescue => e
      Rails.logger.debug { "#{__method__}: #{e}: #{e.message}" }
      '<div>TEI inaccessible.</div>'.html_safe
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
      Rails.logger.debug { "#{base}: included extension UVA::Tei" }
    end

  end

end
