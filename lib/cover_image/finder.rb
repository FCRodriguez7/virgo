# lib/cover_image/finder.rb

require 'uva'

module CoverImage

  # CoverImage::Finder
  #
  class Finder

    # @return [Hash]
    attr_reader :options

    # @return [Array<Finder>]
    attr_reader :finders

    # Initialize a new self instance.
    #
    # @param [Hash] options
    #
    def initialize(options = {})
      options[:first] = true unless options.key?(:first)
      @options = options
      @finders = []
      @cache   = nil
    end

    # add_finder
    #
    # @param [String] source
    # @param [Finder] finder
    #
    # @return [Array<Finder>]
    #
    def add_finder(source, finder)
      @finders << { source: source, finder: finder }
    end

    # find
    #
    # @param [Hash]   keys
    # @param [String] _ext            Currently unused.
    #
    # @return [Array<Hash>]
    #
    # @example
    #   find({ isbn: [1234567812, 9876543214] }, '.jpg')
    #
    def find(keys, _ext = '.*')
      data = []
      finders.each do |f|
        images = f[:finder].find(keys)
        next if images.blank?
        images.each { |image| @cache.store!(image) } if @cache
        data += images
        break if @options[:first]
      end
      if data.empty? && @options[:default_image_url]
        data << {
          source:   '',
          key_type: '',
          key:      '',
          url:      @options[:default_image_url]
        }
      end
      data
    end
  end

end
