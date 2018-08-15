# lib/cover_image/sources/last_fm.rb
#--
# rubocop:disable Rails/Output
#++

require 'open-uri'
require 'uva'

module CoverImage::Sources

  # CoverImage::Sources::LastFM
  #
  class LastFM

    BASE_URL = 'http://ws.audioscrobbler.com/2.0/'.freeze

    # =========================================================================
    # :section:
    # =========================================================================

    public

    # @return [Hash]
    attr_reader :options

    # Initialize a new self instance.
    #
    # @param [Hash] options
    #
    def initialize(options = {})
      options[:first] = true unless options.key?(:first)
      @options = options
    end

    # find
    #
    # @param [Hash] keys
    #
    # @return [Array<Hash>]
    # @return [nil]                   If no keys were provided.
    #--
    # rubocop:disable Metrics/MethodLength # [39/35]
    #++
    def find(keys)

      unless keys[:mbid].is_a?(Array)
        raise ':mbid is required and the only supported key'
      end
      return if keys[:mbid].empty?
      max_matches = @options[:first] ? 1 : nil

      base_url = "xxx"

      result = []
      keys[:mbid].each do |mbid|
        url = "#{base_url}&mbid=#{mbid}"
        puts "LAST FM URL:
        #{url}
        "
        response = get_response(url)
        next if response.blank?

        doc = Nokogiri::XML(response)
        previews = doc.xpath('//album/url').map(&:inner_html).reject(&:blank?)

        %w(extralarge small large medium).each do |size|
          doc.search("//album/image[@size='#{size}']").each do |v|
            h = v.inner_html
            next if h.blank?
            binary = UVA::CoverImage.valid_image_url(h, 100)
            next if binary.blank?
            puts "success on image at #{url}"
            content_vals = UVA::CoverImage.content_vals(h)
            result << {
              source_data:  binary,
              source_url:   h,
              source:       :last_fm,
              content_type: content_vals[:content_type],
              image_size:   content_vals[:image_size],
              key_type:     :mbid,
              key:          mbid,
              ext:          '.jpg',
              preview_urls: previews,
            }
            return result if max_matches && (result.size >= max_matches)
          end
        end
      end
      result
      # rubocop:enable Metrics/MethodLength
    end

    # =========================================================================
    # :section:
    # =========================================================================

    protected

    # get_response
    #
    # @param [String] url
    #
    # @return [String]
    # @return [nil]                   If the service could not be contacted.
    #
    def get_response(url)
      uri = URI.parse(url)
      open(uri).collect.join.tap do |response|
        raise 'internal' if response.casecmp('status="failed"').zero?
      end
    rescue => e
      message = 'LAST FM FAILED!'
      puts message
      message << " (#{e.msg})" unless e.msg == 'internal'
      Rails.logger.info "*** #{message} ***"
      nil
    end

  end

end
