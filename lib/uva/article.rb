# lib/uva/article.rb

require 'uva'

module UVA

  # Switcher between article search provider engines.
  #
  # === Usage Notes
  # To enable switching between article search providers, place the line
  # <code><b>
  #   AE_ON = true
  # </b></code>
  # in the app/config/environments/*.rb file(s) for the execution environments
  # that should display the article-switcher UI on the main page page.
  #
  module Article

    include UVA

    # One time only: autoload all modules from "lib/uva/article".
    # (Loading of an article engine is deferred until its first use.)
    LIB_UVA_ARTICLE_AUTOLOADS ||= {
      Ebsco:  'uva/article/ebsco',
      Primo:  'uva/article/primo',
      Summon: 'uva/article/summon',
    }.each_pair { |name, path| autoload(name, path) }

    # Currently implemented article engines.
    #
    PROVIDERS = [
      (EBSCO  = 'ebsco'),
      (PRIMO  = 'primo'),
      (SUMMON = 'summon'),
    ].deep_freeze

    # Labels for article engine selectors.
    #
    # @see app/views/catalog/_search_box.html.erb
    #
    PROVIDER_LABELS = {
      EBSCO  => 'EBSCO',
      PRIMO  => 'Primo',
      SUMMON => 'Summon'
    }.deep_freeze

    # The current default (and only) active article provider.
    #
    DEFAULT_PROVIDER = EBSCO

    # =========================================================================
    # :section: Module methods
    # =========================================================================

    protected

    class << self

      # Indicate whether the UI for article provider switching is enabled.
      #
      # See the Usage section of the module documentation for details.
      #
      def switching_enabled?
        defined?(AE_ON) && AE_ON
      end

      # The current article engine.
      #
      # @return [Module]
      # @return [nil]
      #
      # @see self#set_engine
      #
      def engine
        @engine ||= nil
      end

      # The identifier of the current article provider.
      #
      # @return [String]
      # @return [nil]
      #
      def provider
        engine.provider if engine
      end

      # The name of the current article provider.
      #
      # @return [String]
      # @return [nil]
      #
      def provider_label
        engine.label if engine
      end

      # The currently-chosen article provider (to support radio button UI
      # selection).
      #
      # If an article engine has not been activated, this value is reported as
      # the default provider.
      #
      # @return [String]
      #
      # @see self#provider
      #
      def selected_provider
        provider || DEFAULT_PROVIDER
      end

      # Set the current article provider.
      #
      # If *article_provider* is different than the current provider, a change
      # will be made.  If *article_provider* is *nil* and there is no current
      # provider then *DEFAULT_PROVIDER* will be used.
      #
      # @param [String] new_provider
      #
      # @return [void]
      #
      # @see self#start_engine
      #
      def set_engine(new_provider = nil)
        new_provider = DEFAULT_PROVIDER unless Article.switching_enabled?
        new_provider ||= selected_provider
        unless new_provider == provider
          Rails.logger.warn {
            "ARTICLES - switching from #{provider} to #{new_provider}"
          } if provider
          @engine =
            case new_provider
              when EBSCO  then Ebsco
              when PRIMO  then Primo
              when SUMMON then Summon
              else raise "Invalid article provider #{new_provider.inspect}"
            end
          @engine.setup
        end
        @engine
      end

    end

    # =========================================================================
    # :section: Article Engine interface
    # =========================================================================

    public

    # Interface definitions for article engine modules.
    #
    # === Usage
    # At the top of the article engine module definition add the line:
    #
    #   include UVA
    #   include UVA::Article
    #   extend UVA::Article::Engine
    #
    # which provides default definitions and assures that the article engine
    # implements the expected methods.
    #
    # === Implementation Notes
    # This should probably be renamed, since the term might suggest to some
    # that this has something to do with Rails "Engines", which it definitely
    # does not.
    #
    module Engine

      require 'xml/mapping'

      include UVA
      include UVA::Article

      # =======================================================================
      # :section:
      # =======================================================================

      public

      # The article provider identifier for this article engine.
      #
      # @return [String]
      #
      def provider(*)
        Rails.logger.error { "ARTICLES - #{__method__}" }
        raise 'Must be overridden'
      end

      # The name of the article provider for this article engine.
      #
      # @return [String]
      #
      def label(*)
        PROVIDER_LABELS[provider]
      end

      # Perform any initializations required before the article engine is ready
      # for use (that is, before the first invocation of #start_session).
      #
      # @return [void]
      #
      def setup(*)
        Rails.logger.debug { "ARTICLES - #{label} #{__method__}" }
        nil
      end

      # Perform any actions required before removing the article engine (that
      # is, after the final invocation of #stop_session).
      #
      # @return [void]
      #
      def teardown(*)
        Rails.logger.debug { "ARTICLES - #{label} #{__method__}" }
        nil
      end

      # Start a session with the article provider.
      #
      # For providers that do not support client sessions, the default method
      # implementation does nothing.
      #
      # @param [Boolean] is_guest
      #
      # @return [Hash]                New session headers.
      # @return [nil]                 If a session could not be established.
      #
      def start_session(is_guest, *)
        Rails.logger.debug { "ARTICLES - #{label} #{__method__}(#{is_guest})" }
        nil
      end

      # Stop the current session with the article provider.
      #
      # For providers that do not support client sessions, the default method
      # implementation does nothing.
      #
      # @param [Hash] headers
      #
      # @return [String]              Return from the provider in JSON format.
      # @return [nil]                 If there was a problem
      #
      def stop_session(headers, *)
        Rails.logger.debug { "ARTICLES - #{label} #{__method__}(#{headers})" }
        nil
      end

      # =======================================================================
      # :section: Search and access
      # =======================================================================

      public

      # Look up a specific article.
      #
      # @param [String] article_id
      # @param [Hash]   search_params
      #
      # @return [Array<(ArticleDoc::Response, Array<ArticleDoc>)>]
      # @return [Array<(ArticleDoc::Response, nil)>]  Error; one of:
      #   *article_ids* blank
      #   *search_params* :headers blank or missing
      #   Search failure
      #
      def get_article_by_id(article_id, search_params)
        Rails.logger.error { "#{__method__}(#{article_id}, #{search_params})" }
        raise 'Must be overridden'
      end

      # Perform an article search via the article provider.
      #
      # @param [Hash] search_params
      #
      # @return [Array<(ArticleDoc::Response, Array<ArticleDoc>)>]
      # @return [Array<(ArticleDoc::Response, nil)>]  Error
      #
      def get_article_search_results(search_params)
        Rails.logger.error { "#{__method__}(#{search_params})" }
        raise 'Must be overridden'
      end

      # Translate a search field name (as configured in ArticlesController)
      # into a facet value specific to the article provider.
      #
      # @param [String] name
      #
      # @return [String]
      #
      def search_field(name)
        Rails.logger.error { "#{__method__}(#{name})" }
        raise 'Must be overridden'
      end

      # Translate a date into the form required for queries to the article
      # provider.
      #
      # @param [Array<String>] args   First argument is the original date; if
      #                                 a second is provided it is used as an
      #                                 indicator of the month (either a number
      #                                 from 1 to 12, a string, or :start for
      #                                 start of year or :end for end of year).
      #
      # @return [String]
      #
      def date_format(*args)
        Rails.logger.error { "#{__method__}(#{name})" }
        raise 'Must be overridden'
      end

      # =======================================================================
      # :section: Logging
      # =======================================================================

      public

      # Update the log based on the type of error that has been handled.
      #
      # @param [Symbol]    method     Usually the caller's *__method__* value.
      # @param [Exception] e
      # @param [String, Net::HTTPResponse] data
      #
      # @return [nil]
      #
      def log_error(method, e, data = nil)
        return if Rails.logger.level > Logger::INFO

        # A SilentError makes use of a rescue block without needing or wanting
        # any log entry.
        return if e.is_a?(SilentError)

        # At minimum, a simple error report for all error types;
        # an InternalError needs only this log entry.
        Rails.logger.info("ARTICLES - #{method}: #{e.message}")
        return if e.is_a?(InternalError) || e.is_a?(Timeout::Error)

        # A backtrace for errors external to this class.
        case e
          when RequestError
            backtrace = false
            data ||= e.response
            data = nil if ignorable_error(data)
          when ParseError
            backtrace = false
            data ||= e.source
          else
            backtrace = true
        end
        Rails.logger.info(e.backtrace.join(NEWLINE)) if backtrace

        # Finally, a dump of the data if it was provided.
        return unless data
        info = []
        info << "ARTICLES >>> #{label} response BEGIN =========="
        case data
          when String, Array, Hash
            info << data.to_s
          when Net::HTTPResponse
            info << data.inspect
            info << data.body
          when REXML::Element
            formatted_xml = ''
            REXML::Formatters::Pretty.new.write(data, formatted_xml)
            info << formatted_xml
          else
            info << "#{data.class}:"
            info << data.inspect
        end
        info << "ARTICLES <<< #{label} response END ============"
        Rails.logger.info(info.compact.join(NEWLINE))
        nil
      end

      # =======================================================================
      # :section: Logging
      # =======================================================================

      protected

      # Indicate whether the response error is one that doesn't require a
      # backtrace.
      #
      # @param [Net::HTTPResponse] _http_response
      #
      # @return [Boolean]
      #
      def ignorable_error(_http_response)
        # May be overridden.
      end

    end

    # =========================================================================
    # :section: Common data item definitions
    # =========================================================================

    public

    # UVA::Article::FacetItem functions as an interchangeable replacement for
    # @see RSolr::Ext::Response::Facets::FacetItem
    #
    # @attribute [String] value
    # @attribute [Fixnum] hits
    #
    class FacetItem

      include UVA::Util

      # @return [String]
      attr_accessor :value

      # @return [Fixnum]
      attr_accessor :hits

      # Initialize new self instance.
      #
      # @param [String] v
      # @param [Fixnum] h
      #
      def initialize(v = nil, h = nil)
        @value = v
        @hits  = h.to_i
      end

      # =======================================================================
      # :section:
      # =======================================================================

      public

      # display_value
      #
      # @param [String, Symbol] facet_name
      #
      # @return [ActiveSupport::SafeBuffer]
      #
      def display_value(facet_name = nil)
        facet_name &&= facet_name.to_sym
        result = (facet_name == :tlevel) ? @value.titlecase : titleize(@value)
        ERB::Util.h(result).gsub(/\s*--\s*/, EM_DASH).html_safe
      end

    end

    # UVA::Article::FacetField functions as an interchangeable replacement for
    # @see RSolr::Ext::Response::Facets::FacetField
    #
    # @attribute [String]           name
    # @attribute [Array<FacetItem>] items
    #
    class FacetField

      # @return [String]
      attr_accessor :name

      # @return [Array<FacetItem>]
      attr_accessor :items

      # Initialize new self instance.
      #
      # @param [String]           n
      # @param [Array<FacetItem>] i
      #
      def initialize(n = nil, i = nil)
        @name  = n
        @items = Array(i).compact
      end

      # =======================================================================
      # :section:
      # =======================================================================

      public

      # display_values
      #
      # @return [Array<String>]
      #
      def display_values
        @items.map { |item| item.display_value(@name) }
      end

    end

    # =========================================================================
    # :section: Exceptions
    # =========================================================================

    public

    # UVA::Article::InternalError
    #
    class InternalError < RuntimeError
    end

    # UVA::Article::SilentError
    #
    class SilentError < InternalError
    end

    # UVA::Article::ParseError
    #
    class ParseError < RuntimeError

      # @return [String]
      attr_reader :source

      # Initialize a new self instance.
      #
      # @param [String] source
      #
      def initialize(source = nil)
        @source = source || ''
        super('invalid response from article provider')
      end

    end

    # UVA::Article::RequestError
    #
    class RequestError < RuntimeError

      # @return [Net::HTTPResponse]
      attr_reader :response

      # Initialize a new self instance.
      #
      # @param [Net::HTTPResponse] response
      #
      def initialize(response)
        @response = response
        super(@response.inspect)
      end

    end

    # UVA::Article::Engine::ResponseError
    #
    class ResponseError < RuntimeError

      # Initialize a new self instance.
      #
      # @param [String] msg
      #
      def initialize(msg = nil)
        msg ||= 'empty response from article provider'
        super(msg)
      end

    end

  end

end
