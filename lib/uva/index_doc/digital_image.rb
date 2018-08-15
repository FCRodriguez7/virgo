# lib/uva/index_doc/digital_image.rb

require 'uva'

module UVA

  # UVA::DigitalImage
  #
  # Digital library/image logic.
  #
  module DigitalImage

    # Actions taken when this module is included.
    #
    # @param [Module] base            The including module or class.
    #
    # @return [void]
    #
    def self.included(base) # :nodoc:
      [Interface].each do |mod|
        base.send(:include, mod) unless base.include?(mod)
      end
    end

  end

  # ===========================================================================
  # :section: DigitalImage IndexDoc mixin
  # ===========================================================================

  public

  module DigitalImage::Interface

    include UVA

    # =========================================================================
    # :section:
    # =========================================================================

    public

    # Indicate whether the current document has TEI data.
    #
    def is_digital_image?(*)
      case doc_type
        when :dl_book, :dl_image then true
        when :data_driven        then has_feature?('has_djatoka_image')
        else                          doc_sub_type == :dl_book
      end
    end

    # The URL of the repository service for the document.
    #
    # @return [String]
    #
    def fedora_url(*)
      FEDORA_REST_URL
    end

    # Return the MODS metadata for the document.
    #
    # @param [String] resource_id     If *nil*, defaults to the current doc_id.
    #
    # @return [String]
    # @return nil
    #
    def mods_get_url(resource_id = nil, *)
      args resource_id
    end

    # Repository metadata for the given repository item.
    #
    # @param [String] resource_id     If *nil*, defaults to the current doc_id.
    #
    # @return [String]
    # @return nil
    #
    def dl_jp2k_metadata(resource_id = nil, *)
      args resource_id
    end

    # A thumbnail image for the given repository item.
    #
    # @param [String] resource_id     If *nil*, defaults to the current doc_id.
    #
    # @return [String]
    # @return nil
    #
    def dl_jp2k_preview(resource_id = nil, *)
      args resource_id
    end

    # The full-size image for the given repository item.
    #
    # @param [String] resource_id     If *nil*, defaults to the current doc_id.
    #
    # @return [String]
    # @return nil
    #
    def dl_jp2k_viewer(resource_id = nil, *)
      args resource_id
    end

    # dl_jp2k_screen
    #
    # @note This method is unused.
    #
    # @param [String] resource_id     If *nil*, defaults to the current doc_id.
    #
    # @return [String]
    # @return nil
    #
    def dl_jp2k_screen(resource_id = nil, *)
      args resource_id
    end

    # dl_image_preview_src
    #
    # @param [String] resource_id     Defaults to the first item in the Solr
    #                                   *media_resource_id_display* field.
    #
    # @return [String]
    # @return nil
    #
    def dl_image_preview_src(resource_id = nil, *)
      args resource_id
    end

    # dl_image_full_src
    #
    # @param [String] resource_id     Defaults to the first item in the Solr
    #                                   *media_resource_id_display* field.
    #
    # @return [String]
    # @return nil
    #
    def dl_image_full_src(resource_id = nil, *)
      args resource_id
    end

    # dl_image_viewer
    #
    # @note This method is unused and may be defunct.
    #
    # @param [String] resource_id
    # @param [String] parent_id
    #
    # @return [String]
    #
    def dl_image_viewer(resource_id, parent_id, *)
      args resource_id, parent_id
    end

    # The route of the link to a viewer for this image.
    #
    # @param [String] resource_id     If *nil*, defaults to the current doc_id.
    # @param [String] focus_id        NOTE: appears to be unused.
    #
    # @return [String]
    #
    # === Usage Notes
    # The value is relative to the main URL of the server.  To make this a full
    # URL within MVC code use:
    #
    #   "http://#{request.host_with_port}#{dl_jp2k_viewer_applet}"
    #
    # The *focus_id* parameter isn't used anywhere so essentially any place in
    # the MVC code that uses `doc.dl_jp2k_viewer_applet` could be replaced by
    # `view_catalog_path`.
    #
    def dl_jp2k_viewer_applet(resource_id = nil, focus_id = nil. *)
      args resource_id, focus_id
    end

    # =========================================================================
    # :section:
    # =========================================================================

    private

    # Allows interface definitions to have required arguments without complaint
    # about unused arguments from syntax checkers.
    #
    def args(*) # :nodoc:
    end

  end

  # ===========================================================================
  # :section: DigitalImage Blacklight (SolrDocument) extension
  # ===========================================================================

  public

  module DigitalImage::Extension

    include UVA
    include UVA::DigitalImage::Interface

    # Solr fields associated with this content type.
    SOLR_FIELDS = [
      :repository_address_display,
      :media_resource_id_display
    ]

    # =========================================================================
    # :section:
    # =========================================================================

    public

    # Indicate whether the current document has TEI data.
    #
    def is_digital_image?
      true
    end

    # The URL of the repository service for the document.
    #
    # @return [String]
    #
    # === Usage Notes
    # In some cases the Solr *repository_address_display* is more than just
    # the base path to the Fedora service.  Specifically, this method strips
    # "/get" from the end of the path so that the result is just the path to
    # the Fedora service.
    #
    def fedora_url
      result = values_for(:repository_address_display).first
      result ? result.sub(%r{/get/?$}, '') : super
    end

    # Return the MODS metadata for the document.
    #
    # @param [String] resource_id     If *nil*, defaults to the current doc_id.
    #
    # @return [String]
    #
    def mods_get_url(resource_id = nil)
      repo_url(resource_id, 'MODS')
    end

    # Repository metadata for the given repository item.
    #
    # @param [String] resource_id     If *nil*, defaults to the current doc_id.
    #
    # @return [String]
    #
    def dl_jp2k_metadata(resource_id = nil)
      repo_url(resource_id, 'djatoka:jp2SDef/getMetadata')
    end

    # A thumbnail image for the given repository item.
    #
    # @param [String] resource_id     If *nil*, defaults to the current doc_id.
    #
    # @return [String]
    #
    def dl_jp2k_preview(resource_id = nil)
      repo_url(resource_id, 'djatoka:StaticSDef/getThumbnail')
    end

    # The full-size image for the given repository item.
    #
    # @param [String] resource_id     If *nil*, defaults to the current doc_id.
    #
    # @return [String]
    #
    def dl_jp2k_viewer(resource_id = nil)
      repo_url(resource_id, 'djatoka:jp2SDef/getImageView')
    end

    # dl_jp2k_screen
    #
    # @note This method is unused.
    #
    # @param [String] resource_id     If *nil*, defaults to the current doc_id.
    #
    # @return [String]
    #
    def dl_jp2k_screen(resource_id = nil)
      repo_url(resource_id, 'djatoka:jp2SDef/getRegion?scale=900,900')
    end

    # dl_image_preview_src
    #
    # @param [String] resource_id     Defaults to the first item in the Solr
    #                                   *media_resource_id_display* field.
    #
    # @return [String]
    #
    def dl_image_preview_src(resource_id = nil)
      resource_id ||= values_for(:media_resource_id_display).first
      repo_url(resource_id, 'uva-lib-bdef:102/getPreview')
    end

    # dl_image_full_src
    #
    # @param [String] resource_id     Defaults to the first item in the Solr
    #                                   *media_resource_id_display* field.
    #
    # @return [String]
    #
    def dl_image_full_src(resource_id = nil)
      resource_id ||= values_for(:media_resource_id_display).first
      # We shouldn't reference the getScreen behaviors because they are broken
      # quite often.  Instead, reference the SCREEN datastream.
      # "#{fedora_url}/#{resource_id}/uva-lib-bdef:102/getScreen"
      repo_url(resource_id, 'SCREEN')
    end

    # dl_image_viewer
    #
    # @note This method is unused and may be defunct.
    #
    # @param [String] resource_id
    # @param [String] parent_id
    #
    # @return [String]
    #
    def dl_image_viewer(resource_id, parent_id)
      repo_url(
        resource_id,
        "uva-lib-bdef:102/getImageViewer?parentPid=#{parent_id}"
      )
    end

    # The route of the link to a viewer for this image.
    #
    # @param [String] resource_id     If *nil*, defaults to the current doc_id.
    #
    # @return [String]
    #
    # === Usage Notes
    # The value is relative to the main URL of the server.  To make this a full
    # URL within MVC code use:
    #
    #   "http://#{request.host_with_port}#{dl_jp2k_viewer_applet}"
    #
    def dl_jp2k_viewer_applet(resource_id = nil)
      resource_id ||= doc_id
      "/catalog/#{resource_id}/view"
    end

    # =========================================================================
    # :section:
    # =========================================================================

    protected

    # Construct a URL to access repository information.
    #
    # @param [String] resource_id     If *nil*, defaults to the current doc_id.
    #
    # @return [String]
    #
    def repo_url(resource_id, *path)
      resource_id ||= doc_id
      action = path.map(&:strip).join('/')
      "#{fedora_url}/get/#{resource_id}/#{action}"
    end

    # =========================================================================
    # :section: Module methods
    # =========================================================================

    public

    # Actions taken when this module is included.
    #
    # @param [Module] base            The including module or class.
    #
    # @return [void]
    #
    def self.included(base) # :nodoc:
      Rails.logger.debug { "#{base}: included extension UVA::DigitalImage" }
    end

  end

end
