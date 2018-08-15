# config/initializers/activesupport_safebuffer.rb
#
# This is borrowed from the stackoverflow.com solution here:
# @see https://stackoverflow.com/questions/11478316/incompatible-character-encodings-utf-8-and-ascii-8bit/16737583#16737583
#
# The root problem forcing the application of this monkey patch is the
# concatenation of Ruby template partials into the complete page.  That
# concatenation handles the template parts as ASCII-8BIT.  This causes errors
# when the generated template partials contain characters that must be
# treated as UTF-8.

require 'active_support/core_ext/string/output_safety'

module ActiveSupport

  class SafeBuffer < String

    # This class attribute provides an "out" for the behavior implemented by
    # this monkey patch.
    #
    # @see RecordMailer#sms_record
    #
    cattr_accessor :disable_force_utf8

    # Append the given string, ensuring that html_safe is not affected.
    #
    # @param [String] value
    #
    # @return [String]
    #
    # @raise [SafeConcatError]        If self is no longer html_safe.
    #
    def safe_concat(value)
      value = force_utf8_encoding(value)
      raise SafeConcatError unless html_safe?
      original_concat(value)
    end

    # Append the given string without affecting html_safe.
    #
    # @param [String] value
    #
    # @return [String]
    #
    def concat(value)
      value = force_utf8_encoding(value)
      if !html_safe? || value.html_safe?
        super(value)
      else
        super(ERB::Util.h(value))
      end
    end

    alias << concat

    protected

    # Fixes strings which contain UTF-8 but have been improperly marked as
    # having something other than UTF-8 encoding.
    #
    # NOTE: This method does not do any transcoding.
    #
    # Both *self* and *value* are assumed to be UTF-8 strings; this method just
    # ensures that they are properly marked as having that encoding.
    #
    # @param [String] value           The object to (potentially) modify.
    #
    # @return [String]                The *value* object with corrected
    #                                   encoding.  If *value* was frozen, the
    #                                   result is a copy.
    #
    def force_utf8_encoding(value)
      return value if SafeBuffer.disable_force_utf8
      self.force_encoding('UTF-8') unless self.encoding.name == 'UTF-8'
      if value.is_a?(String) && (value.encoding.name != 'UTF-8')
        value = value.dup if value.frozen?
        value.force_encoding('UTF-8').html_safe
      else
        value
      end
    end

    public

    # This patch is required to let ActiveSupport::SafeBuffer be used in place
    # of String.  Without this, any code that uses #gsub with a block and uses
    # match reference variables like "$1" will see them as *nil*.
    #
    # === References
    # @see https://makandracards.com/makandra/11171-how-to-fix-gsub-on-safebuffer-objects
    #
    def gsub(*, &block)
      if block_given?
        super do |*other_args|
          Thread.current[:LAST_MATCH_DATA] = $~
          eval('$~ = Thread.current[:LAST_MATCH_DATA]', block.binding)
          block.call(*other_args)
        end
      else
        super.to_str
      end
    end

  end

end
