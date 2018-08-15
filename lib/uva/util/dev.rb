# lib/uva/util/dev.rb

require 'uva'

module UVA::Util

  # Utility methods debugging and development support.
  #
  module Dev

    include UVA

    extend self

    # =========================================================================
    # :section: Module methods
    # =========================================================================

    public

    # Actions taken when this module is included.
    #
    # Creates a Debug subclass for the including module or class.
    #
    # @param [Module] base            The including module or class.
    #
    # @return [nil]
    #
    def self.included(base) # :nodoc:
      base.module_eval %Q(
        module Debug
          extend UVA::Util::Dev::Debug
          internal_setup(#{base})
        end
      )
    end

    # Return lines that show the execution path through application code.
    #
    # @param [Fixnum]        indent   Number of spaces beginning each line.
    # @param [Array<String>] stack    Uses Kernel#caller by default.
    #
    # @return [String]
    # @return [nil]
    #
    def app_call_stack(depth = 1, indent = 2, stack = nil)
      stack ||= caller(depth + 1) || []
      root = Rails.root.to_s
      call_path = stack.select { |v| v.start_with?(root) }
      return if call_path.blank?
      indent  = SPACE * indent
      newline = NEWLINE + indent
      indent + call_path.join(newline)
    end

    # Make a path(s) relative to Rails.root.
    #
    # @param [String, Array<String>, Hash{Object=>String}] path
    #
    # @return [String]
    #
    def erase_root(path)
      case path
        when Hash  then path.map { |k, v| [k, erase_root(v)] }.to_h
        when Array then path.map { |v| erase_root(v) }
        else            path.gsub(%r{#{Rails.root}/}, '')
      end
    end

    # =========================================================================
    # :section: Debugging support
    # =========================================================================

    public

    # Utility method to show the members of an argument list.
    #
    # @param [Array] args
    #
    # @return [String]
    #
    def report_args(*args)
      num = args.size
      arg = 'arg'
      arg = arg.pluralize unless num == 1
      max = 30
      result =
        args.map { |a|
          case a
            when nil, Numeric, Symbol, Range
              a.inspect
            when String
              s = a.inspect
              s = "\"#{s.truncate(max)}\" (#{a.size} chars)" if a.length > max
              s
            when Array
              s = a.inspect
              s = "[#{s.truncate(max)}] (#{a.size} elements)" if s.length > max
              s
            when Hash
              s = a.inspect
              s = "[#{s.truncate(max)}] (#{a.size} pairs)" if s.length > max
              s
            else
              a.class.to_s
          end
        }.join(LIST_SEPARATOR)
      "#{num} #{arg}: #{result}"
    end

    # Utility method to show the members of an argument list in detail.
    #
    # @param [Array] args
    #
    # @return [String]
    #
    def inspect_args(*args)
      num = args.size
      arg = 'arg'
      arg = arg.pluralize unless num == 1
      result = ["#{num} #{arg}"]
      i = -1
      result +=
        args.map do |a|
          i += 1
          "  arg[#{i}]> #{a.inspect}"
        end
      result.join(NEWLINE)
    end

    # =========================================================================
    # :section: On-screen debugging
    # =========================================================================

    public

    # Items to display in the debug panel.  String entries are evaluated with
    # `eval`; symbol entries are interpreted as `session` keys to show.  All
    # other non-nil session values will also be shown, but they will follow any
    # session items that are specified here.
    DEBUG_PANEL_ITEMS = [
      'params',
      :classic,
      :full_view,
      :special_collections,
      :sort_key,
      :peer_reviewed,
      :search_context,
      :search,
      :folder_article_ids,
      :folder_document_ids,
      :illiad_selection,
      :notices_count,
      :notices_expiration,
    ].deep_freeze

    # Session items which will not be included unless explicitly listed in
    # self#DEBUG_PANEL_ITEMS.
    DEBUG_PANEL_IGNORE = [
      :_csrf_token,
      :history,             # Unused Blacklight entry.
      :user_credentials,
      :user_credentials_id
    ].deep_freeze

    # Console output separator lines.
    DEBUG_PANEL_BAR = ('-' * 100).freeze

    # Generate a panel with the contents of `params` and `session` entries.
    #
    # @param [Hash] opt
    #
    # @option opt [String]  :class    CSS class; default: 'debug-panel'.
    # @option opt [Boolean] :console  If *true*, also emit entries to the
    #                                   console.
    #
    # @return [ActiveSupport::SafeBuffer]
    #
    # @see .debug-panel in app/assets/stylesheets/shared/_dev.scss
    #
    def debug_panel(opt = nil)

      html_opt = {
        class:    'debug-panel',
        console:  false,
      }
      html_opt.merge!(opt) if opt.present?
      console_display = html_opt.delete(:console)

      # Include other session keys that were not explicitly listed except for
      # the ones that were to be ignored.
      items = DEBUG_PANEL_ITEMS
      items += (session.keys.map(&:to_sym) - DEBUG_PANEL_IGNORE).sort
      items.uniq!

      # For each item, get a single-line display of its contents.
      lines =
        items.map { |item|
          label, value =
            case item
              when Symbol then ["session[:#{item}]", session[item]]
              when String then [item,                eval(item)]
            end
          next unless label && value
          value = PP.singleline_pp(value, '')
          value.gsub!(/=>/, ' \0 ')
          value.gsub!(/, +(0-9)/, ' \1')
          value.gsub!(/,/, ('\0' + NL))
          value.gsub!(/{(?!})/, ('\0' + NL))
          "#{label} = #{value}\n"
        }.compact
      vars = %w(params session\[[^\]]*\]).join('|')
      keys = UVA::Portal::PORTAL.keys.join('|')

      # Display the lines on the console for reference.
      if console_display
        [(DEBUG_PANEL_BAR + NL), *lines, DEBUG_PANEL_BAR].each do |line|
          STDERR.print(line)
        end
      end

      # Produce an element that can be displayed on-screen.
      content_tag(:div, html_opt) do
        lines.map { |line|
          h(line)
            .sub(/\A[^{]*{/, '\0<br/>')
            .sub(/}[^}]*\z/, '<br/>\0')
            .gsub(/[{}]/, ' \0 ')
            .gsub(/(?<=[{},\n])([^,\n]+)(,?)\n?/, ('<span class="line">\1\2</span>' + NL))
            .gsub(/(?<![\w:])(#{vars})(?!\w)/, '<span class="var">\1</span>')
            .gsub(/(?<![\w:])(#{keys})(?!\w)/, '<span class="key">\1</span>')
            .gsub(/{ *} */, '{&hairsp;}')
            .gsub(/[{}]/, '<span class="punctuation">\0</span>')
            .gsub(/\n/, '<br/>')
        }.join(NEWLINE).html_safe
      end
    end

    # =========================================================================
    # :section: On-screen debugging
    # =========================================================================

    public

    DEBUG_FOOTER_PAIRS = %w(
      params          session
      current_user    user_session
      @documents      @articles
      @document       @article
      @__availability @__catalog_item
      request         @cookies
    ).each_slice(2).to_a.deep_freeze

    # Generate a table with a lot of context information.
    #
    # @return [ActiveSupport::SafeBuffer]
    #
    # @see app/views/layouts/_dev_table.html.erb
    #
    def debug_footer
      @__availability = @document && @document.availability
      @__catalog_item = @__availability && @__availability._catalog_item
      DEBUG_FOOTER_PAIRS.map { |items|
        render 'layouts/dev_table', items: items
      }.join(NEWLINE).html_safe
    end

    # =========================================================================
    # :section: Debugging support
    # =========================================================================

    protected

    # The source of module methods for a debugging context.
    #
    module Debug

      include UVA

      extend self

      # =======================================================================
      # :section: Feature properties
      # =======================================================================

      public

      class << self

        # If *true*, disables use of the Debug module by making each invocation
        # of Debug#setup ignore its arguments so that Debug#active? is always
        # *false*.
        FEATURE_DISABLED = true

        # =====================================================================
        # :section: Module methods
        # =====================================================================

        public

        # Indicate whether the Debug module feature is present.
        #
        # @see self#FEATURE_DISABLED
        #
        def feature_enabled?
          !defined?(FEATURE_DISABLED) || !FEATURE_DISABLED
        end

      end

      # =======================================================================
      # :section:
      # =======================================================================

      public

      DEFAULT_INDENT = 0
      DEFAULT_PREFIX = '!!!'.freeze

      # =======================================================================
      # :section:
      # =======================================================================

      public

      # Debugging status settings for this debugging context.
      #
      # @return [Status]
      #
      def status
        @status ||= Status.null
      end

      # Indicates whether debugging is active for the given debug context.
      #
      # @return [Boolean]
      #
      def active
        status.active
      end

      # Makes `Debug.this_class` a synonym for `Debug.active`.
      #
      alias_method(:this_class, :active)

      # Makes `Debug.this_module` a synonym for `Debug.active`.
      #
      alias_method(:this_module, :active)

      # Set whether debugging is active for the given debug context.
      #
      # @param [Boolean] value
      #
      # @return [Boolean]
      #
      def active=(value)
        raise 'Must run Debug#setup first' \
          if status.readonly? || !status.initialized?
        status.active = value
      end

      # An array of debug status switches.
      #
      # @return[Array<Symbol>]
      #
      def setting
        status.setting
      end

      # Get the debug activation setting for the given method.
      #
      # @param [Symbol] for_method
      #
      # @return [Boolean]
      #
      def [](for_method)
        active && setting[for_method]
      end

      # Set the debug setting for the given method.
      #
      # @param [Symbol]  for_method
      # @param [Boolean] activated
      #
      def []=(for_method, activated)
        status[for_method] = activated
      end

      # Initial setup of the debugging context.
      #
      # Because of the way that modules and classes may be loaded, this method
      # may end up being run multiple times; initialization settings are only
      # applied the first time.
      #
      # @param [nil, Boolean, Hash{Symbol=>Boolean}] init_setting
      #
      # @option init_setting [Boolean] :active
      #   The initial activation status for the Debug instance.
      #
      # @return [Status]
      #
      def setup(init_setting)
        status.set(init_setting) unless status.initialized?
        status
      end

      # Emit line(s) to debugging output.
      #
      # @param [Array<String>] args          Zero or more strings to display,
      #                                        one per output line.  If the
      #                                        first argument is a symbol it
      #                                        is used to make execution of the
      #                                        method conditional.
      #
      # @option args [Boolean] :trace        If provided, causes a stack trace
      #                                        to be appended to the result.
      #
      # @option args [Fixnum] :caller_index  Used as the argument passed to
      #                                        Kernel#caller; the value should
      #                                        be >= 1.  (If provided, implies
      #                                        :trace == true.)
      #
      # @option args [Fixnum] :stack_depth   How much of the call stack to
      #                                        display; defaults to 3.  (If
      #                                        provided, implies :trace ==
      #                                        true.)
      #
      # @yield []
      # @yieldreturn [String, Array<String>]
      # If a block is given its return is appended to the array arguments to
      # emit one per line.
      #
      # @return [nil]
      #
      # === Usage Notes
      #
      # @example String(s) in the argument list
      #
      #   Debug.show(line1, line2, line3)
      #     // Output three lines
      #
      #   Debug.show(__method__, line1, line2, line3)
      #     // Output three lines
      #
      # @example String(s) from block.
      #
      #   Debug.show {
      #     // Block returning a single string or an array of strings...
      #   }
      #
      #   Debug.show(__method__) {
      #     // Block executed only if "__method__" is an active debugging
      #     // context...
      #   }
      #
      #   Debug.show(line1, line2) {
      #     // Block returning a single string which becomes the third line,
      #     // or an array of strings (the third and subsequent lines).
      #   }
      #
      # (The advantage of using the "block form" of the call is that none of
      # the code used to create the debugging message will be evaluated unless
      # debugging for the method is active.  This means that the code can be
      # included in production releases with almost no impact to performance.)
      #
      def show(*args)

        # Extract caller and options from the argument list.  If the arguments
        # are prefixed by the calling method, that is checked to make sure that
        # debugging is turned on for it.
        return unless active
        for_method = (args.shift if args.first.is_a?(Symbol))
        return unless for_method.nil? || setting[for_method]

        # Extract options from argument list.
        opt = args.last.is_a?(Hash) ? args.pop : {}
        stack_trace  = opt[:trace]
        caller_index = opt[:caller_index]
        stack_depth  = opt[:stack_depth]

        indent = !opt.key?(:indent) || opt[:indent]
        case indent
          when true  then indent = DEFAULT_INDENT
          when false then indent = nil
        end

        prefix = !opt.key?(:prefix) || opt[:prefix]
        case prefix
          when true  then prefix = DEFAULT_PREFIX
          when false then prefix = nil
        end

        # Append lines from block to method arguments (if any).
        args += Array(yield) if block_given?

        # Append a stack trace if requested.
        if stack_trace || caller_index || stack_depth
          caller_index ||= 0
          stack_depth  ||= 3
          stack_indent   = SPACE * 2
          new_line = "\n#{stack_indent}"
          stack = caller(caller_index)
          stack_trace =
            UVA::Util::Dev.erase_root(stack[1, stack_depth]).join(new_line)
          args << "--- called from:#{new_line}#{stack_trace}"
          args << '---'
        end

        # Skip output if there were no results.
        args = args.flatten.compact
        return if args.blank?

        # Construct a leader to go in front of every line.
        leader = ''
        leader << (SPACE * indent) if indent && (indent > 0)
        if prefix
          leader << prefix
          leader << SPACE unless prefix.end_with?(SPACE)
        end
        leader << "#{for_method} " if for_method

        # Output results, prefixing each line with the leader.
        results = args.join(NEWLINE)
        lines = results.to_s.count(NEWLINE)
        leader << (lines.zero? ? '-' : '|') << SPACE
        console_output(results.to_s.gsub(/^/, leader))
      end

      # =======================================================================
      # :section:
      # =======================================================================

      protected

      # Called to create the initial setting for the Debug subclass created
      # when this module is included.
      #
      # @param [Class, Module, String, Symbol] base
      #
      # @return [Status]
      #
      def internal_setup(base)
        # The hash key for the Registry is not needed in normal operation but
        # is created as a member variable as a debugging aid for this class.
        @status =
          if UVA::Util::Dev::Debug.feature_enabled?
            @registry_key =
              case base
                when Class
                  # Debugging context is the class which is including this
                  # module.
                  base.name
                when Module
                  # Look for a class ancestor to make the debugging context.
                  # Otherwise accept the module including this module as the
                  # context.
                  context = base.ancestors.find { |a| a.is_a?(Class) }
                  context = base unless context && (context != Object)
                  context.name
                else
                  base.to_s
              end
            Status.create(@registry_key)
          else
            Status.new(false)
          end
      end

      # =======================================================================
      # :section:
      # =======================================================================

      protected

      # Debugging status information associated with a given debug context.
      #
      class Status

        # Keys which represent the activation status for the debugging context.
        ACTIVATION_KEYS = [:active, :this_class, :this_module].freeze

        # A table where each entry is a mapping of a method to an indication of
        # whether debugging is active for that method.
        #
        # @return [Hash{String=>Boolean}]
        attr_reader :setting

        # Initialize a self instance.
        #
        # @param [nil, Boolean, Hash{Symbol=>Boolean}] init_setting
        #
        def initialize(init_setting = nil)
          set(init_setting)
        end

        # =====================================================================
        # :section:
        # =====================================================================

        public

        # If *false* then no settings were provided in the initializer and
        # Debug#setup has not been run to finish the setup of this instance.
        #
        def initialized?
          @setting.present?
        end

        # If *true* then this is a special placeholder instance.
        #
        def readonly?
          @setting[:readonly]
        end

        # Indicates whether debugging is active for the associated debug
        # context.
        #
        # @return [Boolean]
        #
        def active
          @setting[:active]
        end

        # Set whether debugging is active.
        #
        # @param [Boolean] value
        #
        # @return [Boolean]
        #
        def active=(value)
          @setting[:active] = value unless readonly?
        end

        # Get debug setting.
        #
        # @param [Symbol] for_method
        #
        # @return [Boolean]
        # @return [nil]               If *for_method* is not a valid key.
        #
        def [](for_method)
          @setting[for_method.to_sym] if for_method.present?
        end

        # Set debug setting.
        #
        # @param [Symbol]  for_method
        # @param [Boolean] activated
        #
        # @return [Boolean]
        # @return [nil]               If *for_method* is not a valid key.
        #
        def []=(for_method, activated)
          return if for_method.blank?
          for_method = for_method.to_sym
          key = ACTIVATION_KEYS.include?(for_method) ? :active : for_method
          @setting[key] = activated unless readonly?
          @setting[key]
        end

        # Set multiple debug settings
        #
        # @param [nil, Boolean, Hash{Symbol=>Boolean}] init_setting
        #
        # @return [Hash{Symbol=>Boolean}] Updated settings.
        #
        def set(init_setting)
          @setting ||= {}
          case init_setting
            when true, false
              self[:active] = init_setting
            when Hash
              if init_setting[:readonly]
                init_setting = init_setting.except(:readonly)
                @setting[:readonly] = true
              else
                @setting[:active] = false
              end
              init_setting.each_pair do |for_method, active|
                self[for_method] = active
              end
          end
          @setting
        end

        # =====================================================================
        # :section: Status settings registry
        # =====================================================================

        public

        # Create debug status settings for a given type.
        #
        # @param [Object] key
        #
        # @return [Status]
        #
        def self.create(key)
          registry[key] ||= Debug::Status.new
        end

        # The table of debug contexts mapped to debug status settings.
        #
        # @return [Hash{String=>Status}]
        #
        # @see Registry#table
        #
        def self.registry
          Registry.instance.table
        end

        # A special Debug::Status instance used as a placeholder prior to
        # finalization of the debugging context for a class or module that
        # extends Debug.
        #
        # This is only used when debugging Debug or Debug::Status.
        #
        # @return [Status]
        #
        # @see Registry#null
        #
        def self.null
          Registry.instance.null
        end

        # A special Debug::Status instance used when the Debug feature is
        # disabled.
        #
        # @return [Status]
        #
        # @see Registry#disabled
        #
        def self.disabled
          Registry.instance.disabled
        end

        # =====================================================================
        # :section: Status settings registry
        # =====================================================================

        protected

        # Global singleton registry of debug contexts mapped to debug status
        # settings.
        #
        class Registry

          include Singleton

          # The table of debug contexts mapped to debug status settings.
          #
          # @return [Hash{String=>Status}]
          #
          def table
            @table ||= {}
          end

          # A special Debug::Status instance used as a placeholder prior to
          # finalization of the debugging context for a class or module that
          # extends Debug.
          #
          # This is only used when debugging Debug or Debug::Status.
          #
          # @return [Status]
          #
          def null
            @null ||= Debug::Status.new(readonly: true)
          end

        end

      end

    end

  end

end
