# lib/uva/view/item_tooltip.rb

require 'uva'

module UVA::View

  # A generic tooltip for line-oriented content.
  #
  # This object maintains lines to be displayed in an HTML-formatted "tooltip"
  # (actually a hidden HTML element which is uncovered by mouse action).
  #
  # Lines are maintained as an array of Hash elements which may include keys:
  #
  #   - *value* to hold the text for a given line.
  #   - *label* for lines whose value text is preceded by a label.
  #   - *tag*   to specify an HTML tag to wrap labels and values with.
  #   - Other key/value pairs are passed as options to the HTML tag.
  #
  # Lines can be added as a simple value, multiple label/value pairs, or
  # multiple values with the same label.
  #
  # === Usage Notes
  #
  # Use of this class requires CSS support in order to keep the tooltip hidden
  # until an action by the user uncovers it.  The expected CSS (taken from the
  # help text for catalog advanced search) would be of the form:
  #
  #   /* Attributes of enclosing HTML element marked with class "tooltip" */
  #   .tooltip {
  #     /* ... */
  #   }
  #
  #   /* Attributes of the tooltip element which is initially hidden. */
  #   .tooltip > span {
  #       visibility: hidden;
  #   }
  #
  #   /* Attributes of the tooltip element made visible when hovering. */
  #   .tooltip:hover > span {
  #       visibility: visible;
  #   }
  #
  # The actual hidden/visible tooltip is the content within the <span> element.
  # Other parts of the enclosing element with class "tooltip" are visible from
  # the start; the tooltip <span> is visible only when the mouse hovers over
  # the enclosing element.
  #
  class ItemTooltip

    include ActionView::Helpers::TagHelper

    include UVA
    include UVA::Util::HtmlMethods

    HTML_TAG    = 'span'.freeze
    HTML_OPEN   = "<#{HTML_TAG}>\n".freeze
    HTML_CLOSE  = "\n</#{HTML_TAG}>".freeze

    CSS_CLASS   = 'item-metadata'.freeze

    # @return [String]
    attr_reader :line_separator

    # =========================================================================
    # :section:
    # =========================================================================

    public

    # Create a new tooltip instance.
    #
    # @param [Array<String, Array, Hash>] args  Initial line(s); @see #add_line
    #
    # @option args [String] :line_separator             HTML emitted between
    #                                                     lines.
    # @option args [String,Array<String>] :line_class   CSS class(es) for all
    #                                                     lines.
    # @option args [String,Array<String>] :line_style   CSS styling for all
    #                                                     lines.
    # @option args [String,Array<String>] :class        Class(es) for the
    #                                                     tooltip element
    # @option args [String,Array<String>] :style        Styling for the tooltip
    #                                                     element.
    #
    def initialize(*args)
      opt = args.last.is_a?(Hash) ? args.last : {}
      @line_separator = opt.delete(:separator) || "<br/>\n"
      @line_class = make_class(*opt.delete(:line_class))
      @line_style = make_style(*opt.delete(:line_style))
      @class = make_class(CSS_CLASS, *opt.delete(:class))
      @style = make_style(*opt.delete(:style))
      @line = []
      add_line(*args) if args.present?
    end

    # Add a line to the tooltip content.
    #
    # This is essentially a short-cut to #add_line but unlike that method, this
    # method always returns *self*, so it can be invoked in a chain, e.g.:
    # `tt << 'Str1' << 'Str2' << 'Str3'`.
    #
    # @param [String, Array, Hash] value
    #
    # @return [self]
    # @return [nil]
    #
    # @see self#add_line
    #
    # === Examples
    #
    # @example Adding a single line from a String.
    #   tt << 'Str1'
    #
    # @example Adding a single line from an Array.
    #   tt << ['Label1', 'Str1']
    #   tt << ['Label1', 'Str1', tag: 'strong']
    #   tt << ['Label1', 'Str1', tag: 'strong', class: 'cl-css']
    #   tt << ['Label1', 'Str1', ..., 'LabelN', 'StrN']
    #
    # @example Adding a single line from a Hash.
    #   tt << { value: 'Str1' }
    #   tt << { label: 'Label1', value: 'Str1' }
    #   tt << { label: 'Label1', value: 'Str1', tag: 'strong' }
    #   tt << { label: 'Label1', value: 'Str1', tag: 'strong', class: 'clcss' }
    #
    # @example Adding multiple lines from an Array.
    #   tt << ['Label1', 'Str1', ..., 'LabelN', 'StrN']
    #   tt << ['Str1', ..., 'StrN', label: 'Label0']
    #
    # @example Adding multiple lines by chaining.
    #   tt << 'Str1' << 'Str2' << 'Str3'
    #
    def <<(value)
      add_line(*value)
    end

    # Add one or more lines of content.
    #
    # @param [Array<String, Array, Hash>] args
    #
    # @option args [String] :label
    # @option args [String] :value
    # @option args [Fixnum] :max_length  Passed to #append.
    # @option args [String] :tag
    # @option args [String] :label_tag
    # @option args [String] :value_tag
    # @option args [String] :class
    # @option args [String] :label_class
    # @option args [String] :value_class
    #
    # @return [self]
    # @return [nil]
    #
    # === Examples
    #
    # @example Add a simple line.
    #
    #   add_line('String1')
    #
    #   *Effect*:
    #     @line << { value: 'String1' }
    #
    #   *Output*
    #     String1<br/>
    #
    # @example Add a simple line with CSS styling.
    #
    #   add_line('String1', class: 'cl-css')
    #
    #   *Effect*
    #     @line << { value: 'String1', class: 'cl-css' }
    #
    #   *Output*
    #     <div class="cl-css">String1</div><br/>
    #
    # @example Add a line consisting of a label and a string.
    #
    #   add_line('Label1', 'String1')
    #
    #   *Effect:*
    #     @line << { label: 'Label1', value: 'String1' }
    #
    #   *Output:*
    #     <u>Label1</u>: String1<br/>
    #
    # @example Add a label/string wrapped in a *<strong>* tag.
    #
    #   add_line('Label1', 'String1', tag: 'strong')
    #
    #   *Effect*
    #     @line << { label: 'Label1', value: 'String1', tag: 'strong' }
    #
    #   *Output*
    #     <u><strong>Label1</strong></u>: <strong>String1</strong><br/>
    #
    # @example Add multiple lines wrapped in *<strong>* tags.
    #
    #   add_line('Label1', 'String1', 'Label2', 'String2', tag: 'strong')
    #
    #   *Effect*
    #     @line << { label: 'Label1', value: 'String1', tag: 'strong' }
    #     @line << { label: 'Label2', value: 'String2', tag: 'strong' }
    #
    #   *Output*
    #     <u><strong>Label1</strong></u>: <strong>String1</strong><br/>
    #     <u><strong>Label2</strong></u>: <strong>String2</strong><br/>
    #
    # @example The last unpaired string is treated as a simple line.
    #
    #   uneven_pairs = ['Label1', 'String1', 'Label2', 'String2', 'String3']
    #   add_line(uneven_pairs, tag: 'strong')
    #
    #   *Effect*
    #     @line << { label: 'Label1', value: 'String1', tag: 'strong' }
    #     @line << { label: 'Label2', value: 'String2', tag: 'strong' }
    #     @line << { value: 'String3', tag: 'strong' }
    #
    #   *Output*
    #     <u><strong>Label1</strong></u>: <strong>String1</strong><br/>
    #     <u><strong>Label2</strong></u>: <strong>String2</strong><br/>
    #     <strong>String3</strong><br/>
    #
    # @example Multiple lines with the same label.
    #
    #   add_line('Str1', 'Str2', 'Str3', class: 'c', label: 'Label0', tag: :p)
    #
    #   *Effect*
    #     @line << { label: 'Label0', value: 'Str1', class: 'c', tag: :p }
    #     @line << { label: 'Label0', value: 'Str2', class: 'c', tag: :p }
    #     @line << { label: 'Label0', value: 'Str3', class: 'c', tag: :p }
    #
    #   *Output*
    #     <u><p class="c">Label0</p></u>: <p class="c">Str1</p><br/>
    #     <u><p class="c">Label0</p></u>: <p class="c">Str2</p><br/>
    #     <u><p class="c">Label0</p></u>: <p class="c">Str3</p><br/>
    #
    def add_line(*args)

      # Ensure there are enough arguments.  Potentially, all required items are
      # provided through the "options" hash; otherwise there has to be at least
      # one string provided through *args.
      opt = args.last.is_a?(Hash) ? args.pop.dup : {}
      label = opt.delete(:label)
      value = opt.delete(:value)
      args.push(value) if value.present?
      return if args.empty?

      # If :label was provided then each argument is treated as a separate
      # line. Otherwise, arguments as treated are treated as label/value pairs.
      if label
        args.each { |value_only| append([label, value_only], opt) }
      else
        final_value = (args.pop if args.size.odd?)
        args.each_slice(2) { |label_and_value| append(label_and_value, opt) }
        append(final_value, opt) if final_value
      end

      self
    end

    # Begin a series of list items.
    #
    # @return [self]
    #
    def begin_list
      add_line('<dl>')
    end

    # End a series of list items.
    #
    # @return [self]
    #
    def end_list
      add_line('</dl>')
    end

    # Add a list item line.
    #
    # @param [Array<String>] args
    #
    # @option args [String] :label_tag
    # @option args [String] :value_tag
    # @option args [String] :label_class
    # @option args [String] :value_class
    # @option args [Fixnum] :max_length  Passed to #append.
    #
    # @return [self]
    # @return [nil]
    #
    def add_list_item(*args)
      opt = args.last.is_a?(Hash) ? args.pop.dup : {}
      opt[:label_tag] ||= :dt
      opt[:value_tag] ||= :dd
      args.flatten!
      final_value = (args.pop if args.size.odd?)
      args.each_slice(2) { |label_and_value| append(label_and_value, opt) }
      append(final_value, opt) if final_value
      self
    end

    # Emit the HTML-safe tooltip content within a *HTML_TAG* element.
    #
    # @return [ActiveSupport::SafeBuffer]
    #
    def html
      lines =
        @line.map { |entry|

          # Process value.
          value = entry[:value]
          next if value.blank?
          value =
            fmt(
              value,
              tag:        (entry[:value_tag]   || entry[:tag]),
              class:      (entry[:value_class] || entry[:class]),
              max_length: (entry[:value_max]   || entry[:max_length])
            )

          # Process label.
          label       = entry[:label]
          label_tag   = entry[:label_tag]   || entry[:tag]
          label_class = entry[:label_class] || entry[:class]

          # Generate the line.
          if label.blank? && label_tag.blank? && label_class.blank?
            value
          elsif label_tag.blank?
            fmt(label, tag: :u, class: label_class) << ': ' << value
          else
            fmt(label, tag: label_tag, class: label_class) << value
          end
        }.compact.join(line_separator)
      make_tag(HTML_TAG, html_decode(lines).html_safe, @class, @style)
    end

    # =========================================================================
    # :section:
    # =========================================================================

    protected

    # Add a line, but only if a value was provided.
    #
    # @param [Hash, Array, String] new_line
    # @param [Hash]                opt
    #
    # @option opt [String] :label
    # @option opt [String] :value
    # @option opt [Fixnum] :max_length  If present, limit size of :value.
    #
    # @return [Array<String>]         The resulting line hash entries.
    # @return [nil]                   If nothing was added.
    #
    def append(new_line = nil, opt = nil)

      # Use *opt* as the basis for the new entry.
      if opt.nil?
        entry =
          case new_line
            when Hash  then new_line.dup
            when Array then { label: new_line.shift, value: new_line.shift }
            else            { value: new_line.to_s }
          end
      else
        entry = opt.dup
        case new_line
          when Hash
            entry.merge!(new_line)
          when Array
            entry[:label] = new_line.shift
            entry[:value] = new_line.shift
          else
            entry[:value] = new_line.to_s
        end
      end

      # If a value was supplied, include the entry in the @line.
      @line << entry if entry[:value].present?
    end

    # Format a string, applying :tag and other HTML attributes.
    #
    # @param [String, Symbol] text    Text or :blank for a blank line.
    # @param [Hash]           entry
    #
    # @option entry [String]                :tag
    # @option entry [String, Array<String>] :class
    # @option entry [String, Array<String>] :style
    #
    # @return [String]
    #
    def fmt(text, entry = {})
      # Extract CSS specifications and create style and class HTML attribute
      # fragments.
      css   = make_class(@line_class, *entry[:class])
      style = make_style(@line_style, *entry[:style])

      # Extract HTML tag specification (or provide one if required).
      tag = entry[:tag]
      tag = :div if tag.blank? && (css || style)

      # Return the text (potentially as an HTML element).
      if text == :blank
        text = nil
        tag ||= :span # Ensure that the return will not actually be blank.
      end
      tag ? make_tag(tag, text, css, style) : text
    end

    # Combine arguments into a string that can be used in an ERB file to set
    # CSS classes on an HTML element.
    #
    # @param [Array<String>] args
    #
    # @return [String]
    # @return [nil]                   If no classes were provided.
    #
    # @example
    #   css_classes = make_class('class-1', 'class-2', 'class-3')
    #   ...
    #   <div class="<% css_classes -%>">
    #
    def make_class(*args)
      args = args.flatten.map { |v| v.to_s.strip }.reject(&:blank?)
      return if args.empty?
      args.join(SPACE).squeeze(SPACE)
    end

    # Combine arguments into a string that can be used in an ERB file to set
    # CSS style on an HTML element.
    #
    # @param [Array<String>] args
    #
    # @return [String]
    # @return [nil]                   If no styles were provided.
    #
    # @example
    #   styles = make_style('color:red', 'class-2', 'class-3')
    #   ...
    #   <div class="<% css_classes -%>">
    #
    def make_style(*args)
      args = args.flatten.map { |v| v.to_s.strip }.reject(&:blank?)
      return if args.empty?
      args.map { |v| v.sub(/[;\s]+$/, '') }.join(ITEM_SEPARATOR)
    end

    # Generate an HTML element.
    #
    # @param [String,Symbol] tag
    # @param [String]        text
    # @param [String]        css_classes
    # @param [String]        css_styles
    #
    # @return [ActiveSupport::SafeBuffer]
    #
    def make_tag(tag, text, css_classes = nil, css_styles = nil)
      tag  ||= :span
      text ||= ''
      content_tag(tag, text, class: css_classes, style: css_styles)
    end

  end

end
