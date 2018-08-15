# lib/uva/illiad/openurl_fix.rb

require 'openurl'

module OpenURL # :nodoc:

  # Extend OpenURL::ContextObject to support properly constructing serviceType
  # objects so that OpenURL::ContextObject.get_entity_obj('service-type')
  # generates a ScholarlyServiceType object instead of a ContextObjectEntity.
  #
  class ContextObject # :nodoc:

    # get_entity_obj
    #
    # @param [String] abbr
    #
    # @return [OpenURL::ContextObjectEntity]
    #
    def get_entity_obj(abbr)
      case (ivar_name = @@defined_entities[abbr])
        when nil
          nil
        when 'service-type'
          @serviceType << ScholarlyServiceType.new if @serviceType.empty?
          @serviceType.first
        when 'resolver'
          @resolver << ContextObjectEntity.new if @resolver.empty?
          @resolver.first
        when 'referring-entity'
          instance_variable_get('@referringEntity')
        else
          instance_variable_get("@#{ivar_name}")
      end
    end

  end

end
