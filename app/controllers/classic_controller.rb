# app/controllers/classic_controller.rb

require 'uva'

# This controller facilitates the "Virgo Classic lens" -- views and searches
# to provide a familiar experience to Sirsi iLink users.
#
class ClassicController < CatalogController

  # Hints for RubyMine (skipped during execution).
  include CatalogHelper unless ONLY_FOR_DOCUMENTATION
  include UVA::Solr     unless ONLY_FOR_DOCUMENTATION

  include BlacklightAdvancedSearch::Controller
  include ClassicLensConcern

  # ===========================================================================
  # :section: Blacklight Configuration
  # ===========================================================================

  # rubocop:disable Metrics/LineLength

  public

  # === Facets
  # The order here defines the order in which facets are displayed in the
  # search results sidebar.
  CLASSIC_FACETS =
    UVA::Classic.browse_mode_facets.map { |mode, facet_field|
      [facet_field.to_sym, UVA::Classic.browse_mode(mode)]
    }.to_h.merge(
      # Analogs to Sirsi iLink search values but are missing in Solr
      isbn_facet:            ['ISBN',            advanced: false],
      issn_facet:            ['ISSN',            advanced: false],
      location_facet:        ['Location',        advanced: true],
      item_type_facet:       ['Item Type',       advanced: true],
      medical_subject_facet: ['Medical Subject', advanced: true],
    ).deep_freeze
=begin
    .merge(
      # Other
      'av_names_facet'           => 'Name(s)',
      'av_production_info_facet' => 'Production Info',
      'personal_name_facet'      => 'Personal Name',
      'corporate_name_facet'     => 'Corporate Name',
      'geographic_name_facet'    => 'Geographic Name',
      'genre_index_term_facet'   => 'Genre Index Term',
    ).deep_freeze
=end

  # === Search fields
  # The order here defines the order in which search fields are displayed on
  # the advanced search form.
  CLASSIC_SEARCH_FIELDS = {
    series: 'Series',
  }.deep_freeze

  # rubocop:enable Metrics/LineLength

  # ===========================================================================
  # :section: Blacklight Configuration
  #
  # @see Blacklight::Configurable::ClassMethods#configure_blacklight
  # @see Blacklight::Configuration::Fields#add_solr_field
  # ===========================================================================

  # Internal values in addition to the ones copied from CatalogController.
  configure_blacklight do |config|

    adv_search_facets = configure_facets(config, CLASSIC_FACETS)
    configure_search_fields(config, CLASSIC_SEARCH_FIELDS)

    # === Advanced search facets ===
    # Internal values in addition to the ones copied from CatalogController,
    # removing ones that are not useful for this context.
    skip = %w(digital_collection call_number source).map { |k| "#{k}_facet" }
    fsp = config.advanced_search[:form_solr_parameters]
    fsp.delete_if { |key| skip.any? { |facet| key.to_s =~ /\.#{facet}\./ } }
    if (ff = fsp[:'facet.field'])
      ff.delete_if { |key| skip.any? { |facet| key.to_s.include?(facet) } }
      ff += adv_search_facets.map(&:first)
      ff.uniq!
    end

  end

  # ===========================================================================
  # :section: Filters
  # ===========================================================================

  public

  # Actions that might result in a redirect or might modify the session.

  before_filter :adjust_for_classic,  only: [:index, :show]
  before_filter :cleanup_parameters,  only: [:index, :browse]
  before_filter :conditional_redirect

  # Actions involved in data acquisition (and might result in an exception).

  before_filter :get_document_list,   only: [:index, :browse]

  # ===========================================================================
  # :section: Routes
  # ===========================================================================

  public

  # == GET /classic/home
  # "Virgo Classic" lens home page.
  #
  def home
    redirect_to action: 'index' unless portal_home_page?
  end

  # == GET /classic
  # "Virgo Classic" lens search results.
  #
  def index
    if portal_home_page?
      redirect_to action: 'home'
    else
      super
    end
  end

  # == GET /classic/ID
  # "Virgo Classic" lens item details.
  #
  def show
    super
  end

  # == GET /classic/browse?MODE=TERM
  # "Browse by" type, where MODE is one of:
  # - "author"
  # - "title"
  # - "subject"
  # - "series"
  # - "journal" (Journal title)
  #
  def browse
    case (mode = setup_browse_params)
      when nil
        flash[:error] = MESSAGE[:no_browse_mode]
        redirect_to action: 'home'
      when :title #, :call_number
        # Regular search logic but displayed with the browse template.
        index
      when :call_number
        # Currently the Solr sort by "call_number asc" doesn't yield good
        # results because the searched-for call number pattern may match an
        # alternate call number (not the one being used for the sort).
        @response, @document_list =
          get_search_results(params, extra_solr_params)
        render 'catalog/index'
      else
        @response, @facet_list = get_classic_facets(mode, params)
    end
  end

end
