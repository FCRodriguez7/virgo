# lib/uva/view/field/part.rb

require 'uva'

module UVA::View

  class Field

    class Part

      include UVA
      include UVA::Util::HtmlMethods
      include UVA::Util::Dev

      Debug.setup(
        active:      Virgo.desktop_development?,
        initialize:  false,
        merge:       false,
        merge!:      false,
        render:      false,
        get_value:   false,
      )

      ENTRY_TYPES = [Symbol, String, Array, Part].freeze

      # =======================================================================
      # :section:
      # =======================================================================

      public

      # The data value specifier for this display field part, which may have
      # the following forms:
      #
      #   * String - The literal string to be displayed.
      #   * Symbol - Specifies a method or index field that is the data source.
      #   * Array  - String(s) and/or Symbols that behave as described here.
      #
      # @return [Symbol, String, Array<Symbol, String>]
      #
      attr_reader :entry

      # The option settings and HTML attributes that have been specified for
      # this display field part.
      #
      # @return [Options]
      #
      attr_reader :options

      # Initialize a new self instance.
      #
      # @param [Array] args
      #
      # @see self#set
      #
      def initialize(*args)
        Debug.show(__method__) { "#{self.class} - " + report_args(*args) }
        @entry = @options = nil
        merge!(*args)
      end

      # =======================================================================
      # :section:
      # =======================================================================

      public

      # Create a new self instance copied from *self*.
      #
      # @return [self]                  A new self instance.
      #
      # @see self#initialize
      #
      def dup
        self.class.new(self)
      end

      # Create a new instance with merged options.
      #
      # @param [Array] args
      #
      # @return [self]                A new self instance.
      #
      # @see self#initialize
      #
      def merge(*args)
        Debug.show(__method__) { "#{self.class} - " + report_args(*args) }
        dup.merge!(*args)
      end

      # Combine entry and/or options into *self*.
      #
      # @param [Array] args
      #
      # @return [self]                The modified *self* instance.
      #
      # @see self#initialize
      #
      def merge!(*args)
        Debug.show(__method__) { "#{self.class} - " + inspect_args(*args) }
        new_options = (args.pop if [Hash, Options].include?(args.last.class))
        new_entry   = args.shift
        case new_entry
          when Part
            new_entry = new_entry.entry
            part_opt  = new_entry.options
            new_options = new_options ? part_opt.merge(new_options) : part_opt
          when Array, String, Symbol, nil
            # No changes.
          else
            raise "#{new_entry.class}: @entry must be one of #{ENTRY_TYPES}"
        end
        new_entry = new_entry.dup if new_entry.duplicable?
        if @options
          @entry = new_entry if new_entry
          @options = new_options.merge(@options)
        else
          @entry = new_entry
          @options = Options.new(new_options)
        end
        self
      end

      # Produce string(s) that can be used to render this display field part.
      #
      # @param [Array<Symbol, UVA::IndexDoc>] args
      # * UVA::IndexDoc - source of field values
      # * Symbol - context
      #
      # @option args [String, Array<String>] :class
      # etc. # TODO
      #
      # @return [ActiveSupport::SafeBuffer]        If scalar or joined array.
      # @return [Array<ActiveSupport::SafeBuffer>] If an un-joined array.
      #
      def render(*args)
        Debug.show(__method__) { "#{self.class} - " + report_args(*args) }

        # Get options and/or arguments.
        override_options =
          case args.last
            when Part          then args.pop.options
            when Hash, Options then args.pop
            else                    {}
          end

        # If options were specified, allow them to override current settings
        # for the duration of this method.  Extract #get_value options first.
        get_opt = {}
        if override_options.present?
          get_opt[:marc] = override_options.delete(:marc)
          @options = @options.merge(override_options)
        end

        # Get the value; for evaluating a Symbol entry, use the document
        # specified in the argument list unless evaluation is turned off.
        doc =
          unless @options.no_eval
            args.find { |arg| arg.is_a?(UVA::IndexDoc) }
          end
        value = get_value(@entry, doc, get_opt)

        # Render the value(s), joining the compound value into a single string
        # if indicated by options.
        if !value.is_a?(Array)
          render_value(value)
        elsif (separator = @options.join && @options.separator)
          render_value(value.join(separator))
        else
          value.map { |element| render_value(element) }.reject(&:blank?)
        end
      end

      # =======================================================================
      # :section:
      # =======================================================================

      protected

      # Return the value, interpreting Symbol as a MARC method, an IndexDoc
      # method or an index field.
      #
      # @param [String, Symbol, Array] value
      # @param [UVA::IndexDoc]         doc
      # @param [Hash]                  opt
      #
      # @return [String]
      # @return [Array<String>]
      #
      def get_value(value, doc = nil, opt = nil)
        Debug.show(__method__) {
          "value: #{value.inspect}, doc: #{!!doc}, opt: #{opt.inspect}"
        }
        case value
          when Symbol then doc && doc.evaluate(value, opt)
          when Array  then value.flat_map { |v| get_value(v, doc, opt) }
          else             value
        end
          .tap { |v| Debug.show(__method__) { "<- #{v.class} #{v.inspect}" } }
      end

      # Produce a string that can be used to render the given scalar value.
      #
      # @param [String] value
      #
      # @return [ActiveSupport::SafeBuffer]   If `@options.html` is *true*.
      # @return [String]                      If `@options.html` is *false*.
      #
      # TODO: @options setting for embedded newlines in HTML values.
      #
      def render_value(value)
        html   = @options.html
        result = ''
        if @options.visible && value.present?
          sanitize = @options.sanitize
          max_len  = @options.max_len
          value = html ? sanitize_html(value) : strip_html(value) if sanitize
          value = html_truncate(value, length: max_len)           if max_len
          value = [@options.before, value, @options.after].join
          if html
            tag   = @options.html_tag
            attr  = @options.html_attr
            value = "<#{tag}#{attr}>#{value}</#{tag}>"
          end
          result = value
        end
        html ? result.html_safe : result.to_str
      end

      # =======================================================================
      # :section:
      # =======================================================================

      public

      # For basic comparison, two parts match if their entries match regardless
      # of their respective option settings.
      #
      # @return [Boolean]
      #
      def ==(other)
        other.is_a?(self.class) && (@entry == other.entry)
      end

      # For advanced comparison, this method returns *true* only if entries
      # and options match.
      #
      def eql?(other)
        (self == other) && (@options == other.options)
      end

      # A detailed listing of settings and HTML attributes, primarily for
      # development purposes.
      #
      # @return [String]
      #
      def inspect
        "@entry: #{@entry.inspect}, @options: #{@options.inspect}"
      end

    end

  end

end
