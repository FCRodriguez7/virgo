# lib/uva/helper/cover_image.rb

require 'uva'

module UVA::Helper

  # UVA::Helper::CoverImage
  #
  module CoverImage

    include UVA

    # =========================================================================
    # :section:
    # =========================================================================

    public

    # Used by the digital library/image collection views.
    #
    # @param [String] image_src
    #
    def image_url_exists?(image_src)
      UVA::CoverImage.valid_image_url(image_src)
    end

  end

end
