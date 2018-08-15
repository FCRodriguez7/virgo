# lib/uva/view/field.rb

require 'uva'
require_relative 'field/options'
require_relative 'field/part'

module UVA::View

  # A label-value pair that can be rendered in any viewing context.  An
  # instance of this class encapsulates information about the pair and handles
  # the details of expressing them, allowing the rendering code to be
  # streamlined.
  #
  # === Usage Notes
  # In a document-type-specific view template, create Field instances
  # the represent the information to convey about that type.  Then supply this
  # set of instances to view code which causes each instance to render itself
  # in the appropriate context.
  #
  # @example Setting up label-value pair definitions
  #
  #   fields = [
  #     Field.new(
  #       'Title'         => :main_title_display,
  #       'Author'        => marc_display.statement_of_responsibility,
  #       'Str Val'       => 'Text',
  #       'Array Value'   => ['item 1', 'item 2'],
  #       'Styled Field'  => [:series_title_display, class: 'title-field']
  #     ),
  #     Field.new(
  #       # ...
  #     ),
  #     # ...
  #   ]
  #
  # For convenience in bulk handling of Field instances:
  # @see FieldSet
  #
  class Field

    include UVA
    include UVA::Util::Dev

    Debug.setup(
      active:           Virgo.desktop_development?,
      initialize:       false,
      set:              false,
      merge:            false,
      merge!:           false,
      render:           false,
      finalize_options: false,
    )

    # =========================================================================
    # :section:
    # =========================================================================

    public

    # The label portion of the display field.
    #
    # @return [Part]
    #
    attr_reader :label

    # The value portion of the display field.
    #
    # @return [Part]
    #
    attr_reader :value

    # Options that will apply to both parts of the display field.
    #
    # @return [Options]
    #
    attr_reader :options

    # Initialize a new self instance.
    #
    # @param [Array] args
    # * The first argument is the label entry.
    # * The second argument is the value entry.
    # * The final argument is the option hash.
    #
    # === Usage Notes
    # @example Set label, no value, default options
    #   new('Label Name')
    #
    # @example Set value, no label, default options
    #   new(nil, 'Item Value')
    #
    # @example Set options
    #   new(html: true, html_tag: 'span')
    #
    # @example Complete
    #   new('Label Name', :author_facet, html: true, html_tag: 'span')
    #
    # @example Alternate (commonly used in ERB templates)
    #   new('Label Name', [:author_facet, html: true, html_tag: 'span'])
    #
    def initialize(*args)
      Debug.show(__method__) { "#{self.class} - " + report_args(*args) }

      # To support the "Alternate" approach to passing the options hash:
      # Remove the options hash from the end of the value argument and append
      # it to the argument list to become the third (final) argument.
      value_arg = args[-1]
      if value_arg.is_a?(Array)
        arg_options = (value_arg.pop if value_arg.last.is_a?(Hash))
        args[-1] = value_arg.first if value_arg.size == 1
        args << arg_options if arg_options
      end

      @label = @value = @options = nil
      merge!(*args)
    end

    # =========================================================================
    # :section:
    # =========================================================================

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

    # Create a new self instance with merged options.
    #
    # @param [Array] args
    #
    # @return [self]                  A new self instance.
    #
    # @see self#initialize
    #
    def merge(*args)
      Debug.show(__method__) { "#{self.class} - " + report_args(*args) }
      dup.merge!(*args)
    end

    # Modify part entries and/or options.
    #
    # @param [Array] args             A maximum of two non-hash arguments.
    #
    # @return [self]                  The modified *self* instance.
    #
    # @see self#initialize
    #
    # @example One or two non-hash arguments
    #   merge!(df1)               # Label options merged.
    #   merge!(df1, df2)          # Label and value options merged.
    #   merge!(part1)             # Label options merged.
    #   merge!(part1, part2)      # Label and value options merged.
    #
    # @example Final third argument may be a Hash or Options
    #   merge(part1, df2, hash)   # General options from Hash.
    #   merge(df1, part2, option) # General options from Option.
    #
    def merge!(*args)
      Debug.show(__method__) { "#{self.class} - " + inspect_args(*args) }
      opt = label_opt = value_opt = nil

      # Extract part-specific sub-hashes from the options.
      case args.last
        when Options
          opt = args.pop
        when Hash
          opt = args.pop
          label_opt = opt[:label]
          value_opt = opt[:value]
          opt = opt.reject { |_, v| v.is_a?(Hash) }
        when Field, Part, Array, String, Symbol, nil
          # There are no part-specific options in the argument list; any that
          # might be conveyed through a Field or Part argument will be
          # handled below via #finalize_options.
        else
          raise "#{args.last.class}: unexpected"
      end

      # Extract label and part values from the argument list, merging in any
      # general options that may have been specified above.
      label_entry, label_opt = finalize_options(:label, args.shift, label_opt)
      value_entry, value_opt = finalize_options(:value, args.shift, value_opt)

      # Any option values remaining after part-specific sub-hashes have been
      # removed will update the general options that will apply to either part.
      if @options
        @options.merge!(opt)
      else
        @options = Options.new(opt)
      end

      # Apply label-specific entry and/or options.
      label_opt = @options.merge(label_opt)
      if @label
        @label.merge!(label_entry, label_opt)
      else
        @label = Part.new(label_entry, label_opt)
      end

      # Apply value-specific entry and/or options.
      value_opt = @options.merge(value_opt)
      if @value
        @value.merge!(value_entry, value_opt)
      else
        @value = Part.new(value_entry, value_opt)
      end

      # Return with the updated *self* to support chaining.
      Debug.show(__method__) { [
        "#{self.class}: return self: #{inspect}",
        "  label_opt: #{label_opt.inspect}",
        "  label: #{@label.inspect}",
        "  value_opt: #{value_opt.inspect}",
        "  value: #{@value.inspect}",
      ] }
      self

    end

    # Produce a string that can be used to render the field label/value within
    # a display template.
    #
    # @param [Array<Symbol, UVA::IndexDoc, UVA::Marc::Record>] args
    # * UVA::Marc::Record - source of field values
    # * UVA::IndexDoc - source of field values
    # * Symbol - context
    #
    # @return [ActiveSupport::SafeBuffer]
    #
    def render(*args)
      Debug.show(__method__) { [
        "#{self.class} - #{report_args(*args)}",
        "  @label: #{@label.inspect}",
        "  @value: #{@value.inspect}",
        "  @options: #{@options.inspect}",
      ] }

      # Update options based on the context (if one was specified).
      context = args.find { |arg| arg.is_a?(Symbol) }
      if context
        context_options = Constants::CONTEXT[context]
        merge!(context_options.deep_merge(@options.to_hash))
      end

      # Update options based on part-specific conditions (if any).
      no_label = @label.entry.blank? || @label.entry.is_a?(Symbol)
      if no_label
        opt = { label: {}, value: {} }
        opt[:label][:visible]  = false if no_label
        opt[:value][:html_tag] = 'div' if no_label && (context == :index)
        merge!(opt)
      end

      # If the value part doesn't resolve to a non-blank string then just a
      # blank will be returned.
      result = ''
      value_result = @value.render(*args)
      if value_result.present?
        label_result = @label.render(*args)
        result << Array(label_result).join if label_result.present?
        result << Array(value_result).join
        Debug.show(__method__) {
          "result: #{result.inspect}, self: #{inspect}"
        }
      end
      result.html_safe

    end

    # inspect
    #
    # @return [String]
    #
    def inspect
      "@label: #{@label.entry.inspect}, " \
      "@value: #{@value.entry.inspect}, " \
      "@options: #{@options.inspect}"
    end

    # =========================================================================
    # :section:
    # =========================================================================

    protected

    # Set label or value from arguments.
    #
    # @param [Symbol]              part         One of :label or :value.
    # @param [String, Part, Field] new_entry
    # @param [Hash]                new_options
    #
    # @return [Array<String, Hash>]  Modified *new_entry* and *new_options*.
    #
    # @see self#merge!
    #
    def finalize_options(part, new_entry, new_options)
      Debug.show(__method__) { [
        ":#{part} - ",
        "  new_entry = #{new_entry.inspect}",
        "  new_options = #{new_options.inspect}",
      ] }
      for_label = (part == :label)
      part_opt = nil
      case new_entry
        when Field
          df = new_entry
          new_entry = for_label ? df.label.entry   : df.value.entry
          part_opt  = for_label ? df.label.options : df.value.options
        when Part
          p = new_entry
          new_entry = p.entry
          part_opt  = p.options
        when Array, String, Symbol, nil
          # No changes to *new_entry* or *new_options*.
        else
          raise "#{new_entry.class}: unexpected"
      end
      if new_options.blank?
        new_options = part_opt ? part_opt.dup : {}
      elsif part_opt.present?
        new_options = part_opt.merge(new_options)
      end
      return new_entry, new_options
    end

  end

end
