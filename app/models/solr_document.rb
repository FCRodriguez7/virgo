# app/models/solr_document.rb

require 'blacklight/solr/document'
require 'uva'
require 'firehose'

# SolrDocument
#
# @see Blacklight::Solr::Document
# @see UVA::IndexDoc
#
#--
# rubocop:disable Metrics/ClassLength # [914/300]
#++
class SolrDocument

  include UVA

  # This comes first so that its definitions can be overridden.
  include Blacklight::Solr::Document

  # This comes next to patch #will_export_as.
  include UVA::IndexDoc::Base

  # This follows because it uses #will_export_as and supplies the default
  # implementations for MARC documents.
  include Blacklight::Solr::Document::MarcExport

  # Finally, UVA::IndexDoc supplies definitions which override Blacklight
  # methods as the basis for this definitions in this class.
  include UVA::Exceptions
  include UVA::IndexDoc
  include UVA::Marc::Relator
  include UVA::Util::DateMethods
  include UVA::Util::Dev

  Debug.setup(
    active:               Virgo.desktop_development?,
    initialize:           false,
    :[] =>                false,
    availability:         false,
    refresh_availability: true,
    export_as_json:       false,
    marc_display:         false,
    marc_call_numbers:    false,
    get_shelf_numbers:    false,
    get_call_numbers:     false,
  )

  # ===========================================================================
  # :section:
  # ===========================================================================

  public

  # If *true* SolrDocument will be frozen after creation.
  #
  # === Implementation Notes
  # The strategy of freezing SolrDocument is test/development environments can
  # be problematic in conjunction with caching.  For now this will be disabled.
  #
  SOLR_DEEP_FREEZE = false

  # Current list of values that may be in the Solr :feature_facet field.
  #
  # @see self#has_feature?
  #
  SOLR_RECORD_FEATURES = %w(
    has_archival_holdings
    has_djatoka_image
    has_embedded_avalon_media
    has_hierarchy
    pda_ebook
    pda_print
    suppress_endnote_export
    suppress_refworks_export
    suppress_ris_export
  ).deep_freeze

  # Matches export format with a Solr :feature_facet value which indicates that
  # type of export is suppressed for the current item.
  EXPORT_SUPPRESSION = {
    ris:               'suppress_ris_export',
    refworks_marc_txt: 'suppress_refworks_export',
    endnote:           'suppress_endnote_export',
  }.deep_freeze

  # Author names which are known to be inappropriate for displaying as authors.
  #
  # Electronic resources from Ebrary are all mis-cataloged so that the name of
  # the collection appears to be an author (MARC 710 is missing a subfield to
  # specify the role), so these are specifically removed from the results.
  #
  INVALID_AUTHORS = [
    / Collection /,
    / eBook/,
    / ebooks/,
    /E-Book/,
    /iLibrary/,
    /Books Online/,
    /Literature Online/,
    /Online Service/i,
    /Scripts Online/,
    /Scholarship Online/,
    /^Academic Search Complete/,
    /^ACM Digital Library/,
    /^Business Source Complete/,
    /^DOAB: Directory of Open Access Books/,
    /^Ebrary,/i,
    /Ebrary .* Collection/,
    /^Education Research Complete/,
    /^HeinOnline /,
    /^Inter-university Consortium for Political and Social Research/,
    /^MasterFILE/,
    /McGregor Library/,
    /McGregor Fund/,
    /^Naxos Digital Services/,
    /^NetLibrary/,
    /^Open Knowledge Repository/,
    /^Sabin Americana/,
    /^SAGE Research Methods Online/,
    /^SpringerLINK/i,
    /^SPIE Conference Proceedings/,
    /^University of Virginia\. donor/,
  ].deep_freeze

  # A simplified subset of SuDoc classification letters which do not clash with
  # LC call number ranges.
  #
  # @see https://www.fdlp.gov/catalogingandclassification/cataloging-articles/1791-sudocs-classification?showall=&start=2
  # @see https://babel.hathitrust.org/cgi/pt?id=pur1.32754050144454;view=1up;seq=18
  #
  SUDOC_LETTERS = %w(
    AA
    ED EP
    FA FCA FEM FHF FM FMC FR FT FTZ
    GP GS
    HH
    I IA IC ID ITC
    JU
    LR
    MS
    NAS NCU NF NMB NS
    OP
    PREX PRVP
    RR
    SBA SE SI SSA
    TDA
    X
    Y
  ).deep_freeze

  # SuDoc classification letters which overlap LC call number ranges.
  #
  CLASHING_SUDOC_LETTERS = %w(
    A AC AE
    B
    C CC CR
    D
    E
    GA
    HE HS
    J
    L LC
    NC
    P PE PM PR
    S
    T TD
    VA
  ).deep_freeze

  # Patterns which match SuDoc classification numbers.
  SUDOC_PATTERNS =
    /^(#{(SUDOC_LETTERS + CLASHING_SUDOC_LETTERS).sort.join('|')})[^A-Z].*:/i

  # The value of the Solr facet for Congressional Hearings documents.
  CONGRESSIONAL_HEARINGS_FACET =
    'ProQuest U.S. Congressional Hearings Digital Collection'.freeze

  # Publication place for local (repository) items.
  UVA_PUBLICATION_PLACE  = 'Charlottesville, VA'.freeze
  ETD_PUBLICATION_PLACE  = UVA_PUBLICATION_PLACE
  REPO_PUBLICATION_PLACE = UVA_PUBLICATION_PLACE

  # Publisher name for local (repository) items.
  UVA_PUBLISHER  = 'University of Virginia'.freeze
  ETD_PUBLISHER  = UVA_PUBLISHER
  REPO_PUBLISHER = 'University of Virginia Library'.freeze

  # Maximum number of characters of the title to display at the head of the
  # item details show page.  (Use *nil* for no limit.)
  SHOW_TITLE_MAX_LENGTH = nil

  # Maximum number of characters of the author list to display at the head of
  # the item details show page.  (Use *nil* for no limit.)
  SHOW_AUTHORS_MAX_LENGTH = 350

  # Augmented list of words for UVA::Utils::StringMethods#titleize to undo
  # capitalization of parenthesized role terms in names.
  AUTHOR_LOWERCASE_WORDS = (
    RELATOR_MAP.values.map { |v| '\(' + v.downcase.gsub(/\s/, '\ ') + '\)' } +
    LOWERCASE_WORDS.reject { |v| v.length == 1 }
  ).deep_freeze

  # MARC 524 patterns matching accession numbers for use within Regexps.
  ACCESSION_NUMBER_PATTERN = ['Accession ', 'RG-'].join('|').freeze

  # ===========================================================================
  # :section: Blacklight Extensions
  #
  # The `use_extension` method causes the given module to be mixed in to this
  # class at the end of executing RSolr::Ext::Model#initialize
  # ===========================================================================

  extension_parameters[:marc_source_field] = :marc_display
  extension_parameters[:marc_format_type]  = :marcxml

  # This extension makes use of RSolr::Ext::Model::Callbacks#after_initialize
  # to restore the enhanced versions of certain Blacklight methods that are
  # defined under UVA:IndexDoc but are overridden when including
  # Blacklight::Solr::Document and must be redefined via this callback.

  use_extension(Blacklight::Solr::Document::Marc) do |doc|
    doc.key?(:marc_display)
  end

  # If the digital image extension interface is present, determine whether the
  # extension should be applied to the current document.
  if include?(UVA::DigitalImage)
    use_extension(UVA::DigitalImage::Extension) do |doc|
      doc.is_digital_image?
    end
  end

  # If the EAD extension interface is present, determine whether the extension
  # should be applied to the current document.
  if include?(UVA::Ead)
    use_extension(UVA::Ead::Extension) do |doc|
      doc.is_ead?
    end
  end

  # If the TEI extension interface is present, determine whether the extension
  # should be applied to the current document.
  if include?(UVA::Tei)
    use_extension(UVA::Tei::Extension) do |doc|
      doc.is_tei?
    end
  end

  # If the PBCore extension interface is present, determine whether the
  # extension should be applied to the current document.
  if include?(UVA::PBCore)
    use_extension(UVA::PBCore::Extension) do |doc|
      doc.is_pbcore?
    end
  end

  # If the ICPSR extension interface is present, determine whether the
  # extension should be applied to the current document.
  if include?(UVA::ICPSR)
    use_extension(UVA::ICPSR::Extension) do |doc|
      doc.is_icpsr?
    end
  end

  # If the IIIF extension interface is present, determine whether the extension
  # should be applied to the current document.
  if include?(UVA::IIIF)
    use_extension(UVA::IIIF::Extension) do |doc|
      doc.is_iiif?
    end
  end

  # Blacklight export formats.
  #
  # These were originally intended only for documents with MARC metadata.
  #
  # @see self#refresh_export_formats
  # @see Blacklight::Solr::Document::MarcExport#register_export_formats
  #
  BLACKLIGHT_EXPORT_FORMATS = {
    xml:               nil,
    marc:              'application/marc',
    marcxml:           'application/marcxml+xml',
    openurl_ctx_kev:   'application/x-openurl-ctx-kev',
    refworks_marc_txt: 'text/plain',
    endnote:           'application/x-endnote-refer'
  }.deep_freeze

  # UVA export formats.
  #
  # These apply regardless of the document type (MARC or non-MARC).
  #
  # @see self#refresh_export_formats
  #
  UVA_EXPORT_FORMATS = {
    xml:               nil,
    json:              nil,
    ris:               'application/x-research-info-systems',
    endnote:           'x-endnote-refer',
    refworks_marc_txt: 'text/plain',
  }.deep_freeze

  # ===========================================================================
  # :section:
  # ===========================================================================

  public

  # Initialize a new self instance.
  #
  # @param [Hash]                       doc
  # @param [RSolr::Ext::Response::Base] solr_response
  # @param [Hash]                       opt
  #
  # === Development options
  # These are either not relevant or not desirable for deployed production
  # servers.
  #
  # @option opt [Boolean] :availability   If *false*, Firehose will not be
  #                                         contacted for a catalog.
  #
  # @option opt [Boolean] :freeze         If *false*, the underlying data
  #                                         structures will not be frozen.
  #
  def initialize(doc, solr_response = nil, opt = nil)
    # The `use_extension` hooks are executed at the end of the superclass
    # initializer.
    super(doc, solr_response)

    # Get options (if any).
    no_availability = opt && opt.key?(:availability) && !opt[:availability]
    no_normalize    = opt && opt.key?(:normalize)    && !opt[:normalize]
    no_freeze       = opt && opt.key?(:freeze)       && !opt[:freeze]

    # Set up export formats.
    setup_export_formats

    # To skip the request for availability information:
    @availability = :none if no_availability

    # Normalize Unicode
    normalize_fields(_source) unless no_normalize

    # In all non-production environments, freeze the received Solr values to
    # discover any situations in which the data is inadvertently modified.
    deep_freeze if deep_freeze_enabled? && !no_freeze

    debug_self(__method__) if Debug[__method__]
  end

  # ===========================================================================
  # :section:
  # ===========================================================================

  protected

  # Recursively apply Unicode normalization to all String elements of *object*.
  #
  # This translates valid Unicode compositions into the equivalent single
  # character codepoint where possible.
  #
  # @param [String, Array, Hash] object
  #
  # @return [void]
  #
  def normalize_fields(object)
    case object
      when Hash
        object.each_key { |key| normalize_fields(object[key]) }
      when Array
        (0...object.size).each { |index| normalize_fields(object[index]) }
      when String
        object.replace(Unicode.nfc(object))
    end
  end

  # ===========================================================================
  # :section: RSolr::Ext::Model interface
  # ===========================================================================

  public

  # @see UVA::IndexDoc::[]
  #
  # @deprecated Use self#values_for instead.
  #
  # === Implementation Notes
  # The default behavior provided via RSolr::Ext::Model#method_missing is not
  # sufficient to satisfy the interface definition of UVA::IndexDoc.  This
  # method makes the definition explicit -- and faster (YMMV):
  # @see https://github.com/JuanitoFatas/fast-ruby#method-invocation
  #
  def [](field)
    _source[field]
  end

  # ===========================================================================
  # :section: Blacklight::Solr::Document::MarcExport interface
  # ===========================================================================

  protected

  # @see UVA::IndexDoc#get_author_list
  #
  # === Implementation Notes
  # In order to make use of improvements in UVA::Marc::Record, it is assumed
  # that if a record is provided as an argument (from Blacklight code) then
  # that record is the MARC data from this instance of SolrDocument.
  #
  def get_author_list(*)
    marc_display ? marc_authors : get_authors
  end

  # ===========================================================================
  # :section: Document properties (core)
  # ===========================================================================

  public

  # @see UVA::IndexDoc#doc_type
  #
  def doc_type
    @doc_type ||= generate_doc_type
  end

  # @see UVA::IndexDoc#doc_sub_type
  #
  def doc_sub_type
    @doc_sub_type ||= generate_doc_sub_type
  end

  # @see UVA::IndexDoc#ckey
  #
  def ckey
    doc_id[1..-1]
  end

  # @see UVA::IndexDoc#fedora_doc_id
  #
  def fedora_doc_id
    name = values_for(:datafile_name_display).first
    name.sub(%r{^/FedoraRepo/text/}, '') if name.present?
  end

  # ===========================================================================
  # :section: Document properties (core)
  # ===========================================================================

  protected

  # Document type based on the characteristics of the Solr document.
  #
  # @return [Symbol]
  #
  def generate_doc_type
    # rubocop:disable Metrics/LineLength

    # Extremely specialized views.
    return :hathi          if has?(:source_facet, 'Hathi Trust Digital Library')
    return :kluge          if has?(:doc_type_facet, 'klugeruhe')
    return :dataverse      if has?(:doc_type_facet, 'dataverse')
    return :hsl_tutorial   if has?(:digital_collection_facet, 'Bioconnector Tutorials')
    return :lib_coins      if has?(:format_facet, 'Coin')
    return :dl_image       if has?(:content_model_facet, 'media')
    return :dl_wsls_video  if has?(:content_model_facet, /uva-lib:pbcore2CModel/i)
    return :dl_text        if has?(:content_model_facet, 'text')
    return :lib_technical_report \
                           if has?(:doc_type_facet, 'libra')

    # The "data_driven" partial takes everything left that has any
    # "feature_facet" except those items that are from the "Library Catalog".
    catalog = has?(:source_facet, 'Library Catalog')
    return :data_driven    if !catalog && values_for(:feature_facet).present?

    # Choose the correct partial when ambiguous based on the following order of
    # precedence.
    return :lib_album      if has?(:format_facet, /Sound Recording/i)
    return :lib_video_full if has?(:format_facet, 'Video')
    return :lib_catalog    if catalog || has?(:marc_display_facet, 'true')

    # Otherwise...
    :default

    # rubocop:enable Metrics/LineLength
  end

  # Document sub-type based on the characteristics of the Solr document.
  #
  # @return [Symbol]
  #
  def generate_doc_sub_type
    # rubocop:disable Metrics/LineLength
    return :dl_book           if has?(:content_model_facet,      'digital_book')
    return :musical_recording if has?(:format_facet,             /Musical Recording/i)
    return :musical_score     if has?(:format_facet,             /Musical Score/i)
    return :finding_aid       if has?(:digital_collection_facet, /UVa Archival Finding Aids/i)
    :default
    # rubocop:enable Metrics/LineLength
  end

  # ===========================================================================
  # :section: Document methods (core)
  # ===========================================================================

  public

  # @see UVA::IndexDoc#marc_display
  #
  def marc_display
    unless defined?(@marc_display)
      Debug.show(__method__, 'Loading marc_display')
      @marc_display = UVA::Marc::Record.new(to_marc) rescue :no_marc
    end
    @marc_display unless @marc_display == :no_marc
  end

  # @see UVA::IndexDoc#has_marc?
  #
  def has_marc?(*)
    marc_display.present?
  end

  # @see UVA::IndexDoc#has_feature?
  #
  # @see self#SOLR_RECORD_FEATURES
  #
  def has_feature?(*features)
    has?(:feature_facet, *features)
  end

  # @see UVA::IndexDoc#online?
  #
  def online?
    has?(:format_facet, 'Online')
  end

  # @see UVA::IndexDoc#online_only?
  #
  def online_only?
    internet_only? ||
      has_feature?('pda_ebook', 'has_embedded_avalon_media') ||
      values_for(:source_facet).all? { |v| v =~ /Libra.*Repository/i } ||
      (format = values_for(:format_facet)).include?('Coin') ||
      (%w(Online Photographs) - format).empty? ||
      (%w(Online Physical\ Object) - format).empty?
  end

  # @see UVA::IndexDoc#internet_only?
  #
  # (That is, whether "Internet materials" is its sole location.)
  #
  def internet_only?
    values_for(:location_facet) == ['Internet materials']
  end

  # @see UVA::IndexDoc#journal?
  #
  def journal?
    has?(:format_facet, 'Journal/Magazine')
  end

  # @see UVA::IndexDoc#congressional_hearings?
  #
  def congressional_hearings?
    has?(:digital_collection_facet, CONGRESSIONAL_HEARINGS_FACET)
  end

  # @see UVA::IndexDoc#government_document?
  #
  def government_document?
    sudoc_numbers.present?
  end

  # @see UVA::IndexDoc#non_bibliographic?
  #
  def non_bibliographic?
    has?(:format_facet, 'Equipment')
  end

  # @see UVA::IndexDoc#non_physical?
  #
  def non_physical?
    online_only? ||
      [:dl_book, :dl_text, :lib_coins].include?(doc_type) ||
      ((doc_type == :data_driven) && !has_feature?('has_archival_holdings'))
  end

  # @see UVA::IndexDoc#hierarchical?
  #
  def hierarchical?
    has_feature?('has_hierarchy') || (doc_type == :dl_wsls_video)
  end

  # @see UVA::IndexDoc#sas_only?
  #
  def sas_only?
    values_for(:library_facet).one? { |v| v =~ /Semester at Sea/i }
  end

  # @see UVA::IndexDoc#hidden?
  #
  def hidden?
    has?(:shadowed_location_facet, 'HIDDEN')
  end

  # @see UVA::IndexDoc#discoverable?
  #
  def discoverable?
    !has?(:shadowed_location_facet, 'UNDISCOVERABLE')
  end

  # @see UVA::IndexDoc#deliverable?
  #
  def deliverable?
    !hidden? && !online_only? && !pda?
  end

  # @see UVA::IndexDoc#reservable?
  #
  def reservable?
    deliverable? && availability_on_show_page?
  end

  # @see UVA::IndexDoc#availability_on_show_page?
  #
  # This method returns false in those special cases where we want that box
  # suppressed from the UI.  This includes records that have an embedded view
  # of all content and no physical object.
  #
  def availability_on_show_page?
    if has?(:source_facet, 'Library Catalog')
      true # All library catalog materials should present availability.
    elsif has?(:special_collections_holding_display)
      true # SC holding display should always be available too.
    elsif doc_type == :lib_coins
      true
    elsif doc_type == :dl_text
      doc_sub_type != :finding_aid
    else
      !has_feature?(
        'has_hierarchy', 'has_archival_holdings', # Hierarchy component
        'has_embedded_avalon_media',              # Embedded media player
        'iiif'                                    # Embedded image viewer
      )
    end
  end

  # @see UVA::IndexDoc#pda?
  #
  def pda?
    has_feature?('pda_print', 'pda_ebook')
  end

  # @see UVA::IndexDoc#pda_isbn_display
  #
  # @see PdaController#place_purchase_order
  #
  def pda_isbn_display
    values_for(:pda_isbn_display).first.to_s
  end

  # @see UVA::IndexDoc#pda_catkey_display
  #
  # @see PdaController#place_purchase_order
  #
  def pda_catkey_display
    catkey = values_for(:pda_catkey_display).first.to_s
    Firehose::Availability.ckey_converter(catkey)
  end

  # @see UVA::IndexDoc#pda_feature_display
  #
  # @see PdaController#place_purchase_order
  #
  def pda_feature_display
    values_for(:feature_display).first.to_s
  end

  # ===========================================================================
  # :section: Document properties (Title components)
  # ===========================================================================

  public

  # @see UVA::IndexDoc#title
  #
  def title(opt = {})
    unless opt.key?(:value)
      opt[:value] =
        values_for(:main_title_display).presence ||
        values_for(:title_display)
    end
    super(opt)
  end

  # @see UVA::IndexDoc#subtitle
  #
  def subtitle(opt = {})
    opt[:value] = values_for(:subtitle_display) unless opt.key?(:value)
    super(opt)
  end

  # @see UVA::IndexDoc#part
  #
  def part(opt = {})
    opt[:value] = values_for(:part_display) unless opt.key?(:value)
    super(opt)
  end

  # @see UVA::IndexDoc#medium
  #
  def medium(opt = {})
    opt[:value] = values_for(:medium_display) unless opt.key?(:value)
    super(opt)
  end

  # @see UVA::IndexDoc#date_coverage
  #
  def date_coverage(opt = {})
    opt[:value] = values_for(:date_coverage_display) unless opt.key?(:value)
    super(opt)
  end

  # @see UVA::IndexDoc#date_bulk_coverage
  #
  def date_bulk_coverage(opt = {})
    opt[:value] =
      values_for(:date_bulk_coverage_display) unless opt.key?(:value)
    super(opt)
  end

  # @see UVA::IndexDoc#form
  #
  def form(opt = {})
    opt[:value] = values_for(:form_display) unless opt.key?(:value)
    super(opt)
  end

  # ===========================================================================
  # :section: Document properties (Bibliographic information)
  # ===========================================================================

  public

  # @see UVA::IndexDoc#pub_year
  #
  def pub_year
    solr_publication_year.first
  end

  # @see UVA::IndexDoc#pub_date
  #
  def pub_date
    solr_publication_date.first
  end

  # @see UVA::IndexDoc#cite_as
  #
  def cite_as
    result = marc_display && marc_display.citation_note
    result = result.first if result.is_a?(Array)
    result.presence
  end

  # ===========================================================================
  # :section: Document properties (Identifiers)
  # ===========================================================================

  public

  # @see UVA::IndexDoc#isbns
  #
  # === Implementation Notes
  # go through all isbns
  # split on spaces,
  # grab the first item
  # reject all empty values
  # return an array
  #
  def isbns
    @isbns ||=
      get_isbn
        .map { |value| value.split(SPACE).first }
        .clean_uniq
        .tap { |result| result.deep_freeze if frozen? }
  end

  # @see UVA::IndexDoc#oclcs
  #
  # === Implementation Notes
  # go through oclcs as we do for isbns
  #
  def oclcs
    @oclcs ||=
      get_oclc
        .map { |value| value.split(SPACE).first }
        .clean_uniq
        .tap { |result| result.deep_freeze if frozen? }
  end

  # @see UVA::IndexDoc#lccns
  #
  def lccns
    @lccns ||= marc_display ? marc_display.lc_control_number : []
  end

  # @see UVA::IndexDoc#upcs
  #
  # === Implementation Notes
  # go through upcs as we do for isbns
  #
  def upcs
    @upcs ||=
      get_upc
        .map { |value| value.split(SPACE).first }
        .clean_uniq
        .tap { |result| result.deep_freeze if frozen? }
  end

  # @see UVA::IndexDoc#issns
  #
  def issns
    @issns ||=
      get_issn
        .map { |value| value.split(SPACE).first }
        .clean_uniq
        .tap { |result| result.deep_freeze if frozen? }
  end

  # @see UVA::IndexDoc#dois
  #
  # NOTE: Currently the Solr index does not have DOIs.
  #
  def dois
    @dois ||= [].tap { |result| result.deep_freeze if frozen? }
  end

  # @see UVA::IndexDoc#call_numbers
  #
  # NOTE: These are the call number(s) reported by the Solr index.
  # Because these are modified for for the purpose of optimizing the display in
  # search results, they may not be as useful for other purposes.
  #
  # Duplicates are removed but no other validation is performed, unlike:
  # @see self#get_call_numbers
  #
  def call_numbers
    solr_call_numbers.map { |v| v.squeeze(SPACE) }.clean_uniq
  end

  # @see UVA::IndexDoc#shelf_numbers
  #
  # @param [Hash] opt
  #
  # @option opt [Boolean,Symbol] :sudoc     One of *true*, *false*, :only
  #                                           (default: *true*).
  # @option opt [Boolean,Symbol] :invalid   One of *true*, *false*, :only
  #                                           (default: *false*).
  #
  # Invalid call numbers are removed.
  #
  def shelf_numbers(opt = nil)
    sudoc_allow   = true
    sudoc_only    = false
    invalid_allow = false
    invalid_only  = false
    if opt
      case opt[:sudoc]
        when true  then sudoc_allow = true
        when false then sudoc_allow = false
        when :only then sudoc_only  = true
      end
      case opt[:invalid]
        when true  then invalid_allow = true
        when false then invalid_allow = false
        when :only then invalid_only  = true
      end
    end
    values_for(:call_number_display).map { |v|
      next if invalid_call_number?(v) ? !invalid_allow : invalid_only
      next if (v =~ SUDOC_PATTERNS)   ? !sudoc_allow   : sudoc_only
      v.squeeze(SPACE)
    }.clean_uniq
  end

  # @see UVA::IndexDoc#sudoc_numbers
  #
  # @return [Array<String>]
  #
  # === Implementation Notes
  # MARC data is not available for index results, so this method supplements
  # with call numbers that appear to be SuDoc numbers.
  #
  def sudoc_numbers(*)
    marc_display ? marc_display.sudoc_number : shelf_numbers(sudoc: :only)
  end

  # ===========================================================================
  # :section: Document properties (Articles)
  # ===========================================================================

  public

  # @see UVA::IndexDoc#accession_number
  #
  # For the catalog index, this value is applicable only to archival items.
  #
  def accession_number
    get_accession_number.first
  end

  # ===========================================================================
  # :section: Document properties (transient)
  # ===========================================================================

  public

  # @see UVA::IndexDoc#date_indexed
  #
  def date_indexed(fmt = '%Y-%m-%d %H:%M')
    indexing_date = values_for(:date_indexed_facet).first
    return if indexing_date.blank?
    date = DateTime.parse(indexing_date)
    fmt ? date.strftime(fmt) : date
  rescue => e
    Rails.logger.debug { "#{__method__}: #{e} #{e.message}" }
    Rails.logger.info  { "#{__method__}: bad date #{indexing_date.inspect}" }
    nil
  end

  # @see UVA::IndexDoc#image_path
  #
  # @return [String]
  #
  def image_path
    UVA::CoverImage.image_path(self)
  end

  # @see UVA::IndexDoc#availability
  #
  def availability
    unless has_availability_loaded?
      if has_refresh_availability?
        refresh_availability
      else
        @availability = :none
      end
    end
    @availability unless @availability == :none
  end

  # ===========================================================================
  # :section: Document methods (transient)
  # ===========================================================================

  public

  # @see UVA::IndexDoc#has_image?
  #
  def has_image?
    UVA::CoverImage.has_image?(self)
  end

  # @see UVA::IndexDoc#refresh_availability
  #
  # NOTE: currently unused outside of the self#availability method.
  #
  def refresh_availability
    if self[:special_collections_holding_display].present?
      Debug.show(__method__) { "Using SC holding_display for #{doc_id}" }
      @availability = Firehose::JsonAvailability.new(self)

    else
      Debug.show(__method__) { "Fetching availability for #{doc_id}" }
      @availability = Firehose::Availability.find(self)
    end
  end

  # @see UVA::IndexDoc#has_availability_loaded?
  #
  # For catalog items, if this method returns *true* then the document already
  # contains availability information (and self#availability will return
  # Firehose::Availability).
  #
  def has_availability_loaded?(*)
    @availability ||= nil
    @availability.present?
  end

  # @see UVA::IndexDoc#has_refresh_availability?
  #
  # For catalog items, this method returns *true*; for all other items this
  # method returns *false*.
  #
  def has_refresh_availability?(*)
    (doc_id.start_with?('u') &&
      get_url.none? { |url| url.include?('kanopystreaming.com') }) ||
    self[:special_collections_holding_display].present?


  end

  # ===========================================================================
  # :section: Document values (Bibliographic information)
  #
  # Each of these is implemented with some combination of information from the
  # Solr record for the item and information from the MARC record for the item.
  # ===========================================================================

  public

  # @see UVA::IndexDoc#get_format
  #
  def get_format
    result = solr_format
    result.clean_uniq
  end

  # Get format(s) from Solr fields for this item.
  #
  # @return [Array<String>]
  #
  def solr_format
    result = values_for(:format_display)
    result = values_for(:format_facet) if result.blank?
    result.map { |v| titleize(v) }
  end

  # @see UVA::IndexDoc#get_work_type
  #
  def get_work_type
    result = solr_genre
    result.clean_uniq(PHRASE_END)
  end

  # Get genre(s) from the Solr genre facet for this item.
  #
  # @return [Array<String>]
  #
  def solr_genre
    result = values_for(:genre_facet)
    result = values_for(:genre_display) if result.blank?
    result.map { |v| titleize(v) }
  end

  # @see UVA::IndexDoc#get_edition
  #
  def get_edition
    result = marc_edition
    result.clean_uniq
  end

  # Get edition(s) from the MARC metadata for this item.
  #
  # @return [Array<String>]
  #
  def marc_edition
    marc_display ? marc_display.edition : []
  end

  # @see UVA::IndexDoc#get_edition_statement
  #
  def get_edition_statement
    result = marc_edition_statement
    result.clean_uniq
  end

  # Get edition(s) from the MARC metadata for this item.
  #
  # @return [Array<String>]
  #
  def marc_edition_statement
    marc_display ? marc_display.edition_statement : []
  end

  # @see UVA::IndexDoc#get_pub_year
  #
  def get_pub_year(value = nil)
    if [Date, Fixnum, String].include?(value.class)
      result = super
    else
      result = solr_publication_year
      result = marc_publication_year if result.blank?
      result = super if result.blank? && value.is_a?(TrueClass)
    end
    result.clean_uniq(PHRASE_END)
  end

  # Get publication year(s) from the MARC metadata for this item.
  #
  # @return [Array<String>]
  #
  def marc_publication_year
    marc_publication_date.map { |v| extract_year(v) }
  end

  # Get publication year(s) from Solr fields for this item.
  #
  # @return [Array<String>]
  #
  def solr_publication_year
    fields = [
      :year_display,
      :year_facet,
      :published_date_display
    ]
    fields.flat_map { |field| values_for(field) }.map { |v| extract_year(v) }
  end

  # @see UVA::IndexDoc#get_pub_date
  #
  def get_pub_date(value = nil)
    if [Date, Fixnum, String].include?(value.class)
      result = super
    else
      result = solr_publication_date
      result = marc_publication_date if result.blank?
      result = super if result.blank? && value.is_a?(TrueClass)
    end
    result.clean_uniq(PHRASE_END)
  end

  # Get publication date(s) from the MARC metadata for this item.
  #
  # @return [Array<String>]
  #
  def marc_publication_date
    marc_display ? marc_display.publication_date : []
  end

  # Get publication date(s) from Solr fields for this item.
  #
  # @return [Array<String>]
  #
  def solr_publication_date
    fields = [
      :issued_date_display,     # Only for Avalon items(?)
      :date_display,
      :published_date_display,
      :year_display
    ]
    fields.flat_map { |field| values_for(field) }
  end

  # @see UVA::IndexDoc#get_pub_statement
  #
  def get_pub_statement
    result = marc_pub_statement
    result = solr_pub_statement if result.blank?
    result.clean_uniq
  end

  # Get publication statement(s) from the MARC metadata for this item.
  #
  # @return [Array<String>]
  #
  def marc_pub_statement
    marc_display ? marc_display.publication_statement : []
  end

  # Get publication statement(s) from Solr fields for this item.
  #
  # @return [Array<String>]
  #
  def solr_pub_statement
    result = values_for(:published_display).presence
    result ||=
      if has?(:format_facet, /thesis/i, /dissertation/i)
        [ETD_PUBLISHER, ETD_PUBLICATION_PLACE].join(LIST_SEPARATOR)
      elsif has?(:source_facet, 'Digital Library', /UVA Library/)
        [REPO_PUBLISHER, REPO_PUBLICATION_PLACE].join(LIST_SEPARATOR)
      end
    Array(result)
  end

  # @see UVA::IndexDoc#get_publisher
  #
  # For non-MARC repository items, REPO_PUBLISHER is returned.  For non-MARC
  # ETD's (electronic theses and dissertations), ETD_PUBLISHER is returned if
  # no publisher is given; ETD_PUBLISHER is prepended if the reported value
  # does not already include that string.
  #
  def get_publisher
    result = marc_publisher
    result = solr_publisher if result.blank?
    result.clean_uniq(PHRASE_END)
  end

  # Get publisher name(s) from the MARC metadata for this item.
  #
  # @return [Array<String>]
  #
  def marc_publisher
    result = uva_archive
    result &&=
      if result.size >= 4
        result[-4..-3].map { |v|
          v unless v =~ /^(#{ACCESSION_NUMBER_PATTERN})/i
        }.compact.join(', ')
      end
    result = Array(result).reject(&:blank?)
    result = marc_display.publisher if result.blank? && marc_display
    result
  end

  # Get publisher name(s) from Solr fields for this item.
  #
  # @return [Array<String>]
  #
  def solr_publisher
    result = values_for(:published_display).presence
    result ||=
      if has?(:format_facet, /thesis/i, /dissertation/i)
        ETD_PUBLISHER
      elsif has?(:source_facet, 'Digital Library', /UVA Library/)
        REPO_PUBLISHER
      end
    Array(result)
  end

  # @see UVA::IndexDoc#get_publication_place
  #
  # @return [Array<String>]
  #
  def get_publication_place
    result = marc_publication_place
    result = solr_publication_place if result.blank?
    result.clean_uniq(PHRASE_END)
  end

  # Get place(s) of publication from the MARC metadata for this item.
  #
  # @return [Array<String>]
  #
  def marc_publication_place
    result = uva_archive
    result &&=
      if result.size >= 4
        result[-2..-1].map { |v|
          v unless v =~ /Library|#{ACCESSION_NUMBER_PATTERN}/i
        }.compact.join(', ')
      end
    result = [result].reject(&:blank?)
    result = marc_display.publication_place if result.blank? && marc_display
    result
  end

  # Get place(s) of publication based on Solr index information for certain
  # types of items.
  #
  # The index does not currently support this value, but an appropriate value
  # will be returned for Libra ETDs and for Library repository items.
  #
  # @return [Array<String>]
  #
  def solr_publication_place
    result =
      if has?(:format_facet, /thesis/i, /dissertation/i)
        ETD_PUBLICATION_PLACE
      elsif has?(:source_facet, 'Digital Library', /UVA Library/)
        REPO_PUBLICATION_PLACE
      end
    Array(result)
  end

  # @see UVA::IndexDoc#get_uniform_title
  #
  def get_uniform_title(*)
    result = marc_uniform_title
    result = solr_uniform_title if result.blank?
    result.clean_uniq(PHRASE_END)
  end

  # Get the uniform title from Solr fields for this item.
  #
  # @return [Array<String>]
  #
  def solr_uniform_title
    values_for(:uniform_title_facet)
  end

  # Get the uniform title from the MARC metadata for this item.
  #
  # @return [Array<String>]
  #
  def marc_uniform_title
    marc_display ? marc_display.uniform_title : []
  end

  # @see UVA::IndexDoc#get_series
  #
  def get_series
    result = solr_series_title
    result.clean_uniq(PHRASE_END)
  end

  # Get series name(s) from Solr fields for this item.
  #
  # @return [Array<String>]
  #
  def solr_series_title
    values_for(:series_title_facet)
  end

  # @see UVA::IndexDoc#get_series_statement
  #
  # The set of MARC series statements which are distinct (having different
  # non-blank characters) from any of the values returned by #get_series.
  #
  def get_series_statement
    result = marc_series_statement
    if result.present?
      titles = get_series.map { |v| non_blank_chars(v) }
      if titles.present?
        result.delete_if { |v| titles.include?(non_blank_chars(v)) }
      end
    end
    result.clean_uniq(PHRASE_END)
  end

  # Get series statement(s) from the MARC metadata for this item.
  #
  # @return [Array<String>]
  #
  def marc_series_statement
    marc_display ? marc_display.series_statement : []
  end

  # @see UVA::IndexDoc#get_collection
  #
  def get_collection
    result = solr_collection
    result.clean_uniq(PHRASE_END)
  end

  # Get collection name(s) from Solr fields for this item.
  #
  # @return [Array<String>]
  #
  def solr_collection
    values_for(:digital_collection_facet) + values_for(:collection_facet)
  end

  # @see UVA::IndexDoc#get_authors
  #
  # === Implementation Notes
  # Electronic resources from Ebrary are all mis-cataloged so that the name of
  # the collection appears to be an author (MARC 710 is missing a subfield to
  # specify the role), so these are specifically removed from the results.
  #
  def get_authors
    result = get_directors
    result += marc_display ? marc_authors : solr_authors
    result.map { |v|
      next if match_any(v, INVALID_AUTHORS)
      titleize(v, names: true, downcase: AUTHOR_LOWERCASE_WORDS)
    }.clean_uniq(PHRASE_END)
  end

  # Get the list of authors from the MARC metadata for this item.
  #
  # @return [Array<String>]
  #
  def marc_authors
    marc_display ? marc_display.get_author_list : []
  end

  # Get the list of authors from Solr fields for this item.
  #
  # @return [Array<String>]
  #
  def solr_authors
    result = values_for(:author_display)
    result = values_for(:author_facet) if result.blank?
    result += values_for(:linked_author_display)
    result.map do |name|
      name.gsub(/,?[\s(]*(\w+)[\s)]*/) { |substring|
        # If the substring matches an "author" role, then skip the substring.
        # Otherwise, replace the substring with the parenthesized role term.
        role_code, _ = $1 && RELATOR_MAP.find { |_, v| v.casecmp($1).zero? }
        if role_code
          AUTHOR_RELATORS.include?(role_code) ? '' : " (#{$1})"
        else
          substring
        end
      }.sub(/,\s*\d{4}-(\d{4})?\s*$/, '') # Remove date(s).
    end
  end

  # @see UVA::IndexDoc#get_advisors
  #
  def get_advisors
    result = marc_display ? marc_advisors : solr_advisors
    result.clean_uniq(PHRASE_END)
  end

  # Get the list of ETD advisors from MARC metadata for this item.
  #
  # @return [Array<String>]
  #
  def marc_advisors
    []
  end

  # Get the list of ETD advisors from Solr fields for this item.
  #
  # @return [Array<String>]
  #
  def solr_advisors
    values_for(:creator_display).reject do |name|
      (v = name.to_s.downcase).blank? ||
        (v == 'none') || v.start_with?('none ') || v.end_with?(' none')
    end
  end

  # @see UVA::IndexDoc#get_contributors
  #
  def get_contributors
    result = solr_contributors
    result.clean_uniq(PHRASE_END)
  end

  # Get the list of Contributors from Solr fields for this item.
  #
  # @return [Array<String>]
  #
  def solr_contributors
    values_for(:ctb_display).reject do |name|
      (v = name.to_s.downcase).blank? || (v == 'none')
    end
  end

  # @see UVA::IndexDoc#get_sponsoring_agency
  #
  def get_sponsoring_agency
    result = solr_sponsoring_agency
    result.clean_uniq(PHRASE_END)
  end

  # Get the list of sponsoring_agencies from Solr fields for this item.
  #
  # @return [Array<String>]
  #
  def solr_sponsoring_agency
    values_for(:sponsoring_agency_display).reject do |name|
      (v = name.to_s.downcase).blank? || (v == 'none')
    end
  end

  # @see UVA::IndexDoc#get_directors
  #
  def get_directors
    result = solr_directors
    result.clean_uniq(PHRASE_END)
  end

  # Get the list of director(s) from Solr fields for this item.
  #
  # @return [Array<String>]
  #
  def solr_directors
    result = values_for(:drt_display)
    result = values_for(:video_director_facet) if result.blank?
    result
  end

  # @see UVA::IndexDoc#get_language
  #
  # Returns an empty array if the document represents equipment for loan.
  #
  def get_language
    return [] if non_bibliographic?
    result = marc_language
    result = solr_language if result.blank?
    result.clean_uniq(PHRASE_END)
  end

  # Get languages(s) from the MARC metadata for this item.
  #
  # @return [Array<String>]
  #
  def marc_language
    marc_display ? marc_display.language : []
  end

  # Get languages(s) from Solr fields for this item.
  #
  # @return [Array<String>]
  #
  def solr_language
    values_for(:language_facet)
  end

  # @see UVA::IndexDoc#get_physical_description
  #
  def get_physical_description
    result = marc_physical_description
    result = solr_physical_description if result.blank?
    result.clean_uniq
  end

  # Get physical characteristics from the MARC metadata for this item.
  #
  # @return [Array<String>]
  #
  def marc_physical_description
    marc_display ? marc_display.physical_description : []
  end

  # Get physical characteristics from Solr fields for this item.
  #
  # @return [Array<String>]
  #
  def solr_physical_description
    []
  end

  # @see UVA::IndexDoc#get_technical_details
  #
  def get_technical_details
    result = marc_technical_details
    result = solr_technical_details if result.blank?
    result.clean_uniq
  end

  # Get technical details from the MARC metadata for this item.
  #
  # @return [Array<String>]
  #
  def marc_technical_details
    marc_display ? marc_display.technical_details : []
  end

  # Get technical details from Solr fields for this item.
  #
  # @return [Array<String>]
  #
  def solr_technical_details
    []
  end

  # @see UVA::IndexDoc#get_recording_information
  #
  def get_recording_information
    result = marc_recording_information
    result.clean_uniq
  end

  # Get recording characteristics from the MARC metadata for this item.
  #
  # @return [Array<String>]
  #
  def marc_recording_information
    marc_display ? marc_display.recording_information : []
  end

  # @see UVA::IndexDoc#get_target_audience
  #
  def get_target_audience
    result = marc_target_audience
    result.clean_uniq(PHRASE_END)
  end

  # Get audience/rating from the MARC metadata for this item.
  #
  # @return [Array<String>]
  #
  def marc_target_audience
    marc_display ? marc_display.target_audience : []
  end

  # @see UVA::IndexDoc#get_performers
  #
  def get_performers
    result = marc_performers
    result.clean_uniq
  end

  # Get performer(s) from the MARC metadata for this item.
  #
  # @return [Array<String>]
  #
  def marc_performers
    marc_display ? marc_display.performers : []
  end

  # @see UVA::IndexDoc#get_credits
  #
  def get_credits
    result = marc_credits
    result.clean_uniq
  end

  # Get production credits from the MARC metadata for this item.
  #
  # @return [Array<String>]
  #
  def marc_credits
    marc_display ? marc_display.credits : []
  end

  # @see UVA::IndexDoc#get_plot_summary
  #
  def get_plot_summary
    result = solr_plot_summary
    result = marc_plot_summary if result.blank?
    result.clean_uniq
  end

  # Get plot summary description from the MARC metadata for this item.
  #
  # @return [Array<String>]
  #
  def marc_plot_summary
    marc_display ? marc_display.plot_summary : []
  end

  # Get plot summary description from Solr fields for this item.
  #
  # @return [Array<String>]
  #
  def solr_plot_summary
    values_for(:description_note_display)
  end

  # @see UVA::IndexDoc#get_contents
  #
  def get_contents
    result = solr_contents
    result = marc_contents if result.blank?
    result.clean_uniq
  end

  # Get content description from the MARC metadata for this item.
  #
  # @return [Array<String>]
  #
  def marc_contents
    marc_display ? marc_display.contents_note : []
  end

  # Get content description from Solr fields for this item.
  #
  # @return [Array<String>]
  #
  def solr_contents
    values_for(:resource_display)
  end

  # @see UVA::IndexDoc#get_dissertation_note
  #
  # NOTE: Libra ETDs record this information elsewhere.
  #
  def get_dissertation_note
    result = marc_dissertation_note
    result.clean_uniq
  end

  # Get ETD degree information from the MARC metadata for this item.
  #
  # @return [Array<String>]
  #
  def marc_dissertation_note
    marc_display ? marc_display.dissertation_note : []
  end

  # @see UVA::IndexDoc#get_subjects
  #
  def get_subjects
    result = solr_subjects + marc_subjects
    result.clean_uniq(PHRASE_END).map { |v| titleize(v) }
  end

  # Get subjects from the MARC metadata for this item.
  #
  # @return [Array<String>]
  #
  def marc_subjects
    marc_display ? (marc_display.subjects - marc_display.place_names) : []
  end

  # Get subjects from Solr fields for this item.
  #
  # @return [Array<String>]
  #
  def solr_subjects
    values_for(:subject_facet)
  end

  # @see UVA::IndexDoc#get_place_names
  #
  def get_place_names
    result = solr_place_names + marc_place_names
    result.clean_uniq(PHRASE_END)
  end

  # Get geographic subjects from the MARC metadata for this item.
  #
  # @return [Array<String>]
  #
  def marc_place_names
    marc_display ? marc_display.place_names : []
  end

  # Get geographic subjects from Solr fields for this item.
  #
  # @return [Array<String>]
  #
  def solr_place_names
    values_for(:region_facet)
  end

  # @see UVA::IndexDoc#get_related_names
  #
  # @param [Boolean] display          If *true* (the default), names are
  #                                     generated for display; if *false* then
  #                                     the same MARC subfields used by
  #                                     self#get_authors are used here.
  #
  def get_related_names(display = true)
    result = marc_display ? marc_related_names(display) : solr_related_names
    result.clean_uniq(PHRASE_END)
  end

  # Get related names from the MARC metadata for this item.
  #
  # @param [Boolean] display          If *true* (the default), names are
  #                                     generated for display; if *false* then
  #                                     the same MARC subfields used by
  #                                     self#get_authors are used here.
  #
  # @return [Array<String>]
  #
  def marc_related_names(display = true)
    marc_display ? marc_display.get_related_names(display) : []
  end

  # Get related names from Solr fields for this item.
  #
  # === Libra repository items
  # Thesis advisors have two entries in the result -- one with the name alone
  # and one with "(advisor)" appended.  This is intended to support the ability
  # to transform the name strings into search links where the first instance of
  # the name searches for that person as an author and the second instance
  # searches for that person as a thesis advisor.
  #
  # === Avalon repository items
  # Metadata for time-based media deposited in this system contains fields
  # named after MARC relators, e.g.:
  #
  #   :spk_display for Speaker
  #   :msd_display for Musical Director
  #
  # In this context, the Virgo "author" still comes from :author_facet (rather
  # than :aut_display), which is the originator of the recorded production as
  # opposed to the author of the work on which the production was based.
  #
  # @return [Array<String>]
  #
  def solr_related_names
    authors  = solr_authors
    advisors = solr_advisors
    (authors - advisors) +
      advisors.map { |name| "#{name} (advisor)" } +
      relator_mapping.flat_map { |code, _| values_for(:"#{code}_display")  }
  end

  # @see UVA::IndexDoc#get_description
  #
  # The source of this information is highly dependent on the collection, the
  # type of metadata, etc.
  #
  def get_description
    marc_display ? marc_description : solr_description
  end

  # Get a description of the item.
  #
  # @return [Array<String>]
  #
  def marc_description
    get_physical_description + get_technical_details
  end

  # Get a description of the item.
  #
  # The source of this information is highly dependent on the collection, the
  # type of metadata, etc.
  #
  # @return [Array<String>]
  #
  def solr_description
    result = solr_desc_meta_description || solr_media_description
    Array(result)
  end

  # Get the descriptive metadata for a repository item.
  #
  # @return [String]
  # @return [nil]
  #
  # === Usage Notes
  # Although the contents of the Solr *desc_meta_file_display* should be XML
  # DescMetadata for the associated item, there are some cases where this is
  # simple text.  In those cases, this method will return *nil*.
  #
  def solr_desc_meta_description
    result = values_for(:desc_meta_file_display)
    result = show_descmeta(result.join(NEWLINE)) if result.present?
    result.presence
  end

  # Get the description for a media item.
  #
  # @return [String]
  # @return [nil]
  #
  # === Usage Notes
  # For repository items which are single images, the sole element of the Solr
  # *media_description_display* field is the description of the single image.
  # On the other hand, for (older) repository items which are sets of images,
  # this Solr field has an element for each item.
  #
  def solr_media_description
    result = values_for(:media_description_display).first
    result.presence
  end

  # @see UVA::IndexDoc#get_abstract
  #
  def get_abstract
    result = solr_abstract
    result = marc_abstract if result.blank?
    result.clean_uniq
  end

  # Abstract for catalog items.
  #
  # @return [Array<String>]
  #
  def marc_abstract
    marc_display ? marc_display.abstract : []
  end

  # Abstract for non-catalog items.
  #
  # @return [Array<String>]
  #
  def solr_abstract
    result = values_for(:scopecontent_display)
    result = values_for(:abstract_display) if result.blank?
    result
  end

  # @see UVA::IndexDoc#get_copyright_and_permissions
  #
  def get_copyright_and_permissions
    values_for(:cc_uri_display) + values_for(:rs_uri_display)
  end

  # @see UVA::IndexDoc#get_notes
  #
  def get_notes
    result = solr_notes
    result = marc_notes if result.blank?
    result.clean_uniq
  end

  # Notes for catalog items.
  #
  # @return [Array<String>]
  #
  def marc_notes
    result = []
    if marc_display
      result += marc_display.note
      result += marc_display.with_note
      result += marc_display.bibliography_note
    end
    result
  end

  # Notes for non-catalog items.
  #
  # @return [Array<String>]
  #
  def solr_notes
    values_for(:notes_display)
  end

  # =========================================================================
  # :section: Document values (Aggregated information)
  # =========================================================================

  public

  # @see UVA::IndexDoc#get_abstract_fields
  #
  def get_abstract_fields(*parts)
    update_options(__method__, parts, separator: false)
    initial_parts = marc_display ? marc_abstract_fields : solr_abstract_fields
    parts.unshift(*initial_parts)
    super
  end

  # Abstract/summary lines for catalog items.
  #
  # @return [Array<Array<(String, String)>>]
  #
  def marc_abstract_fields
    [
      [nil,               export_abstract(marc: true)],
      [nil,               export_plot_summary(marc: true)],
      ['Release Date',    :release_date_facet],
      ['Run Time',        :video_run_time_display],
      ['Recording Info',  export_recording_information],
      ['Target Audience', export_target_audience],
    ]
  end

  # Abstract/summary lines for non-catalog items.
  #
  # @return [Array<Array<(String, String)>>]
  #
  def solr_abstract_fields
    [
      [nil,               :scopecontent_display],
      [nil,               :abstract_display],
      [nil,               export_plot_summary],
      [nil,               :description_display],
      ['Composition Era', :composition_era_facet],
      ['Release Date',    :release_date_facet],
      ['Run Time',        :video_run_time_display],
      ['Access',          :media_description_display],
    ]
  end

  # @see UVA::IndexDoc#get_note_fields
  #
  def get_note_fields(*parts)
    update_options(__method__, parts, separator: false)
    initial_parts = marc_display ? marc_note_fields : solr_note_fields
    parts.unshift(*initial_parts)
    super
  end

  # Notes for catalog items.
  #
  # @return [Array<Array<(String, String)>>]
  #
  def marc_note_fields
    [
      [nil,                  export_physical_description],
      [nil,                  export_technical_details],
      [nil,                  export_dissertation_note],
      [nil,                  :note],
      [nil,                  :bibliography_note],
      [nil,                  :with_note],
      [nil,                  :local_note],
      [nil,                  :reproduction_note],
      ['Cite as',            export_cite_as],
      ['Performers',         export_performers(marc: true)],
      ['Cited in',           :cited_in],
      ['Located in',         :located_in],
      ['Access Restriction', :access_restriction],
      ['Terms of Use',       :terms_of_use],
    ]
  end

  # Notes for non-catalog items.
  #
  # @return [Array<Array<(String, String)>>]
  #
  def solr_note_fields
    [
      [nil,            :note_display],
      ['Mint',         :mint_display],
      ['Denomination', :denomination_display],
      ['Material',     :material_display],
      [nil,            :location_facet],
      ['Location',     :location_display],
      [nil,            export_media_retrieval_id],
    ]
  end

  # ===========================================================================
  # :section: Document values (Identifiers)
  # ===========================================================================

  public

  # @see UVA::IndexDoc#get_isbn
  #
  def get_isbn
    result = marc_isbns
    result = solr_isbns if result.blank?
    result.clean_uniq
  end

  # Get ISBNs from the MARC metadata for this item.
  #
  # @return [Array<String>]
  #
  def marc_isbns
    marc_display ? marc_display.isbn : []
  end

  # Get ISBNs from Solr fields for this item.
  #
  # @return [Array<String>]
  #
  def solr_isbns
    values_for(:isbn_display)
  end

  # @see UVA::IndexDoc#get_oclc
  #
  def get_oclc
    result = marc_ocns
    result = solr_ocns if result.blank?
    result.clean_uniq
  end

  # Get OCNs from the MARC metadata for this item.
  #
  # @return [Array<String>]
  #
  def marc_ocns
    marc_display ? marc_display.oclc_number : []
  end

  # Get OCNs from Solr fields for this item.
  #
  # @return [Array<String>]
  #
  def solr_ocns
    values_for(:oclc_display)
  end

  # @see UVA::IndexDoc#get_upc
  #
  def get_upc
    result = marc_upcs
    result = solr_upcs if result.blank?
    result.clean_uniq
  end

  # Get OCNs from the MARC metadata for this item.
  #
  # @return [Array<String>]
  #
  def marc_upcs
    marc_display ? marc_display.upc : []
  end

  # Get OCNs from Solr fields for this item.
  #
  # @return [Array<String>]
  #
  def solr_upcs
    values_for(:upc_display)
  end

  # @see UVA::IndexDoc#get_issn
  #
  def get_issn
    result = marc_issns
    result = solr_issns if result.blank?
    result.clean_uniq
  end

  # Get ISBNs from the MARC metadata for this item.
  #
  # @return [Array<String>]
  #
  def marc_issns
    marc_display ? marc_display.issn : []
  end

  # Get ISBNs from Solr fields for this item.
  #
  # @return [Array<String>]
  #
  def solr_issns
    values_for(:issn_display)
  end

  # @see UVA::IndexDoc#get_standard_identifiers
  #
  # The MARC fields are preferable for display purposes because they may
  # contain annotations to differentiate between multiple identifiers.
  #
  def get_standard_identifiers
    result = super
    result = marc_standard_identifiers if result.blank?
    result
  end

  # Get standard identifiers (ISBN or ISSN) from the MARC metadata for this
  # item.
  #
  # @return [Array<String>]
  #
  def marc_standard_identifiers
    marc_display ? (marc_display.isbn + marc_display.issn).uniq : []
  end

  # @see UVA::IndexDoc#get_url
  #
  def get_url
    values_for(:url_display).map { |v| v.split('|').first }
  end

  # @see UVA::IndexDoc#get_url_links
  #
  def get_url_links
    values_for(:url_display).map do |v|
      part = v.split('|')
      [part.first, part.last]
    end
  end

  # @see UVA::IndexDoc#get_supplemental_url_links
  #
  def get_supplemental_url_links
    values_for(:url_supp_display).map do |v|
      part = v.split('|')
      [part.first, part.last]
    end
  end

  # @see UVA::IndexDoc#get_url
  #
  def get_online_url_display
    values_for(:online_url_display).try :first
  end

  # @see UVA::IndexDoc#get_media_retrieval_id
  #
  def get_media_retrieval_id
    values_for(:media_retrieval_id_display)
  end

  # @see UVA::IndexDoc#get_call_numbers
  #
  # Get the indexed call number(s) for this item.  These are the number(s) that
  # used to identify circulating and non-circulating catalog items, so the
  # values here will favor locally-assigned numbers even if they are not LOC
  # call numbers.
  #
  # The return from this method will generally be empty for index documents
  # associated with electronic-only items (regardless of provenance).
  #
  # @return [Array<String>]
  #
  # @see self#call_numbers
  # @see self#get_shelf_numbers
  #
  def get_call_numbers
    # Separate call number sequences that were combined into the single
    # index field by prepending the base call number from the first item of the
    # sequence to the rest of the items in the sequence.
    #
    # (E.g. see https://xxx.virginia.edu/xxx
    #
    # NOTE: It might be preferable to change the index to include these in a
    # new multi-valued field rather than attempting to do that here every time.
    #
    call_numbers.map { |call_number|
      next if invalid_call_number?(call_number, true)
      cn_list     = call_number.split(/\s*,\s*/)
      first_cn    = cn_list.shift
      exploded_cn =
        if cn_list.present?
          parts = first_cn.split(/\s+/)
          parts.pop # Remove the volume number portion.
          if parts.present?
            base_cn = parts.join(SPACE) # The actual (base) call number.
            cn_list.map { |volume| "#{base_cn} #{volume}" }.unshift(first_cn)
          end
        end
      exploded_cn || call_number
    }.flatten.compact
      .tap { |res| Debug.show(__method__) { "CALL NUMBERS: #{res.inspect}" } }
  end

  # The call numbers(s) from the MARC metadata for this item.
  #
  # @return [Array<String>]
  #
  def marc_call_numbers
    marc_display ? marc_display.call_number : []
  end

  # The call numbers(s) from Solr fields for this item.
  #
  # @return [Array<String>]
  #
  def solr_call_numbers
    values_for(:lc_call_number_display).map { |v| v.sub(/^LC:/, '') }
  end

  # @see UVA::IndexDoc#get_shelf_numbers
  #
  def get_shelf_numbers
    result = shelf_numbers
    result = get_call_numbers if result.blank?
    result
  end

  # ===========================================================================
  # :section: Document methods (Identifiers)
  # ===========================================================================

  public

  # @see UVA::IndexDoc#invalid_call_number?
  #
  # @param [Boolean] allow_xx         If *true* do not eliminate "XX(...)"
  #                                     call numbers.
  #
  def invalid_call_number?(number, allow_xx = false)
    super ||
      number.include?('VOID') ||              # Non-existent items
      number.include?('AUTO') ||              # Kanopy videos
      (!allow_xx && number.start_with?('XX')) # Uncataloged items
  end

  # ===========================================================================
  # :section: Document methods (Identifiers)
  # ===========================================================================

  protected

  # Extract info from MARC 524 citation note for an archival citation.
  #
  # @param [String] citation          The citation note.
  #
  # @return [Array<String>]           As given below.
  # @return [nil]                     If no data is present.
  #
  # === Returned Elements
  #   result[0..-7] = Details specific to the item
  #   result[-6]    = 'Tracy W. McGregor Library'     (collection name)
  #   result[-5]    = /^Accession #\d+$/              (accession number)
  #   result[-4]    = 'Albert and Shirley Small Special Collections Library'
  #   result[-3]    = 'University of Virginia'        (publisher)
  #   result[-2]    = 'Charlottesville'               (publication place city)
  #   result[-1]    = 'Va.'                           (publication place state)
  #
  # === References
  # * MLA archival citation:
  #     Genre-appropriate MLA Citation.
  #     Box number, Folder number.
  #     Unique identifier and collection name.
  #     Archives name, Institutional affiliation, Location.
  #     Date accessed.
  # @see https://owl.english.purdue.edu/owl/resource/988/06/
  #
  def uva_archive(citation = nil)
    citation ||= cite_as
    return if citation.blank?
    parts = citation.split(', ')
    case citation
      when /Small Special Collections Library/
        # All fields are as described in the method comment.
      when /Special Collections/
        # Insert a placeholder for the missing collection name.
        parts.insert(-6, '') if parts.size >=5
      when /(#{ACCESSION_NUMBER_PATTERN}).* Virginia/
        # Some citations fail to include "Special Collections" but at least
        # provide an accession number which this method can expose.
      else
        # Other "cite as" values are assumed to be non-UVA.
        parts = nil
    end
    parts
  end

  # ===========================================================================
  # :section: Document values (Articles)
  # ===========================================================================

  public

  # @see UVA::IndexDoc#get_accession_number
  #
  # This is primarily documents representing archival items.
  #
  def get_accession_number
    result = uva_archive
    result &&= result.find { |v| v =~ /^(#{ACCESSION_NUMBER_PATTERN})/i }
    [result].compact.presence || values_for(:accession_display)
  end

  # ===========================================================================
  # :section: Serialization support
  # ===========================================================================

  public

  # @see UVA::IndexDoc#to_xml
  #
  # Gets the XML that was used to generate the document.
  #
  # For MARC items, that's the MARCXML record.
  # For digital library objects, it's desc_meta_file_display.
  #
  # @return [String]
  #
  def to_xml
    if [:dl_book, :dl_image].include?(doc_type)
      url = mods_get_url
      show_mods = false
      Curl::Easy.new(url) do |c|
        c.timeout = 2
        c.on_success { show_mods = true }
        c.http_head
      end
      raise RedirectNeeded, url if show_mods
    end
    values_for(:desc_meta_file_display).join(NEWLINE).presence || super
  end

  # @see UVA::IndexDoc#as_json
  #
  # Override which allows control over how the instance is represented in
  # JSON output.
  #
  # @return [Hash]
  #
  def as_json(*)
    if has_marc?
      Debug.show(__method__, 'MARC fields')
      to_marc.to_hash
    else
      Debug.show(__method__, 'Solr document')
      to_semantic_values
    end
  end

  # ===========================================================================
  # :section: HTML support methods
  # ===========================================================================

  public

  # @see UVA::IndexDoc#show_heading_author
  #
  # Returns a string containing the "authors" suitable for display as the
  # author/creator for the item.
  #
  # @param [Fixnum] max_len           If not set to *nil*, the maximum number
  #                                     of characters to show.
  #
  def show_heading_author(max_len = SHOW_AUTHORS_MAX_LENGTH)
    result =
      values_for(:responsibility_statement_display).presence ||
      (marc_display && marc_display.responsibility_statement.presence) ||
      export_authors.presence ||
      ''
    result = result.join(ITEM_SEPARATOR) if result.is_a?(Array)
    result = result.truncate(max_len)    if max_len
    result
  end

  # @see UVA::IndexDoc#show_heading_title
  #
  # This override makes the main show page title fall back to the series title
  # if the item does not have a title.
  #
  # @param [Fixnum] max_len           If not set to *nil*, the maximum number
  #                                     of characters to show.
  #
  def show_heading_title(max_len = SHOW_TITLE_MAX_LENGTH)
    main_title   = export_title
    series_title = nil # TODO: no good for :data_driven on index
    result = ''
    result << main_title if main_title.present?
    if series_title.present?
      unless result.blank?
        result << ';' unless result.end_with?('.', ',', ';')
        result << ' '
      end
      result << series_title
    end
    if result.blank?
      'n/a'
    elsif max_len
      result.truncate(max_len)
    else
      result
    end
  end

  # ===========================================================================
  # :section: HTML support methods
  # ===========================================================================

  protected

  # Takes a string of XML containing a <descmeta> document, returns a string
  # of HTML for display within a <dl> element.
  #
  # @param [String] xml
  #
  # @return [String]
  # @return [nil]                     If argument is nil or empty.
  #
  def show_descmeta(xml)
    # Transform <descmeta> XML to HTML (namely <dt> and <dd> elements) using
    # XSLT.
    result = xml.present? && UVA::Xsl.apply_xslt(:descmeta, xml)
    return if result.blank?

    # Make a few substitutions that are better handled in Ruby than XSLT 1.0
    result.gsub!(%r{<(titlecase)>([^<]*)</\1>}) do
      titleize($2)
    end
    result.gsub!(%r{<(author_link)>([^<]*)</\1>}) do
      link_to($2, portal_index_path(q: $2, search_field: 'author'))
    end

    result.html_safe
  end

  # ===========================================================================
  # :section: Cache support methods
  # ===========================================================================

  public

  # Called from self#initializer to define export formats in addition to those
  # set by Blacklight.
  #
  # @see self#refresh_export_formats
  #
  def setup_export_formats
    refresh_export_formats(true)
  end

  # Use this method to update Mime::Type from self#export_formats (which is
  # done when SolrDocument#initialize in invoked, but must be done manually if
  # the SolrDocument was serialized from the cache).
  #
  # @param [Boolean] initializing     Default: *false*.
  #
  # @return [self]
  #
  # @see self#export_formats
  # @see Blacklight::Solr::Document::MarcExport#register_export_formats
  #
  # === Implementation Notes
  # Despite the name, this method does not actually refresh the SolrDocument
  # object.  If it did, it would have to take into account the #frozen state
  # of whatever it was attempting to update.  Currently, this method does not
  # since it really only updates Mime::Type.
  #
  def refresh_export_formats(initializing = false)
    if initializing
      # Export formats supported in addition to the formats defined by
      # Blacklight::Solr::Document::MarcExport#register_export_formats (which
      # will have already set up its formats when that module was included).
      UVA_EXPORT_FORMATS.each_pair do |symbol, content_type|
        will_export_as(symbol, content_type)
      end
    else
      # Otherwise, this is a cached document which already has #export_formats
      # filled and just needs Mime::Text updated with constants for those
      # formats.
      [BLACKLIGHT_EXPORT_FORMATS, UVA_EXPORT_FORMATS].each do |format_set|
        format_set.each_pair do |symbol, content_type|
          Mime::Type.register(content_type, symbol) unless Mime[symbol]
        end
      end
    end
    self
  end

  # Called by `Marshal.dump` when saving a SolrDocument to cache.
  #
  # @param [Integer] level            Supplied by `Marshal.dump`; unused here.
  #
  # @return [String]
  #
  # @see UVA::Cache#cache_fetch
  #
  def _dump(level)
    unused(level)
    Marshal.dump(@_source)
  end

  # Called by `Marshal.load` when restoring a SolrDocument from cache.
  #
  # @param [String] src               A string serialized by `Marshal.dump`.
  #
  # @return [SolrDocument]
  #
  def self._load(src)
    SolrDocument.new(Marshal.load(src))
  end

  # ===========================================================================
  # :section: Test and development
  # ===========================================================================

  public

  # Format a self object for verbose output.
  #
  # @param [Array<Symbol>] variables
  #
  # @option fields [Fixnum]  :indent   Defaults to 2.
  # @option fields [String]  :newline  Defaults to "\n".
  # @option fields [Boolean] :expanded  If *true*, the result is expanded to
  #                                       include subfield values.  By default
  #                                       only counts of the MARC fields will
  #                                       be given.
  #
  # @return [String]
  #
  def pretty_inspect(*variables)
    opt = variables.last.is_a?(Hash) ? variables.pop : {}
    indent   = opt[:indent] || 2
    spaces   = SPACE * indent
    newline  = opt[:newline] || "\n#{spaces}"
    expanded = opt[:expanded]
    if variables.empty?
      variables =
        case expanded
          when true       then instance_variables
          when Array      then expanded
          else [:@doc_type, :@doc_sub_type, :@solr_response, :@_source]
        end
    end
    variables.map { |variable|
      value = instance_variable_get(variable) rescue :' ((undefined))'
      # (1) @doc_type, @doc_sub_type
      # (2) @solr_response
      # (3) @_source, @export_formats
      value_display =
        case value
          when String then "\"#{value}\""
          when Array  then "#{value.class} (#{value.size} elements)"
          when Symbol then ":#{value}" # (1)
          when RSolr::Ext::Response::Base # (2)
            inspect_response(value, "#{newline}#{spaces}")
          when Hash # (3)
            if expanded && value.is_a?(Mash) # @_source
              value =
                value.merge('marc_display' => :' ((see UVA::Marc::Record))')
            end
            inspect_hash(value, "#{newline}#{spaces}", !expanded)
          else
            value.inspect
        end
      "#{variable} = #{value_display}"
    }.join(newline).prepend(spaces)
  end

  # Format a response for verbose debug output.
  #
  # @param [RSolr::Ext::Response::Base] member
  # @param [String]                     newline
  #
  # @return [String]
  #
  def inspect_response(member = @solr_response, newline = NEWLINE)
    member_frozen  = ('[frozen] ' if member.frozen?)
    member_display =
      member.instance_variables.map { |variable|
        value = member.instance_variable_get(variable) rescue :' ((undefined))'
        value_frozen  = ('[frozen] ' if value.frozen?)
        value_display =
          case value
            when String then "'#{value}'"
            when Symbol then ":#{value}"
            when Array  then "#{value.class} (#{value.size} elements)"
            when Hash
              if variable == :@original_hash
                resp  = value['response'].merge('docs' => :' ((see @_source))')
                value = value.merge('response' => resp)
              end
              value.inspect
            else
              value.inspect
          end
        "#{variable} = #{value_frozen}#{value_display}"
      }.join(newline)
    "#{member.class} -> #{member_frozen}#{newline}#{member_display}"
  end

  # ===========================================================================
  # :section: Test and development
  # ===========================================================================

  protected

  # Display a self object on debugging output.
  #
  # @param [Symbol] calling_method
  #
  # @return [void]
  #
  def debug_self(calling_method = nil)
    return unless calling_method ? Debug[calling_method] : Debug.this_class
    calling_method =
      if calling_method
        "#{self.class}::#{calling_method}"
      else
        caller[0]
      end
    leader = "\n>>> #{calling_method} [#{@_source.size} Solr fields]"
    values = self.pretty_inspect + NEWLINE
    Debug.show(leader, caller_index: 3)
    Debug.show(values)
  end

  # Indicate whether instances should be frozen after creation.
  #
  def deep_freeze_enabled?
    SOLR_DEEP_FREEZE && !Virgo.deployed_production?
  end

  # In all non-production environments, freeze the received Solr values to
  # discover any situations in which the data is inadvertently modified.
  #
  # (In the deployed production environment, don't risk throwing an error --
  # in principle any potential bugs caused by overwriting these values should
  # have already been eliminated in development/test).
  #
  # @return [void]
  #
  def deep_freeze
    _source.deep_freeze
  end

  # rubocop:enable Metrics/ClassLength
end
