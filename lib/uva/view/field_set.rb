# lib/uva/view/field_set.rb

require 'uva'

module UVA::View

  # A one or more Field instances that are rendered in order.
  #
  class FieldSet < Array

    include UVA
    include UVA::Util::Dev

    Debug.setup(
      active:      Virgo.desktop_development?,
      initialize:  false,
      merge:       false,
      merge!:      false,
      render:      false,
      set_options: false,
    )

    DEF_FIELD_SEPARATOR = NEWLINE
    DEF_CONTEXT         = nil

    INIT_TYPES = [Hash, Field]

    # =========================================================================
    # :section: FieldSet
    # =========================================================================

    public

    # The string to emit between display fields
    #
    # @return [String]
    #
    attr_reader :field_separator

    # The context for rendering the set of display fields.
    #
    # @return [Symbol]
    #
    attr_reader :context

    # Each argument may be either a Hash or Field or an array of
    # Field.  For a Hash, each key-value pair is used to initialize a
    # new Field instance.
    #
    # @param [Array<Hash, Field, Array<Field>>] args
    #
    # === Usage Notes
    #
    # @example With a single Hash argument:
    #
    #   UVA::View::FieldSet.new(
    #     'Type'    => 'Text Resource',
    #     'Creator' => :author_display,
    #     'Date'    => :year_display
    #   )
    #
    # @example With individual Fields
    #
    #   UVA::View::FieldSet.new(
    #     Field.new('Type',    'Text Resource'),
    #     Field.new('Creator', :author_display),
    #     Field.new('Date'),   :year_display)
    #   )
    #
    # @example With a mix (hashes require braces unless as the last argument)
    #
    #   UVA::View::FieldSet.new(
    #     { 'Type' => 'Text Resource', 'Creator' => :author_display },
    #     Field.new('Date', :year_display),
    #     'Collection' => :digital_collection_facet,
    #     'Full Text'  => xtf_link(doc, 'view')
    #   )
    #
    def initialize(*args)
      Debug.show(__method__) { "#{self.class} - " + report_args(*args) }
      super()
      @field_separator = @saved_separator = DEF_FIELD_SEPARATOR
      @context         = @saved_context   = DEF_CONTEXT
      set_options(*args)
      merge!(*args)
    end

    # =========================================================================
    # :section: FieldSet
    # =========================================================================

    public

    # Create a new self instance copied from *self*.
    #
    # @return [self]                  A new self instance.
    #
    # @see self#initialize
    #
    def dup
      self.class.new(*self)
    end

    # Create a new instance with added/modified display fields.
    #
    # @param [Array<Hash, Field, Array<Field>>] args
    #
    # @return [self]                  A new self instance.
    #
    # @see self#initialize
    #
    def merge(*args)
      Debug.show(__method__) { "#{self.class} - " + report_args(*args) }
      dup.merge!(*args)
    end

    # Add/modify display fields.
    #
    # @param [Array<Hash, Field, Array<Field>>] args
    #
    # @return [self]                  The modified *self* instance.
    #
    # @see self#initialize
    #
    def merge!(*args)
      Debug.show(__method__) { "#{self.class} - " + inspect_args(*args) }

      # Process arguments to arrive at an array of Field instances.
      added_display_fields =
        args.flat_map { |arg|
          next unless arg
          case arg
            when Array, Field
              arg
            when Hash
              arg.map { |lbl, val| Field.new(lbl, val) }
            else
              raise "#{arg.class}: must be one of #{INIT_TYPES}"
          end
        }.compact

      # Create a lookup table of existing fields for use below.
      existing_fields = map { |field| [field.label, field] }.to_h

      # New fields are appended; existing fields are modified.
      added_display_fields.each do |df|
        # If the originating argument was an Array, this ensures that it
        # contained only Field elements.
        if !df.is_a?(Field)
          raise "#{df.class}: must be one of #{INIT_TYPES}"
        elsif (existing_field = existing_fields[df.label])
          existing_field.merge!(df)
        else
          push(df)
        end
      end

      # Return with *self* to support chaining.
      self
    end

    # Produce a string that can be used to render the entire set of display
    # fields within a display template.
    #
    # @param [Array<Symbol, UVA::IndexDoc, UVA::Marc::Record>] args
    # * UVA::Marc::Record - source of field values
    # * UVA::IndexDoc - source of field values
    # * Symbol - context
    #
    # @return [ActiveSupport::SafeBuffer]
    #
    # @see Field#render
    #
    def render(*args)
      Debug.show(__method__) { "#{self.class} - " + report_args(*args) }
      set_options(*args)
      map { |df|
        df.render(*args)
      }.reject(&:blank?).join(@field_separator).html_safe
    end

    # =========================================================================
    # :section: FieldSet
    # =========================================================================

    protected

    # Options specific to self are extracted, potentially modifying *args* as a
    # side-effect.
    #
    # If any already-initialized (non-nil) option settings were changed, the
    # method will return *true*.
    #
    # @note The caller's option hash will have :field_separator removed.
    #
    # @param [Array] args
    #
    # @return [Boolean]               True if changes were made.
    #
    def set_options(*args)
      Debug.show(__method__) { "#{self.class} - " + report_args(*args) }
      changes = 0

      opt = (args.pop if args.last.is_a?(Hash))
      if opt && opt.key?(:field_separator)
        @saved_separator = @field_separator
        @field_separator = opt.delete(:field_separator)
        changes += 1 if @field_separator != @saved_separator
      end

      ctx = args.find { |arg| arg.is_a?(Symbol) }
      if ctx && (ctx != @context)
        raise "unexpected context :#{ctx}" unless Constants::CONTEXT.key?(ctx)
        @saved_context = @context
        @context = ctx
        changes += 1 if @context != @saved_context
      end

      !changes.zero?
    end

  end

end
