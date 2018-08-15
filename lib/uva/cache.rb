# lib/uva/cache.rb

require 'active_support/cache'
require 'digest'
require 'uva'

module UVA

  # UVA::Cache
  #
  # === Implementation Notes
  # This requires a "monkey patch" to ActiveSupport::Cache::Entry#value so that
  # cached results are not returned frozen.
  #
  # @see config/initializers/activesupport_cache.rb
  #
  module Cache

    include UVA

    # If *true* then caching is not performed; if *false* (or missing) then
    # caching is performed.
    CACHING_DISABLED = false

    # Used for caching of information that changes slowly.
    #
    # This value should be long enough to get the advantage of caching when
    # scanning back and forth through virtual shelf browse or multiple pages of
    # search results, but short enough that changes to the Solr and/or EBSCO
    # indexes will be evident over time.
    #
    SLOW_EXPIRE = 1.hour

    # Used for caching of information related to availability.
    #
    # This value should be long enough to get the advantage of caching when
    # performing multiple operations on the items of a search results page, but
    # short enough that changes in item status will be evident over time.
    #
    FAST_EXPIRE = 5.minutes

    # Used for caching of information related to account data.
    #
    # This value is a trade-off that provides a little bit of the advantage of
    # caching when rapidly cross-checking account information, but short enough
    # that status changes will be evident quickly.
    #
    INSTANT_EXPIRE = 5.seconds

    # Internally defined option keys.
    INTERNAL_CACHE_OPTIONS = %w(
      cache
      cache_key
      calling_method
      on_hit
      on_miss
      report
    ).map(&:to_sym).freeze

    # Rails.cache option keys.
    RAILS_CACHE_OPTIONS = %w(
      namespace
      expires_in
    ).map(&:to_sym).freeze

    # Option keys.
    CACHE_OPTIONS = (INTERNAL_CACHE_OPTIONS + RAILS_CACHE_OPTIONS).freeze

    # =========================================================================
    # :section:
    # =========================================================================

    public

    # Indicates whether caching is in effect.
    #
    def caching_enabled?
      Cache.enabled?
    end

    # Fetch an item from the cache if it is present, or acquire it from the
    # provided block if it is not.
    #
    # @param [Array] args             If the first argument is a String it is
    #                                 used as the cache key in preference to
    #                                 the :cache_key option.
    #
    # @option args.last [String]  :cache_key
    # @option args.last [Symbol]  :calling_method
    # @option args.last [Proc]    :on_hit
    # @option args.last [Proc]    :on_miss
    # @option args.last [Boolean] :report
    # @option args.last [Symbol]  :file
    #
    # The :file option can be used to support testing by naming a file as the
    # data source instead of a network service.
    #
    # @yieldreturn [Object]
    # If a block is provided, its return value is cached and the cached value
    # will be unmarshalled the next time this key is fetched.
    #
    # @return [Object]
    #
    def cache_fetch(*args, &block)

      # Extract options.
      cache_opt = { expires_in: FAST_EXPIRE }
      cache_opt.merge!(args.pop) if args.last.is_a?(Hash)
      no_cache = cache_opt.key?(:cache) && !cache_opt.delete(:cache)
      caching  = !no_cache && caching_enabled?

      # Get parameters, remove locally-defined options and pass the rest to
      # `Rails.cache`.
      cache_key = cache_opt.delete(:cache_key)
      cache_key = args.shift if args.present?
      on_hit    = cache_opt.delete(:on_hit)
      on_miss   = cache_opt.delete(:on_miss)
      report    = cache_opt.delete(:report)
      filename  = cache_opt.delete(:file)
      method    = cache_opt.delete(:calling_method)
      method  ||= caller[0].to_s.sub(/^[^`]+`/, '').sub(/'$/, '')

      if filename
        # Use the file as the source of data instead of a network service.
        Cache.log(:warn, method) { "FROM #{filename.inspect}" }
        File.read(filename)

      elsif !caching
        # If not caching, execute the block directly.
        Cache.log(:debug, method) { 'UNCACHED' }
        yield

      elsif (result = Rails.cache.fetch(cache_key, cache_opt))
        # If fetching the named value from the cache succeeds then there is no
        # need to execute the block.
        Cache.log(:info, method) { "HIT KEY ==> #{cache_key}" }
        on_hit ? on_hit.call(result) : result

      else
        # If the named value was not in the cache, execute the block to acquire
        # the data.
        Cache.log(:info, method) { "MISS KEY => #{cache_key}" }
        result = cache_get(cache_key, cache_opt, method, report, &block)
        on_miss ? on_miss.call(result) : result

      end

    end

    # Remove an item from the cache.
    #
    # @param [Array] args
    #
    # @return [Boolean]
    #
    def cache_discard(*args)

      # Extract options, removing the locally-defined options and passing the
      # rest to `Rails.cache`.
      cache_opt = { expires_in: FAST_EXPIRE }
      cache_opt.merge!(args.pop) if args.last.is_a?(Hash)
      return if cache_opt.key?(:cache) && !cache_opt.delete(:cache)
      cache_key = cache_opt.delete(:cache_key)
      cache_key = args.shift if args.present?
      method    = cache_opt.delete(:calling_method) || cache_caller
      method  ||= caller[0].to_s.sub(/^[^`]+`/, '').sub(/'$/, '')
      INTERNAL_CACHE_OPTIONS.each { |k| cache_opt.delete(k) }

      # Attempt to remove the named value from the cache.
      cache_key = /^#{cache_key}$/
      return unless Rails.cache.delete_matched(cache_key, cache_opt)
      Cache.log(:info, method) { "DELETE KEY => #{cache_key}" }
      true
    end

    # extract_cache_options
    #
    # @param [Hash] opt               Source hash, which may be modified.
    #
    # @return [Hash]                  New hash
    #
    def extract_cache_options(opt)
      opt ? opt.extract!(*CACHE_OPTIONS).reject { |_, v| v.nil? } : {}
    end

    # cache_caller
    #
    # @param [Fixnum] level           Default: 1.
    #
    # @return [String]
    #
    def cache_caller(level = 1)
      caller[level].to_s.sub(/^[^`]+`/, '').sub(/'$/, '')
    end

    # =========================================================================
    # :section:
    # =========================================================================

    protected

    # Atomic get
    #
    # @param [String]  cache_key
    # @param [Hash]    cache_opt
    # @param [Symbol]  method         Calling method.
    # @param [Boolean] report         Report timing to log.
    #
    # @return [Object]
    #
    def cache_get(cache_key, cache_opt, method, report, &block)
      start_time = Time.current
      Rails.cache.fetch(cache_key, cache_opt, &block).tap do
        Rails.logger.info {
          elapsed_time = (Time.current.to_f - start_time.to_f) * 1000
          sprintf("#{method} fetch in %.1f ms", elapsed_time)
        } if report
      end
    rescue => e
      Cache.log(:info, method) { "DISCARD KEY => #{cache_key} AFTER #{e}" }
      Rails.cache.delete(cache_key, cache_opt)
      raise e
    end

    # =========================================================================
    # :section: Class methods
    # =========================================================================

    public

    ERROR_LEVELS = %w(debug info warn error fatal unknown).deep_freeze

    # Log a cache event.
    #
    # @param [Array] args             First argument is the optional severity
    #                                   level (either Numeric or Symbol), then
    #                                   the calling method followed by zero or
    #                                   more strings.
    #
    # @return [nil]
    #
    def self.log(*args, &block)

      # Extract severity level if present.
      severity =
        if args.first.is_a?(Numeric)
          args.shift
        elsif ERROR_LEVELS.include?(args.first.to_s)
          ERROR_LEVELS.index(args.shift.to_s)
        end
      severity ||= Logger::Severity::UNKNOWN
      return if Rails.logger.level > severity

      # The next argument is the calling method.  Combine any
      # remaining arguments and any string(s) from the block.
      message = ['==== CACHE']
      message << "#{args.shift}:"
      message += args
      message += Array(yield) if block_given?
      Rails.logger.add(severity, message.compact.join(' ')) && nil

    end

    # Indicates whether caching is in effect.
    #
    def self.enabled?
      !defined?(CACHING_DISABLED) || !CACHING_DISABLED
    end

    # =========================================================================
    # :section: Initialization
    # =========================================================================

    # In order for Marshal to be able to handle SolrDocument, it has to be
    # loaded in the context of the cache.
    if enabled?
      Rails.cache.require(Rails.root.join('app/models/solr_document'))
    end

  end

end
