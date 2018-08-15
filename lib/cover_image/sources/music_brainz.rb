# lib/cover_image/sources/music_brainz.rb
#--
# rubocop:disable Rails/Output
#++

require 'open-uri'
require 'cgi'
require 'uva'

module CoverImage::Sources

  # CoverImage::Sources::MusicBrainz
  #
  # === References
  # @see https://musicbrainz.org/doc/Development/XML_Web_Service/Version_2/Search
  #
  class MusicBrainz

    BASE_URL = 'http://musicbrainz.org/ws/2/release'.freeze

    # =========================================================================
    # :section:
    # =========================================================================

    public

    # find_album_ids_by_artist_and_album
    #
    # @param [String] album
    # @param [String] artist
    #
    # @return [Array<String>]
    #
    # NOTE: There are problems with this method.
    #
    # MusicBrainz seems eager to return results, and the first result always
    # seems to have a relevancy score of "100" even if it's not that close of a
    # match.  For example https://xxx.virginia.edu/xxx
    # title "Echoes from the gorge" and artist  "Chou, Wen-Chung" results in
    # a match for "The Gorge" by "Dave Matthews Band".
    #
    # This method should validate the returned XML to make sure that the
    # release/title element matches the *album* argument and the
    # release/artist-credit/name-credit/artist/name element matches the
    # *artist* argument before accepting the result.
    #
    # While having a cover image is nicer than the alternative, having the
    # wrong cover image is actually an irritant to the users.
    #
    def find_album_ids_by_artist_and_album(album, artist = nil)

      url = "#{BASE_URL}?query=#{CGI.escape(album)}"
      url << "&artist:#{CGI.escape(artist)}" unless artist.blank?
      uri = URI.parse(url)

      puts "
      MUSIC BRAINZ URL: #{url}
      "

      begin
        doc = Nokogiri::XML(open(uri.to_s))
      rescue
        puts "
        MUSIC BRAINZ CONNECTION ERROR: #{$ERROR_INFO}
        "
        Rails.logger.info "*** MUSIC BRAINZ ERROR: #{$ERROR_INFO} "
        Rails.logger.info "*** URL: #{uri}"
        return []
      end

      # Make sure that the "best match" really matches the title.
      returned_album = doc.xpath('//title').first
      returned_album &&= returned_album.children
      returned_album &&= returned_album.first
      returned_album &&= returned_album.to_s
      return [] unless same?(album, returned_album)

      # Make sure that the "best match" really matches the artist.
      returned_artist = doc.xpath('//artist/name').first
      returned_artist &&= returned_artist.children
      returned_artist &&= returned_artist.first
      returned_artist &&= returned_artist.to_s
      return [] unless same?(artist, returned_artist)

      releases = doc.xpath("//*[local-name(.)='release']/@id")
      # NOTE: Could check values here: release.text() =~ album etc.
      releases.map(&:text).reject(&:blank?).uniq
    end

    # =========================================================================
    # :section:
    # =========================================================================

    protected

    # same?
    #
    # @param [String] s1
    # @param [String] s2
    #
    def same?(s1, s2)
      squashed(s1) == squashed(s2)
    end

    # squashed
    #
    # @param [String] s
    #
    # @return [String]
    #
    def squashed(s)
      s.downcase.delete('^a-z0-9')
    end

  end

end
