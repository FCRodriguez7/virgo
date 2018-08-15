# lib/cover_image/sources/google.rb
#--
# rubocop:disable Rails/Output
#++

require 'uva'

module CoverImage::Sources

  # CoverImage::Sources::Google
  #
  # === References
  # @see https://developers.google.com/books/docs/dynamic-links
  #
  class Google

    include UVA

    KEY_TYPES = [:isbn, :oclc, :lccn].freeze
    BASE_URL  = 'http://books.google.com/books'.freeze

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
    #
    def find(keys)

      unless KEY_TYPES.any? { |type| keys[type].is_a?(Array) }
        raise "At least one of #{KEY_TYPES} is required"
      end
      bkeys = create_bibkeys(keys)
      return if bkeys.blank?

      # Service requires a JavaScript callback name because it wraps the return
      # as JSONP.  We remove the wrapper from the first and last lines to
      # result in plain JSON so the choice of name for the callback is
      # irrelevant (as long as it's a legal JavaScript identifier).
      cb  = 'CALLBACK'
      url = "#{BASE_URL}?jscmd=viewapi&bibkeys=#{bkeys}&callback=#{cb}&zoom=0"
      uri = URI.parse(url)
      # puts("searching for image at url #{url}")
      path = "#{uri.path}?#{uri.query}"
      body = Net::HTTP.start(uri.host) { |http| http.get(path) }.body
      return [] unless body.include?('thumbnail_url')
      json = body.sub(/^#{cb}\(/, '').sub(/\);$/, '')

      # Loop through each item.
      max_matches = @options[:first] ? 1 : nil
      result = []
      ActiveSupport::JSON.decode(json).each_pair do |_bibkey, item|
        next if (thumbnail_url = item['thumbnail_url']).blank?
        puts("following thumbnail url #{thumbnail_url}")

        # Might be able to change the zoom param in the thumbnail_url to 0 for
        # larger images.
        binary = UVA::CoverImage.valid_image_url(thumbnail_url)
        next if binary.blank? # sometimes google returns an error page!
        puts "success on image at #{url}"
        content_vals = UVA::CoverImage.content_vals(thumbnail_url)
        result << {
          source_data:  binary,
          source_url:   thumbnail_url,
          source:       :google,
          content_type: content_vals[:content_type],
          image_size:   content_vals[:image_size],
          key_type:     item['bib_key'].split(':').first.downcase.to_sym,
          key:          item['bib_key'].sub(/^.+:/, ''),
          ext:          '.jpg'
        }
        return result if max_matches && (result.size >= max_matches)
      end
      result
    end

    # =========================================================================
    # :section:
    # =========================================================================

    protected

    # create_bibkeys
    #
    # @param [Hash] input
    #
    # @return [String]
    # @return [nil]
    #
    def create_bibkeys(input)
      type = KEY_TYPES.find { |t| !input[t].blank? }
      return unless type
      type_label = type.to_s.upcase
      input[type].map { |id| "#{type_label}:#{id}" }.join(',')
    end

  end

end
