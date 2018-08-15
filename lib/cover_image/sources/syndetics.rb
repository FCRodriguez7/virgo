# lib/cover_image/sources/syndetics.rb
#--
# rubocop:disable Rails/Output
#++

require 'uva'

module CoverImage::Sources

  # CoverImage::Sources::Syndetics
  #
  class Syndetics

    KEY_TYPES = [:isbn, :upc, :oclc].freeze
    BASE_URL  = 'http://syndetics.com/index.aspx'.freeze

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
    # @example
    #      find :isbn => [123459087,12358971625]
    #   or find :upc  => [123459087,12358971625]
    #   or find :oclc => [123459087,12358971625]
    #
    #--
    # rubocop:disable Metrics/MethodLength # [57/35]
    #++
    def find(keys)

      unless KEY_TYPES.any? { |type| keys[type].is_a?(Array) }
        raise "At least one of #{KEY_TYPES} is required"
      end
      max_matches = @options[:first] ? 1 : nil

      result = []

      # Query by ISBN.
      keys[:isbn].each do |isbn|
        url = "#{BASE_URL}?isbn=#{isbn}/mc.jpg" # "&client=sirsi&type=rw12"
        next unless (binary = UVA::CoverImage.valid_image_url(url))
        puts "success on image at #{url}"
        content_vals = UVA::CoverImage.content_vals(url)
        result << {
          source_data:  binary,
          source_url:   url,
          source:       :syndetics,
          content_type: content_vals[:content_type],
          image_size:   content_vals[:image_size],
          key_type:     :isbn,
          key:          isbn,
          ext:          '.jpg'
        }
        return result if max_matches && (result.size >= max_matches)
      end

      # Query by UPC.
      keys[:upc].each do |upc|
        url = "#{BASE_URL}?isbn=/mc.jpg&upc=#{upc}"
        next unless (binary = UVA::CoverImage.valid_image_url(url))
        puts "success on image at #{url}"
        content_vals = UVA::CoverImage.content_vals(url)
        result << {
          source_data:  binary,
          source_url:   url,
          source:       :syndetics,
          content_type: content_vals[:content_type],
          image_size:   content_vals[:image_size],
          key_type:     :upc,
          key:          upc,
          ext:          '.jpg'
        }
        return result if max_matches && (result.size >= max_matches)
      end

      # Query by OCLC number.
      keys[:oclc].each do |oclc|
        url = "#{BASE_URL}?isbn=/mc.jpg&oclc=#{oclc}"
        next unless (binary = UVA::CoverImage.valid_image_url(url))
        puts "success on image at #{url}"
        content_vals = UVA::CoverImage.content_vals(url)
        result << {
          source_data:  binary,
          source_url:   url,
          source:       :syndetics,
          content_type: content_vals[:content_type],
          image_size:   content_vals[:image_size],
          key_type:     :oclc,
          key:          oclc,
          ext:          '.jpg'
        }
        return result if max_matches && (result.size >= max_matches)
      end

      # Return nil on failure.
      result.empty? ? nil : result

      # rubocop:enable Metrics/MethodLength
    end

  end

  # CoverImage::Sources::Review
  #
  # @note currently unused
  #
  class Review

    BASE_URL = Syndetics::BASE_URL

    SOURCE_TYPES = {
      preview:   'PWREVIEW',
      summary:   'SUMMARY',
      toc:       'TOC',
      bnatoc:    'BNATOC',
      fiction:   'FICTION',
      dbchapter: 'DBCHAPTER',
      ljreview:  'LJREVIEW',
      sljreview: 'SLJREVIEW',
      chreview:  'CHREVIEW',
      anotes:    'ANOTES',
      blreview:  'BLREVIEW',
      doreview:  'DOREVIEW',
      reviews:   'REVIEWS'
    }.freeze

    # =========================================================================
    # :section:
    # =========================================================================

    public

    # Create a new self instance.
    #
    # @param [String] client_id
    #
    def initialize(client_id = nil)
      @client_id = client_id
    end

    # find_by_isbn
    #
    # @param [String] isbn
    # @param [Hash]   config
    #
    # @return [Net::HTTPResponse]
    #
    # @example
    #   http://syndetics.com/index.aspx?isbn=12358971625/CHREVIEW.HTML
    #
    def find_by_isbn(isbn, config = {})
      opts = {
        source_type:   :preview,
        source_format: :xml,
        type:          nil
      }.merge!(config)
      source = resolve_source(opts[:source_type], opts[:source_format])
      url = "#{BASE_URL}?isbn=#{isbn}/" \
            "#{source}&client=#{@client_id}&type=#{opts[:type]}"
      uri = URI.parse(URI.encode(url))
      Net::HTTP.get(uri)
    end

    # =========================================================================
    # :section:
    # =========================================================================

    protected

    # resolve_source
    #
    # @param [Symbol] source_type
    # @param [String] source_format
    #
    # @return [String]
    #
    def resolve_source(source_type, source_format)
      "#{SOURCE_TYPES[source_type]}.#{source_format.to_s.upcase}"
    end

  end

end
