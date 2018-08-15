# lib/cover_image/image.rb

require 'uva'

module CoverImage

  # CoverImage::Image
  #
  class Image

    BASE_PATH         = File.join('images', 'bookcovers').freeze
    DIR_ROOT_PATH     = File.join(Rails.root.to_s, 'public').freeze

    DEV_PROXY_ALLOWED = Virgo.desktop?
    DEV_PROXY_HOST    = 'http://xxx.virginia.edu'.freeze

    # =========================================================================
    # :section:
    # =========================================================================

    public

    # @return [SolrDocument] doc
    attr_reader :doc

    # Initialize a new self instance.
    #
    # @param [SolrDocument] doc
    #
    def initialize(doc)
      @doc = doc
    end

    # has_image?
    #
    def has_image?
      if proxy_url
        Net::HTTP.get_response(URI(image_path)).is_a?(Net::HTTPSuccess)
      else
        File.exist?(file_path)
      end
    end

    # file_path
    #
    # @return [String]
    #
    def file_path
      File.join(DIR_ROOT_PATH, BASE_PATH, *path_parts)
    end

    # url_path
    #
    # @return [String]
    #
    def url_path
      if has_image?
        image_path
      else
        log_failed_request! unless proxy_url
        default_path
      end
    end

    # Carve up the document id into directories and filename.
    #
    # @return [Array<String>]
    #
    # @example
    #   u1       => u1.jpg
    #   u123     => u123.jpg
    #   u12345   => 123/u12345.jpg
    #   u1234567 => 123/456/u1234567.jpg
    #
    def path_parts
      id = @doc.doc_id
      parts = id.scan(/\d{1,3}/)
      parts[-1] = "#{id}.jpg"
      parts
    end

    # The path used when no cover image is found.
    #
    # @return [String]
    #
    # TODO: Provide different defaults for different document types.
    #
    def default_path
      File.join('/images', 'catalog', 'default_bookcover.gif')
    end

    # Log that a user tried to look at this image, but we didn't have one in
    # the cache.
    #
    # @return [DocumentImageRequestRecord]
    # @return [nil]                   If a request for this image has been
    #                                   made recently.
    #
    def log_failed_request!
      return if recently_requested?
      DocumentImageRequestRecord.create(
        document_id:  @doc.doc_id,
        requested_at: Time.current
      )
    end

    # Check to see if we have already requested this image within the last day.
    #
    def recently_requested?
      DocumentImageRequestRecord.find_by_document_id(
        @doc.doc_id,
        conditions: ['requested_at >= ?', 1.day.ago]
      )
    end

    # Path or URL to image file.
    #
    # @param [Array<String>] parts    If empty, {#path_parts} is used.
    #
    # @return [String]
    #
    def image_path(*parts)
      # For production this becomes [''] so that '/' is prepended to the path.
      path = [proxy_url.to_s]
      path << BASE_PATH
      parts.flatten!
      parts = path_parts if parts.empty?
      parts.compact!
      path += parts
      File.join(*path)
    end

    # =========================================================================
    # :section:
    # =========================================================================

    protected

    # For desktop development, proxy cover images through the production
    # server.
    #
    # This is a convenience for developer desktop execution at UVa (on Grounds
    # or via the VPN) so that cover images can be displayed where expected and
    # to avoid needlessly checking for local cover images that don't exist.
    #
    # @return [String]
    # @return [nil]                   If running in a deployed environment.
    #
    def proxy_url
      DEV_PROXY_HOST if defined?(DEV_PROXY_ALLOWED) && DEV_PROXY_ALLOWED
    end

  end

end
