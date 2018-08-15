# lib/uva/article_doc.rb

require 'uva'

module UVA

  # The interface definition for articles, which should be mixed in to the
  # class which represents an article from a specific article search provider.
  #
  #--
  # rubocop:disable Metrics/ModuleLength # [310/300]
  #++
  module ArticleDoc

    include UVA
    include UVA::Accessibility
    include UVA::IndexDoc

    # Supported formats hard-coded so that index documents based on this module
    # respond like those based on Blacklight::Solr::Document.
    EXPORT_FORMATS = {
      ris:               'ris',      # Zotero RIS
      endnote:           'endnote',  # EndNote
      refworks_marc_txt: 'refworks', # RefWorks
    }.deep_freeze

    # =========================================================================
    # :section:
    # =========================================================================

    public

    # Item metadata.
    #
    # @return [Display]
    #
    attr_accessor :display

    # Item container metadata.
    #
    # @return [AdditionalData]
    #
    attr_accessor :additional_data

    # Item retrieval metadata.
    #
    # @return [Search]
    #
    attr_accessor :search

    # Link(s) to the item.
    #
    # @return [Array<Link>]
    #
    attr_accessor :links

    # @note Only used by Primo
    #
    # @return [Array<GetIt>]
    #
    # @see UVA::Article::Primo::Display#get_its
    #
    attr_accessor :get_its

    # Initialize a self instance.
    #
    # It is expected that the including class will initialize @display,
    # @additional_data and @search with its own derivatives of Display,
    # AdditionalData and Search.
    #
    # @param [Array] args             Passed to the super initializer.
    #
    def initialize(*args)
      super(*args)
      @links   = []
      @get_its = []
    end

    # =========================================================================
    # :section: Blacklight::Solr::Document interface
    # =========================================================================

    public

    # @see UVA::IndexDoc#export_formats
    #
    # Supported formats hard-coded so that index documents based on this module
    # respond like those based on Blacklight::Solr::Document.
    #
    # @return [Hash{Symbol=>String}]
    #
    def export_formats
      EXPORT_FORMATS
    end

    # =========================================================================
    # :section: Document properties (core)
    # =========================================================================

    public

    # @see UVA::IndexDoc#doc_type
    #
    def doc_type
      :article
    end

    # =========================================================================
    # :section: Document methods (core)
    # =========================================================================

    public

    # @see UVA::IndexDoc#online_only?
    #
    def online_only?
      true
    end

    # @see UVA::IndexDoc#internet_only?
    #
    def internet_only?
      true
    end

    # @see UVA::IndexDoc#journal?
    #
    def journal?
      true
    end

    # @see UVA::IndexDoc#availability_on_show_page?
    #
    def availability_on_show_page?
      links.first.present?
    end

    # =========================================================================
    # :section: Document properties (Title components)
    # =========================================================================

    public

    # @see UVA::IndexDoc#title
    #
    def title(opt = {})
      opt[:value] = display.title unless opt.key?(:value)
      super(opt)
    end

    # =========================================================================
    # :section: Document properties (Bibliographic information)
    # =========================================================================

    public

    # @see UVA::IndexDoc#pub_year
    #
    def pub_year
      pub_date.sub(/^(\d\d\d\d).*$/, '\1') if pub_date
    end

    # @see UVA::IndexDoc#pub_date
    #
    def pub_date
      search.creation_date
    end

    # =========================================================================
    # :section: Document properties (Identifiers)
    # =========================================================================

    public

    # @see UVA::IndexDoc#issns
    #
    # @see ArticleDoc#issns=
    #
    def issns
      @issns ||= []
    end

    # @see UVA::IndexDoc#dois
    #
    # @see ArticleDoc#dois=
    #
    def dois
      @dois ||= []
    end

    # @see UVA::IndexDoc#call_numbers
    #
    # @see ArticleDoc#call_numbers=
    #
    def call_numbers
      @call_numbers ||= []
    end

    # =========================================================================
    # :section: Document properties (Articles)
    # =========================================================================

    public

    # @see UVA::IndexDoc#type
    #
    # This value is not part of a controlled vocabulary, and the specific terms
    # used may vary from publisher to publisher.
    #
    def type
      display.type.presence
    end

    # @see UVA::IndexDoc#is_part_of
    #
    def is_part_of
      display.is_part_of.presence
    end

    # @see UVA::IndexDoc#journal
    #
    def journal
      additional_data.journal.presence
    end

    # @see UVA::IndexDoc#volume
    #
    def volume
      additional_data.volume.presence
    end

    # @see UVA::IndexDoc#issue
    #
    def issue
      additional_data.issue.presence
    end

    # @see UVA::IndexDoc#start_page
    #
    # Depending on the publisher (or the context) this number may actually
    # represent a count of the number pages in the article and not a page
    # number location within the publication.
    #
    def start_page
      additional_data.start_page.presence
    end

    # @see UVA::IndexDoc#end_page
    #
    # This may be blank, depending on the publisher -- especially if the
    # #start_page value is actually a page count and not a page number location
    # within the publication.
    #
    def end_page
      additional_data.end_page.presence
    end

    # @see UVA::IndexDoc#accession_number
    #
    def accession_number
      id.to_s.presence
    end

    # @see UVA::IndexDoc#identifiers
    #
    def identifiers
      display.identifier || ''
    end

    # =========================================================================
    # :section: Document values (Bibliographic information)
    # =========================================================================

    public

    # @see UVA::IndexDoc#get_authors
    #
    def get_authors
      Array(display.creator.presence)
    end

    # @see UVA::IndexDoc#get_language
    #
    def get_language
      Array(display.language.presence)
    end

    # @see UVA::IndexDoc#get_subjects
    #
    def get_subjects
      search.subject_facet
    end

    # @see UVA::IndexDoc#get_description
    #
    # @return [Array<String>]
    #
    def get_description
      display.description
    end

    # @see UVA::IndexDoc#get_abstract
    #
    def get_abstract
      get_description
    end

    # @see UVA::IndexDoc#get_abstract_fields
    #
    def get_abstract_fields(*parts)
      update_options(__method__, parts, inner_sep: false)
      parts.unshift([nil, get_abstract])
      super
    end

    # @see UVA::IndexDoc#get_note_fields
    #
    def get_note_fields(*parts)
      parts.unshift([nil, identifiers])
      super
    end

    # =========================================================================
    # :section: Document values (Identifiers)
    # =========================================================================

    public

    # @see UVA::IndexDoc#get_url
    #
    def get_url
      links.map { |link| link.url }.reject(&:blank?)
    end

    # @see UVA::IndexDoc#get_url_links
    #
    # TODO: Need to have a generalized "Link" class that can work for both
    # EBSCO result and Solr results.
    #
    def get_url_links
      links.map { |link| [link.url, link.name] }
    end

    # =========================================================================
    # :section: HTML support methods
    # =========================================================================

    public

    # @see UVA::IndexDoc#show_heading_author
    #
    # Returns a string containing the "authors" suitable for display as the
    # author/creator for the item.
    #
    def show_heading_author
      display.creator
    end

    # @see UVA::IndexDoc#show_heading_title
    #
    # This override make the main show page title fall back to the journal
    # title if the article does not have a title.
    #
    def show_heading_title
      result = title
      result = journal if result.blank?
      result = 'n/a'   if result.blank?
      result
    end

    # =========================================================================
    # :section:
    # =========================================================================

    protected

    # Assign ISSNs to this document.
    #
    # @param [Array<String>] value
    #
    # @return [Array<String>]
    #
    # @see UVA::IndexDoc#issns
    #
    def issns=(value)
      @issns = value
    end

    # Assign DOIs to this document.
    #
    # @param [Array<String>] value
    #
    # @return [Array<String>]
    #
    # @see UVA::IndexDoc#dois
    #
    def dois=(value)
      @dois = value
    end

    # Assign LOC call numbers to this document.
    #
    # @param [Array<String>] value
    #
    # @return [Array<String>]
    #
    # @see UVA::IndexDoc#call_numbers
    #
    def call_numbers=(value)
      @call_numbers = value
    end

    # =========================================================================
    # :section: HTML support methods
    # =========================================================================

    public

    # All links to be shown in the availability box.
    #
    # @return [Array<Link>]
    #
    def all_links
      links
    end

    # A table of titles and links to be shown in the availability box.
    #
    # @return [Array<Array<(ActiveSupport::SafeBuffer,ActiveSupport::SafeBuffer)>>]
    #
    def availability_links
      all_links.map { |link|
        next if link.blank?
        thumbnail = link.thumbnail.presence
        text = link.text.html_safe.presence
        name = link.name.presence
        if name && (name =~ /Serials Solutions/)
          text ||= 'Find at UVa'
          journal = ERB::Util.h(get_journal.first)
          name = "Online via <strong>#{journal}</strong>".html_safe
        end
        h3_title =
          if thumbnail
            %Q(<img src="#{thumbnail}" alt="#{text}" />).html_safe
          else
            text || 'Other Link'
          end
        link_entry =
          if link.url.present?
            tip = name ? strip_html(name) : 'Link'
            name ||= link.url
            opt = {
              href:   link.url,
              target: '_blank',
              title:  "#{tip} (opens in a new window)",
              ARIA_LABEL => tip
            }.map { |k, v|
              %Q(#{k}="#{v}")
            }.join(' ')
            %Q(<a #{opt}>#{name}</a>).html_safe
          else
            name || 'Not provided'
          end
        [ERB::Util.h(h3_title), ERB::Util.h(link_entry)]
      }.compact
    end

    # rubocop:enable Metrics/ModuleLength
  end

  # ===========================================================================
  # :section: Common ArticleDoc data classes
  # ===========================================================================

  public

  # Patterned after a unit of information returned by the original article
  # provider (Primo).
  #
  # @see UVA::Article::Primo::Display
  #
  # TODO: Refactor: This does not need to be a distinct class or module.
  # The information it contains (except for the Primo-specific fields) could
  # simply be stored directly in UVA::ArticleDoc.
  #
  class ArticleDoc::Display

    # A listing the author(s) of the item.
    #
    # @return [String]
    #
    attr_accessor :creator

    # @return [String]
    attr_accessor :identifier

    # The language(s) associated with the item.
    #
    # @return [String]
    #
    attr_accessor :language

    # @return [String]
    attr_accessor :subject

    # @return [String]
    attr_accessor :title

    # @return [String]
    attr_accessor :type

    # @return [Array<String>]
    attr_accessor :description

    # A listing of the publication that contains the item and its location
    # within it (volume, issue, page number).
    #
    # @return [String]
    #
    attr_accessor :is_part_of

    # For Primo, ...
    #
    # @return [String]
    #
    # @see UVA::Article::Primo::Display#lds50
    #
    attr_accessor :lds50

    # For Primo, a listing of the publisher(s) of the publication(s) that
    # contain the item.
    #
    # @return [String]
    #
    # @see UVA::Article::Primo::Display#source
    #
    attr_accessor :source

    # For Primo...
    #
    # @return [String]
    #
    # @see UVA::Article::Primo::Display#version
    #
    attr_accessor :version

    # =========================================================================
    # :section:
    # =========================================================================

    public

    # Initialize a new self instance.
    #
    def initialize
      @type = 'Article'
      @description = []
    end

  end

  # Patterned after a unit of information returned by the original article
  # provider (Primo).
  #
  # @see UVA::Article::Primo::AdditionalData
  #
  # TODO: Refactor: This does not need to be a distinct class or module.
  # The information it contains (except for the Primo-specific fields) could
  # simply be stored directly in UVA::ArticleDoc.
  #
  class ArticleDoc::AdditionalData

    # @return [String]
    attr_accessor :journal

    # @return [String]
    attr_accessor :volume

    # @return [String]
    attr_accessor :issue

    # @return [String]
    attr_accessor :start_page

    # @return [String]
    attr_accessor :end_page

    # =========================================================================
    # :section:
    # =========================================================================

    public

    # Initialize a new self instance.
    #
    def initialize
    end

  end

  # Patterned after a unit of information returned by the original article
  # provider (Primo).
  #
  # @see UVA::Article::Primo::Search
  #
  # TODO: Refactor: This does not need to be a distinct class or module.
  # The information it contains (except for the Primo-specific fields) could
  # simply be stored directly in UVA::ArticleDoc.
  #
  class ArticleDoc::Search

    # @return [String]
    attr_accessor :creation_date

    # @return [String]
    attr_accessor :id

    # @return [Array<String>]
    attr_accessor :subject_facet

    # =========================================================================
    # :section:
    # =========================================================================

    public

    # Initialize a new self instance.
    #
    def initialize
      @subject_facet = []
    end

  end

  # ArticleDoc::Link
  #
  class ArticleDoc::Link

    # @return [String]
    attr_accessor :text

    # @return [String]
    attr_accessor :name

    # @return [String]
    attr_accessor :thumbnail

    # @return [String]
    attr_accessor :url

    # =========================================================================
    # :section:
    # =========================================================================

    public

    # Initialize a new self instance.
    #
    # @param [String] ur
    # @param [String] tx
    # @param [String] nm
    # @param [String] th
    #
    def initialize(ur = nil, tx = nil, nm = nil, th = nil)
      @url       = ur || default_url
      @text      = tx || default_text
      @name      = nm || default_name || @url
      @thumbnail = th || default_thumbnail
    end

    # =========================================================================
    # :section:
    # =========================================================================

    public

    # default_url
    #
    # @return [String]
    # @return [nil]
    #
    def default_url
    end

    # default_text
    #
    # @return [String]
    # @return [nil]
    #
    def default_text
    end

    # default_name
    #
    # @return [String]
    # @return [nil]
    #
    def default_name
    end

    # default_thumbnail
    #
    # @return [String]
    # @return [nil]
    #
    def default_thumbnail
    end

  end

  # Common attributes for the response from the article search provider.
  #
  # This class provides a certain amount of duck-type compatibility with
  # RSolr::Ext::Response::Base through #total, #rows, #params, and #facets.
  #
  # === Implementation Notes
  # In order to have this be the base class for all three article providers,
  # members for *counts*, *facets*, and *docs* cannot be defined here because
  # they would conflict with UVA::Article::Primo::Response.
  #
  class ArticleDoc::Response

    SUCCESS_CODE = 0
    FAILURE_CODE = -1

    DEF_ERROR_CODE    = FAILURE_CODE
    DEF_CURRENT_PAGE  = 1
    DEF_PER_PAGE      = 20
    DEF_PARAMS        = {}.freeze
    DEF_PAGE_SIZES    = %w(20 50 100)

    # =========================================================================
    # :section:
    # =========================================================================

    public

    # For Kaminari paginate.
    PageScope = Struct.new(:current_page, :num_pages, :limit_value)

    # @return [String]
    attr_reader :provider

    # @return [Fixnum]
    attr_accessor :error_code

    # @return [Hash]
    attr_accessor :response

    # @return [Hash]
    attr_accessor :params

    # @return [Fixnum]
    attr_accessor :current_page

    # @return [Fixnum]
    attr_accessor :per_page

    # =========================================================================
    # :section:
    # =========================================================================

    public

    # Initialize a new self instance.
    #
    # @param [String] provider_name   To be set by the derived class.
    #
    def initialize(provider_name = nil)
      @provider     = provider_name
      @error_code   = DEF_ERROR_CODE
      @response     = {}
      @params       = {}
      @current_page = DEF_CURRENT_PAGE
      @per_page     = DEF_PER_PAGE
    end

    # Wipe data and set an error code.
    #
    # @param [Fixnum] code
    #
    def reset(code = nil)
      code ||= DEF_ERROR_CODE if @error_code.zero?
      @error_code = code if code
    end

    # =========================================================================
    # :section: UVA::IndexDoc compatibility
    # =========================================================================

    public

    # Added to complete duck-type compatibility with RSolr::Ext::Response::Base
    #
    def ok?
      @error_code == SUCCESS_CODE
    end

    # =========================================================================
    # :section: Pagination
    # =========================================================================

    public

    # total
    #
    # (For Kaminari)
    #
    # @return [Fixnum]
    #
    def total
      raise 'Must be overridden'
    end

    # total_pages
    #
    # (WillPaginate hook)
    #
    # @return [Fixnum]
    #
    def total_pages
      (total / per_page).ceil + 1
    end

    # previous_page
    #
    # (WillPaginate hook)
    #
    # @return [Fixnum]
    #
    def previous_page
      (current_page > 1) ? (current_page - 1) : 1
    end

    # next_page
    #
    # (WillPaginate hook)
    #
    # @return [Fixnum]
    #
    def next_page
      (current_page == total_pages) ? total_pages : (current_page + 1)
    end

    # =========================================================================
    # :section: Pagination
    # =========================================================================

    public

    # rows
    #
    # (For Kaminari)
    #
    # @return [Fixnum]
    #
    def rows
      per_page
    end

    # start
    #
    # (For Kaminari)
    #
    # @return [Fixnum]
    #
    def start
      (params && params[:start]).to_i
    end

    # per_page_choices
    #
    # @return [Array<String>]
    #
    def per_page_choices
      DEF_PAGE_SIZES
    end

    # This is similar to the Blacklight method but modified to limit access via
    # the Kaminari paginator to no more results than is permitted for articles.
    #
    # @return [PageScope]
    #
    # @see UVA::Article::Primo::Response#paginate_values
    # @see UVA::Article::Summon::Response#paginate_values
    #
    # Compare with:
    # @see Blacklight::CatalogHelperBehavior#paginate_params
    #
    def paginate_values
      per_page = rows || 1
      per_page = 1 if per_page < 1
      current_page = (start / per_page).ceil + 1
      num_pages = (total / per_page.to_f).ceil
      PageScope.new(current_page, num_pages, per_page)
    end

    # =========================================================================
    # :section: Class Methods
    # =========================================================================

    public

    # What page we are on.
    #
    # @param [Hash] search_params
    #
    # @return [Fixnum]
    #
    def self.page(search_params = {})
      p = search_params[:page].to_i
      p.zero? ? DEF_CURRENT_PAGE : p
    end

    # How many results per page.
    #
    # @param [Hash] search_params
    #
    # @return [Fixnum]
    #
    def self.per_page(search_params = {})
      p = search_params[:per_page].to_i
      p.zero? ? DEF_PER_PAGE : p
    end

  end

end
