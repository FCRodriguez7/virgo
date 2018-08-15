# app/controllers/video_controller.rb

require 'uva'

# This controller implements the "Video portal" or "Video lens", which is a
# variation on {CatalogController} functionality.
#
# @see FeaturedItemsConcern
# @see CatalogController
#
# Related:
# @see MusicController
#
class VideoController < CatalogController

  include FeaturedItemsConcern

  FEATURED_GENRES = %w(
    Action/Adventure
    Comedy
    Crime/Mystery
    Drama
    Romance
    SciFi/Fantasy
    Television
  ).deep_freeze

  DEF_RANDOMIZE_GENRE      = false
  DEF_VIDEO_FEATURED_ITEMS = 2 * DEF_FEATURED_ITEM_TOTAL

  # ===========================================================================
  # :section: Blacklight Configuration
  # ===========================================================================

  public

  # === Facets ===
  # The order here defines the order in which facets are displayed in the
  # search results sidebar.
  VIDEO_FACETS = {
    # rubocop:disable Metrics/LineLength
    library_facet:      ['Library',             advanced: true,   missing: true],
    format_facet:       ['Format',              advanced: true],
    video_genre_facet:  ['Genre',               advanced: true,   missing: true],
    subject_facet:      ['Subject',             advanced: false],
    series_title_facet: ['Series',              advanced: false],
    language_facet:     ['Language',            advanced: true,   sort: 'count',  missing: true],
    region_facet:       ['Geographic Location', advanced: true,   sort: 'count',  limit: 500],
    source_facet:       ['Source',              advanced: false],
    location2_facet:    ['Shelf Location',      advanced: true,   optional: true, missing: true],
    year_multisort_i:   ['Year',                advanced: false,  optional: true], # NOTE [1]
    # rubocop:enable Metrics/LineLength
    #
    # NOTE:
    # [1] Only appears within "Switch to" links created on article search
    #     results pages.
    #
  }.deep_freeze

  # ===========================================================================
  # :section: Blacklight Configuration
  #
  # @see Blacklight::Configurable::ClassMethods#configure_blacklight
  # @see Blacklight::Configuration::Fields#add_solr_field
  # ===========================================================================

  configure_blacklight do |config|
    config.facet_fields.clear
    configure_facets(config, VIDEO_FACETS, qt: config.default_qt)
  end

  # ===========================================================================
  # :section: FeaturedItemsConcern overrides
  # ===========================================================================

  protected

  # Number of items to display.
  #
  # @return [Fixnum]
  #
  # @see FeaturedItemsConcern#featured_item_total
  #
  def featured_item_total
    DEF_VIDEO_FEATURED_ITEMS
  end

  # Search facet criteria for selecting featured items for this controller.
  #
  # @return [Hash]
  #
  # @see FeaturedItemsConcern#load_featured_documents
  #
  def selection_filters
    selected_genre = randomize_genre ? rand(FEATURED_GENRES.size) : 0
    {
      format_facet:      %w(Blu-Ray),
      video_genre_facet: FEATURED_GENRES[selected_genre, 1],
    }
  end

  # Indicate whether a random genre will be shown for featured videos.
  #
  # @param [Boolean] setting          If *nil* the current value is used.
  #
  # @return [Boolean]
  #
  def randomize_genre(setting = nil)
    if setting.nil?
      @random_genre ||= DEF_RANDOMIZE_GENRE
    else
      @random_genre = setting
    end
  end

end
