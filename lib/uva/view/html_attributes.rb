# lib/uva/view/html_attributes.rb

require 'uva'

module UVA::View

  # This class is derived from Hash to support treating the key-value pairs as
  # as HTML element attributes (e.g. "class") and their values.
  #
  # Values are maintained as arrays of strings so that it is easy to avoid
  # duplication of individual values.
  #
  class HtmlAttributes < Hash

    include UVA

    # =========================================================================
    # :section:
    # =========================================================================

    public

    # Initialize a new self instance.
    #
    # @param [Hash] other             Initial values for *self*.
    #
    def initialize(other)
      # Call `super()` instead of `super` so that #merge! can process *other*.
      super()
      merge!(other)
    end

    # Create a new self instance copied from *self*.
    #
    # @return [self]                  A new self instance.
    #
    # @see self#initialize
    #
    def dup
      self.class.new(self)
    end

    # The result has unique key-value pairs from *self* and *other*; for keys
    # that are the same in both, the result has a key-value pair where the
    # value is the value of *other[key]* appended to *self[key]*.
    #
    # @param [Hash] other
    #
    # @return [self]                  A new self instance.
    #
    def merge(other)
      dup.merge!(other)
    end

    # Unique key-value pairs from *other* are copied to *self*.  For the same
    # keys, the value of *other[key]* is appended to *self[key]*.
    #
    # @param [Hash] other
    #
    # @return [self]                  Updated *self* instance.
    #
    def merge!(other)
      if other.is_a?(Hash)
        other.each_pair do |k, v|
          self[k] = self[k].split(SPACE) if self[k].is_a?(String)
          v = v.split(SPACE) if v.is_a?(String)
          if self[k].is_a?(Array)
            self[k] += Array(v)
            self[k].uniq!
          else
            self[k] = v
          end
        end
      end
      self
    end

    # Override active_support #deep_merge! since this class does not support
    # a recursive definition (values should only be scalars or arrays, but not
    # hashes).
    #
    # @param [Hash] other
    #
    # @return [self]                  Updated *self* instance.
    #
    def deep_merge!(other)
      merge!(other)
    end

    # The resultant string is ready for inclusion as options in the rendering
    # of an HTML start tag.
    #
    # @return [String]
    #
    def to_s
      result =
        map { |k, v|
          v = v.join(SPACE) if v.is_a?(Array)
          %Q(#{k}="#{v}")
        }.join(SPACE)
      result = SPACE + result if result.present?
      result
    end

    # @see Hash#inspect
    #
    # @return [String]
    #
    def inspect
      super
    end

  end

end
