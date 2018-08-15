# lib/uva/cover_image.rb

require 'net/http'
require 'cover_image/image'
require 'uva'

# Utility methods for cover images.
#
module UVA::CoverImage

  include UVA

  class << self

    include CoverImage

    # =========================================================================
    # :section: Module methods
    # =========================================================================

    public

    # image_path
    #
    # @param [UVA::IndexDoc] doc
    #
    # @return [String]
    #
    def image_path(doc)
      Image.new(doc).url_path
    end

    # has_image?
    #
    # @param [UVA::IndexDoc] doc
    #
    def has_image?(doc)
      Image.new(doc).has_image?
    end

    # content_vals
    #
    # @param [String] url
    #
    # @return [Hash{Symbol=>String}]
    #
    def content_vals(url)
      hdr = fetch_url(url)
      result = {}
      result[:content_type] = hdr['content-type']   if hdr
      result[:image_size]   = hdr['content-length'] if hdr
      result
    end

    # valid_image_url
    #
    # @param [String] url
    # @param [Fixnum] min_length
    # @param [Fixnum] max_length
    #
    # @return [String]
    # @return [nil]
    #
    def valid_image_url(url, min_length = 90, max_length = 65535)
      return if url.blank?
      result  = fetch_url(url)
      content = result && (result.code == '200') && result.body
      length  = content && content.length
      content if length && length.between?(min_length, max_length)
    end

    # =========================================================================
    # :section: Module methods
    # =========================================================================

    protected

    # fetch_url
    #
    # @param [String] url
    #
    # @return [Hash]
    # @return [nil]
    #
    def fetch_url(url)
      url = URI.parse(url)
      http = Net::HTTP.new(url.host, url.port)
      http.use_ssl = (url.port == 443)
      http.get("#{url.path}?#{url.query}")
    rescue
      return nil
    end

  end

end
