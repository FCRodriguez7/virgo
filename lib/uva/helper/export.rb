# lib/uva/helper/export.rb

require 'uva'

module UVA::Helper

  # UVA::Helper::Export
  #
  module Export

    require 'csv'

    include UVA
    include UVA::Xml
    include UVA::Helper::Layout

    # =========================================================================
    # :section: JSON
    # =========================================================================

    public

    # Return valid XML even if the response is *nil*.
    #
    # @param [Object]    response
    # @param [Hash, nil] opt
    #
    # @option opt [Boolean] :recursive    Forces #as_xml even if *response* has
    #                                       #to_xml.
    #
    # @return [String]
    #
    def xml_response(response, opt = nil)
      response ||= {}
      opt      ||= {}
      if !opt.delete(:recursive) && response.respond_to?(:to_xml)
        response.to_xml(opt)
      else
        opt[:root] ||= 'response'
        as_xml(response).to_xml(opt)
      end
    end

    # If the current set of params contains :jsonp then the function name (i.e.
    # string) defined there is used as a wrapping function call for the JSON
    # response.
    #
    # @param [String] response
    #
    # @return [String]
    #
    # @see ArticlesController#index
    # @see CatalogController#index
    # @see CatalogController#show
    # @see ShelfBrowseController#index
    # @see ShelfBrowseController#show
    #
    def json_response(response)
      response ||= {}
      result   = response.to_json
      callback = params[:jsonp].presence
      callback ? "#{callback}(#{result});" : result
    rescue => e
      Rails.logger.info { "ERROR in #{__method__}: #{e} #{e.message}" }
      return response
    end

    # =========================================================================
    # :section: Display
    # =========================================================================

    public

    # Embed OpenURL metadata in COinS.
    #
    # (Zotero scans the page for COinS to extract bibliographic metadata.)
    #
    # @param [UVA::IndexDoc] doc
    #
    # @return [ActiveSupport::SafeBuffer]
    #
    # === References
    # @see https://archive.is/dGBd
    # @see https://en.wikipedia.org/wiki/COinS
    #
    # === Implementation Notes
    # The current (Blacklight) implementation of #export_as_openurl_ctx_kev can
    # only work with MARC metadata.  Until there is a replacement method, this
    # method will return *nil* if `doc.has_marc?` is *false*.
    #
    def embed_coins(doc)
      ctx = doc && doc.has_marc? && doc.export_as_openurl_ctx_kev
      return if ctx.blank?
      ctx << '&amp;rtf_id=' << CGI.escape(canonical_url(doc))
      # Insert an HTML comment to ensure that the element is not empty.
      content_tag(:span, class: 'Z3988', title: ctx.html_safe) do
        '<!-- COinS -->'.html_safe
      end
    end

    # Export to RefWorks URL.
    # (Called in _show_tools)
    #
    # @param [String] id
    #
    # @return [String]
    #
    # Compare with:
    # @see Blacklight::CatalogHelperBehavior#refworks_export_url
    #
    def refworks_catalog_export_url(id = nil)
      base_url = 'https://www.refworks.com/express/expressimport.asp'
      url_query = [
        "vendor=#{application_name}",
        'filter=RefWorks%20Tagged%20Format',
      ]
      if id
        url = catalog_path(id, format: 'refworks_marc_text', only_path: false)
        url_query << "url=#{url_encode(url)}"
      end
      base_url + '?' + url_query.join('&')
    end

    # =========================================================================
    # :section: Actions
    # =========================================================================

    public

    # Handles EndNote generation for multiple documents.
    #
    # @param [Array<UVA::IndexDoc>] documents
    #
    # @return [String]
    #
    # Compare with:
    # @see Blacklight::BlacklightHelperBehavior#render_endnote_texts
    #
    def render_endnote_texts(documents)
      documents.map { |doc|
        url = canonical_url(doc)
        doc.export_as_endnote(url)
      }.join(NEWLINE + NEWLINE)
    end

    # Handles RefWorks generation for multiple documents.
    #
    # @param [Array<UVA::IndexDoc>] documents
    #
    # @return [String]
    #
    # Compare with:
    # @see Blacklight::BlacklightHelperBehavior#render_refworks_texts
    #
    def render_refworks_texts(documents)
      documents.map { |doc|
        url = canonical_url(doc)
        doc.export_as_refworks(url)
      }.join(NEWLINE + NEWLINE)
    end

    # Generates text for a collection of documents into one RIS export string.
    #
    # @param [Array<UVA::IndexDoc>] documents
    #
    # @return [String]
    #
    def render_ris_texts(documents)
      documents.map { |doc|
        url = canonical_url(doc)
        doc.export_as_ris(url)
      }.join(NEWLINE + NEWLINE)
    end

    # Make a CSV string out of a list of documents.
    #
    # @param [Array<UVA::IndexDoc>] documents
    #
    # @return [String]
    #
    # === Implementation Notes
    # Microsoft Excel seems to prefer "CSV" files with fields separated by the
    # pipe symbol ('|') rather than commas.  It will automatically transform
    # the pipe-separated fields into a spreadsheet, but requires manual
    # intervention with comma-separated fields.
    #
    def render_csv(documents)
      CSV.generate(col_sep: '|') { |csv|
        csv << %w(ITEM_ID ITEM_FORMAT ITEM_TITLE ITEM_AUTHOR)
        documents.each do |doc|
          format = doc.export_format
          title  = doc.export_title
          author = doc.export_authors
          csv << [doc.doc_id, format, title, author]
        end
      }
    end

    # Run from the export format template to ensure that the result is
    # downloaded with a somewhat meaningful name with the proper extension.
    #
    # @param [UVA::IndexDoc, Array<UVA::IndexDoc>] documents
    # @param [Symbol, String]                      format
    # @param [Boolean]                             download
    #
    def set_output_filename(documents, format = nil, download = true)
      doc  = documents.respond_to?(:first) ? documents.first : documents
      name = doc.respond_to?(:doc_id) ? doc.doc_id : 'empty'
      ext  = format.to_s.presence || 'txt'
      hdr  = ''
      hdr << 'attachment; ' if download
      hdr << %Q(filename="#{name}.#{ext}")
      headers['Content-Disposition'] = hdr
    end

  end

end
