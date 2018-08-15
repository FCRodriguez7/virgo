# lib/uva/illiad/query.rb

require_relative 'openurl_fix'
require 'uva'

# Support for web access to ILLiad.
#
# === References
# For information on the web API functionality see the following:
# @see https://prometheus.atlas-sys.com/display/illiad/ILLiad+Web+DLL+Tags
# @see https://prometheus.atlas-sys.com/display/illiad/Customizing+the+Web+Interface
# @see https://www.oclc.org/developer/develop/web-services/worldcat-knowledge-base-api/openurl-resource.en.html
#
#--
# rubocop:disable Metrics/ModuleLength # [380/300]
#++
module UVA::Illiad

  include UVA

  FUTURE = false

  # ===========================================================================
  # :section:
  # ===========================================================================

  public

  # Generate a string which can be used as the part of the URL query specifying
  # the document whose attributes are used to fill in the ILLiad form.
  #
  # @param [Boolean]      openurl     Create OpenURL or standard ILLiad URL?
  # @param [SolrDocument] doc         Requested item.
  # @param [String]       sid         Session ID
  # @param [String]       referring_url Virgo item show page
  #
  # @return [String]                  The query portion of a URL.
  #
  # @raise [ArgumentError]            If document is *nil*.
  #
  #--
  # rubocop:disable Metrics/AbcSize # [180.9/45]
  # rubocop:disable Metrics/CyclomaticComplexity # [87/18]
  # rubocop:disable Metrics/PerceivedComplexity # [76/21]
  # rubocop:disable Metrics/MethodLength # [216/35]
  #++
  def create_query(openurl, doc, sid, referring_url = nil)

    # Validate arguments
    raise ArgumentError, 'missing "document" argument' if doc.nil?
    standard_url = !openurl

    # General properties acquired from the metadata of the requested item.
    # These are needed for most or all request types.
    title         = doc.basic_title
    author        = doc.show_heading_author
    date          = doc.export_pub_date
    edition       = doc.export_edition
    isbn          = doc.export_isbn
    issn          = doc.export_issn
    oclc          = doc.export_oclc
    place         = doc.export_publication_place
    publisher     = doc.export_publisher
    series        = doc.export_series

    # ILL_REQ_THESIS properties
    advisor       = nil
    cc            = nil
    co            = nil
    degree        = nil
    institution   = nil

    # ILL_REQ_PATENT properties
    applcc        = nil
    appldate      = nil
    applnumber    = nil
    applyear      = nil
    assignee      = nil
    kind          = nil
    number        = nil
    prioritydate  = nil
    pubdate       = nil

    # ILL_REQ_ARTICLE properties
    article_title = nil
    journal_title = nil
    issue         = nil
    pages         = nil
    start_page    = nil
    end_page      = nil
    volume        = nil
    month         = nil
    year          = date

    # ILL_REQ_BOOK_CHAPTER properties
    book_title    = nil
    chapter_title = nil
    total_pages   = nil

    # Other properties which are used to provide additional information for
    # processing the request and to include in the Notes query field to help
    # identify the requested item.
    ill_request, ill_format = ill_request_and_format(doc)
    formats      = doc.get_format
    call_numbers = doc.call_numbers

    # Adjust values based on the request type.  In general, this is for
    # future enhancement because these request types are not currently
    # generated from Virgo.
    case ill_request
      when ILL_REQ_THESIS
        institution = publisher
      when ILL_REQ_PATENT
        pubdate = date
        date    = nil # TODO: future enhancement
      when ILL_REQ_ARTICLE
        journal_title = series # TODO: future enhancement
        article_title = title
      else
        # In general, all other types are treated as loan requests
        book_title = title
    end

    # -------------------------------------------------------------------------
    # Generate the query in standard ILLiad format.
    # -------------------------------------------------------------------------

    query = ''

    if standard_url

      edition = ill_format if ill_request == ILL_REQ_AUDIO_VIDEO

      query << query_part('SID',                        sid)
      query << query_part('DocumentType',               ill_request)
      query << query_part('ISSN',                       isbn)
      query << query_part('ESPNumber',                  oclc)
      query << query_part('callnumber',                 call_numbers)
      query << query_part('LoanTitle',                  title)
      query << query_part('LoanAuthor',                 author)
      query << query_part('LoanPublisher',              publisher)
      query << query_part('LoanPlace',                  place)
      query << query_part('LoanDate',                   date)
      query << query_part('LoanEdition',                edition)
      query << query_part('PhotoArticleAuthor',         author)
      query << query_part('PhotoArticleTitle',          article_title)
      query << query_part('PhotoJournalVolume',         volume)
      query << query_part('PhotoJournalIssue',          issue)
      query << query_part('PhotoJournalMonth',          month)
      query << query_part('PhotoJournalYear',           year)
      query << query_part('PhotoJournalInclusivePages', pages)

      # NOTE - Without the following, the HSL ILLiad does not display the
      # "Leo/Ivy Request" page even though the action is CMD_REQUEST_LEO.
      query << query_part('genre', 'book')

      # -----------------------------------------------------------------------
      # Generate the query in OpenURL format.
      # -----------------------------------------------------------------------

    else # if use_openurl

      # Create the OpenURL context object that will be used to assemble the
      # information to be included in the query.
      ctx = OpenURL::ContextObject.new

      # Set the referrer to the SID.  This value is used by UVA ILL to
      # differentiate between Ivy Stacks and LEO delivery requests.
      if sid
        rfr = ctx.get_entity_obj('rfr')
        rfr.add_identifier("info:sid/#{sid}") if rfr
      end

      # Create the referring entity.
      if oclc
        rfe = ctx.get_entity_obj('rfe')
        rfe.set_private_data(oclc) if rfe
      end

      # Create the service type based on the requested item type.  In general,
      # except for scanning requests, the service being requested is a loan
      # (and LEO delivery) of the item.  Other OpenURL request types are listed
      # here for completeness but do not currently have any representation in
      # either of the UVA or HSL ILLiad systems.
      svc = ctx.get_entity_obj('svc')
      if svc
        case ill_request
          when ILL_REQ_ARTICLE, ILL_REQ_BOOK_CHAPTER
            svc.fulltext  = 'true'  # Request a scan of the item
          when 'RequestAbstract'
            svc.abstract  = 'true'  # Request an abstract for the item
          when 'RequestCitation'
            svc.citation  = 'true'  # Request a citation for the item
          when 'RequestHoldings'
            svc.holdings  = 'true'  # Request holding information for the item
          else
            svc.ill       = 'true'  # Request a loan of the item
        end
      end

      # Create the referent based on the requested item type.
      rft =
        case ill_request
          when ILL_REQ_ARTICLE then OpenURL::Journal.new
          when ILL_REQ_PATENT  then OpenURL::Patent.new
          when ILL_REQ_THESIS  then OpenURL::Dissertation.new
          else                      OpenURL::Book.new
        end
      rft.genre =
        case ill_request
          # Scanning requests
          when ILL_REQ_ARTICLE          then 'article'
          when ILL_REQ_BOOK_CHAPTER     then 'bookitem'
          # Loan requests
          when ILL_REQ_CONFERENCE_PAPER then 'proceeding'
          when ILL_REQ_REPORT           then 'report'
          else
            case ill_format
              when ILL_FMT_BOOK         then 'book'
              when ILL_FMT_BOUND_VOLUME then 'book'
              when ILL_FMT_GOVDOC       then 'report'
              else                           'document'
            end
        end
      rft.add_identifier(referring_url)
      ctx.referent = rft

      # Assign referent values based on the request type and the item being
      # requested.
      case ill_request
        when ILL_REQ_THESIS
          rft.title         = title         if title
          rft.date          = date          if date
          rft.isbn          = isbn          if isbn
          rft.tpages        = total_pages   if total_pages
          rft.advisor       = advisor       if advisor
          rft.cc            = cc            if cc
          rft.co            = co            if co
          rft.degree        = degree        if degree
          rft.inst          = institution   if institution

        when ILL_REQ_PATENT
          rft.title         = title         if title
          rft.date          = date          if date
          rft.applcc        = applcc        if applcc
          rft.appldate      = appldate      if appldate
          rft.applnumber    = applnumber    if applnumber
          rft.applyear      = applyear      if applyear
          rft.assignee      = assignee      if assignee
          rft.cc            = cc            if cc
          rft.co            = co            if co
          rft.kind          = kind          if kind
          rft.number        = number        if number
          rft.prioritydate  = prioritydate  if prioritydate
          rft.pubdate       = pubdate       if pubdate

        when ILL_REQ_ARTICLE
          rft.atitle        = article_title if article_title
          rft.jtitle        = journal_title if journal_title
          rft.au            = author        if author
          rft.date          = date          if date
          rft.issn          = issn          if issn
          rft.issue         = issue         if issue
          rft.pages         = pages         if pages
          rft.spage         = start_page    if start_page
          rft.epage         = end_page      if end_page
          rft.volume        = volume        if volume

        when ILL_REQ_BOOK_CHAPTER
          rft.atitle        = chapter_title if chapter_title
          rft.btitle        = book_title    if book_title
          rft.au            = author        if author
          rft.date          = date          if date
          rft.edition       = edition       if edition
          rft.isbn          = isbn          if isbn
          rft.place         = place         if place
          rft.pub           = publisher     if publisher
          rft.tpages        = total_pages   if total_pages
          rft.series        = series        if series
          rft.pages         = pages         if pages
          rft.spage         = start_page    if start_page
          rft.epage         = end_page      if end_page

        else # Loan requests
          rft.btitle        = book_title    if book_title
          rft.au            = author        if author
          rft.date          = date          if date
          rft.edition       = edition       if edition
          rft.isbn          = isbn          if isbn
          rft.place         = place         if place
          rft.pub           = publisher     if publisher
          rft.tpages        = total_pages   if total_pages
          rft.series        = series        if series
      end

      # Emit the OpenURL query.
      query << ctx.kev

    end

    # Include optional query arguments to specify conditions placed on the
    # request.
    query << not_wanted_after   if FUTURE # Reserved for future use
    query << non_english        if FUTURE # Reserved for future use
    query << alternate_edition  if FUTURE # Reserved for future use

    # Append a query argument to pre-fill the Notes field with information
    # intended to help identify the requested item (as a stopgap pending future
    # enhancements to the ILLiad forms).
    #
    # This is a multi-line field on the HSL ILLiad page, but a single line
    # field on the UVA ILLiad page - hence the extra spaces/pipe symbols to
    # separate the information items.
    note_parts = {
      nil           => '<< Replace this with volume/copy info if needed >>',
      'FORMAT'      => formats,
      'CALL NUMBER' => call_numbers,
      'VIRGO URL'   => referring_url
    }
    notes =
      note_parts.map { |label, value|
        next if value.blank?
        label += 'S' if label && value.is_a?(Array) && (value.size > 1)
        [label, value].compact.join(' - ')
      }.compact.join(" \n| ")
    query << query_part('Notes', notes)

    # Return the complete query string.
    query

    # rubocop:enable Metrics/AbcSize
    # rubocop:enable Metrics/CyclomaticComplexity
    # rubocop:enable Metrics/PerceivedComplexity
    # rubocop:enable Metrics/MethodLength
  end

  # Generate a string to be used as one element of a URL query.
  #
  # @param [String] field             Query field.
  # @param [Object] value             Query field value.
  # @param [String] separator         Query separator (or none if nil).
  #
  # @return [String]                  "&field=value" or empty string.
  #
  # @raise [ArgumentError]            If field is missing or blank.
  #
  # @example
  #   query_part('field1',  ' value1 ')   #=>   '&field1=value1'
  #   query_part('field2',  '<value2>')   #=>   '&field2=%3Cvalue2%3E'
  #   query_part('&field3', 'value3')     #=>   '&field3=value3'
  #
  def query_part(field, value, separator = QUERY_SEPARATOR)

    # Validate arguments
    raise ArgumentError, 'missing "field" argument' if field.nil?
    field = field.to_s.strip
    raise ArgumentError, 'empty "field" argument' if field.empty?
    value = value.to_s.strip

    # Return "&field=value" only if a value was provided.
    result = ''
    if value.present?
      result << separator if separator && !field.start_with?(separator)
      result << "#{field}=#{CGI.escape(value)}"
    end
    result

  end

  # ===========================================================================
  # :section:
  # ===========================================================================

  protected

  # Use the format facets from provided SolrDocument to determine the ILL
  # request type and ILL format of the item.
  #
  # Note that for a given Virgo item, the set of format facets may be rather
  # ambiguous because it can include all of the formats of all of the
  # individual copies for a given item.  Future enhancements should include ILL
  # requests on specific instances, in which case this method will need to be
  # changed to deal with the specific format of that specific instance.
  #
  # @param [SolrDocument] doc         Requested item.
  #
  # @return [Array<(String,String)>]  ILL request type; ILL format
  #
  #--
  # rubocop:disable Metrics/MethodLength # [39/35]
  #++
  def ill_request_and_format(doc)
    result = []
    provisional_result = [] # Until a more definitive format is encountered
    doc.get_format.each do |format|
      case format
        when 'Video', 'Music Recording', 'Sound Recording'
          provisional_result = [ILL_REQ_AUDIO_VIDEO, ILL_FMT_ANY]
        when 'CD'
          result = [ILL_REQ_AUDIO_VIDEO, ILL_FMT_CD]
        when 'LP'
          result = [ILL_REQ_AUDIO_VIDEO, ILL_FMT_LP]
        when 'DVD'
          result = [ILL_REQ_AUDIO_VIDEO, ILL_FMT_DVD]
        when 'Blu-Ray'
          result = [ILL_REQ_AUDIO_VIDEO, ILL_FMT_BLURAY]
        when 'VHS'
          result = [ILL_REQ_AUDIO_VIDEO, ILL_FMT_VHS]
        when 'Laserdisc'
          result = [ILL_REQ_AUDIO_VIDEO, ILL_FMT_LASERDISC]
        when 'Journal/Magazine'
          result = [ILL_REQ_GENERIC, ILL_FMT_BOUND_VOLUME]
        when 'Thesis/Dissertation'
          result = [ILL_REQ_GENERIC, ILL_FMT_DISSERTATION]
        when 'Newspaper'
          result = [ILL_REQ_GENERIC, ILL_FMT_NEWSPAPER]
        when 'Microform'
          result = [ILL_REQ_GENERIC, ILL_FMT_MICROFORM]
        when 'Government Document'
          result = [ILL_REQ_GENERIC, ILL_FMT_GOVDOC]
        when 'Musical Score'
          result = [ILL_REQ_GENERIC, ILL_FMT_SCORE]
        else
          provisional_result[0] = ILL_REQ_GENERIC if provisional_result.empty?
          provisional_result[1] = format
      end
      break unless result.empty?
    end
    result = provisional_result if result.empty?
    result = [ILL_REQ_GENERIC, ILL_FMT_BOOK] if result.empty?
    result
    # rubocop:enable Metrics/MethodLength
  end

  # ===========================================================================
  # :section: Request modifiers
  #
  # NOTE: These are not currently used but are provided as a starting point if
  # the Virgo ILL interface is expanded to replace interaction with the ILLiad
  # request forms.
  # ===========================================================================

  protected

  # Generate a query section to specify a date after which the request is
  # invalid.
  #
  # @param [Date] req_end_date        Request end date.
  #
  # @return [String]                  Query part for *NotWantedAfter*.
  #
  def not_wanted_after(req_end_date = nil)
    req_end_date ||= Time.zone.today + 1.month
    query_part('NotWantedAfter', req_end_date.strftime('%m/%d/%Y'))
  end

  # Generate a query section to specify whether a non-English item can be
  # provided to satisfy the request.
  #
  # @param [Boolean] accepted         If nil or false, specify English-only.
  #
  # @return [String]                  Query part for *AcceptNonEnglish*.
  #
  def non_english(accepted = false)
    query_part('AcceptNonEnglish', (accepted ? 'Yes' : 'No'))
  end

  # Generate a query section to specify whether a non-English item can be
  # provided to satisfy the request.
  #
  # @param [Boolean] accepted         If nil or false, specified edition only
  #
  # @return [String]                  Query part for AcceptAlternateEdition.
  #
  def alternate_edition(accepted = true)
    query_part('AcceptAlternateEdition', (accepted ? 'Yes' : 'No'))
  end

  # rubocop:enable Metrics/ModuleLength
end
