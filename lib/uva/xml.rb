# lib/uva/xml.rb

require 'uva'

module UVA

  module Xml

    include UVA

    # =========================================================================
    # :section:
    # =========================================================================

    public

    # Express current item as XML.
    #
    # @param [Hash, nil] opt          Options; @see Hash#to_xml.
    #
    # @return [String]
    #
    # == Usage Notes
    # This definition will be incorporated only if the including class does not
    # already have a :to_xml method.
    #
    def to_xml(opt = nil)
      opt ||= {}
      if !respond_to?(:save_to_xml)
        opt[:root] ||= self.class.name.demodulize.underscore
        as_xml(instance_values).to_xml(opt)
      elsif opt[:indent].to_i.nonzero?
        s = ''; REXML::Formatters::Pretty.new.write(save_to_xml, s); s
      else
        save_to_xml
      end
    end unless defined?(:to_xml)

    # Recursively prepare the hierarchy of values to report via XML.
    #
    # @param [Object] obj
    #
    # @param [Object]
    #
    def as_xml(obj)
      case obj
        when nil
          {}
        when ActiveSupport::SafeBuffer
          strip_html(obj)
        when Numeric, String, Symbol, Range, TrueClass, FalseClass
          obj
        when Array
          obj.map { |v| as_xml(v) if xml_ok?(v) }.compact
        when Hash
          obj.map { |k, v| [k, as_xml(v)] if xml_ok?(v) }.compact.to_h
        else
          if obj.respond_to?(:to_xml)
            obj.to_xml
          else
            as_xml(obj.instance_values)
          end
      end
    end

    # Skip elements that are empty or missing.
    #
    # @param [Object] value
    #
    def xml_ok?(value)
      (value.present? || value.is_a?(FalseClass)) && (value != self)
    end

    # Insert XML for the object in a XML builder template.
    #
    # @param [Builder::XmlMarkup] xml
    # @param [Object]             obj
    # @param [Hash, nil]          opt   Options; @see Hash#to_xml.
    #
    # @return [void]
    #
    def xml_builder(xml, obj, opt = nil)
      opt ||= {}
      case obj
        when nil
          nil
        when Numeric, String, Symbol, Range, TrueClass, FalseClass
          key = :value
          opt = { root: key }.merge(opt)
          xml_builder(xml, { key => obj }, opt)
        when Array
          obj.each do |v|
            xml.tag!(:item, as_xml(v))
          end
        when Hash
          obj.each_pair do |k, v|
            k = k.to_s.squish.tr(' ', '_')
            k = k.camelize unless k == k.upcase
            xml.tag!(k, as_xml(v))
          end
        else
          xml_builder(xml, as_xml(obj), opt)
      end
    end

  end

end
