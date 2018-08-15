# app/views/catalog/index.rss.builder

# Overrides Blacklight app/views/catalog/index.rss.builder

xml.instruct! :xml, version: '1.0'
xml.rss(version: '2.0') {

  xml.channel {

    url = request.original_url.sub(%r{/?\.rss}, '')
    main_title =
      if video_home_page? || music_home_page?
        featured_title
      else
        catalog = params[:controller] || catalog_portal
        catalog = catalog.to_s.singularize.capitalize
        "#{catalog} Search Results"
      end
    description = CGI.unescape(url.to_s).presence
    description ||= 'from the University of Virginia Library'
    max_len = CONTEXT[:rss][:max_len] || 100

    xml.link(url)
    xml.title("Virgo #{main_title}")
    xml.description(description)

    (@featured_documents || @document_list || []).each do |doc|
      next unless doc
      link  = canonical_url(doc)
      title = doc.export_title
      title = '(no title)' if title.blank?
      summary = doc.get_abstract.first.presence
      summary &&= html_truncate(summary, length: max_len)
      fields = UVA::View::FieldSet.new(
        'JOURNAL'     => doc.export_is_part_of,
        'AUTHOR'      => doc.export_authors,
        'CALL NUMBER' => doc.export_call_numbers,
        'LOCATION'    => doc.values_for(:library_facet),
        SUMMARY:         summary,
      )
      xml.item do
        xml.link(link)
        xml.title(title)
        xml.description(fields.render(:rss, doc))
      end
    end

  }

}
