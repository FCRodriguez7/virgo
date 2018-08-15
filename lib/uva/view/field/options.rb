# lib/uva/view/field/options.rb

require 'uva'

module UVA::View

  class Field

    class Options

      include UVA

      SETTINGS = {
        field_separator:  (DEF_FIELD_SEPARATOR  = NEWLINE),
        visible:          (DEF_VISIBLE          = true),
        no_eval:          (DEF_NO_EVAL          = false),
        join:             (DEF_JOIN             = false),
        separator:        (DEF_SEPARATOR        = ITEM_SEPARATOR),
        before:           (DEF_BEFORE           = nil),
        after:            (DEF_AFTER            = nil),
        sanitize:         (DEF_SANITIZE         = false),
        min_chars:        (DEF_MIN_CHARS        = nil), # TODO - column align
        max_len:          (DEF_MAX_CHARS        = nil),
        html:             (DEF_HTML             = false),
        html_tag:         (DEF_HTML_TAG         = 'div'),
      }.deep_freeze

      # =======================================================================
      # :section:
      # =======================================================================

      public

      # Initialize a new self instance.
      #
      # @param [Hash, Options] other  Initializer
      #
      # @see self#merge!
      #
      def initialize(other = nil)
        @setting = @html_attr = nil
        merge!(other)
      end

      # The associated item should be seen when rendered.
      #
      # @return [Boolean]
      #
      def visible
        @setting[:visible] || DEF_VISIBLE
      end

      # If the associated item is a symbol, do not evaluate it as a document
      # method or metadata field.
      #
      # NOTE: This is typically set to *true* for the label part to support the
      # ability to initialize a Field with a Hash (where each hash key
      # must be unique) for fields where a label should not be shown.
      #
      # @return [Boolean]
      #
      def no_eval
        @setting[:no_eval] || DEF_NO_EVAL
      end

      # If the associated item is an array, its values should be joined into a
      # single string when rendered.
      #
      # When this is *true* it is implied that the value-part of a display
      # field will rendered as a String regardless of the nature of the data.
      #
      # @return [Boolean]
      #
      # @see self#separator
      #
      def join
        @setting[:join] || DEF_JOIN
      end

      # The associated item should be rendered as part of an HTML element.
      #
      # When this is *true* the entry for a display field part will be wrapped
      # in HTML begin/end tags.
      #
      # @return [Boolean]
      #
      # @see self#html_tag
      # @see self#html_attr
      #
      def html
        @setting[:html] || DEF_HTML
      end

      # If #join is *true*, if the associated item is an array it will be
      # rendered as a single string joined with by this.
      #
      # @return [String]
      #
      # @see self#join
      #
      def separator
        @setting[:separator] || DEF_SEPARATOR
      end

      # Results will be sanitized for e-mail output.
      #
      # @return [Boolean]
      #
      def sanitize
        @setting[:sanitize] || DEF_SANITIZE
      end

      # The maximum number of characters to display for any value.
      #
      # @return [Fixnum]
      # @return [nil]                 If no value has been defined.
      #
      def max_len
        @setting[:max_len] || DEF_MAX_CHARS
      end

      # String to include *before* the item when it is rendered.
      #
      # If #html is *true*, this will come before the HTML tag enclosing the
      # item.
      #
      # @return [String]
      # @return [nil]                 If no value has been defined.
      #
      # @example
      #   *Part*.new('NAME', html: true,  before: '///') #-> ///<div>NAME</div>
      #   *Part*.new('NAME', html: false, before: '///') #-> ///NAME...
      #
      def before
        @setting[:before] || DEF_BEFORE
      end

      # String to include *after* the item when it is rendered.
      #
      # If #html is *true*, this will come after the HTML tag enclosing the
      # item.
      #
      # @return [String]
      # @return [nil]                 If no value has been defined.
      #
      # @example
      #   *Part*.new('NM', html: true,  after: '<br/>') #-> <div>NM</div><br/>
      #   *Part*.new('NM', html: false, after: ': ')    #-> NM: ...
      #
      def after
        @setting[:after] || DEF_AFTER
      end

      # If #html is *true*, the item is rendered as the value of an HTML
      # element indicated by this.
      #
      # @return [String]
      #
      # @example
      #   *Part*.new('NAME', html: true,  html_tag: 'dt') #-> <dt>NAME</dt>
      #   *Part*.new('NAME', html: false, html_tag: 'dt') #-> NAME
      #   *Part*.new('NAME', html: true,  html_tag: :dd)  #-> <dd>NAME</dd>
      #   *Part*.new('NAME', html: false, html_tag: :dd)  #-> NAME
      #
      # @see self#html
      #
      def html_tag
        @setting[:html_tag] || DEF_HTML_TAG
      end

      # If #html is *true*, the item is rendered as the value of an HTML
      # element with attributes constructed from these key-value pairs.
      #
      # @note The key :html_attr does not appear in option hashes.
      # Instead, any hash key that is not associated with a setting will become
      # an HTML attribute.
      #
      # @return [HtmlAttributes]
      #
      # @example With HTML turned on:
      #   *Part*.new('NAME', html: true,  class: 'debug', id: 18)
      #     #-> @html_attr = { class: 'debug', id: 18 }
      #     #-> Effect: '<div class="debug" id="18">NAME</div>'
      #
      # @example Within HTML turned off:
      #   *Part*.new('NAME', html: false, class: 'debug', id: 18)
      #     #-> @html_attr = { class: 'debug', id: 18 }
      #     #-> Effect: 'NAME'
      #
      # @example Another with HTML turned on:
      #   *Part*.new('NAME', html: true,  style: ['color:red', 'float:left'])
      #     #-> @html_attr = { style: ['color:red', 'float:left'] }
      #     #-> Effect: '<div style="color:red; float:left">NAME</div>'
      #
      # @see self#html
      #
      def html_attr
        @html_attr
      end

      # The current setting hash.
      #
      # In most cases this will not contain an entry for every setting -- only
      # the ones that were expressly defined.
      #
      # @return [Hash]
      #
      def setting
        @setting
      end

      # The names of all setting methods.
      #
      # @return [Array<Symbol>]
      #
      def settings
        SETTINGS.keys
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

      # Create a new instance with overridden settings and merged HTML
      # attributes.
      #
      # @param [Hash, Options] other
      #
      # @return [self]                A new self instance.
      #
      # @see self#initialize
      #
      def merge(other)
        dup.merge!(other)
      end

      # Combine values from another self instance into this one.
      #
      # @param [Hash, Options] other
      #
      # @return [self]                The modified *self* instance.
      #
      # @see self#initialize
      #
      def merge!(other)
        new_set = new_attr = nil

        # Extract settings and HTML attributes from *other*.
        case other
          when Options
            new_set  = other.setting
            new_attr = other.html_attr
          when Hash
            new_set  = other.slice(*settings)
            new_attr = other.except(*settings)
        end

        # Merge settings (overriding any that may already be present).
        if @setting && new_set
          @setting.merge!(new_set)
        elsif new_set
          @setting = new_set.dup
        else
          @setting ||= {}
        end

        # Merge HTML attributes (appending to the values of any that may
        # already be present).
        if @html_attr
          @html_attr.merge!(new_attr)
        else
          @html_attr = HtmlAttributes.new(new_attr)
        end

        self
      end

      # To avoid possible confusion, respond to #deep_merge! like a Hash but,
      # since the constituent @setting and @html_attr hashes should be shallow,
      # handle it like #merge!.
      #
      # @param [Hash, Options] other
      #
      # @return [self]                  Updated *self* instance.
      #
      # @see self#merge!
      #
      def deep_merge!(other)
        merge!(other)
      end

      # =======================================================================
      # :section:
      # =======================================================================

      public

      # The contents of self expressed as a Hash, both settings and HTML
      # attributes.
      #
      # @return [Hash]
      #
      def to_hash
        @setting.merge(@html_attr)
      end

      # A detailed listing of settings and HTML attributes, primarily for
      # development purposes.
      #
      # @return [String]
      #
      def inspect
        result  = @setting.map   { |k, v| "#{k}=#{v.inspect}" }
        result += @html_attr.map { |k, v| "#{k}=#{v.inspect}" }
        result.join(LIST_SEPARATOR)
      end

    end

  end

end
