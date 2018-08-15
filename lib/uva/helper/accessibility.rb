# lib/uva/helper/accessibility.rb

require 'uva'

module UVA::Helper

  # UVA::Helper::Accessibility
  #
  module Accessibility

    include UVA
    include UVA::Accessibility

    # =========================================================================
    # :section:
    # =========================================================================

    public

    # Insert content which appears only for screen readers.
    #
    # If a block is given, its result is appended to *content* (if provided).
    #
    # @param [Symbol, nil] tag        HTML element tag; default: :div.
    # @param [String, nil] content    Screen-reader text; default: ''.
    # @param [Hash, nil]   opt
    #
    # @option opt [Symbol,String] :tag      Default: value of *tag* arg.
    # @option opt [String]        :content  Default: value of *content* arg.
    #
    # @return [ActiveSupport::SafeBuffer]
    #
    # @see self#make_element
    #
    def sr_only(tag = nil, content = nil, opt = nil)
      make_element(tag, content, opt, class: 'sr-only')
    end

    # Generate the icon for a help symbol with text for the screen reader.
    #
    # @param [Symbol, nil] tag        Outer tag; default: :div.
    # @param [String, nil] content    Screen-reader text; default: 'Help'.
    # @param [Hash, nil]   opt
    #
    # @option opt [Symbol,String] :tag      Default: value of *tag* arg.
    # @option opt [String]        :content  Default: value of *content* arg.
    #
    # @return [ActiveSupport::SafeBuffer]
    #
    # @see self#make_element
    #
    def help_symbol(tag = nil, content = nil, opt = nil)
      defaults = {
        class:   'fa fa-question-circle',
        content: sr_only('Help:')
      }
      make_element(tag, content, opt, defaults)
    end

    # =========================================================================
    # :section:
    # =========================================================================

    protected

    # Generate an HTML element.
    #
    # @param [Array] args
    #
    # args[0] [Symbol, nil] tag        HTML element tag; default: :div.
    # args[1] [String, nil] content    Screen-reader text; default: ''.
    # args[2] [Hash, nil]   opt
    # args[3] [Hash, nil]   defaults
    #
    # @option [Symbol,String] :tag      Default: value of *tag* arg.
    # @option [String]        :content  Default: value of *content* arg.
    #
    # @example make_element(:h1, 'Title', {class: 'c'}, {class: 'd'})
    # yields: <h1 class="c d">Title</h1>
    #
    # @example make_element(:h1, {class: 'c', content: 'Title'}, {class: 'd'})
    # yields: <h1 class="c d">Title</h1>
    #
    # @example make_element(class: 'c', content: 'Title', tag: :h1)
    # yields: <h1 class="c">Title</h1>
    #
    # @example make_element('Title', {class: 'c'}, {class: 'd'})
    # yields: <div class="c d">Title</div>
    #
    # @example make_element({class: 'c'}, {class: 'd'})
    # yields: <div class="c d" aria-hidden="true"></div>
    #
    # @return [ActiveSupport::SafeBuffer]
    #
    def make_element(*args)
      args.compact!
      tag     = args.first.is_a?(Symbol) && args.shift.presence || :div
      content = args.first.is_a?(String) && args.shift.presence || ''
      opt     = args.first.is_a?(Hash)   && args.shift.presence || {}
      def_opt = args.first.is_a?(Hash)   && args.shift.presence || {}

      css = [*opt[:class], *def_opt[:class]].join(' ').squish.presence
      html_opt = def_opt.merge(opt).merge(class: css).reject { |_, v| v.nil? }
      opt_val  = html_opt.extract!(:tag, :content)

      tag = opt_val[:tag] if opt_val[:tag].is_a?(Symbol)

      content = ERB::Util.h(content)
      content += opt_val[:content] if opt_val[:content].is_a?(String)
      blk_val = (yield if block_given?)
      content += blk_val if blk_val.is_a?(String)

      html_opt[ARIA_HIDDEN] = true if content.blank?
      content_tag(tag, content, html_opt)
    end

  end

end
