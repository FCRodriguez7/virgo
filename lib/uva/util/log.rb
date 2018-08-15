# lib/uva/util/log.rb

require 'uva/util'

module UVA::Util

  module Log

    extend self

    # =========================================================================
    # :section: Console output
    # =========================================================================

    public

    # Send output to the console (i.e. $stderr).
    #
    # @param [Array<String>] args
    #
    # @return [nil]
    #
    def console_output(*args, &block)
      args = make_lines(args, &block)
      return if args.empty?
      log_flush
      $stderr.puts(*args)
    end

    # =========================================================================
    # :section: Logging
    # =========================================================================

    public

    # A "sink" for method arguments that are intentionally unused but are
    # required to exist in the argument list for external reasons.
    #
    # @return [nil]
    #
    # === Usage Notes
    # Prefixing the name of an item with underscore is the typical Ruby
    # convention for indicating that the item is intentionally unused; RubyMine
    # and Rubocop honor this and won't flag the unused item as an error.
    #
    # If there are reasons why prefixing the name with an underscore is
    # problematic, the alternative is to "feed" the arguments to this method
    # so that they do not appear to be ignored.
    #
    def unused(*)
    end

    # Send output to the log file.
    #
    # @param [Array<String>] args
    #
    # @return [nil]
    #
    def log_debug(*args, &block)
      return if Logger::Severity::DEBUG < Rails.logger.level
      args = make_lines(args, &block)
      return if args.empty?
      Rails.logger.debug(args.join("\n"))
      log_flush
    end

    # Flush buffered log content.
    #
    # (This does nothing if `Rails.logger` is not buffered.)
    #
    # @return [nil]
    #
    def log_flush
      Rails.logger.flush if Rails.logger.respond_to?(:flush)
      nil
    end

    # =========================================================================
    # :section:
    # =========================================================================

    private

    # Each array element becomes a separate line; embedded newlines result in
    # new array elements.
    #
    # @param [Array<String>] args
    #
    # @return [Array<String>]
    #
    def make_lines(args, &block)
      delta_t = Time.gm(0) + (Time.now - BOOT_TIME)
      args += Array(yield) if block_given?
      args = args.join("\n").split("\n")
      first = args.find_index(&:present?)
      args[first] = "#{delta_t.strftime('%T.%L')} #{args[first]}" if first
      args
    end

  end

end
