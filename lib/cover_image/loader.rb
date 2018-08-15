# lib/cover_image/loader.rb
#--
# rubocop:disable Rails/Output
# rubocop:disable Rails/TimeZone
#++

require 'uva'
require 'cover_image/finder'
require 'cover_image/sources/google'
require 'cover_image/sources/last_fm'
require 'cover_image/sources/library_thing'
require 'cover_image/sources/music_brainz'
require 'cover_image/sources/syndetics'

module CoverImage

  # CoverImage::Loader
  #
  class Loader

    include Blacklight::Configurable
    include UVA
    include UVA::Solr

    # =========================================================================
    # :section: Blacklight Configuration
    # =========================================================================

    configure_blacklight do |config|
      config.default_solr_params = {
        qt:   'search',
        rows: 500
      }
      config.max_per_page = 500
      config.default_qt = 'search'
    end

    # =========================================================================
    # :section:
    # =========================================================================

    public

    # Initialize a new self instance.
    #
    # @param [Boolean] do_solr_updates
    # @param [String]  date_string
    #
    def initialize(do_solr_updates, date_string)
      docs = do_solr_updates ? solr_add_docs(date_string) : hourly_updates
      harvest_for_all(docs)
    end

    # params
    #
    # @return [Hash]
    #
    def params
      {}
    end

    # Gets requested added to the index on the given date_string (YYYYmmdd).
    #
    # @param [String] date_string
    #
    # @return [Array<SolrDocument>]
    #
    def solr_add_docs(date_string)
      local_params = {}
      local_params[:f] = {}
      local_params[:f][:date_first_indexed_facet] = [date_string]
      local_params[:sort] = 'date_received_facet desc'
      _response, documents = get_search_results(local_params)
      puts "got #{documents.size} documents"
      documents
    end

    # Gets requests for the last hour.
    #
    # @return [Array<SolrDocument>]
    #
    def hourly_updates
      # Get requests for the last hour.
      end_time   = DateTime.new(*Time.now.to_a[3..5].reverse)
      start_time = end_time - 1
      image_requests =
        DocumentImageRequestRecord.all(
          conditions: { requested_at: start_time..end_time }
        )

      # Transform the document ids into Solr docs.
      image_requests.map(&:document_id).each_slice(100) { |ids|
        _response, documents = get_solr_response_for_field_values('id', ids)
        documents
      }.flatten
    end

    # Harvest for each Solr document.
    #
    # @param [Array<SolrDocument>] docs
    #
    # @return [void]
    #
    def harvest_for_all(docs)
      ids = docs.map(&:doc_id)
      puts("about to look for covers for docs #{ids}")
      docs.each { |doc| harvest_for(doc) }
    end

    # Harvest an image for this doc.
    #
    # @param [SolrDocument] doc
    #
    # @return [void]
    #
    def harvest_for(doc)
      # Locate a thumbnail for this Solr document.
      doc_image = doc && CoverImage::Image.new(doc)
      images    = doc_image && image_find(doc_image)
      return if images.blank?
      puts "found image for #{doc.doc_id}"

      # Save the thumbnail image.
      FileUtils.mkdir_p(File.dirname(doc_image.file_path))
      File.open(doc_image.file_path, 'wb') do |f|
        f.puts images.first[:source_data]
      end
    end

    # Dispatch the appropriate finder.
    #
    def image_find(doc)
      case doc.doc_type
        when :lib_catalog, :lib_video, :lib_video_full # , :hathi # TODO
          find_bookcovers(doc)
        when :lib_album
          return unless doc.get_collection.blank?
          mbids = music_brainz_ids(doc)
          find_albumcovers(mbids)
      end
    end

    # Load the finder for finding book covers and video covers.
    #
    # @param [SolrDocument] doc
    #
    # @return [Array<Hash>]
    # @return [nil]
    #
    def find_bookcovers(doc)
      puts "LOOKING FOR A COVER for #{doc.doc_id} - " \
           "ISBN: #{doc.isbns}, OCLC: #{doc.oclcs}, UPC: #{doc.upcs}"
      ri = CoverImage::Finder.new(use_cache: false)
      ri.add_finder :syndetics,     CoverImage::Sources::Syndetics.new
      ri.add_finder :google,        CoverImage::Sources::Google.new
      ri.add_finder :library_thing, CoverImage::Sources::LibraryThing.new
      ri.find(isbn: doc.isbns, oclc: doc.oclcs, upc: doc.upcs)
    end

    # Load the finder for finding album covers.
    #
    # @param [Array<String>] ids
    #
    # @return [Array<Hash>]
    # @return [nil]
    #
    def find_albumcovers(ids)
      puts 'LOOKING FOR AN ALBUM COVER'
      ri = CoverImage::Finder.new(use_cache: false)
      ri.add_finder :last_fm, CoverImage::Sources::LastFM.new
      ri.find(mbid: ids)
    end

    # Looking up the MusicBrainz ID(s) for the given document.
    #
    # @param [SolrDocument] doc
    #
    # @return [Array<Hash>]
    # @return [nil]
    #
    def music_brainz_ids(doc)
      puts "MusicBrainz lookup for doc_id: #{doc.doc_id}"
      author = doc.get_authors.first
      title  = doc.get_title.first
      return if author.blank? && title.blank?
      # Remove that last little annoying bit:
      author.sub!(/ \(Musical group\)/, '') unless author.blank?
      mb = CoverImage::Sources::MusicBrainz.new
      mb.find_album_ids_by_artist_and_album(title, author)
    end

  end

end
