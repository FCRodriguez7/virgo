# lib/uva/article/summon.rb

require 'uva'

module UVA::Article

  # Support for using ProQuest Summon as an article search provider.
  #
  # NOTE: This module has not been fully retested since the refactoring.
  #
  module Summon

    require 'happymapper'
    require 'summon'

    include ::Summon

    include UVA
    include UVA::Article

    extend UVA::Article::Engine

    # =========================================================================
    # :section:
    # =========================================================================

    public

    SUMMON_ACCESS_ID  = 'virginia'.freeze
    SUMMON_SECRET_KEY = 'ki5ACx4PH4Z9PsrKs0d5fZWZiqgW6ByI'.freeze

    # Summon only allows access to the first 1000 results in any result set.
    SUMMON_MAX_ACCESSIBLE_RESULTS = 1000
    SUMMON_MAX_PER_PAGE = 50

    SEARCH_FIELD_MAP = {
      'keyword'          => 'Keywords',
      'author'           => 'Author',
      'title'            => 'Title',
      'journal'          => 'PublicationTitle',
      'publication_date' => 'PublicationDate',
      'subject'          => 'SubjectTerms',
    }.deep_freeze

    DEFAULT_SEARCH_FIELD = 'Keywords'.freeze

    # =========================================================================
    # :section: Data items
    # =========================================================================

    public

    # @see UVA::Article::FacetItem
    #
    # Compare with:
    # @see UVA::Article::Primo::Item
    # @see UVA::Article::Ebsco::Item
    # @see UVA::Article::Summon::Item
    #
    class Item < UVA::Article::FacetItem
    end

    # @see UVA::Article::FacetField
    #
    # @see Summon::Facet
    #
    # Compare with:
    # @see UVA::Article::Primo::Facet
    # @see UVA::Article::Ebsco::Facet
    # @see UVA::Article::Summon::Facet
    #
    class Facet < UVA::Article::FacetField

      # =======================================================================
      # :section: Class Methods
      # =======================================================================

      public

      # convert
      #
      # @param [Summon::Facet] summon_facet
      #
      # @return [Facet]
      #
      def self.convert(summon_facet)
        name  = summon_facet.display_name
        items = summon_facet.counts.map { |f| Item.new(f.value, f.count) }
        Facet.new(name, items)
      end

    end

    # =========================================================================
    # :section: Article document class
    # =========================================================================

    public

    # UVA::Article::Summon::Document
    #
    # @see Summon::Document
    #
    # Compare with:
    # @see UVA::Article::Primo::Document
    # @see UVA::Article::Ebsco::Document
    # @see UVA::Article::Summon::Document
    #
    class Document

      include UVA::ArticleDoc

      # @return [String]
      attr_accessor :provider_id

      # @return [Array<String>]
      attr_accessor :authors

      # Initialize a self instance.
      #
      # @param [Array] args             Passed to the super initializer.
      #
      def initialize(*args)
        super(*args)
        @display         = Display.new
        @additional_data = AdditionalData.new
        @search          = Search.new
        @authors         = []
      end

      # =======================================================================
      # :section: RSolr::Ext::Model interface
      # =======================================================================

      public

      # @see UVA::IndexDoc#id
      #
      def id
        @provider_id
      end

      # =======================================================================
      # :section: Citation Export
      # =======================================================================

      public

      # @see UVA::IndexDoc#get_authors
      #
      def get_authors
        authors
      end

      # =======================================================================
      # :section: Class Methods
      # =======================================================================

      public

      # convert
      #
      # @param [Summon::Document] summon_doc
      #
      # @return [Document]
      #--
      # rubocop:disable Metrics/AbcSize # [128.2/45]
      # rubocop:disable Metrics/CyclomaticComplexity # [25/18]
      # rubocop:disable Metrics/PerceivedComplexity # [28/21]
      # rubocop:disable Metrics/MethodLength # [79/35]
      #++
      def self.convert(summon_doc)

        doc = Document.new

        # Set the fields on the base document class and the Display class.
        # These will supply enough info for an articles results page.
        doc.provider_id = summon_doc.id

        doc.authors = [*summon_doc.authors].reject(&:blank?).map(&:fullname)
        doc.display.creator = doc.authors.join(ITEM_SEPARATOR)
        doc.display.description << summon_doc.abstract if summon_doc.abstract

        # Stuff doc.display.identifier with all the identifier IDs for a
        # combined string. Put only the doi in doc.dois and only issns in
        # doc.issns for separated strings.
        doc.dois         = summon_doc.doi || ''
        doc.issns        = summon_doc.issns + summon_doc.eissns
        doc.call_numbers = summon_doc.call_numbers
        ids = []
        ids << "DOI: #{doc.dois}" if doc.dois.present?
        ids += summon_doc.issns.map  { |id| "ISSN: #{id}"   if id.present? }
        ids += summon_doc.eissns.map { |id| "E-ISSN: #{id}" if id.present? }
        doc.display.identifier = ids.compact.join(ITEM_SEPARATOR)

        citation = []
        citation << summon_doc.publication_title
        citation << summon_doc.publication_date.year
        citation << summon_doc.edition
        citation << "Vol. #{summon_doc.volume}" if summon_doc.volume
        citation << "(#{summon_doc.issue})" if summon_doc.issue
        pages = ''
        pages = "p. #{summon_doc.start_page}" if summon_doc.start_page
        if summon_doc.page_count.to_i > 0
          pages << "(#{summon_doc.page_count})"
        elsif summon_doc.end_page
          pages << "-#{summon_doc.end_page}"
        end
        citation << pages
        citation.delete_if(&:blank?)
        doc.display.is_part_of = citation.join(ITEM_SEPARATOR) if citation.present?

        doc.display.language = summon_doc.languages.join(LIST_SEPARATOR)
        doc.display.source   = summon_doc.publishers.join(ITEM_SEPARATOR)
        doc.display.subject  = summon_doc.subject_terms.join(ITEM_SEPARATOR)
        doc.display.title    = summon_doc.title

        link = Link.new(summon_doc.link)
        link.thumbnail =
          summon_doc.thumbnail_medium ||
            summon_doc.thumbnail_small ||
            summon_doc.thumbnail_large
        doc.links << link

        # Set the additional_data fields.
        start_page = summon_doc.start_page
        end_page   = summon_doc.end_page
        pages      = summon_doc.page_count
        doc.additional_data.start_page = start_page || ''
        doc.additional_data.end_page   = end_page
        doc.additional_data.end_page ||=
          if start_page && pages
            start_page.to_i + pages.to_i - 1
          else
            ''
          end
        doc.additional_data.issue   = summon_doc.issue.to_s
        doc.additional_data.volume  = summon_doc.volume.to_s
        doc.additional_data.journal = summon_doc.publication_title

        # Set the search data fields.
        date = summon_doc.publication_date
        year = (date && date.year) || 0
        if year > 0
          month = date.month || 0
          day   = date.day   || 0
          doc.search.creation_date =
            if month.zero?
              year.to_s
            elsif day.zero?
              Date.new(year, month, 1).strftime('%B %Y')
            else
              Date.new(year, month, day).strftime('%B %-d, %Y')
            end
        end

        doc.search.subject_facet = [*summon_doc.subject_terms].reject(&:blank?)

        doc

        # rubocop:enable Metrics/AbcSize
        # rubocop:enable Metrics/CyclomaticComplexity
        # rubocop:enable Metrics/PerceivedComplexity
        # rubocop:enable Metrics/MethodLength
      end

      # dump_the_summon_doc
      #
      # @param [Summon::Document] summon_doc
      #
      # @return [void]
      #--
      # rubocop:disable Metrics/AbcSize # [367.3/45]
      # rubocop:disable Metrics/CyclomaticComplexity # [32/18]
      # rubocop:disable Metrics/PerceivedComplexity # [32/21]
      # rubocop:disable Metrics/MethodLength # [127/35]
      #++
      def self.dump_the_summon_doc(summon_doc)
        # rubocop:disable Metrics/LineLength # TODO
        fields = [
          :id, :title, :subtitle, :publication_title,
          :publication_series_title, :content_types,
          :authors, :corporate_authors, :publishers,
          :volume, :issue, :edition,
          :start_page, :end_page, :page_count,
          :publication_date, :publication_place, :meeting_name,
          :database_title, :source,
          :isi_cited_references_count, :isi_cited_references_uri,
          :in_holdings, :library, :call_numbers, :deweys, :doi,
          :issns, :eissns,:isbns, :eisbns,
          :patent_number, :gov_doc_class_nums, :copyright, :subject_terms,
          :genres, :languages, :snippet, :abstract, :fulltext, :print,
          :uri, :link, :url, :openurl,
          :thumbnail_small, :thumbnail_medium, :thumbnail_large,
          :availability_id, :eric, :dbid, :lib_guide_tab, :spotlight_children,
          :fulltext_hit, :peer_documents, :related_records
        ]
        Rails.logger.info('ARTICLES >>> Summon document BEGIN')
        indent = ' ' * 2
        fields.flat_map { |field|
          value = summon_doc.send(field)
          if value.is_a?(Array)
            [":#{field} ="] + value.map { |v| "#{indent}#{v}" }
          else
            ":#{field} = #{value}"
          end
        }.join("\n#{indent}")
        Rails.logger.info('ARTICLES <<< Summon document END')
        # rubocop:enable Metrics/AbcSize
        # rubocop:enable Metrics/CyclomaticComplexity
        # rubocop:enable Metrics/PerceivedComplexity
        # rubocop:enable Metrics/MethodLength
      end

    end

    # =========================================================================
    # :section: Common article data classes
    # =========================================================================

    public

    # UVA::Article::Summon::Display
    #
    class Display < UVA::ArticleDoc::Display
    end

    # UVA::Article::Summon::AdditionalData
    #
    class AdditionalData < UVA::ArticleDoc::AdditionalData
    end

    # UVA::Article::Summon::Search
    #
    class Search < UVA::ArticleDoc::Search
    end

    # UVA::Article::Summon::Link
    #
    class Link < UVA::ArticleDoc::Link

      def default_text
        'Access through UVA Library'
      end

    end

    # UVA::Article::Summon::Response
    #
    # Compare with:
    # @see UVA::Article::Primo::Response
    # @see UVA::Article::Ebsco::Response
    # @see UVA::Article::Summon::Response
    #
    class Response < UVA::ArticleDoc::Response

      # @return [Fixnum]
      attr_accessor :counts

      # @return [Array<Facet>]
      attr_accessor :facets

      # @return [Array<Document>]
      attr_accessor :docs

      # =======================================================================
      # :section:
      # =======================================================================

      public

      # Initialize a new self instance.
      #
      def initialize
        super(UVA::Article::SUMMON)
        @counts = 0
        @facets = []
        @docs   = []
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
        @counts
      end

      # =======================================================================
      # :section:
      # =======================================================================

      public

      # per_page_choices
      #
      # @return [Array<String>]
      #
      def per_page_choices
        %w(20 50)
      end

      # This is similar to the Blacklight method but modified to limit access
      # via the Kaminari paginator to no more results than is permitted for
      # articles.
      #
      # @return [PageScope]
      #
      # @see UVA::ArticleDoc::Response#paginate_values
      # @see UVA::Article::Primo::Response#paginate_values
      #
      # Compare with:
      # @see Blacklight::CatalogHelperBehavior#paginate_params
      #
      def paginate_values
        per_page = rows || 1
        per_page = 1 if per_page < 1
        current_page = (start / per_page).ceil + 1
        num_pages = (total / per_page.to_f).ceil

        # Do not let the Kaminari paginator offer pages beyond what the article
        # provider permits. We will accomplish this by modifying the num_pages
        # to restrict it.
        max = SUMMON_MAX_ACCESSIBLE_RESULTS
        max_per_page = (max / per_page).ceil
        num_pages    = max_per_page     if (num_pages * per_page) > max
        current_page = max_per_page + 1 if start > max

        PageScope.new(current_page, num_pages, per_page)
      end

      # =======================================================================
      # :section: Class methods
      # =======================================================================

      public

      # Currently, the only filter we will use is the 'is scholarly' (i.e. peer
      # reviewed) filter. And peer reviewed will always be one of the Summon
      # 'facets'.
      #
      # @return [Array<Facet>]
      #
      # Identical to:
      # @see UVA::Article::Ebsco::Response#limiters
      #
      def self.limiters
        @limiters ||=
          begin
            new_facet_item = Item.new
            new_facet_item.value = 'peer_reviewed'
            new_facet_item.hits  = 1

            new_facet = Facet.new
            new_facet.name = 'tlevel'
            new_facet.items ||= []
            new_facet.items << new_facet_item

            [new_facet]
          end
      end

      # Convert the Summon::Search response into the Response needed by Virgo
      # (a simple field mapping of one class onto the other).
      #
      # @param [Summon::Search] summon_search
      # @param [Hash]           search_params
      #
      # @return [Response]
      #
      # Compare with:
      # @see UVA::Article::Primo::Response#custom_parse
      # @see UVA::Article::Ebsco::Response#custom_parse
      # @see UVA::Article::Summon::Response#custom_parse
      #
      def self.custom_parse(summon_search, search_params)

        response = Response.new

        # Check that the parsed response is valid.
        if summon_search.errors.empty?

          response.counts = summon_search.record_count.to_i
          response.current_page = Response.page(search_params)
          response.per_page = Response.per_page(search_params)

          # Hacking this object to look like Solr responses.
          response.response = { 'numFound' => response.total }
          start_num = response.per_page * (response.current_page - 1)
          response.params = { start: start_num }

          # Obtain the facets returned from the search. For Summon, the filters
          # will appear as 'facets' in our UI.
          response.facets += summon_search.facets.map { |f| Facet.convert(f) }
          response.facets += limiters

          # If there are results in the set, convert the Summon::Document to a
          # Virgo document.
          response.docs +=
            summon_search.documents.map { |doc| Document.convert(doc) }
          response.error_code = 0

        else

          Rails.logger.error("ARTICLES - Summon error #{summon_search.errors}")
          response.error_code = -1

        end

        response
      end

      # =======================================================================
      # :section: Test and development
      # =======================================================================

      public

      # dump_summon_response
      #
      # @param [Summon::Search] summon_search
      #
      # @return [void]
      #
      def self.dump_summon_response(summon_search)

        # rubocop:disable Style/FirstArrayElementLineBreak

        attrs             = [:version, :session_id, :page_count, :record_count,
                             :query_time, :total_request_time]
        facet_attrs       = [:display_name, :field_name, :combine_mode]
        facet_count_attrs = [:value, :count]

        # rubocop:enable Style/FirstArrayElementLineBreak

        lines = []
        lines << 'ARTICLES >>> Summon search metadata BEGIN'
        lines << ":query = #{summon_search.query.query_string}"
        lines += attrs.map { |attr| ":#{attr} = #{summon_search.send(attr)}" }
        lines +=
          summon_search.facets.map do |facet|
            facet_attrs.map { |attr| "  :#{attr} = #{facet.send(attr)}" }
            facet.counts.map do |fc|
              facet_count_attrs.map { |attr| "  :#{attr} = #{fc.send(attr)}" }
            end
          end
        result = lines.flatten.join("\n    ") << NEWLINE
        result << 'ARTICLES <<< Summon search metadata END'
        Rails.logger.info(result)
      end

    end

    # =========================================================================
    # :section: Module methods
    # =========================================================================

    public

    # @see UVA::Article::Engine#provider
    #
    def self.provider
      UVA::Article::SUMMON
    end

    # =========================================================================
    # :section: Module methods
    # =========================================================================

    protected

    # dump_params_to_logger
    #
    # @param [Hash] params
    #
    # @return [void]
    #
    def self.dump_params_to_logger(params)
      lines = []
      lines << 'ARTICLES >>> Summon query params BEGIN =========='
      lines +=
        params.map do |key, value|
          value = value.join(' | ') if value.is_a?(Array)
          "   #{key} = #{value}"
        end
      lines << 'ARTICLES <<< Summon query params END ============'
      Rails.logger.info(lines.join(NEWLINE))
    end

    # =========================================================================
    # :section: Module methods - Search and access
    # =========================================================================

    public

    # Look up a specific article using the article identifier.
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
      return Response.new, nil if index > SUMMON_MAX_ACCESSIBLE_RESULTS

      # Make the request to Summon.
      response = search_request(nil, search_params)

      # HACK: This is a request for a single article for an article details
      # page. Based on the index, get that article out of the result set.
      unless index.zero?
        if index > SUMMON_MAX_PER_PAGE
          modulo_result = index.divmod(SUMMON_MAX_PER_PAGE)
          index = modulo_result[1] # 2nd element of array is the remainder.
        end

        # Now pluck that article from the docs list and make it the only
        # article in the list.
        article = response.docs[index - 1]
        response.docs = [article]
      end

      return response, response.docs
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
      date_string = '1000' if date_string.blank?
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

      # Make the request to Summon.
      # t0 = Time.current
      options  = { access_id: SUMMON_ACCESS_ID, secret_key: SUMMON_SECRET_KEY }
      @service = Summon::Service.new(options)
      query =
        if article_id
          { 's.fids' => article_id }
        else
          build_search_query(search_params)
        end
      content = @service.search(query)
      # t1 = Time.current

      # Process the response.
      response = Response.custom_parse(content, search_params)
      # t2 = Time.current
      # Rails.logger.info {
      #   "ARTICLES - Summon Search Query:  #{search.query.query_string}\n" \
      #   'ARTICLES - Summon Total hits, Query time, Parse time = ' \
      #   "#{response.total}, "\
      #   "#{t1 - t0}, "\
      #   "#{t2 - t1}"
      # }
      response
    end

    # Construct query parameters for the request to the article provider.
    #
    # @param [Hash] search_params
    #
    # @return [Hash{'s.q'=>String}]
    #
    # Compare with:
    # @see UVA::Article::Primo#build_search_query
    # @see UVA::Article::Ebsco#build_search_query
    # @see UVA::Article::Summon#build_search_query
    #
    def self.build_search_query(search_params = {})
      Hash[
        ParamParts.advanced_queries(search_params) +
        ParamParts.query(search_params) +
        ParamParts.uva_holdings_only(search_params) +
        ParamParts.get_paging(search_params) +
        ParamParts.remove_highlighting(search_params) +
        ParamParts.sort(search_params) +
        ParamParts.facets_and_filters(search_params) +
        ParamParts.list_facets
      ].tap { |result| dump_params_to_logger(result) }
    end

    # =========================================================================
    # :section: Module methods - Search and access
    # =========================================================================

    public

    # UVA::Article::Summon::ParamParts
    #
    # Methods for making Summon key-value pairs for building a search request.
    #
    # Compare with:
    # @see UVA::Article::Ebsco::ParamParts
    # @see UVA::Article::Summon::ParamParts
    #
    module ParamParts

      class << self
        include UVA::Helper::Facets
      end

      # Escape standard ASCII chars which are considered special by Summon:
      QUERY_TRANSLATION_MAP = {
        ',' => '\,', # '%5C%2C',
        ':' => '\:', # '%5C%3A',
        # '\' => '\\', # '%5C%5C',
        '(' => '\(', # '%5C%28',
        ')' => '\)', # '%5C%29',
        '$' => '\$', # '%5C%24',
        '{' => '\{', # '%5C%7B',
        '}' => '\}'  # '%5C%7D'
      }.deep_freeze

      # =======================================================================
      # :section:
      # =======================================================================

      public

      # Extract params[:q].
      #
      # @param [Hash] search_params
      #
      # @return [Array<'s.q',String>]
      #
      # Compare with:
      # @see UVA::Article::Primo#get_query
      # @see UVA::Article::Ebsco::ParamParts#query
      # @see UVA::Article::Summon::ParamParts#query
      #
      def self.query(search_params = {})
        return 's.q', search_params[:q].to_s
      end

      # Set the number of results per page.
      #
      # @param [Hash] search_params
      #
      # @return [Array<'s.ps',Fixnum>]
      #
      def self.per_page(search_params = {})
        return 's.ps', Response.per_page(search_params)
      end

      # Set which page to get.
      #
      # @param [Hash] search_params
      #
      # @return [Array<'s.pn',Fixnum>]
      #
      def self.page(search_params = {})
        return 's.pn', Response.page(search_params)
      end

      # Extract start index and per page and make URL piece.
      #
      # @param [Hash] search_params
      #
      # @return [Array<'s.ps',Fixnum,'s.pn',Fixnum>]
      #
      # Compare with:
      # @see UVA::Article::Primo#get_paging
      # @see UVA::Article::Ebsco::ParamParts#get_paging
      # @see UVA::Article::Summon::ParamParts#get_paging
      #
      def self.get_paging(search_params = {})

        if search_params[:index]
          # Summon cannot reference a page number higher than
          # SUMMON_MAX_PER_PAGE so we will not ask for a page containing one
          # article per page. We will get the page on which that article
          # resides assuming the articles per page is SUMMON_MAX_PER_PAGE.
          # Later, we will pluck that single article out of the results for the
          # article details page.
          my_per_page = SUMMON_MAX_PER_PAGE
          my_page     = (search_params[:index].to_f / my_per_page).ceil
        else
          my_per_page = Response.per_page(search_params)
          my_page     = Response.page(search_params)
        end

        # Summon limits the maximum number of 'retrievable' results so we are
        # going to do some adjustment to the pagination so that a user cannot
        # page beyond that max number of results.
        if (my_per_page * my_page) > SUMMON_MAX_ACCESSIBLE_RESULTS
          my_page = (SUMMON_MAX_ACCESSIBLE_RESULTS / my_per_page).ceil
        end

        return 's.ps', my_per_page, 's.pn', my_page
      end

      # Turn on UVa holdings only.
      #
      # @param [Hash] _search_params  Currently unused.
      #
      # @return [Array<'s.ho',Boolean>]
      #
      def self.uva_holdings_only(_search_params = nil)
        return 's.ho', true
      end

      # Turn off highlighting.
      #
      # @param [Hash] _search_params  Currently unused.
      #
      # @return [Array<'s.hl',Boolean>]
      #
      def self.remove_highlighting(_search_params = nil)
        return 's.hl', false
      end

      # Turn off 'did you mean' heuristics.
      #
      # @param [Hash] _search_params  Currently unused.
      #
      # @return [Array<'s.dym',Boolean>]
      #
      def self.remove_did_you_mean_guessing(_search_params = nil)
        return 's.dym', false
      end

      # Add facets.
      #
      # @param [Hash] search_params
      #
      # @return [Array<'s.fvf',Array<String>>]
      #
      # Compare with:
      # @see UVA::Article::Primo#get_facets
      # @see UVA::Article::Ebsco::ParamParts#facets_and_limiters
      # @see UVA::Article::Summon::ParamParts#facets_and_filters
      #
      def self.facets_and_filters(search_params = {})
        facets = ['ContentType,JournalArticle']
        facets +=
          [*search_params[:f]].flat_map { |facet_field, value_list|
            next if facet_field.blank?
            [*value_list].map do |value|
              next if value.blank?
              if facet_field.to_sym == :tlevel
                'isScholarly,true'
              else
                "#{facet_field},#{scrubbed_query(value)}"
              end
            end
          }.compact
        return 's.fvf', facets
      end

      # list_facets
      #
      # @return [Array<'s.ff',Array<String>>]
      #
      def self.list_facets
        facets = %w(
          SubjectTerms,and
          ContentType,and
          PublicationTitle,and
          Author,and
          Language,and
          Audience,and
          GeographicLocations,and
        )
        return 's.ff', facets
      end

      # Get sort
      #
      # @param [Hash] search_params
      #
      # @return [Array<'s.sort',String>]
      #
      # Compare with:
      # @see UVA::Article::Primo#get_sort
      # @see UVA::Article::Ebsco::ParamParts#sort
      # @see UVA::Article::Summon::ParamParts#sort
      #
      def self.sort(search_params = {})
        result = {}
        sort =
          if (sort_key = get_current_sort_key(search_params)).present?
            sort_fields_config(ArticlesController).find do |value, entry|
              break value if sort_key == entry.sort_key
            end
          end
        result['s.sort'] = 'PublicationDate:desc' if sort == 'scdate'
        result
      end

      # Extract populated advanced search fields and make URL pieces.
      #
      # @param [Hash] search_params
      #
      # @return [Hash{'s.q','s.fq','s.rf'=>String,Array<String>}]
      #
      # Compare with:
      # @see UVA::Article::Primo#get_advanced_search_queries
      # @see UVA::Article::Ebsco::ParamParts#advanced_queries
      # @see UVA::Article::Summon::ParamParts#advanced_queries
      #
      def self.advanced_queries(search_params = {})
        queries = []
        filters = []
        ranges  = []
        advanced_search_fields.each_pair do |key, field_def|
          facet = UVA::Article::Summon.search_field(key.to_s)
          value = search_params[key.to_sym]
          next if value.blank? || facet.blank?
          if true_value?(field_def.range)
            # Add *facet* *value* to ranges.
            # The range is split into the parts on either side of the '-' (to
            # be replaced with ':' for the Summon date range syntax).  If there
            # is no '-' then the range becomes "year:year".  If there is no
            # <startyear> then a default of '1000' is used.
            start_date, end_date = value.delete(' ').split('-')
            start_date = date_format(start_date)
            end_date   = end_date.blank? ? start_date : date_format(end_date)
            value = "#{start_date}:#{end_date}"
            ranges << "#{facet},#{value}"

          elsif facet == 'Keywords'
            # Use *value* as the query.
            queries << value

          else
            # Add *facet* *value* to filters.
            value = scrubbed_query(value)
            filters << "#{facet}:(#{value})"

          end
        end
        result = {}
        result['s.q']  = queries.join(' AND ') if queries.present?
        result['s.fq'] = filters               if filters.present?
        result['s.rf'] = ranges                if ranges.present?
        result.to_a.flatten(1)
      end

      # =======================================================================
      # :section:
      # =======================================================================

      protected

      # scrubbed_query
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
        query.gsub(/[,:\\\(\)\$\{\}]/) { |match| QUERY_TRANSLATION_MAP[match] }
      end

    end

  end

end
