# lib/cover_image/sources/library_thing.rb
#--
# rubocop:disable Rails/Output
#++

require 'uva'

module CoverImage::Sources

  # CoverImage::Sources::LibraryThing
  #
  class LibraryThing

    BASE_URL = 'http://covers.librarything.com'.freeze

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
    # @return [nil]
    #
    def find(keys)

      unless keys[:isbn].is_a?(Array)
        raise ':isbn keys are required and are the only supported key type'
      end
      return if keys[:isbn].empty?
      max_matches = @options[:first] ? 1 : nil

      api_key  = LIBRARY_THING_API_KEY
      base_url = "#{BASE_URL}/devkey/#{api_key}/large/isbn/"
      base_uri = URI.parse(base_url)

      result = []
      keys[:isbn].each do |isbn|
        image_url = "#{base_uri}#{isbn}"
        # puts "searching for image at #{image_url}"
        binary = UVA::CoverImage.valid_image_url(image_url)
        next if binary.blank?
        content_vals = UVA::CoverImage.content_vals(image_url)
        puts "success on image at #{image_url}"
        result << {
          source_data:  binary,
          source_url:   image_url,
          source:       :library_thing,
          content_type: content_vals[:content_type],
          image_size:   content_vals[:image_size],
          key_type:     :isbn,
          key:          isbn,
          ext:          '.jpg'
        }
        return result if max_matches && (result.size >= max_matches)
      end
      result
    end

  end

end
