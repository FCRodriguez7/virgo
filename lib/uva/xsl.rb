# lib/uva/xsl.rb

require 'nokogiri'
require 'uva'

module UVA

  module Xsl

    include UVA

    # =========================================================================
    # :section:
    # =========================================================================

    public

    # Transform used the indicated template to transform the given XML.
    #
    # @param [Symbol, String] type
    # @param [String]         xml
    #
    # @return [String]
    # @return [nil]
    #
    def apply_xslt(type, xml)
      Xsl.apply_xslt(type, xml)
    end

    # =========================================================================
    # :section: Module methods
    # =========================================================================

    public

    # Transform used the indicated template to transform the given XML.
    #
    # @param [Symbol, String] type
    # @param [String]         xml
    #
    # @return [String]
    # @return [nil]
    #
    def self.apply_xslt(type, xml)
      template = Xsl.transform(type)
      template.apply_to(Nokogiri::XML(xml)) if xml && template
    end

    # Return the XSLT object.
    #
    # @param [Symbol, String, IO] type
    #
    # @return [Nokogiri::XSLT]
    #
    # @raise [SystemCallError]        If there was a problem with the file.
    #
    def self.transform(type)
      @transform ||= {}
      @transform[type] ||=
        begin
          type =
            type.name.underscore.split('/').last.to_sym if type.is_a?(Module)
          file = type.is_a?(Symbol) ? "lib/uva/xsl/#{type}.xsl" : type
          source = file.is_a?(IO) ? file.read : File.read(file)
          Nokogiri::XSLT(source) if source.present?
        end
    end

  end

end
