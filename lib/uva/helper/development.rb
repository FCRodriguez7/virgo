# lib/uva/helper/development.rb

require 'uva'

module UVA::Helper

  # Development-only display elements.
  #
  module Development

    include UVA
    include UVA::Util::Dev

    # =========================================================================
    # :section: Feature properties
    # =========================================================================

    public

    class << self

      # If *true*, refrain from showing development display elements.
      FEATURE_DISABLED = true

      # =======================================================================
      # :section: Module methods
      # =======================================================================

      public

      # Indicate whether the development display elements should be present.
      #
      # @see self#FEATURE_DISABLED
      #
      def feature_enabled?
        !defined?(FEATURE_DISABLED) || !FEATURE_DISABLED
      end

    end

    # =========================================================================
    # :section: Console/logging methods
    # =========================================================================

    public

    # The *view_debug* method will only produce output if *source* matches
    # one of these patterns.
    #
    # @see self#view_debug
    #
    VIEW_DEBUG_TARGETS = [
      %r{/index\.html\.erb$},
      %r{/show\.html\.erb$},
      %r{/catalog/email/_},
      %r{/catalog/index/_},
      %r{/catalog/row/_},
      %r{/catalog/show/_},
      %r{/layouts/[^_]},
      %r{/google/},
    ].deep_freeze

    # Generate debugging output from a view template in selected situations.
    #
    # @param [String]        source   Use __FILE__ in the calling parameter.
    # @param [Array<String>] args
    #
    # @return [nil]
    #
    # @see self#VIEW_DEBUG_TARGETS
    #
    def view_debug(source, *args)
      return unless UVA::Helper::Development.feature_enabled?
      return unless match_any(source, VIEW_DEBUG_TARGETS)
      output = "VIEW #{source} - "
      output << args.join(LIST_SEPARATOR) << ' - ' if args.present?
      output << "params = #{params.inspect}"
      console_output(output)
    end

    # =========================================================================
    # :section: Display methods
    # =========================================================================

    public

    # Render a control for developer use to get information about the current
    # display context.
    #
    # @param [Array<String, UVA::IndexDoc>] args
    #                                 If *item* is a document (SolrDocument or
    #                                   UVA::ArticleDoc), the tooltip will be
    #                                   the type of the document; otherwise
    #                                   *item* will be displayed as a string in
    #                                   the tooltip.
    #
    # @option [String] :label         The text to display on the screen
    #                                   (default: asterisk).
    # @option [String] :title         Specify tooltip text which overrides
    #                                   the text derived from *item*.
    # @option [String] :class         The CSS class for the created "<span>"
    #                                   (default: 'debug-note').
    #
    # @return [ActiveSupport::SafeBuffer]
    #
    # NOTE: If the SolrDocument or UVA::ArticleDoc has a #dev_note method
    # the return value from that method will be included in the tooltip text.
    #
    def show_dev_note(*args)
      return '' unless UVA::Helper::Development.feature_enabled?
      opt = args.last.is_a?(Hash) ? args.pop.dup : {}
      label = opt.delete(:label) || '&#x273D;'
      opt[:class] ||= 'debug-note'
      if !opt[:title] || true_value?(opt[:title])
        args << (@document || "[#{__method__}]") if args.blank?
        prefix = nil
        opt[:title] =
          args.map { |arg|
            if arg.is_a?(UVA::IndexDoc)
              "(:#{arg.doc_type} / :#{arg.doc_sub_type})" +
                if arg.respond_to?(:dev_note)
                  NEWLINE + arg.dev_note.to_s
                else
                  ''
                end
            elsif (arg = arg.to_s).index(File::SEPARATOR)
              prefix ||= Rails.root.join('app', 'views').to_s + File::SEPARATOR
              arg.sub(%r{^#{prefix}}, '').sub(/\.html\.erb$/, '')
            else
              arg
            end
          }.join(NEWLINE)
      end
      content_tag(:span, label.html_safe, opt)
    end

  end

end
