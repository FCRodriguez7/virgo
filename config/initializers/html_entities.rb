# config/initializers/html_entities.rb
#
# Any characters that are not included in htmlentities/mappings/expanded.rb
# can be included here, which will inject them into the feature so that
#
#   HTMLEntities.new.decode(string)
#
# will convert them into the indicated UTF-8 character value.
#
# === References
# https://dev.w3.org/html5/html-author/charref


require 'htmlentities'

class HTMLEntities

  unless defined?(LOCAL_MAPPING_EXTENSIONS)

    LOCAL_MAPPING_EXTENSIONS = {
      'ctdot' => 0x22ef,
    }

    MAPPINGS['expanded'].merge!(LOCAL_MAPPING_EXTENSIONS)

  end

end

class HTMLEntities

  class Decoder #:nodoc:
    def initialize(flavor)
      @flavor = flavor
      @map = HTMLEntities::MAPPINGS[@flavor]
      @entity_regexp = entity_regexp
    end
  end

  def decode(source)
    (@decoder ||= Decoder.new(@flavor)).decode(source)
  end

end
