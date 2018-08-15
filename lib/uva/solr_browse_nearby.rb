# lib/uva/solr_browse_nearby.rb

require 'uva'

module UVA

  # Query the Solr "alphaTerms" request handler to get items with neighboring
  # call numbers.
  #
  # === Terminology
  #
  # ==== Page
  # A contiguous set of items requested from Solr.  The "page size" is the
  # number of items expected to be returned from Solr when requesting a
  # particular page.
  #
  # ==== Page buffer
  # Storage for items requested from Solr.
  #
  # ==== Window
  # A contiguous set of items on the "virtual shelf".  The "window size" is
  # determined by "view" code, generally based on the space available for
  # displaying the virtual shelf window.
  #
  # === Usage Notes
  # When the class is constructed, a specific document (as identified by its
  # Solr document id) serves as a "stake in the ground" for a search which
  # returns a "window" into a portion of the virtual shelf centered on that
  # item.
  #
  # The window width is defined by the constructor :width option which is held
  # in the self#hits_requested attribute.  If no :width option is given, then
  # self#DEFAULT_HITS is used a the default window width.
  #
  # The location of the window into the virtual shelf is defined by the
  # constructor :page option which is held in the self#requested_page
  # attribute.  If no :page option is given, then the default is 0, which is
  # the window centered on the specified document itself.
  #
  # === Implementation Notes
  # This is liberally adapted from the "blacklight_browse_nearby" gem.
  #
  # For the algorithm to transform a call number into a shelfkey:
  # @see https://github.com/solrmarc/solrmarc/blob/master/src/org/solrmarc/callnum/LCCallNumber.java
  #
  # === References
  # @see https://github.com/projectblacklight/blacklight_browse_nearby
  #
  class SolrBrowseNearby

    include Blacklight::Configurable
    include Blacklight::SolrHelper
    include UVA
    include UVA::Solr

    # =========================================================================
    # :section: Constants
    # =========================================================================

    public

    DEFAULT_PAGE           = 0
    DEFAULT_OFFSET         = :center
    DEFAULT_HITS           = 7
    FULL_VIEW_DEFAULT_HITS = 11
    SOLR_REQUEST_HANDLER   = 'alphaTerms'.freeze

    VALUE_FIELD            = 'lc_call_number_display'.freeze
    SORTKEY_FIELD          = 'shelfkey'.freeze
    REVERSE_SORTKEY_FIELD  = 'reverse_shelfkey'.freeze

    REQUIRED_FIELDS =
      [VALUE_FIELD, SORTKEY_FIELD, REVERSE_SORTKEY_FIELD].freeze

    OFFSETS = [:left, :center, :right].freeze

    # =========================================================================
    # :section:
    # =========================================================================

    public

    # The Solr request handler for getting shelf key sequences (default
    # self#SOLR_REQUEST_HANDLER).
    #
    # @return [String]
    #
    attr_reader :request_handler

    # The Solr field containing the shelf key (normalized call number) for a
    # document used to collate documents in the forward direction (increasing
    # call number collation order).
    #
    # @return [String]
    #
    attr_reader :fwd_shelfkey

    # The Solr field containing the shelf key (normalized call number) for a
    # document used to collate documents in the reverse direction (decreasing
    # call number collation order).
    #
    # @return [String]
    #
    attr_reader :rev_shelfkey

    # The location of the window into the virtual shelf centered on the
    # specified item.
    #
    # - A *negative* page number indicates documents "behind" the item.
    # - A *positive* page number indicates documents "in front of" the item.
    # - A *zero* page number indicates a window centered on the item itself.
    #
    # @return [Fixnum]
    #
    attr_reader :requested_page

    # The width of the virtual shelf window.
    #
    # (This value is the same as the page size for the Solr request used to
    # acquire the items in that window.)
    #
    # @return [Fixnum]
    #
    attr_reader :hits_requested

    # The item which represents the origin of this virtual shelf.
    #
    # @return [SolrDocument]
    #
    attr_reader :origin

    # The array of documents which is the contents of the location on the
    # virtual shelf specified by the page offset from the specified item and
    # with a length equal to the window width.
    #
    # @return [Array<SolrDocument,Symbol>]
    #
    attr_reader :documents

    # An indicator of the position of the origin on page 0.
    #
    # @return [Symbol]                One of :left, :center, or :right.
    #
    attr_reader :offset

    # The starting call number when invoked with "?start=number".
    #
    # @return [String]
    # @return [nil]
    #
    attr_reader :start

    # A copy of `params` supplied through self#initialize which satisfies
    # Blacklight configuration interface methods called from this instance.
    #
    attr_reader :params

    # A copy of `session` supplied through self#initialize which satisfies
    # Blacklight configuration interface methods called from this instance.
    #
    attr_reader :session

    # Initialize a new self object.
    #
    # @param [SolrDocument, String] doc
    # @param [Hash]                 opt
    #
    # @option opt [Fixnum] :start         # params[:start]
    # @option opt [Fixnum] :page          # params[:page]
    # @option opt [Fixnum] :width         # params[:per_page]
    # @option opt [Symbol] :offset        One of self#OFFSETS
    # @option opt [String] :origin
    # @option opt [String] :skip          For SolrDocument#initialize
    # @option opt [String] :qt
    # @option opt [String] :fwd_shelfkey
    # @option opt [String] :rev_shelfkey
    # @option opt [Hash]   :params        Required.
    # @option opt [Hash]   :session       Required.
    #
    # === Usage Notes
    # If *doc* is a document with SORTKEY_FIELD and REVERSE_SORTKEY_FIELD then
    # it is accepted as the origin of the virtual shelf.  If it does not have
    # those fields then its ID is used to acquire a suitable replacement.
    # Otherwise *doc* is interpreted as a document ID to lookup.
    #
    # @see self#get_nearby_documents
    #
    def initialize(doc, opt = nil)
      opt ||= {}

      # Operational properties.
      @request_handler = str(opt[:qt])           || SOLR_REQUEST_HANDLER
      @fwd_shelfkey    = str(opt[:fwd_shelfkey]) || SORTKEY_FIELD
      @rev_shelfkey    = str(opt[:rev_shelfkey]) || REVERSE_SORTKEY_FIELD

      # Request properties.
      @origin         = nil
      @start          = str(opt[:start])
      @offset         = sym(opt[:offset])
      @requested_page = int(opt[:page])  || DEFAULT_PAGE
      @hits_requested = int(opt[:width]) || DEFAULT_HITS
      @skip           = str(opt[:skip])

      # Copies of `params` and `session` for use within Blacklight
      # configuration interface methods.
      @params  = opt[:params]  || {}
      @session = opt[:session] || {}

      # Get the selection of documents from the virtual shelf centered on the
      # given document.  If no document or ID was supplied, use the :start
      # option parameter containing a call number to acquire a virtual shelf
      # window starting with the nearest matching call number.
      if doc
        @offset ||= :center
        @origin    = get_origin(doc)
        @documents = get_nearby_documents
      elsif @start
        @offset ||= :left
        @documents = get_documents_from(@start)
      else
        Rails.logger.warn { "SolrBrowseNearby: invalid opt = #{opt.inspect}" }
      end

      # Ensure that the result is usable.
      @documents ||= []
      normalize(@documents)
    end

    # =========================================================================
    # :section:
    # =========================================================================

    protected

    # Retrieve a document that is suitable for use as the origin of the virtual
    # shelf.
    #
    # @param [String, SolrDocument] doc
    #
    # @return [SolrDocument]
    # @return [nil]
    #
    def get_origin(doc)
      if has_required_fields?(doc)
        doc
      else
        id = doc.is_a?(SolrDocument) ? doc.doc_id : doc
        _response, docs = get_solr_response_for_field_values(:id, id)
        docs.first
      end
    end

    # Based on a given document's page number in the the search results, get
    # the neighboring documents.
    #
    # - Negative page numbers return documents "behind" the ID.
    # - Positive page numbers return documents "in front of" the ID.
    # - Otherwise, the result includes the documents "behind", the document
    #     itself, and the documents "in front of" the ID.
    #
    # @param [SolrDocument] doc       Defaults to self#origin.
    #
    # @return [Array<SolrDocument,Symbol>]
    #
    def get_nearby_documents(doc = nil)

      doc ||= @origin

      # Determine the size and page number of the Solr request.
      mode =
        case offset
          when :left  then -1
          when :right then +1
          else             (requested_page <=> 0)
        end

      # Get the part(s) of the virtual shelf window.
      result = []
      result << get_prev_documents(doc) if mode <= 0
      result << doc                     if mode == 0
      result << get_next_documents(doc) if mode >= 0
      result.compact.flatten

    end

    # Get a section of the virtual shelf starting with the given call number.
    #
    # @param [String,Lcc::LccNum] call_number   Default self#start.
    # @param [Fixnum]             page          Default self#requested_page
    #
    # @return [Array<SolrDocument,Symbol>]
    # @return [nil]                   If the terms could not be acquired.
    #
    def get_documents_from(call_number, page = nil)
      call_number ||= start
      page        ||= requested_page
      starting_point = Lcc::LccNum[call_number]
      if page < 0
        get_prev_documents(starting_point)
      else
        get_next_documents(starting_point)
      end
    end

    # Get the prior set of documents.
    #
    # @param [SolrDocument,String,Lcc::LccNum] starting_point
    #   Either a document, a call number or a literal shelfkey value.
    #
    # @return [Array<SolrDocument,Symbol>]
    # @return [nil]                   If the terms could not be acquired.
    #
    def get_prev_documents(starting_point)
      get_documents(starting_point, @rev_shelfkey)
    end

    # Get the next set of documents.
    #
    # @param [SolrDocument,String,Lcc::LccNum] starting_point
    #   Either a document, a call number or a literal shelfkey value.
    #
    # @return [Array<SolrDocument,Symbol>]
    # @return [nil]                   If the terms could not be acquired.
    #
    def get_next_documents(starting_point)
      get_documents(starting_point, @fwd_shelfkey)
    end

    # Returns an array of documents forward of the given term in the given
    # field.
    # These documents are sorted by the configured solr field.
    # Using solr's termsComponent we request the next terms from the given
    # field and value.
    # This works for backward sorting by using a reverse-sort keys.
    # We then request the documents for those terms from solr via Blacklight's
    # get_solr_response_for_field_values
    #
    # @param [SolrDocument,String,Lcc::LccNum] starting_point
    #   Either a document, a call number or a literal shelfkey value.
    # @param [Symbol] field
    #   Either @fwd_shelfkey or @rev_shelfkey
    #
    # @return [Array<SolrDocument,Symbol>]
    # @return [nil]                   If the terms could not be acquired.
    #
    # === Implementation Notes
    # Acquiring the documents requires two Solr queries -- the first to get the
    # sequence of shelfkeys, and the second to query for the documents matching
    # those shelfkeys.
    #
    def get_documents(starting_point, field)

      # Determine the shelfkey value based on the nature of *starting_point*.
      forward = (field != @rev_shelfkey)
      skey = doc = nil
      case starting_point
        when SolrDocument
          doc  = starting_point
          skey = doc[field]
        when String
          skey = starting_point
        when Lcc::LccNum
          skey =
            if forward
              starting_point.to_shelfkey
            else
              starting_point.to_reverse_shelfkey
            end
        else
          Rails.logger.error { "#{__method__}: #{doc.class} unexpected" }
      end

      # Get the Solr list of shelfkeys starting with *skey*.
      terms = get_ordered_terms(skey, field)
      return if terms.blank?

      # Get a Solr document for each shelfkey.
      request_size = terms.size
      opt = { per_page: request_size, skip: @skip }
      _response, docs = get_solr_response_for_field_values(field, terms, opt)

      # Make sure that the returned array is in non-decreasing order.
      sort_key = @fwd_shelfkey
      docs.sort! { |a, b| a[sort_key].to_s <=> b[sort_key].to_s }
      Rails.logger.debug {
        "*** #{field} count=#{docs.size} #{docs.map(&:doc_id)}"
      }

      # If there was an unexpected result, report an error and adjust.
      # (For example, if the shelfkey scheme in Solr includes items that are
      # not supposed to be displayed in Virgo [and are filtered out by the Solr
      # request] then `docs.size` will be less than `request_size`.)
      missing = request_size - docs.size
      action =
        case (missing <=> 0)
          when +1 then :pad
          when -1 then :drop
        end
      if action
        Rails.logger.error {
          ident = doc ? doc.doc_id : starting_point
          action_taken =
            (action == :pad) ? "padding #{missing}" : "dropping #{-missing}"
          %Q(
            ERROR: #{ident}:
            expected #{request_size}; got #{docs.size}; #{action_taken}
            [#{field} == #{skey.inspect}]
          ).squish
        }
      end
      case action
        when :pad
          padding = [:empty] * missing
          forward ? (docs + padding) : (padding + docs)
        when :drop
          docs.take(request_size)
        else
          docs
      end

    end

    # Returns an array of the next terms using solr's termsComponent.
    # The number of terms requested/returned from solr may be much larger than
    # what is returned by this method when paging.
    # The pagination happens here and we paginate the returned terms before we
    # request the related documents.
    # This keeps the URLs free of sortkey values.
    #
    # @param [String] skey            A *shelfkey* or *reverse_shelfkey* value.
    # @param [Symbol] field           Either @fwd_shelfkey or @rev_shelfkey.
    #
    # @return [Array<String>]
    # @return [nil]                   If *skey* or *field* was missing.
    #
    def get_ordered_terms(skey, field)
      return if skey.blank? || field.blank?
      Rails.logger.debug { ">>> #{__method__} for #{skey.inspect}" }
      first = start_of_terms
      last  = total_terms - 1
      url_params = {
        :'terms.fl'    => field.to_s,
        :'terms.lower' => skey.downcase,
        :'terms.limit' => total_terms,
      }
      response = solr_request(request_handler, url_params)
      terms = response && response['terms'].presence
      terms &&= terms[field]
      terms &&= terms.select { |term| term.is_a?(String) }
      terms &&= terms[first..last]
      Rails.logger.debug {
        %Q(
          *** #{__method__}
          (count #{terms && terms.size})
          terms[#{first}..#{last}] =
          #{terms && terms.inspect}
        ).squish
      }
      terms
    end

    # Guard against duplicates.
    #
    # @return [Array<SolrDocument,Symbol>]
    #
    # @return [void]
    #
    def normalize(docs = nil)
      docs ||= @documents || []
      ids = {}
      docs.length.times do |index|
        doc = docs[index]
        next unless docs[index].is_a?(SolrDocument)
        id = doc.doc_id
        if ids[id]
          docs[index] = :error
          Rails.logger.error {
            "SolrBrowseNearby: duplicate ID: #{id.inspect}"
          }
        else
          ids[id] = true
        end
      end
    end

    # The beginning of the range of terms we'll request from Solr.
    #
    # @return [Fixnum]
    #
    def start_of_terms
      (requested_page == 0) ? 0 : (total_terms - hits_requested)
    end

    # The total number of terms to request from Solr to get a full page of
    # results starting with the origin.
    #
    # @return [Fixnum]
    #
    def total_terms
      page_0_offset + page_terms
    end

    # The number of terms to request from Solr to get to the requested page in
    # the search results.
    #
    # @return [Fixnum]
    #
    def page_terms
      requested_page.abs * hits_requested
    end

    # The number of items before (or after) the item at the center of the
    # window.
    #
    # Since page 0 is centered on the item of interest, this number represents
    # the offset to the pages preceding or following page 0.
    #
    # @return [Fixnum]
    #
    def page_0_offset
      case @offset
        when :left   then hits_requested
        when :center then (hits_requested - 1) / 2
        when :right  then raise 'not currently implemented'
        else              raise "offset :#{@offset} unexpected"
      end
    end

    # Indicates whether the document has all the required fields for browsing.
    #
    # @param [SolrDocument] doc
    #
    def has_required_fields?(doc)
      doc.is_a?(SolrDocument) &&
        REQUIRED_FIELDS.all?  { |field| doc.values_for(field).first }
    end

    # =========================================================================
    # :section:
    # =========================================================================

    private

    # Return Fixnum or *nil* for *value*.
    #
    # @param [Object] value
    #
    # @return [Fixnum]
    # @return [nil]
    #
    def int(value)
      value.to_i if value.present?
    end

    # Return String or *nil* for *value*.
    #
    # @param [Object] value
    #
    # @return [String]
    # @return [nil]
    #
    def str(value)
      value.to_s if value.present?
    end

    # Return Symbol or *nil* for *value*.
    #
    # @param [Object] value
    #
    # @return [Symbol]
    # @return [nil]
    #
    def sym(value)
      value.to_sym if value.present?
    end

  end

end
