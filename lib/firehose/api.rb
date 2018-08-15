# lib/firehose/api.rb

require 'firehose/common'

# Firehose is the locally-created API service which interfaces with the
# Sirsi/Dynix Unicorn OPAC.
#
module Firehose

  # Firehose::API
  #
  module API

    include UVA
    include UVA::Cache

    extend self

    # For desktop development, proxy Firehose availability through a deployed
    # server host.
    #
    # This is a convenience for developer desktop execution at UVa (on Grounds
    # or via the VPN) so that availability can be displayed where expected and
    # doesn't just say "No information available at this time".
    #
    # === Usage Notes
    # Provide a hostname in the FIREHOSE_PROXY_HOST environment variable when
    # running the application to cause Firehose messages to be proxied.  The
    # implementation relies on your ability to `ssh` to that host.  If your
    # local user does not already have a trust relationship set up with the
    # account on the proxy host, set environment variable SSH_ASKPASS to "true"
    # to be prompted for a password.
    #
    PROXY_HOST = ENV['FIREHOSE_PROXY_HOST'].freeze
    PROXY_USER = ENV['FIREHOSE_PROXY_USER'].freeze

    # =========================================================================
    # :section:
    # =========================================================================

    public

    # Get data from Firehose.
    #
    # @param [Array<String>] args     Path components to Firehose API; if the
    #                                   last is a Hash, it is passed as the
    #                                   options to the cache #fetch.
    #
    # @return [String]
    # @return [nil]
    #
    # @see ActiveSupport::Cache::Store#fetch
    #
    # === Usage Notes
    # To perform quick desktop testing, `cache_params` can be modified to
    # indicate that a file should be used as the source of data instead of
    # contacting Firehose.  E.g.:
    #
    #   cache_params.merge!(file: 'test/fixtures/mst3k_account.xml')
    #
    # directly before `cache_fetch` will return the contents of that XML file
    # instead of your own Sirsi account information.
    #
    def get(*args)
      opt = (args.pop if args.last.is_a?(Hash))
      args.unshift(FIREHOSE_URL) unless args.first.include?('//')
      action = args[1]
      url = File.join(*args)
      uri = URI.parse(url)
      cache_params = API.generate_cache_params(action, uri)
      cache_params.merge!(opt) if opt.present?
      cache_fetch(cache_params) do
        proxy_get(uri) || uri.read
      end
    end

    # Post data to Firehose.
    #
    # @param [Array<String>] args     Path components to Firehose API; the last
    #                                   should be a Hash containing the data
    #                                   items to send.
    #
    # @return [Net::HTTPResponse]
    # @return [nil]
    #
    def post(*args)
      http_params = args.last.is_a?(Hash) ? args.pop : {}
      args.unshift(FIREHOSE_URL) unless args.first.include?('//')
      url = File.join(*args)
      uri = URI.parse(url)
      proxy_post(uri, http_params) || Net::HTTP.post_form(uri, http_params)
    end

    # Discard cached data from Firehose.
    #
    # @param [Array<String>] args     Path components to Firehose API; if the
    #                                   last is a Hash, it is passed as the
    #                                   options to the cache #fetch.
    #
    # @return [String]
    # @return [nil]
    #
    # @see ActiveSupport::Cache::Store#fetch
    #
    def discard(*args)
      opt = (args.pop if args.last.is_a?(Hash))
      args.unshift(FIREHOSE_URL) unless args.first.include?('//')
      action = args[1]
      url = File.join(*args)
      uri = URI.parse(url)
      cache_params = API.generate_cache_params(action, uri)
      cache_params.merge!(opt) if opt.present?
      cache_discard(cache_params)
    end

    # =========================================================================
    # :section:
    # =========================================================================

    protected

    # Get data via proxy host.
    #
    # @param [String] url
    #
    # @return [String]
    # @return [nil]
    #
    # @see self#PROXY_HOST
    #
    def proxy_get(url)
      return if PROXY_HOST.blank?
      proxy_run(%Q(curl -s -S "#{url}"))
    end

    # Post data via proxy host.
    #
    # @param [String] url
    # @param [Hash]   http_params
    #
    # @return [Net::HTTPResponse]
    # @return [nil]
    #
    # @see self#PROXY_HOST
    #
    def proxy_post(url, http_params)
      return if PROXY_HOST.blank?
      proxy_run(%Q(curl -s -S -X POST -d "#{http_params.to_param}" "#{url}"))
    end

    # Run a command on the proxy host.
    #
    # @param [String] command
    #
    # @return [String]
    #
    def proxy_run(command)
      ssh = %w(ssh -n -T -o PermitLocalCommand=no)
      ssh += %W(-l #{PROXY_USER}) unless PROXY_USER.blank?
      ssh << PROXY_HOST
      ssh << %Q('#{command}')
      ssh = ssh.join(' ')
      `#{ssh}`
    end

    # =========================================================================
    # :section:
    # =========================================================================

    private

    class << self

      include UVA
      include UVA::Cache

      DEFAULT_CACHE_OPT = {
        namespace:  'FIREHOSE',
        expires_in: FAST_EXPIRE,
      }.deep_freeze

      # generate_cache_params
      #
      # @param [String]               action
      # @param [String, URI::Generic] url
      # @param [Hash]                 cache_opt   Caching options.
      #
      # @return [Hash]
      #
      def generate_cache_params(action, url, cache_opt = nil)

        # Extract cache-specific options; what remains in *search_params* will
        # be used to generate the cache key.
        cache_opt = extract_cache_options(cache_opt)
        method = caller[0].to_s.sub(/^[^`]+`/, '').sub(/'$/, '')
        method = (cache_opt[:calling_method] ||= method)
        unless cache_opt[:expires_in]
          case action
            when 'users' then cache_opt[:expires_in] = INSTANT_EXPIRE
            when 'list'  then cache_opt[:expires_in] = SLOW_EXPIRE
          end
        end

        # Generate the cache key.
        cache_key = url.to_s.gsub(%r(^#{FIREHOSE_URL}/), '')

        # Generate the rest of the cache options.
        Cache.log(:debug, method) { "KEY => #{cache_key}" }
        DEFAULT_CACHE_OPT.merge(cache_key: cache_key)

      end

    end

  end

end
