# app/controllers/music_controller.rb

require 'uva'

# This controller implements the "Music portal" or "Music lens", which is a
# variation on CatalogController functionality.
#
# @see FeaturedItemsConcern
# @see CatalogController
#
# Related:
# @see VideoController
#
class MusicController < CatalogController

  include FeaturedItemsConcern

  # ===========================================================================
  # :section: Blacklight Configuration
  # ===========================================================================

  public

  # === Facets
  # The order here defines the order in which facets are displayed in the
  # search results sidebar.
  MUSIC_FACETS = {
    # rubocop:disable Metrics/LineLength
    library_facet:                ['Library',               advanced: true,   missing: true],
    format_facet:                 ['Format',                advanced: true],
    instrument_facet:             ['Instrument',            advanced: true],
    music_composition_era_facet:  ['Composition Era',       advanced: true],
    recordings_and_scores_facet:  ['Recordings and Scores', advanced: false],
    recording_format_facet:       ['Recording Format',      advanced: false],
    author_facet:                 ['Author',                advanced: false],
    subject_facet:                ['Subject',               advanced: false],
    series_title_facet:           ['Series',                advanced: false],
    language_facet:               ['Language',              advanced: true,   sort: 'count',  missing: true],
    region_facet:                 ['Region',                advanced: true,   sort: 'count',  limit: 500],
    source_facet:                 ['Source',                advanced: false],
    location2_facet:              ['Shelf Location',        advanced: true,   optional: true, missing: true],
    year_multisort_i:             ['Year',                  advanced: false,  optional: true], # [1]
    # rubocop:enable Metrics/LineLength
    #
    # NOTE:
    # [1] Only appears within "Switch to" links created on article search
    #     results pages.
    #
  }.deep_freeze

  # === Search fields
  # The field labeled 'Keyword' is actually the 'music' field for music search.
  MUSIC_SEARCH_FIELDS =
    CATALOG_SEARCH_FIELDS.map { |field, properties|
      field = :music if field == :keyword
      [field, properties]
    }.to_h.deep_freeze

  # ===========================================================================
  # :section: Blacklight Configuration
  #
  # @see Blacklight::Configurable::ClassMethods#configure_blacklight
  # @see Blacklight::Configuration::Fields#add_solr_field
  # ===========================================================================

  configure_blacklight do |config|
    config.facet_fields.clear
    configure_facets(config, MUSIC_FACETS, qt: config.default_qt)
    config.search_fields.clear
    configure_search_fields(config, MUSIC_SEARCH_FIELDS)
  end

  # ===========================================================================
  # :section: FeaturedItemsConcern overrides
  # ===========================================================================

  protected

  # Search facet criteria for selecting featured items for this controller.
  #
  # @return [Hash]
  #
  # @see FeaturedItemsConcern#load_featured_documents
  #
  def selection_filters
    {
      library_facet: %w(Music),
    }
  end

end
