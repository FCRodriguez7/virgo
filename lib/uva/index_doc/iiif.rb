# lib/uva/index_doc/iiif.rb

require 'uva'

module UVA

  # International Image Interoperability Framework (IIIF) images.
  #
  # @see http://iiif.io
  #
  module IIIF

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
  # :section: IIIF IndexDoc mixin
  # ===========================================================================

  public

  module IIIF::Interface

    include UVA

    STATUS = {
      no_iiif:     'IIIF metadata unavailable',
      no_manifest: 'Missing IIIF manifest',
      ambiguous:   'Ambiguous IIIF manifest',
    }.deep_freeze

    # =========================================================================
    # :section:
    # =========================================================================

    public

    # Indicate whether the current document contains IIIF.
    #
    def is_iiif?(*)
      has_feature?('iiif')
    end

    # Indicate whether the current document has IIIF data.
    #
    def has_iiif_metadata?
      values_for(:iiif_presentation_metadata_display).present?
    end

    # Metadata for display of IIIF images.
    #
    # @return [Array<(String, nil)>]     Metadata with no issues reported.
    # @return [Array<(String, String)>]  Metadata and status message.
    # @return [Array<(nil,    String)>]  If IIIF is not present.
    #
    def iiif_metadata(*)
      return nil, STATUS[:no_iiif]
    end

    # A document may have multiple visual representations using IIIF, most
    # commonly when there are multiple copies that have been digitized.  The
    # information about each copy is spread across the solr document but this
    # method gathers it together into a reasonable array of hashes
    #
    # @return [Array<Hash>]
    #
    def get_iiif_array(*)
      []
    end

  end

  # ===========================================================================
  # :section: IIIF Blacklight (SolrDocument) extension
  # ===========================================================================

  public

  module IIIF::Extension

    include UVA
    include UVA::Util::Json
    include UVA::Util::RouteMethods
    include UVA::IIIF::Interface

    # Solr fields associated with this content type.
    SOLR_FIELDS = [
      :iiif_presentation_metadata_display,
      :alternate_id_facet,
      :individual_call_number_display,
      :rights_wrapper_url_display,
      :thumbnail_url_display
    ]

    # =========================================================================
    # :section:
    # =========================================================================

    public

    # Indicate whether the current document contains IIIF.
    #
    def is_iiif?
      true
    end

    # Metadata for display of IIIF images.
    #
    # @param [String] id              Defaults to `doc_id`.
    #
    # @return [Array<(String, nil)>]     Metadata with no issues reported.
    # @return [Array<(String, String)>]  Metadata and status message.
    # @return [Array<(nil,    String)>]  If IIIF is not present.
    #
    # == Implementation Notes
    # This method no longer returns status :ambiguous because it seemed like
    # this was coming up for everything, so there's no point in noting it in
    # the log file.
    #
    def iiif_metadata(id = nil)
      result = status = nil
      metadata = values_for(:iiif_presentation_metadata_display)
      if metadata.blank?
        status = :no_manifest
      else
        id ||= doc_id
        result =
          metadata.find do |m|
            (json = json_parse(m)) && json['@id'].to_s.end_with?(id)
          end
        # status = :ambiguous unless result
        result ||= metadata.first
      end
    rescue => e
      status = e.message
      result = nil
    ensure
      status = STATUS[status] if status.is_a?(Symbol)
      return result, status
    end

    # A document may have multiple visual representations using IIIF, most
    # commonly when there are multiple copies that have been digitized.  The
    # information about each copy is spread across the Solr document but this
    # method gathers it together into a reasonable array of hashes.
    #
    # @return [Array<Hash>]
    #
    def get_iiif_array

      (@iiif_array ||= nil) and return @iiif_array

      alternate_ids         = values_for(:alternate_id_facet)
      call_numbers          = values_for(:individual_call_number_display)
      rights_wrapper_url    = values_for(:rights_wrapper_url_display)
      thumbnail_url_display = values_for(:thumbnail_url_display)
      manifests             = values_for(:iiif_presentation_metadata_display)

      # Use alternate ids if present.
      index = -1
      @iiif_array =
        alternate_ids.map do |pid|
          index += 1
          iiif_array_entry(
            pid,
            manifests[index],
            thumbnail_url_display[index],
            rights_wrapper_url[index],
            call_numbers[index]
          )
        end

      # Otherwise use the document id.
      if @iiif_array.blank?
        @iiif_array <<
          iiif_array_entry(
            doc_id,
            manifests.first,
            thumbnail_url_display.first,
            rights_wrapper_url.first
          )
      end

    rescue => e
      Rails.logger.warn { "#{__method__}: #{e.message}" }
      @iiif_array = []

    ensure
      return @iiif_array
    end

    # =========================================================================
    # :section:
    # =========================================================================

    protected

    # iiif_array_entry
    #
    # @param [String]       pid
    # @param [String, Hash] manifest
    # @param [String, nil]  tn          Thumbnail; from *manifest* if missing.
    # @param [String, nil]  rw          Rights wrapper URL
    # @param [String, nil]  cn          Call number
    #
    # @return [Hash]
    #
    def iiif_array_entry(pid, manifest, tn = nil, rw = nil, cn = nil)
      manifest = json_parse(manifest) || {} unless manifest.is_a?(Hash)
      cid, ci  = get_start_canvas_id_and_index(manifest)
      {
        'pid'                => pid,
        'thumbnail'          => tn || manifest['thumbnail'],
        'rights_wrapper_url' => rw,
        'call_number'        => cn,
        'first_canvas_index' => ci,
        'first_canvas_id'    => cid,
        'manifest_uri'       => iiif_manifest_path(id: pid)
      }
    end

    # get_start_canvas_id_and_index
    #
    # @param [String, Hash] manifest
    #
    # @return [Array<(String, Integer)>, nil]
    #
    def get_start_canvas_id_and_index(manifest)
      manifest = json_parse(manifest) unless manifest.is_a?(Hash)
      sequence = manifest && manifest['sequences']
      sequence &&= sequence.first
      canvases = sequence && sequence['canvases']
      return unless canvases.present?
      start_id = sequence['startCanvas']
      if start_id.present?
        canvases.each_with_index do |canvas, index|
          return start_id, index if canvas['@id'] == start_id
        end
      end
      return canvases.first['@id'], 0
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
      Rails.logger.debug { "#{base}: included extension UVA::IIIF" }
    end

  end

end
