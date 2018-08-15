# lib/uva/article/primo.rb

require 'uva'

module UVA::Article

  # Support for using ExLibris Primo as an article search provider.
  #
  # NOTE: This module has not been fully retested since the refactoring.
  #
  module Primo

    require 'happymapper'

    include UVA
    include UVA::Article
    include UVA::Helper::Facets

    extend UVA::Article::Engine

    # =========================================================================
    # :section:
    # =========================================================================

    public

    # Primo only allows access to the first 2000 results in any result set.
    PRIMO_MAX_ACCESSIBLE_RESULTS = 2000

    NS_SEARCH = 'http://www.exlibrisgroup.com/xsd/jaguar/search'.freeze
    NS_PRIMO  = 'http://www.exlibrisgroup.com/xsd/primo/primo_nm_bib'.freeze

    SEARCH_FIELD_MAP = {
      'keyword'          => 'any',
      'author'           => 'creator',
      'title'            => 'title',
      'journal'          => 'jtitle',
      'publication_date' => 'creationdate',
      'subject'          => 'sub',
    }.deep_freeze

    DEFAULT_SEARCH_FIELD = 'any'.freeze

    # =========================================================================
    # :section: Data items
    # =========================================================================

    public

    # @see UVA::Article::FacetItem
    #
    # @attr [Integer] hits
    # @attr [String]  value
    #
    # Compare with:
    # @see UVA::Article::Primo::Item
    # @see UVA::Article::Ebsco::Item
    # @see UVA::Article::Summon::Item
    #
    class Item < UVA::Article::FacetItem

      include HappyMapper

      register_namespace 'sear', NS_SEARCH
      register_namespace 'prim', NS_PRIMO

      tag 'FACET_VALUES'

      namespace 'sear'

      attribute :hits, Integer, tag: 'VALUE'
      attribute :value, String, tag: 'KEY'

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
      def display_value(facet_name)
        if (facet_name.to_s == 'lang') && LANGUAGES.key?(@value.downcase)
          ERB::Util.h(LANGUAGES[@value.downcase])
        else
          super
        end
      end

    end

    # @see UVA::Article::FacetField
    #
    # @attr [Integer]     hits
    # @attr [String]      name
    # @attr [Array<Item>] items
    #
    # Compare with:
    # @see UVA::Article::Primo::Facet
    # @see UVA::Article::Ebsco::Facet
    # @see UVA::Article::Summon::Facet
    #
    class Facet < UVA::Article::FacetField

      include HappyMapper

      register_namespace 'sear', NS_SEARCH
      register_namespace 'prim', NS_PRIMO

      tag 'FACET'

      namespace 'sear'

      attribute :hits, Integer, tag: 'COUNT'
      attribute :name, String,  tag: 'NAME'

      # @return [Array<Item>]
      has_many :items, Item, namespace: 'sear', tag: 'FACET_VALUES'

    end

    # UVA::Article::Primo::Counts
    #
    # @param [Integer] hits
    # @param [Integer] first_hist
    # @param [Integer] last_hist
    #
    # Compare with:
    # @see UVA::Article::Primo::Counts
    # @see UVA::Article::Ebsco::Statistics
    #
    class Counts

      include HappyMapper

      register_namespace 'sear', NS_SEARCH
      register_namespace 'prim', NS_PRIMO

      tag 'DOCSET'

      namespace 'sear'

      attribute :hits,      Integer, tag: 'TOTALHITS'
      attribute :first_hit, Integer, tag: 'FIRSTHIT'
      attribute :last_hit,  Integer, tag: 'LASTHIT'

    end

    # UVA::Article::Primo::GetIt
    #
    # @attr [String] get_it_1
    # @attr [String] get_it_2
    # @attr [String] delivery_category
    #
    class GetIt

      include HappyMapper

      register_namespace 'sear', NS_SEARCH
      register_namespace 'prim', NS_PRIMO

      tag 'GETIT'

      namespace 'sear'

      attribute :get_it_1,          String, tag: 'GetIt1'
      attribute :get_it_2,          String, tag: 'GetIt2'
      attribute :delivery_category, String, tag: 'deliveryCategory'

    end

    # =========================================================================
    # :section: ArticleDoc implementation
    # =========================================================================

    public

    # UVA::Article::Primo::Document
    #
    # Compare with:
    # @see UVA::Article::Primo::Document
    # @see UVA::Article::Ebsco::Document
    # @see UVA::Article::Summon::Document
    #
    class Document

      include HappyMapper
      include UVA::ArticleDoc

      register_namespace 'sear', NS_SEARCH
      register_namespace 'prim', NS_PRIMO

      tag 'DOC'

      namespace 'sear'

      # @return [Display]
      has_one :display,         Display,        tag: 'display', deep: 'true'

      # @return [AdditionalData]
      has_one :additional_data, AdditionalData, tag: 'addata',  deep: 'true'

      # @return [Search]
      has_one :search,          Search,         tag: 'search',  deep: 'true'

      # @return [Array<Link>]
      has_many :links,          Link,           tag: 'LINKS',   deep: 'true'

      # @return [Array<GetIt>]
      has_many :get_its,        GetIt,          tag: 'GETIT'

      # =======================================================================
      # :section: RSolr::Ext::Model interface
      # =======================================================================

      public

      # @see UVA::IndexDoc#id
      #
      def id
        search.id
      end

    end

    # =========================================================================
    # :section: Common article data classes
    # =========================================================================

    public

    # UVA::Article::Primo::Display
    #
    # @attr [String] creator
    # @attr [String] identifier
    # @attr [String] is_part_of
    # @attr [String] language
    # @attr [String] lds50
    # @attr [String] source
    # @attr [String] subject
    # @attr [String] title
    # @attr [String] type
    # @attr [String] version
    #
    # Compare with:
    # @see UVA::Article::Primo::Display
    # @see UVA::Article::Ebsco::Display
    # @see UVA::Article::Summon::Display
    #
    class Display < UVA::ArticleDoc::Display

      include HappyMapper
      include UVA

      register_namespace 'sear', NS_SEARCH
      register_namespace 'prim', NS_PRIMO

      tag 'display'

      namespace 'prim'

      element :creator,    String
      element :identifier, String
      element :is_part_of, String, tag: 'ispartof'
      element :language,   String
      element :lds50,      String
      element :source,     String
      element :subject,    String
      element :title,      String
      element :type,       String
      element :version,    String

      # @return [Array<String>]
      has_many :description, String, tag: 'description'

      # =======================================================================
      # :section:
      # =======================================================================

      public

      # identifier
      #
      # @return [String]
      #
      def identifier
        @identifier.gsub(/<\/?b>/, '')
      end

    end

    # UVA::Article::Primo::AdditionalData
    #
    # @attr [String] journal
    # @attr [String] volume
    # @attr [String] issue
    # @attr [String] start_page
    # @attr [String] end_page
    #
    # Compare with:
    # @see UVA::Article::Primo::AdditionalData
    # @see UVA::Article::Ebsco::AdditionalData
    # @see UVA::Article::Summon::AdditionalData
    #
    class AdditionalData < UVA::ArticleDoc::AdditionalData

      include HappyMapper

      register_namespace 'sear', NS_SEARCH
      register_namespace 'prim', NS_PRIMO

      tag 'addata'

      namespace 'prim'

      element :journal,    String, tag: 'jtitle'
      element :volume,     String
      element :issue,      String
      element :start_page, String, tag: 'spage'
      element :end_page,   String, tag: 'epage'

    end

    # UVA::Article::Primo::Search
    #
    # @attr [String] creation_date
    # @attr [String] id
    #
    # Compare with:
    # @see UVA::Article::Primo::Search
    # @see UVA::Article::Ebsco::Search
    # @see UVA::Article::Summon::Search
    #
    class Search < UVA::ArticleDoc::Search

      include HappyMapper

      register_namespace 'sear', NS_SEARCH
      register_namespace 'prim', NS_PRIMO

      tag 'search'

      namespace 'prim'

      element :creation_date,  String, tag: 'creationdate'
      element :id,             String, tag: 'recordid'

      # @return [Array<String>]
      has_many :subject_facet, String, tag: 'subject'

    end

    # UVA::Article::Primo::Link
    #
    # @attr [String] back_link
    # @attr [String] thumbnail
    # @attr [String] url
    #
    # Compare with:
    # @see UVA::Article::Primo::Link
    # @see UVA::Article::Ebsco::Link
    # @see UVA::Article::Summon::Link
    #
    class Link < UVA::ArticleDoc::Link

      include HappyMapper

      register_namespace 'sear', NS_SEARCH
      register_namespace 'prim', NS_PRIMO

      tag 'LINKS'

      namespace 'sear'

      element :url,       String, tag: 'openurlfulltext'
      element :back_link, String, tag: 'backlink'
      element :thumbnail, String

      # =======================================================================
      # :section:
      # =======================================================================

      public

      def default_text
        Primo.label
      end

    end

    # UVA::Article::Primo::Response
    #
    # Compare with:
    # @see UVA::Article::Primo::Response
    # @see UVA::Article::Ebsco::Response
    # @see UVA::Article::Summon::Response
    #
    class Response < UVA::ArticleDoc::Response

      include HappyMapper
      include UVA::Scope

      # Register the namespaces used by PRIMO.  Also register the default xmlns
      # namespace to be the PRIMO 'sear' namespace.
      register_namespace 'xmlns', NS_SEARCH
      register_namespace 'sear',  NS_SEARCH
      register_namespace 'prim',  NS_PRIMO

      tag 'JAGROOT'

      namespace 'sear'

      # @return [Counts]
      has_one :counts, Counts, tag: 'DOCSET', deep: 'true'

      # @return [Array<Facet>]
      has_many :facets, Facet, tag: 'FACET', deep: 'true'

      # @return [Array<Document>]
      has_many :docs, Document, tag: 'DOC', deep: 'true'

      # =======================================================================
      # :section:
      # =======================================================================

      public

      # Initialize a new self instance.
      #
      def initialize
        super(UVA::Article::PRIMO)
      end

      # Wipe data and set an error code.
      #
      # @param [Fixnum] code
      #
      def reset(code = nil)
        super(code)
        @counts = 0
        @facets = []
        @docs   = []
      end

      # total
      #
      # (For Kaminari)
      #
      # @return [Fixnum]
      #
      def total
        @counts ? @counts.hits : 0
      end

      # =======================================================================
      # :section:
      # =======================================================================

      public

      # This is similar to the Blacklight method but modified to limit access
      # via the Kaminari paginator to no more results than is permitted for
      # articles.
      #
      # @return [PageScope]
      #
      # @see UVA::ArticleDoc::Response#paginate_values
      # @see UVA::Article::Summon::Response#paginate_values
      #
      # Compare with:
      # @see Blacklight::CatalogHelperBehavior#paginate_params
      #
      def paginate_values
        per_page = rows
        per_page = 1 if per_page < 1
        current_page = (start / per_page).ceil + 1
        num_pages = (total / per_page.to_f).ceil

        # Do not let the Kaminari paginator offer pages beyond what the article
        # provider permits. We will accomplish this by modifying the num_pages
        # to restrict it.
        max = PRIMO_MAX_ACCESSIBLE_RESULTS
        max_per_page = (max / per_page).ceil
        num_pages    = max_per_page     if (num_pages * per_page) > max
        current_page = max_per_page + 1 if start > max

        PageScope.new(current_page, num_pages, per_page)
      end

      # =======================================================================
      # :section: Class methods
      # =======================================================================

      public

      class << self
        include UVA::Helper::Facets
      end

      # custom_parse
      #
      # @param [String] content
      # @param [Hash]   search_params
      #
      # @return [Response]
      #
      # Compare with:
      # @see UVA::Article::Primo::Response#custom_parse
      # @see UVA::Article::Ebsco::Response#custom_parse
      # @see UVA::Article::Summon::Response#custom_parse
      #
      def self.custom_parse(content, search_params)
        # HappyMapper parsing.
        response = Response.parse(content, single: true)

        # Check that the parsed response is valid.  Do nothing and exit if it
        # is not valid.
        if response.respond_to?('current_page=')

          # Local customizations.
          # These are better set from the input params than from the output.
          response.current_page = Response.page(search_params)
          response.per_page = Response.per_page(search_params)

          # Hacking this object to look like Solr responses.
          response.response = { 'numFound' => response.total }
          first_hit = (response.counts && response.counts.first_hit) || 1
          start_num = first_hit - 1
          start_num = 0 if start_num < 0
          response.params = { start: start_num }
          response.error_code = 0

        else

          Rails.logger.error('ARTICLES - Primo error')
          Rails.logger.info {
            info = []
            info << 'ARTICLES >>> Primo response BEGIN =========='
            info << content
            info << 'ARTICLES <<< Primo response END ============'
            info.compact.join(NEWLINE)
          }
          response.error_code = -1

        end

        response
      end

    end

    # =========================================================================
    # :section: Module methods
    # =========================================================================

    public

    # @see UVA::Article::Engine#provider
    #
    def self.provider
      UVA::Article::PRIMO
    end

    # =========================================================================
    # :section: Module methods - Search and access
    # =========================================================================

    public

    # Look up a specific article using the article identifier in "rid".
    #
    # @see UVA::Article::Engine#get_article_by_id
    #
    def self.get_article_by_id(article_id, search_params = {})
      response = search_request(article_id, search_params)
      return response, (response.docs.first if response.ok?)
    end

    # Perform an article search via the article provider.
    #
    # @see UVA::Article::Engine#get_article_search_results
    #
    def self.get_article_search_results(search_params = {})
      # There will be no access to articles in the result set beyond the max
      # accessible.
      index = search_params[:index].to_i
      return Response.new, nil if index > PRIMO_MAX_ACCESSIBLE_RESULTS

      # Make the request to Primo.
      response = search_request(nil, search_params)

      # HACK: If by chance the response parsing did not yield a valid response
      # object, run the query against the article service again.
      unless response.respond_to?('current_page=')
        response = search_request(nil, search_params)
      end

      return response, (response.docs if response.ok?)
    end

    # Translate a search field name (as configured in ArticlesController)
    # into a facet value specific to the article provider.
    #
    # @param [String] name
    #
    # @return [String]
    #
    def self.search_field(name)
      SEARCH_FIELD_MAP[name] || DEFAULT_SEARCH_FIELD
    end

    # Translate a date into the form required for queries to the article
    # provider.
    #
    # @param [Array<String>] args     First argument is the original date.
    #
    # @return [String]
    #
    # @see UVA::Article::Engine#date_format
    #
    def self.date_format(*args)
      date_string = args.shift.to_s.squeeze(' ').strip
      date_string = '0' if date_string.blank?
      date_string
    end

    # =========================================================================
    # :section: Module methods - Search and access
    # =========================================================================

    protected

    # Send a search request to the article provider.
    #
    # @param [String] article_id
    # @param [Hash]   request_params
    #
    # @return [Response]
    #
    # Compare with:
    # @see UVA::Article::Primo#search_request
    # @see UVA::Article::Ebsco#request_by_dbid_an
    # @see UVA::Article::Summon#search_request
    #
    def self.search_request(article_id, search_params)
      # Make the request to Primo.
      # t0 = Time.current
      url = build_search_query(article_id, search_params)
      uri = URI.parse(URI.encode(url))
      content = uri.read
      # t1 = Time.current

      # Process the response.
      response = Response.custom_parse(content, search_params)
      # t2 = Time.current
      # Rails.logger.info {
      #   'ARTICLES - Primo Total hits, Query time, Parse time = ' \
      #   "#{response.total}, "\
      #   "#{t1 - t0}, "\
      #   "#{t2 - t1}"
      # }
      response
    end

    # If it begins and ends with quotes, make it exact.
    #
    # @param [String] query
    #
    # @return [String]
    #
    def self.scope(query)
      (query =~ /^["'].+["']$/) ? 'exact' : 'contains'
    end

    # Throw out quotes, commas, colons, exclamation points, periods,
    # semi-colons, question marks.
    #
    # @param [String] query
    #
    # @return [String]
    #
    # Compare with:
    # @see UVA::Article::Primo#scrubbed_query
    # @see UVA::Article::Ebsco::ParamParts#scrubbed_query
    # @see UVA::Article::Summon::ParamParts#scrubbed_query
    #
    def self.scrubbed_query(query)
      query.tr(':,;.!?\'"', ' ')
    end

    # Extract params[:q] and make URL piece.
    #
    # @param [Hash] search_params
    #
    # @return [Array<String>]
    #
    # Compare with:
    # @see UVA::Article::Primo#get_query
    # @see UVA::Article::Ebsco::ParamParts#query
    # @see UVA::Article::Summon::ParamParts#query
    #
    def self.get_query(search_params = {})
      result = []
      if search_params[:q].present?
        query = search_params[:q]
        result << "query=any,#{scope(query)},#{scrubbed_query(query)}"
      elsif search_params[:subject].present?
        # This bit of code permits searching on subjects in Primo. The Primo
        # query <field> is 'sub' for the :subject parameter in the Virgo query.
        subject = search_params[:subject]
        result << "query=sub,#{scope(subject)},#{scrubbed_query(subject)}"
      end
      result
    end

    # Extract populated advanced search fields and make URL pieces.
    #
    # @param [Hash] search_params
    #
    # @return [Array<String>]
    #
    # Compare with:
    # @see UVA::Article::Primo#get_advanced_search_queries
    # @see UVA::Article::Ebsco::ParamParts#advanced_queries
    # @see UVA::Article::Summon::ParamParts#advanced_queries
    #
    def self.get_advanced_search_queries(search_params = {})
      advanced_search_fields.map { |key, field_def|
        facet = search_field(key.to_s)
        value = search_params[key.to_sym]
        next if value.blank?
        if true_value?(field_def.range)
          # The range is split into the parts on either side of the '-' (to be
          # replaced with ' TO ' for the Primo range syntax).  If there is no
          # '-' then the range becomes "year TO year".  If there is no
          # start_date then a default of '0' is used.
          start_date, end_date = value.delete(' ').split('-')
          start_date = date_format(start_date)
          end_date   = end_date.blank? ? start_date : date_format(end_date)
          value = "#{start_date} TO #{end_date}"
          "query=facet_#{facet},exact,[#{value}]"

        elsif facet == 'jtitle'
          # Special treatment for the journal title field of the advanced
          # search.   We are going to treat that as a title facet on the
          # search, i.e. finding the search query within that journal.
          "query=facet_#{facet},exact,#{value}"

        else
          # Add a query term.
          "query=#{facet},#{scope(value)},#{scrubbed_query(value)}"

        end
      }.reject(&:blank?)
    end

    # Extract params[:f] and make URL pieces.
    #
    # @param [Hash] search_params
    #
    # @return [Array<String>]
    #
    # Compare with:
    # @see UVA::Article::Primo#get_facets
    # @see UVA::Article::Ebsco::ParamParts#facets_and_limiters
    # @see UVA::Article::Summon::ParamParts#facets_and_filters
    #
    def self.get_facets(search_params = {})
      [*search_params[:f]].flat_map { |facet_field, value_list|
        next if facet_field.blank?
        [*value_list].map do |value|
          next if value.blank?
          value = scrubbed_query(value)
          value = "[#{value} TO #{value}]" if facet_field == 'creationdate'
          "query=facet_#{facet_field},exact,#{value}"
        end
      }.compact
    end

    # Extract start index and per page and make URL piece.
    #
    # @param [Hash] search_params
    #
    # @return [Array<String>]
    #
    # Compare with:
    # @see UVA::Article::Primo#get_paging
    # @see UVA::Article::Ebsco::ParamParts#get_paging
    # @see UVA::Article::Summon::ParamParts#get_paging
    #
    def self.get_paging(search_params = {})
      if search_params.key?(:index)
        my_per_page = 1
        my_page     = search_params[:index].to_i - 1
      else
        my_per_page = Response.per_page(search_params)
        my_page     = Response.page(search_params) - 1
      end

      # Primo limits the maximum number of 'retrievable' results so we are
      # going to do some adjustment to the pagination so that a user cannot
      # page beyond that max number of results.
      if (my_page * my_per_page) > PRIMO_MAX_ACCESSIBLE_RESULTS
        my_page = (PRIMO_MAX_ACCESSIBLE_RESULTS / my_per_page).ceil
      end
      start_index = (my_page * my_per_page) + 1

      return "indx=#{start_index}", "bulkSize=#{my_per_page}"
    end

    # Extract sort and make URL piece.
    #
    # @param [Hash] search_params
    #
    # @return [Array<String>]
    #
    # Compare with:
    # @see UVA::Article::Primo#get_sort
    # @see UVA::Article::Ebsco::ParamParts#sort
    # @see UVA::Article::Summon::ParamParts#sort
    #
    def self.get_sort(search_params = {})
      result = []
      sort =
        if (sort_key = get_current_sort_key(search_params)).present?
          sort_fields_config(ArticlesController).find do |value, entry|
            break value if sort_key == entry.sort_key
          end
        end
      result << "sortField=#{sort}" if sort.present?
      result
    end

    # get_scope
    #
    # @return [String]
    #
    def self.get_scope(*)
      'loc=adaptor,primo_central_multiple_fe'
    end

    # get_full_text_filter
    #
    # @return [String]
    #
    def self.get_full_text_filter(*)
      'query=facet_tlevel,exact,online_resources_PC_TN'
    end

    # Construct query parameters for the request to the article provider.
    #
    # @param [String] article_id      If *nil* then this is a search.
    # @param [Hash]   search_params
    #
    # @return [String]
    #
    # @see UVA::Article::Primo#build_article_url
    # @see UVA::Article::Primo#build_search_url
    #
    # Compare with:
    # @see UVA::Article::Primo#build_search_query
    # @see UVA::Article::Ebsco#build_search_query
    # @see UVA::Article::Summon#build_search_query
    #
    def self.build_search_query(article_id, search_params = {})
      if article_id
        build_article_url(article_id, search_params)
      else
        build_search_url(search_params)
      end
    end

    # Construct query parameters to request a single item.
    #
    # @param [String] article_id
    # @param [Hash]   search_params
    #
    # @return [String]
    #
    # @see UVA::Article::Primo#build_search_url
    #
    def self.build_article_url(article_id, search_params = {})
      [
        PRIMO_URL,
        "query=rid,exact,#{article_id}",
        get_scope(search_params)
      ].flatten.compact.join('&')
        .tap { |url| Rails.logger.info("ARTICLES - Primo request: #{url}") }
    end

    # Construct query parameters to request a search.
    #
    # @param [Hash] search_params
    #
    # @return [String]
    #
    # @see UVA::Article::Primo#build_article_url
    #
    def self.build_search_url(search_params = {})
      [
        PRIMO_URL,
        get_advanced_search_queries(search_params),
        get_query(search_params),
        # 'query=facet_pfilter,exact,articles', # Make it be just articles.
        get_facets(search_params),
        get_paging(search_params),
        get_sort(search_params),
        get_scope(search_params),
        get_full_text_filter(search_params)
      ].flatten.compact.join('&')
        .tap { |url| Rails.logger.info("ARTICLES - Primo request: #{url}") }
    end

  end

end
