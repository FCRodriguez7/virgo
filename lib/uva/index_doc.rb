# lib/uva/index_doc.rb

require 'pp'
require 'uva'

module UVA

  # This module defines interface methods that are expected for any object that
  # is manageable as an "indexable document" (that is, to be part of search
  # results, to be displayable in item details show pages, etc.).
  #
  # The primary basis for this is SolrDocument (and the definitions on which
  # it relies - Blacklight::Solr::Document, RSolr::Ext::Model) and also
  # UVA::ArticleDoc (the common basis for UVA::Article::Ebsco::Document and
  # other classes related to external article search providers).
  #
  # === Usage Notes
  # Place "include UVA::IndexDoc" after all other includes that implement the
  # methods defined here.  This strategy makes it possible to support
  # "abstract" methods by making the default implementation in this module
  # raise an exception, ensuring that the method definition is overridden.
  #
  # === Implementation Notes
  # As a matter of course, the interface methods are defined with arbitrary
  # arguments like:
  #
  #   def method_name(*)
  #   end
  #
  # This allows subclasses to extend the definition with arguments as
  # appropriate.
  #
  # There is one significant caveat to the object-oriented design pattern: it
  # eliminates "duck-typing".  That is, #respond_to? can't be used as a way to
  # differentiate between classes derived from IndexDoc -- all instances of
  # derivatives of IndexDoc will respond to all methods defined on IndexDoc,
  # whether they provide their own implementation or not.
  #
  module IndexDoc

    include UVA

    # The list of extensions.  Each symbol here relates to a file in this
    # directory containing a module which will be included in the module which
    # includes IndexDoc::Base.
    #
    # For example the presence of :Ead in this list indicates that there is a
    # file 'lib/uva/ead.rb' which contains module 'UVA::Ead::Interface'.
    #
    EXTENSIONS = {
      DigitalImage: 'uva/index_doc/digital_image',
      Ead:          'uva/index_doc/ead',
      ICPSR:        'uva/index_doc/icpsr',
      IIIF:         'uva/index_doc/iiif',
      PBCore:       'uva/index_doc/pbcore',
      Tei:          'uva/index_doc/tei',
    }

    # =========================================================================
    # :section: Module methods
    # =========================================================================

    public

    # When a document class includes UVA::IndexDoc, this method is triggered to
    # load all of the extensions and include their base interface definitions
    # into the document.
    #
    # @param [Module] base            The including module or class.
    #
    # @return [void]
    #
    def self.included(base) # :nodoc:
      EXTENSIONS.each_pair do |ext_name, ext_file|
        require(ext_file)
        extension = "UVA::#{ext_name}".constantize
        next if base.include?(extension)
        base.send(:include, extension)
      end
    end

  end

  # ===========================================================================
  # :section:
  # ===========================================================================

  public

  # Fallback definitions for lower-level IndexDoc interface methods.
  #
  # === Usage Notes
  # Place "include UVA::IndexDoc::Base" before all other includes that
  # implement the methods defined here.  In the general case, this does not
  # need to be explicitly included -- it's done implicitly when including
  # UVA::IndexDoc.  It needs to be done explicitly when creating a class based
  # on Blacklight (e.g. SolrDocument) so that the default method
  # implementations defined here are properly overridden by the Blacklight
  # definitions.
  #
  module IndexDoc::Base

    include UVA
    include UVA::Util::Dev

    Debug.setup(
      active:            Virgo.desktop_development?,
      :[] =>             false,
      export_formats:    false,
      to_marc:           false,
      export_as_marc:    true,
      export_as_marcxml: true,
    )

    # Hints for RubyMine (skipped during execution).
    include Blacklight::Solr::Document unless ONLY_FOR_DOCUMENTATION

    # =========================================================================
    # :section: RSolr::Ext::Model interface
    # =========================================================================

    public

    # Gets an array of values for the given metadata field.
    #
    # @deprecated Use self#values_for instead.
    #
    # For Virgo development, #values_for should be used instead of this method.
    # However, this method needs to be defined to allow index documents derived
    # from UVA::IndexDoc to work within Blacklight in the same way that
    # SolrDocuments do.
    #
    # @param [Symbol] field
    #
    # @return [Array<String>]         For a field defined to be multi-valued
    #                                   (even if it happens to have only one
    #                                   value).
    # @return [String]                For a single-valued field (e.g. the Solr
    #                                   fields :id and :marc_display).
    # @return [nil]                   If the metadata field is not present.
    #
    # Compare with:
    # @see Mash#[]
    #
    # === Implementation Notes
    # Note that there is no Blacklight::Solr::Document#[] -- this functionality
    # is supplied by way of RSolr::Ext::Model#method_missing to access the hash
    # of Solr field values directly.
    #
    def [](field, *)
      Debug.show(__method__) { ":#{field} (IndexDoc::Base)" }
      return if field.blank?
      field = field.to_sym
      if self.class.method_defined?(field)
        self.class.instance_method(field).bind(self).call
      elsif self.class.instance_variables.include?(field)
        self.class.instance_variable_get(field)
      end
    end

    # Gets the value of the given metadata field.
    #
    # @note Defined for compatibility.
    # @deprecated Use #values_for instead.
    #
    # @param [Symbol] field
    # @param [Hash]   opt
    #
    # @option opt [String]                :sep
    # @option opt [String, Array<String>] :default
    #
    # @return [Array<String>]         For a field defined to be multi-valued
    #                                   (even if it happens to have only one
    #                                   value).
    # @return [String]                For a single-valued field (e.g. the Solr
    #                                   fields :id and :marc_display).
    # @return [nil]                   If the metadata field is not present.
    #
    # Compare with:
    # @see RSolr::Ext::Doc#get
    #
    def get(field, opt = nil)
      Debug.show(__method__) { ":#{field} (IndexDoc::Base)" }
      default_opt = { sep: LIST_SEPARATOR, default: nil }
      opt = opt.is_a?(Hash) ? default_opt.merge(opt) : default_opt
      result = self[field]
      if result.blank?
        opt[:default]
      elsif result.is_a?(Array) && opt[:sep]
        result.join(opt[:sep])
      else
        result
      end
    end

    # =========================================================================
    # :section: Blacklight::Solr::Document interface
    # =========================================================================

    public

    # The version of Blacklight currently in use has some bogus code in
    # #will_export_as which for some reason is now starting to get triggered
    # (maybe timing related?), so I'm overriding with the most recent
    # definition.
    #
    # @param [Symbol, String] short_name
    # @param [String]         content_type
    #
    # @see Blacklight::Solr::Document#will_export_as
    #
    def will_export_as(short_name, content_type = nil)
      symbol = short_name.to_sym
      if Mime[symbol]
        content_type ||= Mime[symbol]
      else
        Mime::Type.register(content_type, symbol)
      end
      export_formats[symbol] = { content_type: content_type }
    end

    # @see UVA::IndexDoc#export_formats
    #
    # @return [Hash{Symbol=>String}]
    #
    def export_formats(*)
      Debug.show(__method__) { '(IndexDoc::Base)' }
      @export_formats ||= {}
    end

    # =========================================================================
    # :section: Blacklight::Solr::Document::Marc interface
    # =========================================================================

    public

    # @see UVA::IndexDoc#to_marc
    #
    # @return [MARC::Record]
    # @return [nil]
    #
    def to_marc(*)
      Debug.show(__method__) { '(IndexDoc::Base)' }
    end

    # =========================================================================
    # :section: Blacklight::Solr::Document::MarcExport interface
    # =========================================================================

    public

    # @see UVA::IndexDoc#export_as_marc
    #
    # @return [MARC::Record]
    # @return [nil]
    #
    def export_as_marc(*)
      Debug.show(__method__) { '(IndexDoc::Base)' }
    end

    # @see UVA::IndexDoc#export_as_marcxml
    #
    # @return [String]
    # @return [nil]
    #
    def export_as_marcxml(*)
      Debug.show(__method__) { '(IndexDoc::Base)' }
    end

    # @see Blacklight::Solr::Document::MarcExport#export_as_xml
    #
    # @return [String]
    #
    def export_as_xml(*)
      to_xml
    end

    # @see UVA::IndexDoc#export_as_apa_citation_txt
    #
    # @return [String]
    #
    def export_as_apa_citation_txt(*)
    end

    # @see UVA::IndexDoc#export_as_mla_citation_txt
    #
    # @return [String]
    #
    def export_as_mla_citation_txt(*)
    end

    # @see UVA::IndexDoc#export_as_chicago_citation_txt
    #
    # @return [String]
    #
    def export_as_chicago_citation_txt(*)
    end

    # @see UVA::IndexDoc#export_as_openurl_ctx_kev
    #
    # @return [String]
    #
    def export_as_openurl_ctx_kev(*)
    end

    # @see UVA::IndexDoc#export_as_refworks_marc_txt
    #
    # @return [String]
    #
    def export_as_refworks_marc_txt(*)
    end

    # =========================================================================
    # :section: Blacklight::Solr::Document::MarcExport interface
    # =========================================================================

    protected

    # @see UVA::IndexDoc#get_author_list
    #
    # @return [Array<String>]
    #
    def get_author_list(*)
      get_authors
    end

    # =========================================================================
    # :section: Citation Export
    # =========================================================================

    public

    # @see UVA::IndexDoc#export_as_endnote
    #
    # @return [String]
    #
    def export_as_endnote(*)
    end

  end

  # ===========================================================================
  # :section:
  # ===========================================================================

  public

  module IndexDoc

    include ActionView::Helpers::TagHelper
    include ActionView::Helpers::UrlHelper

    # If this has been included previously, it will not be included now.
    include UVA::IndexDoc::Base

    include UVA::Util::DateMethods
    include UVA::Util::HtmlMethods
    include UVA::Util::Dev

    Debug.setup(
      active:             Virgo.desktop_development?,
      :[] =>              false,
      get_author_list:    false,
      id:                 false,
      :has? =>            false,
      get:                false,
      export_formats:     false,
      to_marc:            false,
      export_as_marc:     false,
      export_as_marcxml:  false,
      values_for:         false,
      get_meta_tags:      false,
    )

    # A table of default options for each kind of metadata.
    #
    DEFAULT = {

      # === Title components
      title:                  { separator: ITEM_SEPARATOR },
      subtitle:               { separator: ITEM_SEPARATOR },  # no get_* method
      part:                   { separator: LIST_SEPARATOR },  # no get_* method
      medium:                 { separator: LIST_SEPARATOR },  # no get_* method
      date_coverage:          { separator: ITEM_SEPARATOR },  # no get_* method
      date_bulk_coverage:     { separator: ITEM_SEPARATOR },  # no get_* method
      form:                   { separator: ITEM_SEPARATOR },  # no get_* method

      # === Identifiers
      isbns:                  { separator: LIST_SEPARATOR },  # no get_* method
      oclcs:                  { separator: LIST_SEPARATOR },  # no get_* method
      ocns:                   { separator: LIST_SEPARATOR },  # no get_* method
      lccns:                  { separator: LIST_SEPARATOR },  # no get_* method
      upcs:                   { separator: LIST_SEPARATOR },  # no get_* method
      issns:                  { separator: LIST_SEPARATOR },  # no get_* method
      dois:                   { separator: LIST_SEPARATOR },  # no get_* method

      # === Bibliographic information
      format:                 { separator: ITEM_SEPARATOR },  # no base method
      work_type:              { separator: ITEM_SEPARATOR },  # no base method
      edition:                { separator: LIST_SEPARATOR },  # no base method
      edition_statement:      { separator: INLINE_BREAK },    # no base method
      pub_year:               { separator: LIST_SEPARATOR },
      pub_date:               { separator: ITEM_SEPARATOR },
      pub_statement:          { separator: INLINE_BREAK },    # no base method
      publisher:              { separator: ITEM_SEPARATOR },  # no base method
      publication_place:      { separator: ITEM_SEPARATOR },  # no base method
      uniform_title:          { separator: ITEM_SEPARATOR },  # no base method
      series:                 { separator: ITEM_SEPARATOR },  # no base method
      series_statement:       { separator: INLINE_BREAK },    # no base method
      collection:             { separator: ITEM_SEPARATOR },  # no base method
      author:                 { separator: ITEM_SEPARATOR },  # no base method
      authors:                { separator: ITEM_SEPARATOR },  # no base method
      advisors:               { separator: ITEM_SEPARATOR },  # no base method
      directors:              { separator: ITEM_SEPARATOR },  # no base method
      language:               { separator: LIST_SEPARATOR },  # no base method
      physical_description:   { separator: SPACE },           # no base method
      technical_details:      { separator: INLINE_BREAK },    # no base method
      recording_information:  { separator: PART_DIVIDER },    # no base method
      target_audience:        { separator: ITEM_SEPARATOR },  # no base method
      performers:             { separator: ITEM_SEPARATOR },  # no base method
      credits:                { separator: ITEM_SEPARATOR },  # no base method
      plot_summary:           { separator: ITEM_SEPARATOR },  # no base method
      contents:               { separator: INLINE_BREAK },    # no base method
      dissertation_note:      { separator: ITEM_SEPARATOR },  # no base method
      cite_as:                { separator: INLINE_BREAK },
      keywords:               { separator: ITEM_SEPARATOR },  # no base method
      subjects:               { separator: ITEM_SEPARATOR },  # no base method
      place_names:            { separator: ITEM_SEPARATOR },  # no base method
      related_names:          { separator: ITEM_SEPARATOR },  # no base method
      description:            { separator: ITEM_SEPARATOR },  # no base method
      abstract:               { separator: INLINE_BREAK },    # no base method
      notes:                  { separator: INLINE_BREAK },    # no base method

      # === Identifiers
      isbn:                   { separator: LIST_SEPARATOR },  # no base method
      oclc:                   { separator: LIST_SEPARATOR },  # no base method
      ocn:                    { separator: LIST_SEPARATOR },  # no base method
      lccn:                   { separator: LIST_SEPARATOR },  # no base method
      upc:                    { separator: LIST_SEPARATOR },  # no base method
      issn:                   { separator: LIST_SEPARATOR },  # no base method
      doi:                    { separator: LIST_SEPARATOR },  # no base method
      standard_identifiers:   { separator: LIST_SEPARATOR },  # no base method
      url:                    { separator: ITEM_SEPARATOR },  # no base method
      url_links:              { separator: ITEM_SEPARATOR },  # no base method
      supplemental_url_links: { separator: ITEM_SEPARATOR },  # no base method
      media_retrieval_id:     { separator: LIST_SEPARATOR },  # no base method
      call_numbers:           { separator: ITEM_SEPARATOR },
      shelf_numbers:          { separator: ITEM_SEPARATOR },

      # === Articles
      type:                   { separator: ITEM_SEPARATOR },
      is_part_of:             { separator: ITEM_SEPARATOR },
      journal:                { separator: ITEM_SEPARATOR },
      volume:                 { separator: LIST_SEPARATOR },
      issue:                  { separator: LIST_SEPARATOR },
      start_page:             { separator: LIST_SEPARATOR },
      end_page:               { separator: LIST_SEPARATOR },
      pages:                  { separator: LIST_SEPARATOR },
      accession_number:       { separator: ITEM_SEPARATOR },
      identifiers:            { separator: ITEM_SEPARATOR },

    }.deep_freeze

    # Hints for RubyMine (skipped during execution).
    unless ONLY_FOR_DOCUMENTATION
      include Blacklight::Solr::Document::MarcExport
    end

    # =========================================================================
    # :section: RSolr::Ext::Model interface
    # =========================================================================

    public

    # @see UVA::IndexDoc::Base#[]
    #
    # @deprecated Use self#values_for instead.
    #
    # @param [Symbol] field
    #
    # @return [Array<String>]
    # @return [String]
    # @return [nil]
    #
    def [](field, *)
      Debug.show(__method__) { ":#{field} - [IndexDoc OVERRIDE calls super]" }
      super
    end

    # A unique identifier for this document.
    #
    # @return [String]
    #
    # Compare with:
    # @see RSolr::Ext::Doc#id
    #
    # === Implementation Notes
    # The including class must provide its own definition of this method.
    # (Otherwise this fall-back method will @raise [NoMethodError].)
    #
    def id(*)
      Debug.show(__method__) { '[IndexDoc OVERRIDE calls super]' }
      super
    end

    # Override of the RSolr::Ext helper method for checking if value(s) exist
    # for a given key.
    #
    # The method returns the first element of *values* which matches one of the
    # metadata value(s) specified by *field*.
    #
    # @param [Symbol]               field
    # @param [Array<String,Regexp>] values
    #
    # Compare with:
    # @see RSolr::Ext::Doc#has?
    #
    # === Implementation Notes
    # This RSolr method has never worked as described for the case of checking
    # multiple values because it would terminate with the first one (whether it
    # matched or not).
    #
    # This implementation maintains the semantics where "doc.has?(:key)" will
    # return *true* if :key is an existing field even if it is empty (however
    # if it exists and has a *nil* value the method will return *false*).  If
    # *values* are given and the field contains one of them, the matching value
    # will be returned.
    #
    def has?(field, *values)
      Debug.show(__method__) { ":#{field} (IndexDoc)" }
      target = self[field]
      values.compact!
      if target.nil?
        false
      elsif values.empty?
        true
      elsif target.is_a?(Array)
        values.find do |v|
          target.any? { |tgt| v.is_a?(Regexp) ? (tgt =~ v) : (tgt == v) }
        end
      else
        values.find do |v|
          v.is_a?(Regexp) ? (target =~ v) : (target == v)
        end
      end
    end

    # @see UVA::IndexDoc::Base#get
    #
    # @note Defined for compatibility.
    # @deprecated Use self#values_for instead.
    #
    # @param [Symbol] field
    # @param [Hash]   opt
    #
    # @return [Array<String>]
    # @return [String]
    # @return [nil]
    #
    def get(field, opt = nil)
      Debug.show(__method__) { ":#{field} - [IndexDoc OVERRIDE calls super]" }
      super
    end

    # =======================================================================
    # :section: Blacklight::Solr::Document interface
    # =======================================================================

    public

    # A mapping of formats to MIME types.
    #
    # @return [Hash{Symbol=>String}]
    #
    # @see Blacklight::Solr::Document#export_formats
    #
    def export_formats(*)
      Debug.show(__method__) { '[IndexDoc OVERRIDE calls super]' }
      super
    end

    # Invoke an export method identified symbolically.
    #
    # @param [Symbol] export_format
    # @param [Array]  args
    #
    # @return [String]
    #
    # Compare with:
    # @see Blacklight::Solr::Document#export_as
    #
    # === Implementation Notes
    # This method overrides the Blacklight implementation to allow passing
    # additional parameters.
    #
    def export_as(export_format, *args)
      send("export_as_#{export_format}".to_sym, *args)
    end

    # =========================================================================
    # :section: Blacklight::Solr::Document::Marc interface
    # =========================================================================

    public

    # Get the metadata for this document as a MARC record.
    #
    # @return [MARC::Record]          If the item has MARC metadata.
    # @return [nil]                   Otherwise.
    #
    # @see Blacklight::Solr::Document::Marc#to_marc
    #
    def to_marc(*)
      Debug.show(__method__) { '[IndexDoc OVERRIDE calls super]' }
      super
    end

    # =========================================================================
    # :section: Blacklight::Solr::Document::MarcExport interface
    # =========================================================================

    public

    # Get this document in MARC format.
    #
    # @return [MARC::Record]          If the item has MARC metadata.
    # @return [nil]                   Otherwise.
    #
    # @see Blacklight::Solr::Document::MarcExport#export_as_marc
    #
    def export_as_marc(*)
      Debug.show(__method__) { '[IndexDoc OVERRIDE calls super]' }
      super
    end

    # Get this document in MARCXML format.
    #
    # @return [String]                If the item has MARC metadata.
    # @return [nil]                   Otherwise.
    #
    # @see Blacklight::Solr::Document::MarcExport#export_as_marcxml
    #
    def export_as_marcxml(*)
      Debug.show(__method__) { '[IndexDoc OVERRIDE calls super]' }
      super
    end

    # @see Blacklight::Solr::Document::MarcExport#export_as_xml
    #
    # @return [String]
    #
    def export_as_xml(*)
      if has_marc?
        export_as_marcxml
      else
        to_xml
      end
    end

    # Get the APA bibliographic citation for this document.
    #
    # @deprecated Use {#apa_citation} directly.
    #
    # @param [String] url             If provided, this is the URL for the item
    #                                   to be used in place of the result from
    #                                   #export_url.
    # @return [String]
    #
    # Replaces:
    # @see Blacklight::Solr::Document::MarcExport#export_as_apa_citation_txt
    #
    # @see self#apa_citation
    #
    def export_as_apa_citation_txt(url = nil, *)
      apa_citation(url)
    end

    # Get the MLA bibliographic citation for this document.
    #
    # @deprecated Use {#mla_citation} directly.
    #
    # @param [String] url             If provided, this is the URL for the item
    #                                   to be used in place of the result from
    #                                   #export_url.
    # @return [String]
    #
    # Replaces:
    # @see Blacklight::Solr::Document::MarcExport#export_as_mla_citation_txt
    #
    # @see self#mla_citation
    #
    def export_as_mla_citation_txt(url = nil, *)
      mla_citation(url)
    end

    # Get the Chicago Manual of Style bibliographic citation for this document.
    #
    # @param [String] url             If provided, this is the URL for the item
    #                                   to be used in place of the result from
    #                                   #export_url.
    # @return [String]
    #
    # @see Blacklight::Solr::Document::MarcExport#export_as_chicago_citation_txt
    #
    def export_as_chicago_citation_txt(url = nil, *)
      chicago_citation(url)
    end

    # Export this document as in OpenURL format.
    #
    # @return [String]
    #
    # @see Blacklight::Solr::Document::MarcExport#export_as_openurl_ctx_kev
    #
    # === Implementation Notes
    # Our primary application for OpenURL is in generating ILLiad requests for
    # LEO delivery (and related ILL functions).  That work was based on the
    # 'openurl' gem, and if there was a use-case for a more generalized OpenURL
    # implementation via this method then it should probably use the work in
    # @see UVA::Illiad#query as starting point, then UVA::Illiad should be
    # refactored to make use of this method.
    #
    # TODO: Implement locally to support articles as well as MARC records.
    #
    def export_as_openurl_ctx_kev(format = nil, *)
      Debug.show(__method__) { '[IndexDoc OVERRIDE calls super]' }
      format ||= get_format.first
      super(format)
    end

    # Get the metadata for this document in RefWorks import format.
    #
    # @note Defined for compatibility.
    # @deprecated Use #export_as_refworks instead.
    #
    # @return [String]
    #
    # @see Blacklight::Solr::Document::MarcExport#export_as_refworks_marc_txt
    #
    def export_as_refworks_marc_txt(*)
      Debug.show(__method__) { '[IndexDoc OVERRIDE calls super]' }
      super
    end

    # =========================================================================
    # :section: Blacklight::Solr::Document::MarcExport interface
    #
    # These methods are protected in MarcExport but they are made public here
    # because they can be called directly for any object derived from IndexDoc.
    # =========================================================================

    public

    # Get the Chicago Manual of Style bibliographic citation for this document.
    #
    # @param [String] url             If provided, this is the URL for the item
    #                                   to be used in place of the result from
    #                                   #export_url.
    # @param [Array]  args
    #
    # @return [String]
    #
    # Replaces:
    # @see Blacklight::Solr::Document::MarcExport#chicago_citation
    #
    # === References
    # @see https://owl.english.purdue.edu/owl/resource/717/01/
    #
    def chicago_citation(url = nil, *args)

      # If a citation has been specified, use that rather than constructing a
      # citation from metadata.
      result = cite_as
      return result if result
      result = ''

      # === Options
      # Strip leading "http://" or "https://" from the URL.  (DOI should retain
      # its "doi:" prefix.)
      opt = args.last.is_a?(Hash) ? args.last : {}
      opt[:strip_protocol] = true

      # Determine type of formatting required.
      is_article = (doc_type == :article)

      # Get data values first.
      authors   = get_author_list
      title     = setup_title_info
      editors   = nil # TODO: Journal editors as opposed to book editors
      journal   = export_journal
      volume    = setup_volume(true)
      issue     = setup_issue(true)
      pages     = setup_pages(true)
      edition   = setup_edition
      publisher = setup_pub_info
      date      = setup_pub_date
      link      = setup_link(url, opt)
      an        = is_article ? nil : accession_number

      # Make adjustments if necessary
      date = nil if an

      # === Author(s)
      # First author in "Last, First" form; second author in "First Last" form;
      # three or more authors shown as the first author followed by ", et al.".
      # If the author is the same as the publisher, skip the author.
      eds   = []
      comps = []
      trans = []
      get_related_names(false).each do |name_and_role|
        name_and_role = name_and_role.to_s
        if (name = name_and_role.sub!(/\W+Editor\W*$/i, ''))
          eds   << name
        elsif (name = name_and_role.sub!(/\W+Compiler\W*$/i, ''))
          comps << name
        elsif (name = name_and_role.sub!(/\W+Translator\W*$/i, ''))
          trans << name
        end
      end
      authors.delete_if do |v|
        (v == publisher) || comps.include?(v) || trans.include?(v)
      end
      if authors.present?
        result << cmos_names(authors, true)
        if (authors - eds).empty?
          eds = []
          result << ', ed'
          result << 's' if authors.size > 1
        elsif (authors - comps).empty?
          comps = []
          result << ', comp'
          result << 's' if authors.size > 1
        elsif (authors - trans).empty?
          trans = []
          result << ', trans'
        end
        result << '.'
      end

      # === Item Title
      # Titles of larger works (books, journals, etc) are italicized; title of
      # shorter works (poems, articles, etc) are in quotes.  If the article
      # title contains double quotes, convert them to single quotes before
      # wrapping the title in double quotes.
      if title.present?
        result << SPACE unless result.blank?
        title = mla_citation_title(title)
        if is_article
          title.gsub!(/[#{DQUOTE}\p{Pi}\p{Pf}]/u, SQUOTE)
          result << %Q("#{title}.")
        else
          result << "<em>#{title}</em>."
        end
      end

      # === Editors, Compilers, or Translators
      actors = { 'Edited' => eds, 'Compiled' => comps, 'Translated' => trans }
      actors.each_pair do |action, names|
        next unless names.present?
        result << SPACE unless result.blank? || result.end_with?(SPACE)
        result << action << ' by ' << cmos_names(names) << '.'
      end

      # === Container Title
      if journal.present?
        result << SPACE unless result.blank? || result.end_with?(SPACE)
        journal = mla_citation_title(journal)
        result << "<em>#{journal}</em>"
      end

      # === Version/Edition
      if edition.present?
        unless result.blank?
          result << ','   unless result.end_with?(SPACE, '.', ',')
          result << SPACE unless result.end_with?(SPACE)
        end
        result << clean_end_punctuation(edition)
      end

      # === Container Editors
      if editors.present?
        unless result.blank?
          result << ','   unless result.end_with?(SPACE, '.', ',')
          result << SPACE unless result.end_with?(SPACE)
        end
        editors = cmos_names(editors)
        result << clean_end_punctuation(editors)
      end

      # === Accession Number (for archival collections)
      if an.present?
        unless result.blank?
          result << ','   unless result.end_with?(SPACE, '.', ',')
          result << SPACE unless result.end_with?(SPACE)
        end
        result << an
      end

      # === Volume
      if volume.present?
        unless result.blank?
          result << ','   unless result.end_with?(SPACE, '.', ',')
          result << SPACE unless result.end_with?(SPACE)
        end
        result << volume
      end

      # === Issue
      if issue.present?
        unless result.blank?
          result << ','   unless result.end_with?(SPACE, '.', ',')
          result << SPACE unless result.end_with?(SPACE)
        end
        result << issue
      end

      # === Publisher
      if publisher.present?
        unless result.blank?
          result << '.'   unless result.end_with?(SPACE, '.', ',')
          result << SPACE unless result.end_with?(SPACE)
        end
        result << publisher
      end

      # === Date of publication
      # Should be "YYYY" for a book; "[Day] Mon. YYYY" for an article.
      if date.present?
        date_string = export_date(date, month_names: true)
        year, month, day = (date_string || date).split('/')
        month = "#{month[0,3]}." if month && (month.size > 3)
        if year && month && day && is_article
          date = "#{day} #{month} #{year}"
        elsif year && month && is_article
          date = "#{year}, #{month}"
        elsif year
          date = year.sub(/^(\d{4}).*$/, '\1')
        end
        unless result.blank?
          result << ','   unless result.end_with?(SPACE, '.', ',')
          result << SPACE unless result.end_with?(SPACE)
        end
        result << date
      end

      # === Pages
      if pages.present?
        unless result.blank?
          result << ','   if result =~ /\d$/
          result << ':'   unless result.end_with?(SPACE, '.', ',', ':')
          result << SPACE unless result.end_with?(SPACE)
        end
        result << pages
      end

      # === URL/DOI
      if link.present?
        unless result.blank?
          result << ','   unless result.end_with?(SPACE, '.', ',')
          result << SPACE unless result.end_with?(SPACE)
        end
        result << link
      end

      # The end of the citation should be a period.
      result << '.' unless result.end_with?('.')

      result
    end

    # Get the MLA bibliographic citation for this document.
    #
    # @param [String] url             If provided, this is the URL for the item
    #                                   to be used in place of the result from
    #                                   #export_url.
    # @param [Array]  args
    #
    # @return [String]
    #
    # Replaces:
    # @see Blacklight::Solr::Document::MarcExport#mla_citation
    #
    # === References
    # @see https://owl.english.purdue.edu/owl/resource/747/01/
    # @see https://owl.english.purdue.edu/owl/resource/747/06/
    #
    # === Notes
    # @note The general form of MLA citations:
    #
    #   Author. Title_of_source. Title_of_container, Other_contributors,
    #     Version, Number, Publisher, Date, Location.
    #
    # * Author.
    # * Title of source.
    # * Title of container (journal/newspaper/anthology),
    # * Other contributors (translators/editors),
    # * Version (edition),
    # * Number (vol. and/or no.),
    # * Publisher (for non-periodicals),
    # * Publication date (periodicals-"Day Month Year"/otherwise-"Year"),
    # * Location (pages/paragraphs/URL/DOI).
    #
    # === Implementation Notes
    # Although the original Blacklight method is for MARC-based items only,
    # this method can be used with any type of item.
    #
    # The related Blacklight method is intended to be used as a module method
    # and expects "record" to provide the metadata for the citation; this
    # method is written as an instance method which accesses the metadata of
    # the instance directly.
    #
    def mla_citation(url = nil, *args)

      # If a citation has been specified, use that rather than constructing a
      # citation from metadata.
      result = cite_as
      return result if result
      result = ''

      # === Options
      # Strip leading "http://" or "https://" from the URL.  (DOI should retain
      # its "doi:" prefix.)
      opt = args.last.is_a?(Hash) ? args.last : {}
      opt[:strip_protocol] = true

      # Determine type of formatting required.
      is_article = (doc_type == :article)

      # Get data values first.
      authors   = get_author_list
      title     = setup_title_info
      editors   = nil # TODO: Journal editors as opposed to book editors
      journal   = export_journal
      volume    = setup_volume(true)
      issue     = setup_issue(true)
      pages     = setup_pages(true)
      edition   = setup_edition
      publisher = clean_end_punctuation(export_publisher)
      date      = setup_pub_date
      link      = setup_link(url, opt)
      an        = is_article ? nil : accession_number

      # Make adjustments if necessary
      date = nil if an

      # === Author(s)
      # First author in "Last, First" form; second author in "First Last" form;
      # three or more authors shown as the first author followed by ", et al.".
      # If the author is the same as the publisher, skip the author.
      authors.delete_if { |v| v == publisher }
      if authors.present?
        total = authors.size
        list  = capitalize(authors.first.dup)
        if total > 2
          list << ', et al'
        elsif total > 1
          list << ', and ' << name_reverse(authors.last)
        end
        result << clean_end_punctuation(list)
        # Indicate if the "authors" are actually editors of the work.
        eds =
          get_related_names(false).map { |name_and_role|
            name_and_role.to_s.sub!(/\W+Editor\W*$/i, '')
          }.reject(&:blank?)
        if (authors - eds).empty?
          result << '.' if total > 2
          result << ', editor'
          result << 's' if total > 1
        end
        result << '.'
      end

      # === Item Title
      # Titles of larger works (books, journals, etc) are italicized; title of
      # shorter works (poems, articles, etc) are in quotes.  If the article
      # title contains double quotes, convert them to single quotes before
      # wrapping the title in double quotes.
      if title.present?
        result << SPACE unless result.blank?
        title = mla_citation_title(title)
        if is_article
          title.gsub!(/[#{DQUOTE}\p{Pi}\p{Pf}]/u, SQUOTE)
          result << "\"#{title}.\""
        else
          result << "<em>#{title}</em>."
        end
      end

      # === Container Title
      if journal.present?
        result << SPACE unless result.blank? || result.end_with?(SPACE)
        journal = mla_citation_title(journal)
        result << "<em>#{journal}</em>"
      end

      # === Version/Edition
      if edition.present?
        unless result.blank?
          result << ','   unless result.end_with?(SPACE, '.', ',')
          result << SPACE unless result.end_with?(SPACE)
        end
        result << clean_end_punctuation(edition)
      end

      # === Container Editors
      if editors.present?
        unless result.blank?
          result << ','   unless result.end_with?(SPACE, '.', ',')
          result << SPACE unless result.end_with?(SPACE)
        end
        total = editors.size
        list  = editors.first.dup
        if total > 2
          list << ', et al.'
        elsif total > 1
          list << ', and ' << name_reverse(editors.last)
        end
        result << clean_end_punctuation(list)
      end

      # === Accession Number (for archival collections)
      if an.present?
        unless result.blank?
          result << ','   unless result.end_with?(SPACE, '.', ',')
          result << SPACE unless result.end_with?(SPACE)
        end
        result << an
      end

      # === Publisher
      if publisher.present?
        unless result.blank?
          result << ','   unless result.end_with?(SPACE, '.', ',')
          result << SPACE unless result.end_with?(SPACE)
        end
        result << publisher
      end

      # === Volume
      if volume.present?
        unless result.blank?
          result << ','   unless result.end_with?(SPACE, '.', ',')
          result << SPACE unless result.end_with?(SPACE)
        end
        result << volume
      end

      # === Issue
      if issue.present?
        unless result.blank?
          result << ','   unless result.end_with?(SPACE, '.', ',')
          result << SPACE unless result.end_with?(SPACE)
        end
        result << issue
      end

      # === Date of publication
      # Should be "YYYY" for a book; "[Day] Mon. YYYY" for an article.
      if date.present?
        date_string = export_date(date, month_names: true)
        year, month, day = (date_string || date).split('/')
        month = "#{month[0,3]}." if month && (month.size > 3)
        if year && month && day && is_article
          date = "#{day} #{month} #{year}"
        elsif year && month && is_article
          date = "#{year}, #{month}"
        elsif year
          date = year.sub(/^(\d{4}).*$/, '\1')
        end
        unless result.blank?
          result << ','   unless result.end_with?(SPACE, '.', ',')
          result << SPACE unless result.end_with?(SPACE)
        end
        result << date
      end

      # === Pages
      if pages.present?
        unless result.blank?
          result << ','   unless result.end_with?(SPACE, '.', ',')
          result << SPACE unless result.end_with?(SPACE)
        end
        result << pages
      end

      # === URL/DOI
      if link.present?
        unless result.blank?
          result << ','   unless result.end_with?(SPACE, '.', ',')
          result << SPACE unless result.end_with?(SPACE)
        end
        result << link
      end

      # The end of the citation should be a period.
      result << '.' unless result.end_with?('.')

      result
    end

    # Get the APA bibliographic citation for this document.
    #
    # @param [String] url             If provided, this is the URL for the item
    #                                   to be used in place of the result from
    #                                   #export_url.
    # @param [Array]  args
    #
    # @return [String]
    #
    # Replaces:
    # @see Blacklight::Solr::Document::MarcExport#apa_citation
    #
    # === References
    # @see https://owl.english.purdue.edu/owl/resource/560/05/
    #
    # === Notes
    # @note APA citations for books:
    #
    #   Author. (Year). Title: Subtitle. Publication_location: Publisher.
    #
    # @note APA citations for articles:
    #
    #   Author. (Year). Title_of_article. Title_of_periodical, volume(issue),
    #     pages.  URL
    #
    # === Implementation Notes
    # Although the original Blacklight method is for MARC-based items only,
    # this method can be used with any type of item.
    #
    # The related Blacklight method is intended to be used as a module method
    # and expects "record" to provide the metadata for the citation; this
    # method is written as an instance method which accesses the metadata of
    # the instance directly.
    #
    def apa_citation(url = nil, *args)

      # If a citation has been specified, use that rather than constructing a
      # citation from metadata.
      result = cite_as
      return result if result
      result = ''

      # === Options
      opt = (args.last if args.last.is_a?(Hash))

      # Determine type of formatting required.
      is_article = (doc_type == :article)
      add_pp     = (doc_sub_type == :newspaper_article) # TODO

      # Get data values first.
      authors   = get_author_list
      title     = setup_title_info
      editors   = nil # TODO: Journal editors as opposed to book editors
      journal   = export_journal
      volume    = setup_volume
      issue     = setup_issue
      pages     = setup_pages(add_pp)
      edition   = setup_edition
      publisher = setup_pub_info
      date      = setup_pub_date
      link      = setup_link(url, opt)
      an        = is_article ? nil : accession_number

      # Make adjustments if necessary
      date = nil if an

      # === Author(s)
      # No more than seven names are listed in "Last, F. M." form.  If there
      # are between 2 and 7 total authors they are listed separated by commas
      # with '& ' before the last one.  If there are more than 7 authors, only
      # the first 6 are listed separated by commas, then an ellipsis (...)
      # followed by the final author.
      if authors.present?
        list = authors.map { |name| abbreviate_name(name) }
        total_authors = list.size
        final_author  = list.pop
        result <<
          case total_authors
            when 1    then final_author
            when 2..7 then list.join(', ') + ', &amp; ' + final_author
            else           list[0,6].join(', ') + ', ... ' + final_author
          end
        # Indicate if the "authors" are actually editors of the work.
        eds =
          get_related_names(false).map { |name_and_role|
            name_and_role.to_s.sub!(/\W+Editor\W*$/i, '')
          }.reject(&:blank?)
        if (authors - eds).empty?
          s = ('s' if total_authors > 1)
          result << " (Ed#{s}.)."
        end
      end

      # === Date of publication
      # Should be "(YYYY)" for a book; "(YYYY, Month [Day])" for an article.
      if date.blank?
        result << '.'   unless result.blank? || result.end_with?('.')
      else
        result << SPACE unless result.blank? || result.end_with?(SPACE)
        date_string = export_date(date, month_names: true)
        year, month, day = (date_string || date).split('/')
        if year && month && day && is_article
          date = "#{year}, #{month} #{day}"
        elsif year && month && is_article
          date = "#{year}, #{month}"
        elsif year
          date = year.sub(/^(\d{4}).*$/, '\1')
        end
        result << "(#{date})."
      end

      # === Item Title
      # The title is in sentence-case (only the first word and proper nouns
      # are capitalized); if there is a sub-title, it also has the first word
      # capitalized followed by lower-case words.
      if title.present?
        result << SPACE unless result.blank? || result.end_with?(SPACE)
        title = clean_end_punctuation(title)
        result << (is_article ? title : "<em>#{title}</em>")
      end

      # === Container Editors
      if editors.present?
        unless result.blank?
          result << '.'   unless result.end_with?('.')
          result << SPACE unless result.end_with?(SPACE)
        end
        list = editors.map { |name| abbreviate_name(name) }
        total_editors = list.size
        final_editor  = list.pop
        result <<
          case total_editors
            when 1    then final_editor
            when 2..7 then list.join(', ') + ', &amp; ' + final_editor
            else           list[0,6].join(', ') + ', ... ' + final_editor
          end
      end

      # === Container Title
      # Journal titles are capitalized like MLA titles.
      if journal.present?
        unless result.blank?
          result << '.'   unless result.end_with?(SPACE, '.', ',')
          result << SPACE unless result.end_with?(SPACE)
        end
        journal = mla_citation_title(journal)
        result << "<em>#{journal}</em>"
      end

      # === Version/Edition
      if edition.present?
        result << SPACE unless result.blank? || result.end_with?(SPACE)
        edition = clean_end_punctuation(edition)
        result << "(#{edition})."
      elsif journal.blank?
        result << '.' unless result.end_with?('.')
      end

      # === Volume
      if volume.present?
        unless result.blank?
          result << ','   unless result.end_with?(SPACE, '.', ',')
          result << SPACE unless result.end_with?(SPACE)
        end
        result << clean_end_punctuation(volume)
      end

      # === Issue
      if issue.present?
        if volume.blank?
          result << SPACE unless result.blank? || result.end_with?(SPACE)
        end
        issue = clean_end_punctuation(issue)
        result << "(#{issue})"
      end

      # === Pages
      # For articles, pages do not include "p." or "pp." *except* for articles
      # in a newspaper.
      if pages.present?
        unless result.blank?
          result << ','   unless result.end_with?(SPACE, '.', ',')
          result << SPACE unless result.end_with?(SPACE)
        end
        result << pages
      end

      # === Accession Number (for archival collections)
      if an.present?
        unless result.blank?
          result << ','   unless result.end_with?(SPACE, '.', ',')
          result << SPACE unless result.end_with?(SPACE)
        end
        result << an
      end

      # === Publisher
      if publisher.present?
        unless result.blank?
          result << ','   unless result.end_with?(SPACE, '.', ',')
          result << SPACE unless result.end_with?(SPACE)
        end
        result << publisher
        result << '.'
      end

      # The end of the citation proper should be a period.
      result << '.' unless result.blank? || result.end_with?('.')

      # === URL/DOI
      if link.present?
        result << SPACE unless result.blank? || result.end_with?(SPACE)
        result << 'Retrieved from '
        result << link
      end

      result
    end

    # =========================================================================
    # :section: Blacklight::Solr::Document::MarcExport interface
    #
    # These are methods which override protected MarcExport methods.
    # =========================================================================

    protected

    # Format a title for use in an MLA citation.
    #
    # All words other than connector words are capitalized.  If the title ends
    # with a period, the period is removed so that the caller as control over
    # where the period is added back in.  Other terminal punctuation
    # (including "...") is left untouched.
    #
    # @param [String] title_text
    #
    # @return [String]
    #
    # Replaces:
    # @see Blacklight::Solr::Document::MarcExport#mla_citation_title
    #
    # TODO: Implement using UVA::Utils::StringMethods#titleize
    #
    def mla_citation_title(title_text, *)
      no_upcase = %w(a an and but by for it of the to with)
      words = title_text.to_s.strip.split(SPACE)
      words.map { |w|
        no_upcase.include?(w) ? w : capitalize(w)
      }.join(SPACE).sub(/(?<!\.\.)\.$/, '')
    end

    # Get the title of this document for use in citations.
    #
    # @return [String]
    # @return [nil]
    #
    # Replaces:
    # @see Blacklight::Solr::Document::MarcExport#setup_title_info
    #
    def setup_title_info(*)
      basic_title
    end

    # Get the publication date of this document for use in citations.
    #
    # @return [String]
    # @return [nil]
    #
    # Replaces:
    # @see Blacklight::Solr::Document::MarcExport#setup_pub_date
    #
    def setup_pub_date(*)
      clean_end_punctuation(get_pub_date(true).first)
    end

    # Get the publisher of this document for use in citations.
    #
    # @return [String]
    # @return [nil]
    #
    # Replaces:
    # @see Blacklight::Solr::Document::MarcExport#setup_pub_info
    #
    def setup_pub_info(*)
      place = clean_end_punctuation(get_publication_place.first)
      name  = clean_end_punctuation(get_publisher.first)
      if place.present? && name.present?
        if name.include?(place)
          place = nil
        elsif place.include?(name)
          name = nil
        end
      end
      [place, name].reject(&:blank?).join(': ')
    end

    # Get the publication edition of this document for use in citations.
    #
    # @return [String]
    # @return [nil]
    #
    # Replaces:
    # @see Blacklight::Solr::Document::MarcExport#setup_edition
    #
    def setup_edition(*)
      result = clean_end_punctuation(get_edition.first)
      return if result.blank?
      case result.downcase
        when /^1st/, /^first/
          # First editions do not need to be indicated.
          nil
        when / eds?\.$/, / eds?\. /
          # The result already appears to be in the right form.
          result
        when / ed[[:punct:]]*$/, / edition[[:punct:]]*$/
          result.sub($LAST_MATCH_INFO.regexp, ' ed.')
        else
          result + ' ed.'
      end
    end

    # Transforms the form "last_name[, first_name [middle_names][, suffix]"
    # into the form "last_name[, initials][, suffix]".
    #
    # For now it's assumed that if a name has parentheses then it's probably a
    # corporate name that can't be "abbreviated" in this way.  Names like this
    # are returned unmodified.
    #
    # @param [String] name
    #
    # @return [String]
    #
    # Replaces:
    # @see Blacklight::Solr::Document::MarcExport#abbreviate_name
    #
    def abbreviate_name(name, *)
      name = name.to_s.squish
      return name if name.blank?

      # Assuming this is a corporate name.
      return name if name.include?('(') || name.include?(')')

      # If there are no commas then assume this a corporate name or a person
      # with only one name (e.g. "Christo", "Michelangelo").  Remove date(s)
      # from the end if the name includes them.
      parts  = name.split(',').map(&:strip).reject(&:blank?)
      result = parts.shift.to_s
      parts.pop if parts.last =~ /\d{4}/

      # The rest of the parts (first name and/or middle name(s)) are turned
      # into initials.  However, suffixes remain untouched:
      # (1) Roman numerals (e.g. "Henry VIII")
      # (2) Suffix         (e.g. "Martin Luther King, Jr.")
      if parts.present?
        result << ', '
        result <<
          parts.map { |part|
            part.split(SPACE).map { |s|
              next if LOWERCASE_WORDS.include?(s)
              keep = s.include?('.')
              keep ||= (s =~ /^([IX][IVX]*|VI*)$/i)   # (1)
              keep ||= NAME_SUFFIX_WORDS.include?(s)  # (2)
              keep ? s : "#{s[0]}."
            }.compact.join(SPACE)
          }.join(', ')
      end

      capitalize(result)
    end

    # Transforms the form "last_name, first_name [middle_names][, suffix]"
    # into the form "first_name [middle_names] last_name[, suffix]".  If the
    # name could not be reversed, the original name is returned.
    #
    # The method is somewhat poorly-named because the intent is really to
    # restore the reading order of a name that is in bibliographic order.
    #
    # @param [String] name
    #
    # @return [String]
    #
    # Replaces:
    # @see Blacklight::Solr::Document::MarcExport#name_reverse
    #
    # === Usage Notes
    # If *name* is in bibliographic order, make sure that the surname is
    # capitalized appropriately.  E.g., if *name* is "De la Croix, Jean" then
    # the result will be "Jean De la Croix", whereas "de la Croix, Jean" will
    # result in "Jean de la Croix".
    #
    def name_reverse(name, *)
      name = name.to_s.squish
      return name if name.blank?

      # Assuming this is a corporate name that should not be reversed.
      return name if name.include?('(') || name.include?(')')

      # Remove suffix(es) from the end; these will stay at the end of the name
      # even after the other parts are reordered.
      comma_parts  = name.split(',').map(&:strip).reject(&:blank?)
      suffix_parts = []
      while NAME_SUFFIX_WORDS.include?(comma_parts.last)
        suffix_parts.unshift(comma_parts.pop)
      end
      suffixes = (', ' << suffix_parts.join(', ') unless suffix_parts.empty?)

      # If the remaining name has two or more comma-separated parts then assume
      # it was in bibliographic order.  Otherwise, extract the last name parts,
      # leaving behind the given name(s).
      if comma_parts.size > 1
        last_name   = comma_parts.shift
        other_names = comma_parts.join(', ').presence
      else
        name_parts  = comma_parts.first.split(' ')
        last_name   = extract_last_name!(name_parts)
        other_names = name_parts.join(' ').presence
      end
      other_names << ' ' if other_names

      # Return with the names in reading order.
      "#{other_names}#{last_name}#{suffixes}"
    end

    # Remove surrounding pairs of parentheses or brackets trailing spaces and
    # punctuation from a string.
    #
    # @param [String] text
    #
    # @return [String]
    #
    # Replaces:
    # @see Blacklight::Solr::Document::MarcExport#clean_end_punctuation
    #
    def clean_end_punctuation(text, *)
      strip_brackets(text.to_s.sub(FIELD_END, ''))
    end

    # Get all personal/corporate authors of this document for use in citations.
    #
    # @return [Array<String>]
    #
    # @see Blacklight::Solr::Document::MarcExport#get_author_list
    #
    def get_author_list(*)
      Debug.show(__method__) { '[IndexDoc OVERRIDE calls super]' }
      super
    end

    # =========================================================================
    # :section: Blacklight::Solr::Document::MarcExport extensions
    # =========================================================================

    protected

    # Remove the elements from the end of *name_parts* which appear to be a
    # last name, accounting for multi-part names like "de la Croix" or
    # "v. Ribbentrop".
    #
    # @param [Array<String>] name_parts   Array to be modified.
    #
    # @return [String]
    #
    # === Implementation Notes
    # It is assumed that the full name represented by *name_parts* is comprised
    # of zero or more "given" names and a surname which may begin with zero or
    # more lowercase words (like "de" or "la") followed by one or more surnames
    # (or ordinal designations like "VIII") which each begin with a capital
    # (although the surnames themselves may contain spaces).
    #
    def extract_last_name!(name_parts)
      surname   = name_parts.pop
      lowercase = /^\p{Lower}+([\s.-]\p{Lower})*$/u
      if name_parts.any? { |part| part =~ lowercase }
        result = [surname]
        result.unshift(name_parts.pop) while name_parts.last !~ lowercase
        result.unshift(name_parts.pop) while name_parts.last =~ lowercase
        result.join(' ')
      else
        surname
      end
    end

    # Transforms "first_name [middle_names] last_name[, suffix]" into the form
    # "last_name, first_name [middle_names][, suffix]".
    #
    # (This is essentially the opposite of self#name_reverse.)
    #
    # @param [String] name
    #
    # @return [String]
    #
    # === Usage Notes
    # Because this method preserves the case of the names, the result may not
    # begin with a capital letter, e.g. "de la Croix, Jean".
    #
    def bib_order(name, *)
      name = name.to_s.squish
      return name if name.blank?

      # Remove suffix(es) from the end; these will stay at the end of the name
      # even after the other parts are reordered.
      comma_parts  = name.split(', ')
      suffix_parts = []
      while NAME_SUFFIX_WORDS.include?(comma_parts.last)
        suffix_parts.unshift(comma_parts.pop)
      end

      # If two or more comma-separated parts remain then assume that the name
      # was already in bibliographic order.  If there were nothing but suffixes
      # (and *comma_parts* is now empty), give up and return the name as-is.
      return name unless comma_parts.size == 1

      # Extract the last name parts, leaving behind the given name(s).
      name_parts  = comma_parts.first.split(' ')
      last_name   = extract_last_name!(name_parts)
      other_names = name_parts.join(' ').presence

      # Return with the last name, given name(s), and any suffixes.
      ([last_name, other_names] + suffix_parts).compact.join(', ')
    end

    # Format a list of names for Chicago Manual of Style citations.
    #
    # @param [Array<String>] names    One or more personal or corporate names.
    # @param [Boolean]       authors  Treat as author names if *true*.
    #
    # @return [String]
    #
    # === Usage Notes
    # For author citations use `cmos_names(src, true)` to emit the first listed
    # name in bibliographic order (with the surname first).  Otherwise all
    # names are emitted in reading order (with the surname last).
    #
    def cmos_names(names, authors = false)
      total  = names.size
      et_al  = (total > 10)
      names  = et_al ? names.take(7) : names.dup
      first  = names.shift
      result = authors ? capitalize(first.dup) : name_reverse(first)
      if names.present?
        names.map! { |n| name_reverse(n) }
        final = et_al ? 'et al' : "and #{names.pop}"
        result << ', ' << names.join(', ') unless names.blank?
        result << ' ' << final
      end
      clean_end_punctuation(result)
    end

    # Get the volume number of the journal containing the item for use in
    # citations.
    #
    # @return [String]
    # @return [nil]
    #
    def setup_volume(add_prefix = false, *)
      result = export_volume
      return if result.blank?
      result = clean_end_punctuation(result)
      result = "vol. #{result}" if add_prefix && (result !~ /^vol/i)
      result
    end

    # Get the issue number of the journal containing the item for use in
    # citations.
    #
    # @return [String]
    # @return [nil]
    #
    def setup_issue(add_prefix = false, *)
      result = export_issue
      return if result.blank?
      result = clean_end_punctuation(result)
      result = "no. #{result}" if add_prefix && (result !~ /^(n[ou]|is)/i)
      result
    end

    # Get the page(s) for the item for use in citations.
    #
    # @param [Boolean] add_prefix     If true, prefix a single page number with
    #                                   "p." or a range of page numbers with
    #                                   "pp.".
    #
    # @return [String]
    # @return [nil]
    #
    def setup_pages(add_prefix = false, *)
      result = export_pages
      return if result.blank?
      result = result.gsub(/p{1,2}\.\s+/, '')
      if add_prefix
        prefix = result.include?('-') ? 'pp.' : 'p.'
        "#{prefix} #{result}"
      else
        result
      end
    end

    # Get the link (DOI or URL) for the item for use in citations.
    #
    # DOI is preferred; if present it is converted into URL form.
    #
    # NOTE: Because the OpenURL link for articles is sort of ugly, this method
    # will return *nil* for articles unless they have a DOI.
    #
    # @param [String,Boolean] url     If set (not *nil* or *false*) then return
    #                                   a link even if the item is not an
    #                                   exclusively online item.  If a String,
    #                                   then also use that value in place of
    #                                   the result from #export_url.
    # @param [Array]  args
    #
    # @return [String]
    # @return [nil]
    #
    def setup_link(url = nil, *args)
      # Supply/override *url* as needed.
      if (doi = dois.first.presence)
        # Prefer DOI if it's directly available.
        url = 'https://doi.org/' + doi.sub(/^doi:/, '')
      elsif (u = get_url.first) && (u =~ %r{^https?://(\w+\.)?doi\.org/})
        # Prefer DOI if it's present indirectly -- even if a *url* parameter
        # was provided.
        url = u
      elsif url.blank? && !born_digital?
        # Only show a link if this is an electronic item.
        return
      end

      # Only show a URL if this is an electronic item.
      return if url.blank? || !born_digital?

      # Create the URL as a link unless the context requires simple text.
      opt = args.last.is_a?(Hash) ? args.last.dup : {}
      result  = opt.delete(:strip_protocol) ? url.sub(%r{^\w+://}, '') : url
      context = opt.delete(:context)
      if context && ![:email, :export].include?(context)
        link_to(result, url, opt)
      else
        result
      end
    end

    # =========================================================================
    # :section: Document properties (core)
    # =========================================================================

    public

    # A unique identifier for this document.
    #
    # @return [String]
    #
    def doc_id(*)
      @id ||= id
    end

    # Indicate what kind of document this is.
    #
    # @return [Symbol]
    #
    def doc_type(*)
      :default
    end

    # Indicate the sub-type of this document, which can be used for variations
    # in behavior for items with the same #doc_id.
    #
    # @return [Symbol]
    #
    def doc_sub_type(*)
      :default
    end

    # The Virgo catalog number (Sirsi catkey) for this document.
    #
    # @return [String]
    # @return [nil]
    #
    def ckey(*)
    end

    # The Fedora repository identifier associated with this document.
    #
    # @return [String]
    # @return [nil]
    #
    def fedora_doc_id(*)
    end

    # =========================================================================
    # :section: Document methods (core)
    # =========================================================================

    public

    # Access to the MARC data for this document (if any).
    #
    # @return [UVA::Marc::Record]
    # @return [nil]                     If the document does not have MARC.
    #
    def marc_display(*)
    end

    # Indicate whether this document has an associated MARC record.
    #
    def has_marc?(*)
    end

    # Indicate whether this document has any of the named feature(s).
    #
    # @param [Array<String, Array<String>>] *
    #
    # @return [String]                  The first matching feature.
    # @return [nil]                     If none of *features* were found.
    #
    def has_feature?(*)
    end

    # Indicate whether the content associated with this document is available
    # in an online form.
    def online?(*)
    end

    # Indicate whether the content associated with this document is only
    # available to the user in an online form.
    #
    # If the document represents an item that could circulate (e.g. a book)
    # then this method will return *false*.
    #
    def online_only?(*)
    end

    # Indicate whether this document represents a catalog item that is only
    # available online through the Internet.
    #
    def internet_only?(*)
    end

    # Indicate whether this document is a journal or other serial.
    #
    def journal?(*)
    end

    # Indicate whether this document is a Congressional Hearings item.
    #
    def congressional_hearings?(*)
    end

    # Indicate whether this document is a government document.
    #
    def government_document?(*)
    end

    # Indicate whether this document has online content which did not have an
    # original form that was published through print media.
    #
    # For citation purposes, a born-digital item includes a "Retrieved from"
    # notation.
    #
    def born_digital?(*)
      # TODO: Verify this definition...
      online_only? && isbns.blank? && issns.blank?
    end

    # Indicate whether this document is associated with item(s) that may be
    # managed alongside bibliographic items (e.g. physical items that can be
    # "checked out" via the OPAC like headphones, laptops, etc.).
    #
    def non_bibliographic?(*)
    end

    # Indicate whether this document is associated with physical holdings
    # (specifically, that could be displayed in the table of holdings in the
    # Availability box on the item details show page).
    #
    def non_physical?
      true
    end

    # Indicate whether this document contains (or is contained within) a
    # hierarchy.
    #
    def hierarchical?(*)
    end

    # Indicate whether this document is held in a UVa Library repository.
    #
    def uva_content?(*)
    end

    # Indicate whether this document is associated with a catalog item that has
    # only Semester-At-Sea holdings.
    #
    def sas_only?(*)
    end

    # Indicate whether this document is shadowed (that is, not viewable and
    # not discoverable).
    #
    def hidden?(*)
    end

    # Indicate whether this document can be discovered via the main search box.
    #
    # Such records, even if not independently discoverable can be linked to and
    # accessed directly.  This is useful in the case of records that are
    # 'part of' a discoverable collection.
    #
    def discoverable?(*)
      true
    end

    # Indicate whether this document represents an item that could be delivered
    # by LEO.
    #
    def deliverable?(*)
    end

    # Indicate whether this document represents an item that could be put on
    # course reserve.
    #
    def reservable?(*)
    end

    # Indicate whether an "availability" block should be displayed on the item
    # details show page for this document.
    #
    def availability_on_show_page?(*)
    end

    # Indicate whether this document represents an item that is accessible
    # through Patron Driven Acquisitions (PDA).
    #
    def pda?(*)
    end

    # The ISBN associated with the PDA item request.
    #
    # @return [String]
    #
    def pda_isbn_display(*)
      ''
    end

    # The Sirsi catalog key associated with the PDA item request.
    #
    # @return [String]
    #
    def pda_catkey_display(*)
      ''
    end

    # Feature display associated with the PDA item request.
    #
    # @return [String]
    #
    def pda_feature_display(*)
      ''
    end

    # =========================================================================
    # :section: Document properties (Title components)
    # =========================================================================

    public

    # The primary title component which represents the name of the item.
    #
    # @param [Hash] opt               @see self#title_component
    #
    # @return [String]                @see self#title_component
    # @return [Array<String>]
    # @return [nil]
    #
    # === Implementation Notes
    # @note This base implementation only defines behavior but does not supply
    # a value; the subclass override must supply this via the :value option.
    #
    # @see self#title_component
    #
    def title(opt = {})
      title_component(__method__, opt)
    end

    # The secondary title component which, if present, represents an alternate
    # name of the item.
    #
    # @param [Hash] opt               @see self#title_component
    #
    # @return [String]                @see self#title_component
    # @return [Array<String>]
    # @return [nil]
    #
    # === Implementation Notes
    # @note This base implementation only defines behavior but does not supply
    # a value; the subclass override must supply this via the :value option.
    #
    # @see self#title_component
    #
    def subtitle(opt = {})
      title_component(__method__, opt)
    end

    # An auxiliary title component which, if present, indicates that the item
    # is one of a set of similarly-named items.
    #
    # @param [Hash] opt               @see self#title_component
    #
    # @return [String]                @see self#title_component
    # @return [Array<String>]
    # @return [nil]
    #
    # === Implementation Notes
    # @note This base implementation only defines behavior but does not supply
    # a value; the subclass override must supply this via the :value option.
    #
    # @see self#title_component
    #
    def part(opt = {})
      title_component(__method__, opt)
    end

    # An auxiliary title component which, if present, indicates the medium of
    # representation (particularly to distinguish the item's entry other
    # entries which have been expressed in other media).
    #
    # For example, to be distinguished from the book "Les Misérables", the
    # movie appears as "Les Misérables [videorecording]".
    #
    # @param [Hash] opt               @see self#title_component
    #
    # @return [String]                @see self#title_component
    # @return [Array<String>]
    # @return [nil]
    #
    # === Implementation Notes
    # @note This base implementation only defines behavior but does not supply
    # a value; the subclass override must supply this via the :value option.
    #
    # @see self#title_component
    #
    def medium(opt = {})
      title_component(__method__, opt)
    end

    # For archival materials, this auxiliary title component indicates the span
    # of time over which the contents were created.
    #
    # @param [Hash] opt               @see self#title_component
    #
    # @return [String]                @see self#title_component
    # @return [Array<String>]
    # @return [nil]
    #
    # === Implementation Notes
    # @note This base implementation only defines behavior but does not supply
    # a value; the subclass override must supply this via the :value option.
    #
    # @see self#title_component
    #
    def date_coverage(opt = {})
      title_component(__method__, opt)
    end

    # For archival materials, this auxiliary title component indicates the span
    # of time over which the majority of the contents were created.
    #
    # @param [Hash] opt               @see self#title_component
    #
    # @return [String]                @see self#title_component
    # @return [Array<String>]
    # @return [nil]
    #
    # === Implementation Notes
    # @note This base implementation only defines behavior but does not supply
    # a value; the subclass override must supply this via the :value option.
    #
    # @see self#title_component
    #
    def date_bulk_coverage(opt = {})
      title_component(__method__, opt)
    end

    # For archival materials, a term describing the materials.
    #
    # @param [Hash] opt               @see self#title_component
    #
    # @return [String]                @see self#title_component
    # @return [Array<String>]
    # @return [nil]
    #
    # === References
    # @see https://www.loc.gov/marc/bibliographic/bd245.html
    #
    # === Implementation Notes
    # @note This base implementation only defines behavior but does not supply
    # a value; the subclass override must supply this via the :value option.
    #
    # @see self#title_component
    #
    def form(opt = {})
      title_component(__method__, opt)
    end

    # =========================================================================
    # :section: Document properties (Title components)
    # =========================================================================

    protected

    # Return a value as indicated by the options.
    #
    # @param [Symbol] component          Invoking method.
    # @param [Hash]   opt
    #
    # @option opt [String, Array<String>] :value
    # @option opt [String]                :separator
    #
    # @return [String]                If :separator missing or not set to *nil*
    # @return [Array<String>]         If :separator is explicitly set to *nil*.
    # @return [nil]                   If :separator missing or not set to *nil*
    #                                   and :value is an empty string.
    #
    def title_component(component, opt = {})
      default_opt = item_defaults(component)
      opt = default_opt.merge(opt) if default_opt.present?
      value = opt[:value]
      separator = opt.key?(:separator) ? opt[:separator] : ITEM_SEPARATOR
      return_array = separator.nil?
      if value.is_a?(Array)
        value = value.reject(&:blank?)
        return_array ? value : value.join(separator)
      elsif (value = value.to_s).blank?
        return_array ? [] : nil
      else
        return_array ? [value] : value
      end
    end

    # =========================================================================
    # :section: Document methods (Title components)
    # =========================================================================

    public

    # Components of a "full title".  (Commenting-out a line here removes that
    # component from #show_full_title results.)
    #
    # === Implementation Notes
    # Each hash key is associated with an IndexDoc method:
    # @see self#title
    # @see self#part
    # @see self#medium
    # @see self#subtitle
    # @see self#date_coverage
    # @see self#date_bulk_coverage
    # @see self#form
    #
    TITLE_COMPONENTS = {
      title:              {},
      part:               { class: 'documentPart' },
      medium:             { class: 'documentMedium' },
      subtitle:           { class: 'documentSubtitle' },
      date_coverage:      { class: 'documentDate_coverage' },
      date_bulk_coverage: { class: 'documentDate_bulk_coverage' },
      form:               { class: 'documentForm' },
    }

    # Just the main title.
    #
    # @param [Hash] opt               Control options and/or title components.
    #
    # @return [String]
    #
    # @see self#full_title
    #
    def main_title(opt = nil)
      opt ||= {}
      full_title(opt.deep_merge(include: [:title]))
    end

    # Just the main title and subtitle.
    #
    # @param [Hash] opt               Control options and/or title components.
    #
    # @return [String]
    #
    # @see self#full_title
    #
    def basic_title(opt = nil)
      opt ||= {}
      full_title(opt.deep_merge(include: [:title, :subtitle]))
    end

    # All components of the title.
    #
    # @param [Hash] opt               Control options (below) and/or title
    #                                   component specifications to use in
    #                                   place of self#TITLE_COMPONENTS.
    #
    # @return [String]
    #
    # === Options
    # @option opt [Boolean] :style    If *true*, wrap each title component in a
    #                                   "<span>" tag.
    #
    # @option opt [String]  :colon    Separator added between the main title
    #                                   and subtitle (default: ':').  To have
    #                                   no colon use '' rather than *nil*.
    #
    # @option opt [Symbol, Array<Symbol>] :include  Emit only title components
    #                                   whose keys match one of these.
    #
    # @option opt [Symbol, Array<Symbol>] :except   Emit all title components
    #                                   except those whose keys match one of
    #                                   these.
    #
    # === Examples
    # @example No styling
    #   full_title
    #   #=> 'Main Title part1 [recording]: Subtitle'
    #
    # @example Default attributes
    #   full_title(style: true)
    #   #=> 'Main Title <span class="documentPart">part1</span> ' \
    #       '<span class="documentMedium">[recording]</span>: ' \
    #       '<span class="documentSubtitle">Subtitle</span>'
    #
    # @example Display selected parts with default attributes
    #   full_title(title: true, medium: true)
    #   #=> 'Main Title [recording]'
    #
    # @example Display selected parts with default attributes with styling
    #   full_title(style: true, title: true, subtitle: true)
    #   #=> 'Main Title: <span class="documentSubtitle">Subtitle</span>'
    #
    # @example Display selected parts with added/replacement attributes
    #   full_title(style: true, title: { id: 't' }, subtitle: { class: 'st' })
    #   #=> '<span id="t">Main Title</span>: <span class="st">Subtitle</span>'
    #
    # === Implementation Notes
    # This method invokes one or more methods associated with:
    # @see self#TITLE_COMPONENTS
    #
    def full_title(opt = nil)
      # Extract control options (if any); any remaining hash values are taken
      # to be the title components (and their associated CSS option hashes) to
      # use instead of the default TITLE_COMPONENTS.
      opt = opt ? opt.dup : {}
      style  = opt.delete(:style)
      colon  = opt.delete(:colon) || ':'
      keep   = Array(opt.delete(:include)).compact
      except = Array(opt.delete(:except)).compact

      # Determine the title components to emit.  Any that are given with a
      # value of *true* (instead of a hash) will take their CSS options from
      # the equivalent TITLE_COMPONENTS entry.
      opt =
        if opt.blank?
          TITLE_COMPONENTS.dup
        else
          opt.map { |key, options|
            next unless options
            key = key.to_sym unless key.is_a?(Symbol)
            options = TITLE_COMPONENTS[key] unless options.is_a?(Hash)
            [key, options]
          }.compact.to_h
        end
      opt.keep_if   { |key, _| keep.include?(key) }   if keep.present?
      opt.delete_if { |key, _| except.include?(key) } if except.present?

      # Execute each named property method to fill a table of property keys
      # and property values.
      values =
        opt.keys.map { |key|
          value = send(key)
          next if value.blank?
          if key == :medium
            value = "[#{value}]" unless value.start_with?('[')
          else
            value = titleize(value)
            value = value.gsub("&Quot;", "&quot;")
          end
          [key, value]
        }.compact.to_h

      # Adjust punctuation between parts depending on what parts are present.
      insert_colon_after =
        if values[:subtitle]
          [:medium, :part, :title].find { |key| values[key] }
        elsif values[:part]
          [:title].find { |key| values[key] }
        end

      # Return styled or un-styled parts concatenated into a string.
      opt = {} unless style
      values.map { |key, value|
        if opt[key].present?
          value = strip_html(value)
          value = content_tag(:span, ERB::Util.h(value), opt[key])
        end
        value << colon if insert_colon_after == key
        value
      }.join(SPACE).gsub(/(\n) +/, '\1')
    end

    # =========================================================================
    # :section: Document properties (Bibliographic information)
    # =========================================================================

    public

    # The main year of publication, consisting of a string of one to four
    # decimal digits.
    #
    # @return [String]
    # @return [nil]
    #
    def pub_year(*)
    end

    # The main date of publication, in whatever form was supplied by the
    # underlying metadata.
    #
    # @return [String]
    # @return [nil]
    #
    def pub_date(*)
    end

    # An item with a specific "cite as" value which overrides the normal logic
    # of constructing a citation from title components.
    #
    # @return [String]
    # @return [nil]
    #
    def cite_as(*)
    end

    # =========================================================================
    # :section: Document properties (Identifiers)
    # =========================================================================

    public

    # International Standard Book Numbers (ISBN) for this document.
    #
    # @return [Array<String>]
    #
    # === References
    # @see https://wikipedia.org/wiki/International_Standard_Book_Number
    #
    def isbns(*)
      []
    end

    # OCLC Control Numbers for this document.
    #
    # @return [Array<String>]
    #
    # === References
    # @see https://www.oclc.org/batchload/controlnumber.en.html
    #
    def oclcs(*)
      []
    end

    # The "proper" term for an OCLC number is "OCN" (OCLC Control Number).
    #
    alias_method(:ocns, :oclcs)

    # Library of Congress Control Numbers (LCCN) for this document.
    #
    # @return [Array<String>]
    #
    # === References
    # @see https://www.loc.gov/marc/lccn_structure.html
    #
    def lccns(*)
      []
    end

    # Universal Product Codes (UPC) for this document.
    #
    # @return [Array<String>]
    #
    # === References
    # @see https://wikipedia.org/wiki/Universal_Product_Code
    #
    def upcs(*)
      []
    end

    # International Standard Serial Numbers (ISSN) for this document.
    #
    # @return [Array<String>]
    #
    # === References
    # @see http://www.issn.org
    #
    def issns(*)
      []
    end

    # Digital Object Identifiers (DOI) for this document.
    #
    # @return [Array<String>]
    #
    # === References
    # @see https://www.doi.org
    #
    def dois(*)
      []
    end

    # Library of Congress (LoC) call numbers for this document.
    #
    # @return [Array<String>]
    #
    # === References
    # @see https://www.loc.gov/catdir/cpso/lcco
    #
    def call_numbers(*)
      []
    end

    # Shelving numbers for this document.
    #
    # In the default case this is identical to the LOC call numbers.
    #
    # @return [Array<String>]
    #
    # @see self#call_numbers
    #
    def shelf_numbers(*)
      []
    end

    # Superintendent of Documents classification number.
    #
    # @return [Array<String>]
    #
    # @see https://www.fdlp.gov/catalogingandclassification/cataloging-articles/1791-superintendent-of-documents-sudocs-classification-scheme
    #
    def sudoc_numbers(*)
      []
    end

    # =========================================================================
    # :section: Document properties (Articles)
    # =========================================================================

    public

    # A descriptor indicating the kind of item associated with this document.
    #
    # @return [String]
    #
    def type(*)
      doc_sub_type.to_s.capitalize
    end

    # A locator for this item that shows its location within a serial
    # publication (by giving the journal name, volume, issue and page numbers).
    #
    # @return [String]
    # @return [nil]
    #
    def is_part_of
    end

    # The name of the journal (or other serial) containing this item.
    #
    # @return [String]
    # @return [nil]
    #
    def journal(*)
    end

    # The volume number of the publication containing this item.
    #
    # @return [String]
    # @return [nil]
    #
    def volume(*)
    end

    # The issue number of the publication containing this item.
    #
    # @return [String]
    # @return [nil]
    #
    def issue(*)
    end

    # The starting page location within the publication containing this item.
    #
    # @return [String]
    # @return [nil]
    #
    def start_page(*)
    end

    # The ending page location within the publication containing this item.
    #
    # @return [String]
    # @return [nil]
    #
    def end_page(*)
    end

    # The page location(s) where this item is found within its containing
    # publication.
    #
    # This may be given as a single page (which may indicate its page number
    # location or just the number of pages in the article -- the definition
    # depends on the publisher), or range of page numbers, or a comma-separated
    # list of single page numbers and/or page number ranges.
    #
    # @param [Array] args
    #
    # @option args [String, Fixnum] :start  Overrides the default initial page
    #                                         (self#start_page).
    # @option args [String, Fixnum] :end    Overrides the default final page
    #                                         (self#end_page).
    # @option args [String] :separator      Overrides the default page range
    #                                         separator ('-').
    #
    # @return [String]
    # @return [nil]
    #
    # @see self#get_pages
    #
    def pages(*args)
      opt = args.last.is_a?(Hash) ? args.pop : {}
      first_page = opt[:start]     || start_page
      last_page  = opt[:end]       || end_page
      separator  = opt[:separator] || ' - '
      result = [first_page, last_page].reject(&:blank?)
      result.join(separator) if result.present?
    end

    # A value which indicates the "database" that indexed the article and an
    # identifier that specifies the article within that database.
    #
    # @return [String]
    # @return [nil]
    #
    def accession_number(*)
    end

    # A single string listing of all the identifiers associated with this item.
    #
    # @return [String]
    #
    def identifiers(*)
      ids = {
        'UPC'             => upcs,
        'ISBN'            => isbns,
        'DOI'             => dois,
        'ISSN'            => issns,
        'LOC call number' => get_shelf_numbers,
      }
      if (aux_id = get_media_retrieval_id).present?
        ids['Retrieval ID'] = aux_id
      elsif (aux_id = values_for(:location_display)).present?
        ids['Location'] = aux_id
      end
      ids.map { |label, value|
        "#{label}: " + Array.wrap(value).join(LIST_SEPARATOR) if value.present?
      }.compact.join(ITEM_SEPARATOR)
    end

    # =========================================================================
    # :section: Document properties (transient)
    # =========================================================================

    public

    # Return with the time the that the document was included in the index.
    #
    # @param [String] fmt             Format passed to DateTime#strftime.
    #
    # @return [String]
    # @return [DateTime]              If *fmt* was explicitly set to *nil*.
    # @return [nil]                   Indexing date not available.
    #
    def date_indexed(fmt = nil, *)
      unused(fmt)
    end

    # URL of the cover image for this document.
    #
    # @return [String]
    # @return [nil]
    #
    def image_path(*)
    end

    # Return the circulation information for the item(s) associated with this
    # document.
    #
    # @return [Firehose::Availability]
    # @return [nil]                     For non-catalog related documents.
    #
    # @see self#has_availability_loaded?
    #
    def availability(*)
    end

    # =========================================================================
    # :section: Document methods (transient)
    # =========================================================================

    public

    # Indicate whether this document has a cover image.
    #
    def has_image?(*)
    end

    # Re-acquire circulation information for the item(s) associated with this
    # document.
    #
    # @return [Firehose::Availability]
    # @return [nil]
    #
    # @see self#has_refresh_availability?
    #
    # === Implementation Notes
    # If the derived class does not cache availability information then this
    # method may not do anything.
    #
    def refresh_availability(*)
    end

    # Indicate whether this document has availability information.
    #
    # While self#availability will trigger the acquisition of availability
    # information if it's not present, use this method to check for the
    # presence of availability information without inadvertantly fetching it.
    #
    # If self#has_availability_loaded? is *true* then self#refresh_availability
    # does not need to be run.  (It does not necessarily mean that
    # self#availability will return a non-*nil* value.)
    #
    # @see self#availability
    #
    def has_availability_loaded?(*)
    end

    # Indicate whether this document has the capability of acquiring
    # availability information.
    #
    # If self#has_refresh_availability? is *false* then self#availability will
    # always return *nil* because the document instance does not have the
    # ability to acquire availability information.
    #
    # @see self#refresh_availability
    #
    def has_refresh_availability?(*)
    end

    # =========================================================================
    # :section: Document values (Title components)
    # =========================================================================

    public

    # The title(s) of the work expression associated with this document.
    #
    # @return [Array<String>]
    #
    # TODO: Should make sure that linked title and translated title are both here
    #
    def get_title(*)
      title(separator: nil)
    end

    # =========================================================================
    # :section: Document values (Bibliographic information)
    # =========================================================================

    public

    # The format(s) reported for this document.
    #
    # If there are multiple items associated with this document, this value
    # represents the union of the format(s) of all individual items.
    #
    # @return [Array<String>]
    #
    def get_format(*)
      Array(type)
    end

    # The type(s) of creative work associated with this document.
    #
    # @return [Array<String>]
    #
    def get_work_type(*)
      Array(type)
    end

    # The edition(s) of the work manifestation associated with this document.
    #
    # @return [Array<String>]
    #
    def get_edition(*)
      []
    end

    # Full descriptions of the edition(s) of the work manifestation associated
    # with this document.
    #
    # @return [Array<String>]
    #
    def get_edition_statement(*)
      []
    end

    # The year(s) of publication of the work manifestation associated with this
    # document.
    #
    # @param [Boolean, Date, Fixnum, String] value
    #   If *nil* or *false*, use the value of #pub_year.
    #   If *true*, and #pub_year is missing, extract year from #pub_date.
    #   Otherwise *value* is used to produce a year value.
    #
    # @return [Array<String>]
    #
    def get_pub_year(value = nil, *)
      result =
        case value
          when Date   then value.year.to_s
          when Fixnum then value.to_s
          when String then extract_year(value)
          when true   then pub_year || extract_year(pub_date)
          else             pub_year
        end
      Array(result)
    end

    # The date(s) of publication of the work manifestation associated with this
    # document.
    #
    # @param [Boolean, Date, Fixnum, String] value
    #   If *nil* or *false*, use the value of #pub_date.
    #   If *true*, and #pub_date is missing, use #pub_year.
    #   Otherwise *value* as the date value.
    #
    # @return [Array<String>]
    #
    def get_pub_date(value = nil, *)
      result =
        case value
          when Date   then value.to_formatted_s(:long)
          when Fixnum then value.to_s
          when String then value
          when true   then pub_date || pub_year
          else             pub_date
        end
      Array(result)
    end

    # Publication information for the work manifestation associated with this
    # document.
    #
    # The value(s) returned by this method are intended for display purposes
    # for showing the publisher and place of publication in combination.
    #
    # @return [Array<String>]
    #
    # @see self#get_publisher
    # @see self#get_publication_place
    #
    def get_pub_statement(*)
      []
    end

    # The name of publisher(s) of the work manifestation associated with this
    # document.
    #
    # @return [Array<String>]
    #
    def get_publisher(*)
      []
    end

    # The place(s) of publication of the work manifestation associated with
    # this document.
    #
    # @return [Array<String>]
    #
    def get_publication_place(*)
      []
    end

    # get_uniform_title
    #
    # @return [Array<String>]
    #
    def get_uniform_title(*)
      []
    end

    # The name(s) of series that include the work manifestation associated
    # with this document.
    #
    # @return [Array<String>]
    #
    # TODO: Should this relate to #is_part_of in some way?
    #
    def get_series(*)
      []
    end

    # Phrase(s) describing the series that include the work manifestation
    # associated with this document.
    #
    # @return [Array<String>]
    #
    def get_series_statement(*)
      []
    end

    # The name of collection(s) that include the work manifestation associated
    # with this document.
    #
    # @return [Array<String>]
    #
    def get_collection(*)
      []
    end

    # The list of authors/creators of the work manifestation associated with
    # this document.
    #
    # NOTE: For many/most export formats, use this instead of #export_authors.
    #
    # @return [Array<String>]
    #
    def get_authors(*)
      []
    end

    # The list of ETD advisors associated with this document.
    #
    # In particular for ETDs, this includes the thesis/dissertation advisor and
    # may also include the defense committee.
    #
    # NOTE: For many/most export formats, use this instead of #export_advisors.
    #
    # @return [Array<String>]
    #
    def get_advisors(*)
      []
    end

    # get_contributors
    #
    # @return [Array<String>]
    #
    def get_contributors
      []
    end

    # get_sponsoring_agency
    #
    # @return [Array<String>]
    #
    def get_sponsoring_agency
      []
    end

    # The list of motion picture directors for the work manifestation
    # associated with this document.
    #
    # NOTE: For many/most export formats, use this instead of #export_directors
    #
    # @return [Array<String>]
    #
    def get_directors(*)
      []
    end

    # The natural language(s) for the work expression associated with this
    # document.
    #
    # @return [Array<String>]
    #
    def get_language(*)
      []
    end

    # Details about the physical characteristics the work manifestation
    # associated with this document.
    #
    # @return [Array<String>]
    #
    def get_physical_description(*)
      []
    end

    # Details about technical aspects of the work manifestation associated with
    # this document.
    #
    # @return [Array<String>]
    #
    def get_technical_details(*)
      []
    end

    # Details about the reproduction characteristics of the time-based medium
    # work manifestation associated with this document.
    #
    # @return [Array<String>]
    #
    def get_recording_information(*)
      []
    end

    # The intended audience (including video rating) for the work manifestation
    # associated with this document.
    #
    # @return [Array<String>]
    #
    def get_target_audience(*)
      []
    end

    # The list of performer(s) of the work manifestation associated with this
    # document.
    #
    # @return [Array<String>]
    #
    def get_performers(*)
      []
    end

    # The list of people (or other agents) with production credit for the work
    # manifestation associated with this document.
    #
    # @return [Array<String>]
    #
    def get_credits(*)
      []
    end

    # One or more lines summarizing the plot of the work associated with this
    # document.
    #
    # @return [Array<String>]
    #
    def get_plot_summary(*)
      []
    end

    # One or more lines describing the contents of the work manifestation
    # associated with this document.
    #
    # For books this is a table of contents or similar listing; for musical
    # recordings this is the track list.
    #
    # @return [Array<String>]
    #
    def get_contents(*)
      []
    end

    # A description of the degree earned for the thesis or dissertation
    # associated with this document.
    #
    # @return [Array<String>]
    #
    def get_dissertation_note(*)
      []
    end

    # An item with a specific "cite as" value which overrides the normal logic
    # of constructing a citation from title components.
    #
    # @return [Array<String>]
    #
    def get_cite_as(*)
      Array(cite_as)
    end

    # Get related subjects and/or related names for this item.
    #
    # @return [Array<String>]
    #
    def get_keywords(*)
      (get_subjects + get_related_names).uniq
    end

    # Get related subjects for this item.
    #
    # @return [Array<String>]
    #
    def get_subjects(*)
      []
    end

    # Get related geographic subjects / place names for this item.
    #
    # @return [Array<String>]
    #
    def get_place_names(*)
      []
    end

    # Get personal (or corporate) names associated with this item.
    #
    # @return [Array<String>]
    #
    def get_related_names(*)
      get_authors
    end

    # Get descriptive text about the item.
    #
    # @return [Array<String>]
    #
    def get_description(*)
      []
    end

    # Get an abstract/summary for the item.
    #
    # @return [Array<String>]
    #
    def get_abstract(*)
      []
    end

    # Get a copyright and permissions and field for the item.
    #
    # @return [Array<String>]
    #
    def get_copyright_and_permissions(*)
      []
    end

    # Get notes for the item.
    #
    # @return [Array<String>]
    #
    def get_notes(*)
      []
    end

    # =========================================================================
    # :section: Document values (Aggregated information)
    # =========================================================================

    public

    # One or more lines serving as an abstract or summary for the work
    # associated with this document.
    #
    # This exists primarily to support self#export_abstract_fields, which is
    # intended to support citation export.
    #
    # @param [Array<Array<(String, String)>>] parts  Additional entries.
    #
    # @return [Array<String>]           If :separator is missing or *false*.
    # @return [String]                  If :separator is a string or *true*.
    #
    # === Options
    # @see self#update_options
    # @see self#label_value_list
    #
    # === Implementation Notes
    # @note This base implementation only defines behavior but does not supply
    # a value; the subclass override must supply this via *parts*.
    #
    def get_abstract_fields(*parts)
      update_options(__method__, parts, separator: false)
      label_value_list(*parts)
    end

    # One or more lines with notes about for the work associated with this
    # document.
    #
    # This exists primarily to support self#export_note_fields, which is
    # intended to support citation export.
    #
    # @param [Array<Array<(String, String)>>] parts  Additional entries.
    #
    # @return [Array<String>]           If :separator is missing or *false*.
    # @return [String]                  If :separator is a string or *true*.
    #
    # === Options
    # @see self#update_options
    # @see self#label_value_list
    #
    # === Implementation Notes
    # @note This base implementation only defines behavior but does not supply
    # a value; the subclass override must supply this via *parts*.
    #
    def get_note_fields(*parts)
      update_options(__method__, parts, separator: false)
      label_value_list(*parts)
    end

    # =========================================================================
    # :section: Document values (Identifiers)
    # =========================================================================

    public

    # International Standard Book Numbers (ISBN) for this document.
    #
    # Each entry may include an annotation after the identifier value.
    #
    # @return [Array<String>]
    #
    # @see self#isbns
    #
    def get_isbn(*)
      isbns
    end

    # OCLC Control Numbers for this document.
    #
    # Each entry may include an annotation after the identifier value.
    #
    # @return [Array<String>]
    #
    # @see self#oclcs
    #
    def get_oclc(*)
      oclcs
    end

    # The "proper" term for an OCLC number is "OCN" (OCLC Control Number).
    #
    alias_method(:get_ocn, :get_oclc)

    # Library of Congress Control Numbers (LCCN) for this document.
    #
    # Each entry may include an annotation after the identifier value.
    #
    # @return [Array<String>]
    #
    # @see self#lccns
    #
    def get_lccn(*)
      lccns
    end

    # Universal Product Codes (UPC) for this document.
    #
    # Each entry may include an annotation after the identifier value.
    #
    # @return [Array<String>]
    #
    # @see self#upcs
    #
    def get_upc(*)
      upcs
    end

    # International Standard Serial Numbers (ISSN) for this document.
    #
    # Each entry may include an annotation after the identifier value.
    #
    # @return [Array<String>]
    #
    # @see self#issns
    #
    def get_issn(*)
      issns
    end

    # Digital Object Identifiers (DOI) for this document.
    #
    # Each entry may include an annotation after the identifier value.
    #
    # @return [Array<String>]
    #
    # @see self#dois
    #
    def get_doi(*)
      dois
    end

    # Get a list of the primary identifiers for this document.
    #
    # Since an item usually only has ISBN(s) or ISSN(s), this method will
    # usually return one set of numbers or the other.
    #
    # @return [Array<String>]
    #
    def get_standard_identifiers(*)
      (isbns + issns).uniq
    end

    # The online content URL(s) associated with this item.
    #
    # @return [Array<String>]
    #
    # Compare with:
    # @see self#get_url_links
    # (the same set of URL's but with labels included)
    #
    def get_url(*)
      []
    end

    # The online content links associated with this item.
    #
    # The result is an array where each element is either
    #   - a [url, label] pairs or
    #   - a [url] singleton if no label text was provided.
    #
    # @return [Array<Array<(String,String>>]
    #
    # Compare with:
    # @see self#get_url
    # (the same set of URL's but with no labels)
    #
    def get_url_links(*)
      []
    end

    # Links to online material related to this item.
    #
    # The result is an array where each element is either
    #   - a [url, label] pairs or
    #   - a [url] singleton if no label text was provided.
    #
    # @return [Array<Array<(String,String>>]
    #
    def get_supplemental_url_links(*)
      []
    end

    # The ID's associated with this item for accessing online repository
    # content.
    #
    # @return [Array<String>]
    #
    def get_media_retrieval_id(*)
      []
    end

    # The LOC call number(s) for all of the work instances associated with this
    # document.
    #
    # This method returns valid unique call numbers, where spaces are ignored
    # in the comparison for duplicate numbers.
    #
    # @return [Array<String>]
    #
    def get_call_numbers(*)
      call_numbers
        .reject { |v| invalid_call_number?(v) }
        .uniq { |v| non_blank_chars(v) }
    end

    # The shelving number(s) for all of the work instances associated with this
    # document.
    #
    # In the default case this is identical to the LOC call numbers.
    #
    # @return [Array<String>]
    #
    # @see self#get_call_numbers
    #
    def get_shelf_numbers(*)
      get_call_numbers
    end

    # =========================================================================
    # :section: Document methods (Identifiers)
    # =========================================================================

    public

    # Indicate whether the given value is a meaningful call number.
    #
    # @param [String] number
    #
    def invalid_call_number?(number, *)
      number.blank?
    end

    # =========================================================================
    # :section: Document values (Articles)
    # =========================================================================

    public

    # Descriptor(s) indicating the kind of item associated with this document.
    #
    # @return [Array<String>]
    #
    # @see self#type
    #
    def get_type(*)
      get_work_type
    end

    # Locator(s) for this item that shows its location within a serial
    # publication (by giving the journal name, volume, issue and page numbers).
    #
    # @return [Array<String>]
    #
    # @see self#is_part_of
    #
    def get_is_part_of(*)
      Array(is_part_of)
    end

    # Name(s) of the journals (or other serials) containing this item.
    #
    # @return [Array<String>]
    #
    # @see self#journal
    #
    def get_journal(*)
      Array(journal)
    end

    # Volume number(s) of the publication(s) containing this item.
    #
    # @return [Array<String>]
    #
    # @see self#volume
    #
    def get_volume(*)
      Array(volume)
    end

    # Issue number(s) of the publication(s) containing this item.
    #
    # @return [Array<String>]
    #
    # @see self#issue
    #
    def get_issue(*)
      Array(issue)
    end

    # Starting page location(s) within the publication containing this item.
    #
    # @return [Array<String>]
    #
    # @see self#start_page
    #
    def get_start_page(*)
      Array(start_page)
    end

    # The ending page location(s) within the publication containing this item.
    #
    # @return [Array<String>]
    #
    # @see self#end_page
    #
    def get_end_page(*)
      Array(end_page)
    end

    # The page location(s) where this item is found within its containing
    # publication.
    #
    # @see self#pages
    #
    def get_pages(*args)
      Array(pages(*args))
    end

    # Values which indicates the "database" that indexed the article and an
    # identifier that specifies the article within that database.
    #
    # @return [Array<String>]
    #
    def get_accession_number(*)
      Array(accession_number)
    end

    # Strings listing of all the identifiers associated with this item.
    #
    # @return [Array<String>]
    #
    def get_identifiers(*)
      Array(identifiers)
    end

    # =========================================================================
    # :section: Document methods (from SolrDocument)
    # =========================================================================

    public

    # Gets an array of values for the given metadata field.
    #
    # The :default value will be returned if there is no data for the given
    # field which may mean one of four things:
    # * The named Solr *field* is not present at all
    # * The *field* is present but its value is *nil*.
    # * The *field* is present but its value is a blank String ("").
    # * The *field* is present but its value is an empty Array ([]).
    #
    # @note To test whether *field* is present use `has?(field)` instead of
    # this method.
    #
    # @param [Symbol] field
    # @param [Hash]   opt
    #
    # @option opt [Object]  :default
    # @option opt [Boolean] :process_values
    #
    # @return [Array<String>]
    # @return [nil]                   Or whatever opt[:default] was set to;
    #                                   returned if there were no values.
    #
    def values_for(field, opt = nil)
      Debug.show(__method__) { ":#{field}" }
      result = self[field]
      if result.blank?
        default_opt = { default: [] }
        opt = opt.is_a?(Hash) ? default_opt.merge(opt) : default_opt
        opt[:default]
      elsif !result.is_a?(Array)
        [result.strip]
      else
        result.map(&:strip)
      end
    end

    # evaluate
    #
    # @param [Symbol] symbol
    # @param [Hash]   opt
    #
    # @option opt [Boolean] :marc
    #
    # @return [Array<String>]
    # @return [String]
    # @return [Object]
    #
    def evaluate(symbol, opt = nil)
      default_opt = { marc: false, methods: true, fields: true }
      opt = opt.is_a?(Hash) ? default_opt.merge(opt) : default_opt
      use = default_opt.map { |k, _| [k, nil] }.to_h
      off = {}
      marc = marc_display

      # Process options in order.
      opt.each_pair do |key, value|
        next unless value
        use[key] = (key != :marc) || marc
        next unless use[key] && (value == :only)
        off.each_key { |k| off[k] = true unless k == key }
      end
      off.each_key { |k| use.delete(k) }

      # Evaluate the symbol in the order defined by the options.
      use.find do |key, value|
        next if value.blank?
        result =
          case key
            when :marc    then marc.respond_to?(symbol) && marc.send(symbol)
            when :methods then respond_to?(symbol) && send(symbol)
            when :fields  then values_for(symbol)
          end
        break result if result
      end
    end

    # =========================================================================
    # :section: Serialization support
    # =========================================================================

    public

    # Generate XML from the metadata for this document.
    #
    # @return [String]
    #
    def to_xml(*)
      instance_values.to_xml
    end

    # Generate a hash that will be serialized as JSON.
    #
    # In the default case this includes the values of all instance variables.
    #
    # @return [Hash]
    #
    def as_json(*)
      instance_values
    end

    # Generate JSON from the metadata for this document.
    #
    # @return [String]
    #
    def export_as_json(*)
      as_json.to_json
    end

    # =========================================================================
    # :section: HTML support methods
    # =========================================================================

    public

    # Return values that can be used to create <meta> tags for this item.
    #
    # @return [Hash{Symbol=>String}]
    #
    def get_meta_tags(*)

      title = strip_html(values_for(:linked_title_display).first).presence
      title ||= export_title

      format = get_format + get_work_type
      format = format.reject { |v| v == 'Online' }.uniq.presence
      format &&= 'Format: ' + format.join(LIST_SEPARATOR)
      if (pub = get_pub_statement.presence)
        pub = 'Published: ' + pub.join(' / ')
      elsif (pub = get_publisher.presence)
        pub = 'Publisher: ' + pub.join(' / ')
      end
      description =
        [format, identifiers, pub].reject(&:blank?).join(ITEM_SEPARATOR)

      result = {
        title:       title,
        author:      export_authors,
        keywords:    export_subjects,
        description: description,
      }
      result.reject { |_, v| v.blank? }
    end

    # Used on show partials for the author/creator displayed at the top of the
    # content area.
    #
    # @return [String]
    #
    def show_heading_author(*)
      export_authors
    end

    # Used on show partials for the title displayed at the top of the content
    # area.
    #
    # @return [ActiveSupport::SafeBuffer]
    #
    def show_heading_title(*)
      show_full_title
    end

    # Show just the main title.
    #
    # @param [Hash] opt               Control options and/or title components.
    #
    # @return [ActiveSupport::SafeBuffer]
    #
    # @see self#main_title
    # @see self#full_title
    #
    def show_main_title(opt = nil)
      default_opt = { style: true }
      opt = opt.is_a?(Hash) ? default_opt.merge(opt) : default_opt
      main_title(opt).html_safe
    end

    # Show just the main title and subtitle.
    #
    # @param [Hash] opt               Control options and/or title components.
    #
    # @return [ActiveSupport::SafeBuffer]
    #
    # @see self#basic_title
    # @see self#full_title
    #
    def show_basic_title(opt = nil)
      default_opt = { style: true }
      opt = opt.is_a?(Hash) ? default_opt.merge(opt) : default_opt
      basic_title(opt).html_safe
    end

    # show_full_title
    #
    # @param [Hash] opt               Control options and/or title components.
    #
    # @return [ActiveSupport::SafeBuffer]
    #
    # @see self#full_title
    #
    def show_full_title(opt = nil)
      default_opt = { style: true }
      opt = opt.is_a?(Hash) ? default_opt.merge(opt) : default_opt
      full_title(opt).html_safe
    end

    # =========================================================================
    # :section: Citation Export
    #
    # These methods support exporting the article information in EndNote and
    # RefWorks and RIS (for Zotero) format. The methods mimic methods on Solr
    # documents which are required in order for this document to process
    # through Blacklight in the export pipeline.
    #
    # All output text is encoded as UTF-8.
    #
    # The _full_show_path parameter on each method is the full url to the Virgo
    # details/show page for the article.  Currently this is not being used as
    # the URL to the article for export; it is supplied should the need to use
    # it rather than the Serials Solution link.
    # =========================================================================

    public

    # Get the metadata for this document in EndNote import format.
    #
    # @param [String] url             URL to report instead of the default.
    #
    # @return [String]
    #
    # Compare with:
    # @see Blacklight::Solr::Document::MarcExport#export_as_endnote
    #
    # === References
    # For information about EndNote tags:
    # @see https://web.archive.org/web/20160930000824/http://www.cardiff.ac.uk/insrv/educationandtraining/guides/endnote/endnote_codes.html
    #
    # The format of the representation is based on the Refer/BiblX tag syntax:
    # @see http://hcibib.org/refer.html
    #
    # EndNote has several modifications to that tag syntax:
    # @see https://web.archive.org/web/20070916102251/http://www.ecst.csuchico.edu/~jacobsd/bib/formats/endnote.html
    # (Though this reference is rather old, it succinctly summarizes the
    # differences.)
    #
    # === Implementation Notes
    # This method overrides the Blacklight method to supply more fields and to
    # support articles and catalog items without MARC records.
    #
    # @note If you change this method, you may also need to examine and change
    # the corresponding methods for RefWorks, EndNote and Zotero RIS:
    # @see self#export_as_endnote
    # @see self#export_as_refworks
    # @see self#export_as_ris
    #
    def export_as_endnote(url = nil)

      # NOTE: The original code stated "%Z does not import into EndNote" and
      # used '%<' instead for the notes field, but that might have been an
      # EndNote-version-specific issue.

      generate_export(
        '%0' => reference_type(:endnote),
        '%U' => (url || get_url),

        # === Creators
        '%A' => endnote_author(get_authors),
        '%H' => endnote_author([]), # NOTE: translated authors
        '%E' => endnote_author([]), # NOTE: editors OR secondary authors
        '%Y' => endnote_author([]), # NOTE: translators OR tertiary authors
        '%?' => endnote_author(get_advisors), # NOTE: subsidiary authors

        # === Publication
        '%T' => endnote_title(export_title),
        '%Q' => endnote_title(''),  # NOTE: translated title
        '%O' => endnote_title(''),  # NOTE: alternate title
        '%B' => export_series,      # NOTE: secondary (book or conference name)
        '%S' => endnote_title(''),  # NOTE: tertiary title
        '%J' => export_journal,
        '%V' => export_volume,
        '%N' => export_issue,
        '%P' => (export_pages || export_physical_description),
        '%D' => export_pub_year,
        '%7' => export_edition_statement,
        '%8' => export_pub_date,
        '%C' => export_publication_place,
        '%I' => export_publisher,

        # === Identifiers
        '%R' => export_doi,
        '%@' => export_standard_identifiers,
        '%W' => '',                 # NOTE: provider (e.g., 'EBSCO'?)
        '%~' => '',                 # NOTE: database (e.g., EBSCO db number?)
        '%M' => export_accession_number,
        '%L' => export_shelf_numbers,

        # === Contents
        '%9' => export_work_type,
        '%6' => '',                 # NOTE: number of volumes
        '%G' => export_language,
        '%1' => export_contents,
        '%2' => export_directors,
        '%3' => export_credits,

        # === Notes
        '%K' => get_subjects,
        '%<' => endnote_notes(''),  # NOTE: research notes
        '%Z' => endnote_notes(export_note_fields(ascii: true)),
        '%X' => endnote_notes(export_abstract_fields(ascii: true)),
      )

    end

    # Get the metadata for this document in RefWorks import format.
    #
    # @param [String] url             URL to report instead of the default.
    #
    # @return [String]
    #
    # === References
    # For information about RefWorks tags:
    # @see https://www.refworks.com/refworks/help/RefWorks_Tagged_Format.htm
    # RefWorks Direct Export interface:
    # @see https://www.refworks.com/DirectExport.htm#DEFormPost
    #
    # === Implementation Notes
    # @note If you change this method, you may also need to examine and change
    # the corresponding methods for RefWorks, EndNote and Zotero RIS:
    # @see self#export_as_endnote
    # @see self#export_as_refworks
    # @see self#export_as_ris
    #
    def export_as_refworks(url = nil)

      result = generate_export(
        'RT' => reference_type(:refworks),
        'SR' => (born_digital? ? 'Electronic(1)' : 'Print(0)'),
        'UL' => (url || get_url),

        # === Creators
        'A1' => get_authors,
        'A2' => [],                 # NOTE: editors
        'A3' => get_advisors,
        # 'A3' => [],               # NOTE: series editors
        'A4' => [],                 # NOTE: translators
        'A5' => [],                 # NOTE: compilers
        'A6' => [],                 # NOTE: website editors

        # === Publication
        'T1' => refworks_title(export_title),
        'OT' => refworks_title(''),            # NOTE: original foreign title
        'T2' => refworks_title(export_series), # NOTE: secondary title
        'T3' => refworks_title(''),            # NOTE: tertiary title
        'JF' => export_journal,
        'VO' => export_volume,
        'IS' => export_issue,
        'SP' => export_start_page,
        'OP' => export_end_page,
        'YR' => export_pub_year,
        'ED' => export_edition_statement,
        'FD' => export_pub_date,
        'PP' => export_publication_place,
        'PB' => export_publisher,

        # === Identifiers
        'DO' => export_doi,
        'SN' => export_standard_identifiers,
        'DS' => '',                 # NOTE: provider (e.g., 'EBSCO'?)
        'DB' => '',                 # NOTE: database (e.g., EBSCO db number?)
        'AN' => export_accession_number,
        'CN' => export_shelf_numbers,

        # === Contents
        'CL' => export_work_type,
        'LA' => export_language,
        'U1' => export_contents,
        'U2' => export_directors,
        'U3' => export_credits,

        # === Notes
        'K1' => get_subjects,
        'NO' => export_note_fields(ascii: true),
        'AB' => export_abstract_fields(ascii: true),
      )
      # NOTE: This was present for articles; assuming it's safe in all cases...
      ActiveSupport::Multibyte::Chars.new(result).normalize(:c).to_s

    end

    # Get the metadata for this document in Zotero RIS import format.
    #
    # RIS (Reference Information Systems) format is the suggested format to be
    # used for Zotero import.
    #
    # @param [String] url             URL to report instead of the default.
    #
    # @return [String]
    #
    # === References
    # For information about Zotero RIS tags:
    # @see https://www.zotero.org/support/kb/field_mappings
    # @see https://en.wikipedia.org/wiki/RIS_%28file_format%29
    # @see http://refman.com/sites/rm/files/m/direct_export_ris.pdf
    #
    # === Implementation Notes
    # NOTE: If you change this method, you may also need to examine and change
    # the corresponding methods for RefWorks, EndNote and Zotero RIS:
    # @see self#export_as_endnote
    # @see self#export_as_refworks
    # @see self#export_as_ris
    #
    #--
    # rubocop:disable Metrics/MethodLength # [44/35]
    #++
    def export_as_ris(url = nil)

      generate_export(
        'TY  -' => reference_type(:ris),
        'UR  -' => (url || get_url),

        # === Creators
        'AU  -' => get_authors,
        'A3  -' => get_advisors,

        # === Publication
        'TI  -' => export_title,
        'T2  -' => export_series,
        'JF  -' => export_journal,  # NOTE: not in EndNote RIS import
        'VL  -' => export_volume,
        'IS  -' => export_issue,
        'SP  -' => export_start_page,
        'EP  -' => export_end_page,
        'PY  -' => ris_year(get_pub_year.first),
        'ET  -' => export_edition_statement,
        'DA  -' => ris_date(get_pub_date.first),
        'CY  -' => export_publication_place,
        'PB  -' => export_publisher,

        # === Identifiers
        'DO  -' => export_doi,
        'SN  -' => export_standard_identifiers,
        'DP  -' => '',              # NOTE: provider (e.g., 'EBSCO'?)
        'DB  -' => '',              # NOTE: database (e.g., EBSCO db number?)
        'AN  -' => export_accession_number,
        'CN  -' => export_shelf_numbers,

        # === Contents
        'M3  -' => export_work_type,
        'LA  -' => export_language,
        'C1  -' => export_contents,
        'C2  -' => export_directors,
        'C3  -' => export_credits,

        # === Notes
        'KW  -' => ris_keywords(get_subjects),
        'N1  -' => export_note_fields(ascii: true),
        'AB  -' => export_abstract_fields(ascii: true),
        'C4  -' => export_copyright_and_permissions,
        'ER  -' => :empty_field     # NOTE: Required "End of reference"
      )

      # rubocop:enable Metrics/MethodLength
    end

    # =========================================================================
    # :section: Citation Export
    # =========================================================================

    protected

    # Common export logic for all citation formats.
    #
    # The *fields* hash entries consist of a key which is the export format tag
    # and a value which is either a single String or an array of Strings.
    #
    # If the String is blank or the Array<String> is empty, no instances of
    # that tag will be produced in the result.
    #
    # @param [Hash{String=>String,Array<String>}] fields
    #
    # @return [String]
    #
    # === Examples
    # @example Single instance
    #   { String => String } # Produces a single instance of the tagged value
    #                          in the result.
    #
    # @example Multiple instances
    #   { String => Array<String> } # Produces multiple instance of the tag,
    #                                 one for each array element.
    #
    # NOTE: Whether a given tag may be repeated depends on the export format.
    #
    def generate_export(fields)
      raise "#{fields.class}: expected a Hash" unless fields.is_a?(Hash)
      fields.map { |tag, values|
        Array(values).map do |value|
          Array(value).map do |v|
            next if v.blank?
            field_value = [tag]
            field_value << v unless v == :empty_field
            field_value.join(SPACE)
          end
        end
      }.flatten.compact.join(NEWLINE)
        .tap do |result| # NOTE: debugging
          Rails.logger.info {
            fmt =
              case caller
                when /_refworks/ then 'REFWORKS'
                when /_endnote/  then 'ENDNOTE'
                when /_ris/      then 'ZOTERO RIS'
                else                  caller
              end
            "#{fmt} =============================\n#{result}"
          } if Virgo.desktop_development?
        end
    end

    # Corporate authors should end with a comma so that the entire string is
    # treated as a last name (and thus won't be reversed by EndNote).
    #
    # The asterisk character (ASCII 42) is not allowed in the author, keywords
    # or periodical name ('J2  - ') fields.
    #
    # @param [Array<String>] a
    #
    # @return [Array<String>]
    # @return [nil]                   If the argument was blank.
    #
    def endnote_author(a)
      return if a.blank?
      a.map { |v|
        next if v.blank?
        v += ',' unless v.include?(',')
        v.tr('*', '#')
      }.compact
    end

    # Remove periods from the end of titles.
    #
    # @param [String] s
    #
    # @return [String]
    # @return [nil]                   If the argument was blank.
    #
    def endnote_title(s)
      s.chomp('.') if s.present?
    end

    # Note fields can hold up to 64,000 characters.
    #
    # @param [String] s
    #
    # @return [String]
    # @return [nil]                   If the argument was blank.
    #
    def endnote_notes(s)
      s.truncate(64000) if s.present?
    end

    # Remove periods from the end of titles.
    #
    # @param [String] s
    #
    # @return [String]
    # @return [nil]                   If the argument was blank.
    #
    def refworks_title(s)
      s.chomp('.') if s.present?
    end

    # Required form for "PY  -" is "YYYY".
    #
    # @param [String] s
    #
    # @return [String]
    # @return [nil]                   If the string did not have a year value.
    #
    def ris_year(s)
      extract_year(s)
    end

    # Required form for "DA  -" is "YYYY/MM/DD/other_info" where "YYYY" and
    # the slashes are required but the others are not.  If "MM" and "DD" are
    # present he must be digits.
    #
    # @param [String] s
    #
    # @return [String]
    # @return [nil]                   If the string did not have a date value.
    #
    def ris_date(s)
      export_date(s, allow_extra_text: true)
    end

    # Keywords are limited to 255 characters.
    #
    # The asterisk character (ASCII 42) is not allowed in the author, keywords
    # or periodical name ('J2  - ') fields.
    #
    # @param [Array<String>] a
    #
    # @return [Array<String>]
    # @return [nil]                   If the argument was blank.
    #
    def ris_keywords(a)
      a.map { |v| v.truncate(255).tr('*', '#') } if a.present?
    end

    # =========================================================================
    # :section: Citation Export
    # =========================================================================

    public

    # The category of the reference type depending on the citation export.
    #
    # If the heuristics fail to match any reference type the generic reference
    # type for the citation export format will be returned.
    #
    # @param [Symbol] export_type     One of :ris, :refworks, :endnote or *nil*
    #
    # @return [Symbol]                If *export_type* was *nil* the key for
    #                                   the self#TYPE_TABLE entry matching the
    #                                   document type.
    # @return [String]                The document type string required by
    #                                   *export_type*.
    # @return [nil]                   If there is no matching document type for
    #                                   *export_type*.
    #
    # === References
    #
    # For EndNote:
    # @see https://web.archive.org/web/20160930000824/http://www.cardiff.ac.uk/insrv/educationandtraining/guides/endnote/endnote_codes.html
    # (list of values for %0 tag)
    #
    # For RefWorks:
    # @see https://www.refworks.com/refworks/help/RefWorks_Tagged_Format.htm
    # (list of values for RT tag under "Reference Type Indicator Tag")
    #
    # For Zotero RIS:
    # @see https://en.wikipedia.org/wiki/RIS_%28file_format%29#Type_of_reference
    # (list of values for TY tag)
    #
    def reference_type(export_type = nil)
      # rubocop:disable Style/MultilineOperationIndentation
      type = { generic: true }
      type[:govdoc] = true if government_document?
      case doc_type
        when :article                         then type[:article] = true
        when :dl_book                         then type[:book]    = true
        when :dl_image                        then type[:image]   = true
        when :dl_video, :dl_wsls_video        then type[:video]   = true
        when :lib_album                       then type[:audio]   = true
        when :lib_coins                       then type[:image]   = true
        when :lib_video, :lib_video_full      then type[:video]   = true
      end
      get_format.each do |format|
        case format
          when 'Musical Score'                then type[:score]      = true
          when 'Manuscript'                   then type[:manuscript] = true
          when 'Newspaper'                    then type[:newspaper]  = true
          when /Thesis/, /Dissertation/       then type[:etd]        = true
          when 'Map', 'Atlas', 'Globe'        then type[:map]        = true
          when /Video/, 'DVD', 'Blu-Ray'      then type[:video]      = true
          when /Audio/, 'CD'                  then type[:audio]      = true
          when /^Musical/, /Recording$/       then type[:audio]      = true
          when /Photo/, /Image/               then type[:image]      = true
          when /Visual/, /Physical/           then type[:image]      = true
          when 'Government Document'          then type[:govdoc]     = true
          when /^Journal/, /Article/          then type[:article]    = true
          when 'Book'                         then type[:book]       = true
        end
      end
      type_key = TYPE_TABLE.keys.find { |key| type[key] }
      (type_key && export_type) ? TYPE_TABLE[type_key][export_type] : type_key
      # rubocop:enable Style/MultilineOperationIndentation
    end

    # A mapping of reference type keys to the matching reference types in each
    # citation export format.
    #
    # The order of the entries defines the precedence.  For example, if a
    # a given item has format 'Manuscript; Musical Score' then the result for
    # Zotero RIS and RefWorks will be the entry for :score.  (For EndNote it
    # will be :manuscript because there is no equivalent applicable reference
    # type).
    #
    TYPE_TABLE = {
      # rubocop:disable Metrics/LineLength
      score:      { ris: 'MUSIC',                                 refworks: 'Music Score' },
      manuscript: { ris: 'MANSCPT', endnote: 'Manuscript',        refworks: 'Unpublished Material' },
      newspaper:  { ris: 'NEWS' },
      etd:        { ris: 'THES',    endnote: 'Thesis',            refworks: 'Dissertation/Thesis' },
      map:        { ris: 'MAP',     endnote: 'Map',               refworks: 'Map' },
      video:      { ris: 'VIDEO',   endnote: 'Film or Broadcast', refworks: 'Video/DVD' },
      audio:      { ris: 'SOUND',   endnote: 'Sound Recording',   refworks: 'Audiovisual Material' },
      image:      { ris: 'ART',     endnote: 'Artwork',           refworks: 'Artwork' },
      govdoc:     { ris: 'GOVDOC',  endnote: 'Government Document' },
      article:    { ris: 'JOUR',    endnote: 'Journal Article',   refworks: 'Journal Article' },
      book:       { ris: 'BOOK',    endnote: 'Book',              refworks: 'Book, Whole' },
      generic:    { ris: 'GEN',     endnote: 'Generic',           refworks: 'Generic' },
      # rubocop:enable Metrics/LineLength
    }

    # =========================================================================
    # :section: Citation Export (Title components)
    # =========================================================================

    public

    # The full title (without medium) joined into a single line for export.
    #
    # @param [Hash] opt               @see self#return_export
    #
    # @return [String]
    # @return [nil]                   If there was no data for the field.
    #
    # @see self#basic_title
    #
    def export_title(opt = {})
      opt[:value] = full_title(except: :medium) unless opt.key?(:value)
      return_export(__method__, opt)
    end

    # =========================================================================
    # :section: Citation Export (Bibliographic information)
    # =========================================================================

    public

    # Results of the related get_* method joined into a single line for export.
    #
    # @param [Hash] opt               @see self#return_export
    #
    # @return [String]
    # @return [nil]                   If there was no data for the field.
    #
    # @see self#get_format
    #
    def export_format(opt = {})
      return_export(__method__, opt)
    end

    # Results of the related get_* method joined into a single line for export.
    #
    # @param [Hash] opt               @see self#return_export
    #
    # @return [String]
    # @return [nil]                   If there was no data for the field.
    #
    # @see self#get_work_type
    #
    def export_work_type(opt = {})
      return_export(__method__, opt)
    end

    # Results of the related get_* method joined into a single line for export.
    #
    # @param [Hash] opt               @see self#return_export
    #
    # @return [String]
    # @return [nil]                   If there was no data for the field.
    #
    # @see self#get_edition
    #
    def export_edition(opt = {})
      return_export(__method__, opt)
    end

    # Results of the related get_* method joined into a single line for export.
    #
    # @param [Hash] opt               @see self#return_export
    #
    # @return [String]
    # @return [nil]                   If there was no data for the field.
    #
    # @see self#get_edition_statement
    #
    def export_edition_statement(opt = {})
      return_export(__method__, opt)
    end

    # Results of the related get_* method joined into a single line for export.
    #
    # @param [Boolean] value          @see self#get_pub_year
    # @param [Hash]    opt            @see self#return_export
    #
    # @return [String]
    # @return [nil]                   If there was no data for the field.
    #
    # @see self#get_pub_year
    #
    def export_pub_year(value = nil, opt = {})
      return_export(__method__, value, opt)
    end

    # Results of the related get_* method joined into a single line for export.
    #
    # @param [Boolean] value          @see self#get_pub_date
    # @param [Hash]    opt            @see self#return_export
    #
    # @return [String]
    # @return [nil]                   If there was no data for the field.
    #
    # @see self#get_pub_date
    #
    def export_pub_date(value = nil, opt = {})
      return_export(__method__, value, opt)
    end

    # Results of the related get_* method joined into a single line for export.
    #
    # @param [Hash] opt               @see self#return_export
    #
    # @return [String]
    # @return [nil]                   If there was no data for the field.
    #
    # @see self#get_pub_statement
    #
    def export_pub_statement(opt = {})
      return_export(__method__, opt)
    end

    # Results of the related get_* method joined into a single line for export.
    #
    # @param [Hash] opt               @see self#return_export
    #
    # @return [String]
    # @return [nil]                   If there was no data for the field.
    #
    # @see self#get_publisher
    #
    def export_publisher(opt = {})
      return_export(__method__, opt)
    end

    # Results of the related get_* method joined into a single line for export.
    #
    # @param [Array] parts            @see self#return_export
    #
    # @return [String]
    # @return [nil]                   If there was no data for the field.
    #
    # @see self#get_copyright_and_permissions
    def export_copyright_and_permissions(*parts)
      return_export(__method__, *parts)
    end

    # Results of the related get_* method joined into a single line for export.
    #
    # @param [Hash] opt               @see self#return_export
    #
    # @return [String]
    # @return [nil]                   If there was no data for the field.
    #
    # @see self#get_publication_place
    #
    def export_publication_place(opt = {})
      return_export(__method__, opt)
    end

    # Results of the related get_* method joined into a single line for export.
    #
    # @param [Hash] opt               @see self#return_export
    #
    # @return [String]
    # @return [nil]                   If there was no data for the field.
    #
    # @see self#get_uniform_title
    #
    def export_uniform_title(opt = {})
      return_export(__method__, opt)
    end

    # Results of the related get_* method joined into a single line for export.
    #
    # @param [Hash] opt               @see self#return_export
    #
    # @return [String]
    # @return [nil]                   If there was no data for the field.
    #
    # @see self#get_series
    #
    def export_series(opt = {})
      return_export(__method__, opt)
    end

    # Results of the related get_* method joined into a single line for export.
    #
    # @param [Hash] opt               @see self#return_export
    #
    # @return [String]
    # @return [nil]                   If there was no data for the field.
    #
    # @see self#get_series_statement
    #
    def export_series_statement(opt = {})
      return_export(__method__, opt)
    end

    # Results of the related get_* method joined into a single line for export.
    #
    # @param [Hash] opt               @see self#return_export
    #
    # @return [String]
    # @return [nil]                   If there was no data for the field.
    #
    # @see self#get_collection
    #
    def export_collection(opt = {})
      return_export(__method__, opt)
    end

    # Results of the related get_* method joined into a single line for export.
    #
    # NOTE: For many/most export formats, use #get_authors instead.
    #
    # @param [Hash] opt               @see self#return_export
    #
    # @return [String]
    # @return [nil]                   If there was no data for the field.
    #
    # @see self#get_authors
    #
    def export_authors(opt = {})
      return_export(__method__, opt)
    end

    # Results of the related get_* method joined into a single line for export.
    #
    # NOTE: For many/most export formats, use #get_advisors instead.
    #
    # @param [Hash] opt               @see self#return_export
    #
    # @return [String]
    # @return [nil]                   If there was no data for the field.
    #
    # @see self#get_advisors
    #
    def export_advisors(opt = {})
      return_export(__method__, opt)
    end

    # Results of the related get_* method joined into a single line for export.
    #
    # NOTE: For many/most export formats, use #get_directors instead.
    #
    # @param [Hash] opt               @see self#return_export
    #
    # @return [String]
    # @return [nil]                   If there was no data for the field.
    #
    # @see self#get_directors
    #
    def export_directors(opt = {})
      return_export(__method__, opt)
    end

    # Results of the related get_* method joined into a single line for export.
    #
    # @param [Hash] opt               @see self#return_export
    #
    # @return [String]
    # @return [nil]                   If there was no data for the field.
    #
    # @see self#get_language
    #
    def export_language(opt = {})
      return_export(__method__, opt)
    end

    # Results of the related get_* method joined into a single line for export.
    #
    # @param [Hash] opt               @see self#return_export
    #
    # @return [String]
    # @return [nil]                   If there was no data for the field.
    #
    # @see self#get_physical_description
    #
    def export_physical_description(opt = {})
      return_export(__method__, opt)
    end

    # Results of the related get_* method joined into a single line for export.
    #
    # @param [Hash] opt               @see self#return_export
    #
    # @return [String]
    # @return [nil]                   If there was no data for the field.
    #
    # @see self#get_technical_details
    #
    def export_technical_details(opt = {})
      return_export(__method__, opt)
    end

    # Results of the related get_* method joined into a single line for export.
    #
    # @param [Hash] opt               @see self#return_export
    #
    # @return [String]
    # @return [nil]                   If there was no data for the field.
    #
    # @see self#get_recording_information
    #
    def export_recording_information(opt = {})
      return_export(__method__, opt)
    end

    # Results of the related get_* method joined into a single line for export.
    #
    # @param [Hash] opt               @see self#return_export
    #
    # @return [String]
    # @return [nil]                   If there was no data for the field.
    #
    # @see self#get_target_audience
    #
    def export_target_audience(opt = {})
      return_export(__method__, opt)
    end

    # Results of the related get_* method joined into a single line for export.
    #
    # @param [Hash] opt               @see self#return_export
    #
    # @return [String]
    # @return [nil]                   If there was no data for the field.
    #
    # @see self#get_performers
    #
    def export_performers(opt = {})
      return_export(__method__, opt)
    end

    # Results of the related get_* method joined into a single line for export.
    #
    # @param [Hash] opt               @see self#return_export
    #
    # @return [String]
    # @return [nil]                   If there was no data for the field.
    #
    # @see self#get_credits
    #
    def export_credits(opt = {})
      return_export(__method__, opt)
    end

    # Results of the related get_* method joined into a single line for export.
    #
    # @param [Hash] opt               @see self#return_export
    #
    # @return [String]
    # @return [nil]                   If there was no data for the field.
    #
    # @see self#get_plot_summary
    #
    def export_plot_summary(opt = {})
      return_export(__method__, opt)
    end

    # Results of the related get_* method joined into a single line for export.
    #
    # @param [Hash] opt               @see self#return_export
    #
    # @return [String]
    # @return [nil]                   If there was no data for the field.
    #
    # @see self#get_contents
    #
    def export_contents(opt = {})
      return_export(__method__, opt)
    end

    # Results of the related get_* method joined into a single line for export.
    #
    # @param [Hash] opt               @see self#return_export
    #
    # @return [String]
    # @return [nil]                   If there was no data for the field.
    #
    # @see self#get_dissertation_note
    #
    def export_dissertation_note(opt = {})
      return_export(__method__, opt)
    end

    # Results of the related get_* method joined into a single line for export.
    #
    # @param [Hash] opt               @see self#return_export
    #
    # @return [String]
    # @return [nil]                   If there was no data for the field.
    #
    # @see self#get_cite_as
    #
    def export_cite_as(opt = {})
      return_export(__method__, opt)
    end

    # Results of the related get_* method joined into a single line for export.
    #
    # @param [Hash] opt               @see self#return_export
    #
    # @return [String]
    # @return [nil]                   If there was no data for the field.
    #
    # @see self#get_keywords
    #
    def export_keywords(opt = {})
      return_export(__method__, opt)
    end

    # Results of the related get_* method joined into a single line for export.
    #
    # @param [Hash] opt               @see self#return_export
    #
    # @return [String]
    # @return [nil]                   If there was no data for the field.
    #
    # @see self#get_subjects
    #
    def export_subjects(opt = {})
      return_export(__method__, opt)
    end

    # Results of the related get_* method joined into a single line for export.
    #
    # @param [Hash] opt               @see self#return_export
    #
    # @return [String]
    # @return [nil]                   If there was no data for the field.
    #
    # @see self#get_place_names
    #
    def export_place_names(opt = {})
      return_export(__method__, opt)
    end

    # Results of the related get_* method joined into a single line for export.
    #
    # @param [Hash] opt               @see self#return_export
    #
    # @return [String]
    # @return [nil]                   If there was no data for the field.
    #
    # @see self#get_related_names
    #
    def export_related_names(opt = {})
      return_export(__method__, opt)
    end

    # Results of the related get_* method joined into a single line for export.
    #
    # @param [Hash] opt               @see self#return_export
    #
    # @return [String]
    # @return [nil]                   If there was no data for the field.
    #
    # @see self#get_description
    #
    def export_description(opt = {})
      return_export(__method__, opt)
    end

    # Results of the related get_* method joined into a single line for export.
    #
    # @param [Hash] opt               @see self#return_export
    #
    # @return [String]
    # @return [nil]                   If there was no data for the field.
    #
    # @see self#get_abstract
    #
    def export_abstract(opt = {})
      return_export(__method__, opt)
    end

    # Results of the related get_* method joined into a single line for export.
    #
    # @param [Hash] opt               @see self#return_export
    #
    # @return [String]
    # @return [nil]                   If there was no data for the field.
    #
    # @see self#get_notes
    #
    def export_notes(opt = {})
      return_export(__method__, opt)
    end

    # Results of the related get_* method joined into a single line for export.
    #
    # @param [Array<Array<(String, String)>>] parts  Additional entries.
    #
    # @return [String]
    # @return [Array<String>]           If :separator set to *nil*.
    #
    # === Options
    # @see self#label_value_list
    #
    # @see self#get_abstract_fields
    #
    def export_abstract_fields(*parts)
      return_export(__method__, *parts)
    end

    # Results of the related get_* method joined into a single line for export.
    #
    # @param [Array<Array<(String, String)>>] parts  Additional entries.
    #
    # @return [String]
    # @return [Array<String>]           If :separator set to *nil*.
    #
    # === Options
    # @see self#label_value_list
    #
    # @see self#get_note_fields
    #
    def export_note_fields(*parts)
      return_export(__method__, *parts)
    end

    # =========================================================================
    # :section: Citation Export (Identifiers)
    # =========================================================================

    public

    # Results of the related get_* method joined into a single line for export.
    #
    # @param [Hash] opt               @see self#return_export
    #
    # @return [String]
    # @return [nil]                   If there was no data for the field.
    #
    # @see self#get_isbn
    #
    def export_isbn(opt = {})
      return_export(__method__, opt)
    end

    # Results of the related get_* method joined into a single line for export.
    #
    # @param [Hash] opt               @see self#return_export
    #
    # @return [String]
    # @return [nil]                   If there was no data for the field.
    #
    # @see self#get_oclc
    #
    def export_oclc(opt = {})
      return_export(__method__, opt)
    end

    # The "proper" term for an OCLC number is "OCN" (OCLC Control Number).
    #
    alias_method(:export_ocn, :export_oclc)

    # Results of the related get_* method joined into a single line for export.
    #
    # @param [Hash] opt               @see self#return_export
    #
    # @return [String]
    # @return [nil]                   If there was no data for the field.
    #
    # @see self#get_lccn
    #
    def export_lccn(opt = {})
      return_export(__method__, opt)
    end

    # Results of the related get_* method joined into a single line for export.
    #
    # @param [Hash] opt               @see self#return_export
    #
    # @return [String]
    # @return [nil]                   If there was no data for the field.
    #
    # @see self#get_upc
    #
    def export_upc(opt = {})
      return_export(__method__, opt)
    end

    # Results of the related get_* method joined into a single line for export.
    #
    # @param [Hash] opt               @see self#return_export
    #
    # @return [String]
    # @return [nil]                   If there was no data for the field.
    #
    # @see self#get_issn
    #
    def export_issn(opt = {})
      return_export(__method__, opt)
    end

    # Results of the related get_* method joined into a single line for export.
    #
    # @param [Hash] opt               @see self#return_export
    #
    # @return [String]
    # @return [nil]                   If there was no data for the field.
    #
    # @see self#get_doi
    #
    def export_doi(opt = {})
      return_export(__method__, opt)
    end

    # Results of the related get_* method joined into a single line for export.
    #
    # @param [Hash] opt               @see self#return_export
    #
    # @return [String]
    # @return [nil]                   If there was no data for the field.
    #
    # @see self#get_standard_identifiers
    #
    def export_standard_identifiers(opt = {})
      return_export(__method__, opt)
    end

    # Results of the related get_* method joined into a single line for export.
    #
    # @param [Hash] opt               @see self#return_export
    #
    # @return [String]
    # @return [nil]                   If there was no data for the field.
    #
    # @see self#get_url
    #
    def export_url(opt = {})
      return_export(__method__, opt)
    end

    # Results of the related get_* method joined into a single line for export.
    #
    # @param [Hash] opt               @see self#return_export
    #
    # @return [String]
    # @return [nil]                   If there was no data for the field.
    #
    # @see self#get_media_retrieval_id
    #
    def export_media_retrieval_id(opt = {})
      return_export(__method__, opt)
    end

    # Results of the related get_* method joined into a single line for export.
    #
    # @param [Hash] opt               @see self#return_export
    #
    # @return [String]
    # @return [nil]                   If there was no data for the field.
    #
    # @see self#get_call_numbers
    #
    def export_call_numbers(opt = {})
      return_export(__method__, opt)
    end

    # Results of the related get_* method joined into a single line for export.
    #
    # @param [Hash] opt               @see self#return_export
    #
    # @return [String]
    # @return [nil]                   If there was no data for the field.
    #
    # @see self#get_shelf_numbers
    #
    def export_shelf_numbers(opt = {})
      return_export(__method__, opt)
    end

    # =========================================================================
    # :section: Citation Export (Articles)
    # =========================================================================

    public

    # Results of the related get_* method joined into a single line for export.
    #
    # @param [Hash] opt               @see self#return_export
    #
    # @return [String]
    # @return [nil]                   If there was no data for the field.
    #
    # @see self#get_type
    #
    def export_type(opt = {})
      return_export(__method__, opt)
    end

    # Results of the related get_* method joined into a single line for export.
    #
    # @param [Hash] opt               @see self#return_export
    #
    # @return [String]
    # @return [nil]                   If there was no data for the field.
    #
    # @see self#get_is_part_of
    #
    def export_is_part_of(opt = {})
      return_export(__method__, opt)
    end

    # Results of the related get_* method joined into a single line for export.
    #
    # @param [Hash] opt               @see self#return_export
    #
    # @return [String]
    # @return [nil]                   If there was no data for the field.
    #
    # @see self#get_journal
    #
    def export_journal(opt = {})
      return_export(__method__, opt)
    end

    # Results of the related get_* method joined into a single line for export.
    #
    # @param [Hash] opt               @see self#return_export
    #
    # @return [String]
    # @return [nil]                   If there was no data for the field.
    #
    # @see self#get_volume
    #
    def export_volume(opt = {})
      return_export(__method__, opt)
    end

    # Results of the related get_* method joined into a single line for export.
    #
    # @param [Hash] opt               @see self#return_export
    #
    # @return [String]
    # @return [nil]                   If there was no data for the field.
    #
    # @see self#get_issue
    #
    def export_issue(opt = {})
      return_export(__method__, opt)
    end

    # Results of the related get_* method joined into a single line for export.
    #
    # @param [Hash] opt               @see self#return_export
    #
    # @return [String]
    # @return [nil]                   If there was no data for the field.
    #
    # @see self#get_start_page
    #
    def export_start_page(opt = {})
      return_export(__method__, opt)
    end

    # Results of the related get_* method joined into a single line for export.
    #
    # @param [Hash] opt               @see self#return_export
    #
    # @return [String]
    # @return [nil]                   If there was no data for the field.
    #
    # @see self#get_end_page
    #
    def export_end_page(opt = {})
      return_export(__method__, opt)
    end

    # Results of the related get_* method joined into a single line for export.
    #
    # @param [String] separator       @see self#get_pages
    # @param [Hash]   opt             @see self#return_export
    #
    # @return [String]
    # @return [nil]                   If there was no data for the field.
    #
    # @see self#get_pages
    #
    def export_pages(separator = nil, opt = {})
      opt[:separator] = separator if separator
      return_export(__method__, opt)
    end

    # Results of the related get_* method joined into a single line for export.
    #
    # @param [Hash] opt               @see self#return_export
    #
    # @return [String]
    # @return [nil]                   If there was no data for the field.
    #
    # @see self#get_accession_number
    #
    def export_accession_number(opt = {})
      return_export(__method__, opt)
    end

    # Results of the related get_* method joined into a single line for export.
    #
    # @param [Hash] opt               @see self#return_export
    #
    # @return [String]
    # @return [nil]                   If there was no data for the field.
    #
    # @see self#get_identifiers
    #
    def export_identifiers(opt = {})
      return_export(__method__, opt)
    end

    # =========================================================================
    # :section: Citation Export
    # =========================================================================

    protected

    # A generalized mechanism for implementing an "export_" method in terms of
    # its related "get_" method.
    #
    # @param [Symbol] caller          Invoking method.
    # @param [Array]  args
    #
    # @option args [Array<String>, String] :value
    #                                   If supplied, this value is used rather
    #                                     than invoking the method implied by
    #                                     *caller*.
    # @option args [Boolean] :ascii     Translate some extended characters into
    #                                     an acceptable 7-bit ASCII equivalent.
    # @option args [Fixnum] :limit      If *value* is an array, take only the
    #                                     first *limit* items.
    # @option args [String] :separator  If *value* is an array, this string is
    #                                     used to join the parts.  If not
    #                                     supplied, ITEM_SEPARATOR is used as
    #                                     the default.
    #
    # @return [String]
    # @return [nil]                   If there was no data for the field.
    #
    def return_export(caller, *args)
      opt = args.last.is_a?(Hash) ? args.pop : {}

      # Get the default options for the item associated with the caller and
      # use them to supply defaults for settings not already in *opt*.
      default_opt = item_defaults(caller)
      opt = default_opt.merge(opt) if default_opt.present?

      # Get the value for the item associated with the caller unless it was
      # already supplied through the option hash.
      value = opt.key?(:value) ? opt[:value] : item_value(caller, *args)
      return if value.blank?

      # Return the value, joined with the default or supplied :separator
      # (unless it was explicitly set to *nil*).
      if value.is_a?(Array)
        separator = opt.key?(:separator) ? opt[:separator] : ITEM_SEPARATOR
        separator = nil unless separator
        limit = opt[:limit]
        value = value.take(limit) if limit.is_a?(Fixnum) && (limit > 0)
        value = value.join(separator)
      end

      # Return with the value stripped of HTML elements and entities.
      strip_html(value, ascii: opt[:ascii])
    end

    # Update the array so that its final element is guaranteed to be an option
    # hash.  If *default_opt* is supplied, its key-value pairs will be copied
    # to that option hash (except for any keys that were already present).
    #
    # @param [Symbol] caller          Invoking method.
    # @param [Array]  parts           The array to modify, whose last element
    #                                   may or may not already be a Hash.
    # @param [Hash]   override        Overrides the default settings (settings
    #                                   explicitly in the *parts* option hash
    #                                   will still take precedence).
    #
    # @return [Array]                 The (potentially modified) source array.
    #
    def update_options(caller, parts, override = nil)
      update_array(parts, override) if override.is_a?(Hash)
      update_array(parts, item_defaults(caller))
      parts
    end

    # Generate a list for export or display comprised of labels and values.
    # TODO: describe...
    #
    # @param [Array<Array<(String, String)>>] parts
    #
    # @return [Array<String>]         If :separator is missing or *false*.
    # @return [String]                If :separator is a string or *true*.
    # @return [Array<Array<String>>]  If :inner_separator is set to *false*.
    #
    # === Options
    # @option parts [String] :separator  Separation between result elements:
    #
    # * If *nil* then the parts will be concatenated with no separation.
    # * If *true* then the parts will be joined with "\n".
    # * If *false* (or missing) then the method will return an array.
    #
    # @option parts [String] :label_tag
    #
    # @option parts [String] :label_css
    #
    # @option parts [String] :inner_sep  Handling of array field values:
    #
    # * If *nil* the resulting entry will be a concatenation of the array
    #   elements with no separation.
    # * If *true* (or missing) the resulting entry will be a string made from
    #   the array elements joined with LIST_SEPARATOR.
    # * If *false* then the resulting entry for any field value (array or not)
    #   will be an array whose first element is the label and following
    #   elements are the field value(s).
    #
    #   @note Setting :inner_sep to *false* forces :separator to *false*.
    #
    # @option parts [Boolean] :marc   MARC fields:
    #
    # * If *true* then interpret a symbol in the label field as specifying the
    #   MARC method to use to acquire the value for the field.
    # * If missing, *nil*, or *false* then symbols are interpreted as
    #   specifying index fields.
    #
    def label_value_list(*parts)
      label_open = label_close = nil

      # Extract options.
      opt = parts.last.is_a?(Hash) ? parts.pop : {}
      label_tag = opt[:label_tag]
      label_css = opt[:label_css]
      separator = opt[:separator]
      inner_sep = opt[:inner_sep]
      use_marc  = opt[:marc] && marc_display

      # Adjust options and setup results formatting.
      if label_css
        label_tag ||= :div
        label_css = " class=\"#{label_css}\""
      end
      if label_tag
        label_open  = "<#{label_tag}#{label_css}>"
        label_close = "</#{label_tag}>"
      end
      case separator
        when false then separator = nil
        when true  then separator = NEWLINE
        when nil   then separator = INLINE_BREAK
      end
      case inner_sep
        when false then inner_sep = nil
        when true  then inner_sep = LIST_SEPARATOR
        when nil   then inner_sep = INLINE_BREAK
      end

      result =
        parts.flat_map { |label_and_value|
          case label_and_value
            when nil   then next
            when Array then label, value = label_and_value
            else            label = nil; value = label_and_value
          end
          value = evaluate(value, marc: use_marc) if value.is_a?(Symbol)
          next if value.blank?
          label = "#{label_open}#{label}#{label_close}: " if label.present?
          if inner_sep
            value = value.join(inner_sep) if value.is_a?(Array)
            "#{label}#{value}"
          elsif label
            [label, *value]
          else
            value
          end
        }.compact
      (separator && inner_sep) ? result.join(separator) : result
    end

    # =========================================================================
    # :section:
    # =========================================================================

    protected

    # Update an array so that its last element is an option hash with *options*
    # providing the default settings.
    #
    # After running this method the last element of *args* will be a hash (even
    # if it is an empty one).
    #
    # @param [Array] args             The array to be modified.
    # @param [Hash]  opt
    #
    # @return [void]
    #
    def update_array(args, opt)
      return unless args.is_a?(Array)
      opt = {} unless opt.is_a?(Hash)
      if args.last.is_a?(Hash)
        args[-1].reverse_merge!(opt) if opt.present?
      else
        args << opt
      end
    end

    # Map a caller name to a key in the DEFAULT hash.
    #
    # @param [Symbol] caller          Typically, the value of __method__ in the
    #                                   caller.
    #
    # @return [Symbol]                The DEFAULT hash key associated with the
    #                                   caller.
    # @return [nil]                   The caller is not associated with a
    #                                   DEFAULT hash entry.
    #
    # === Examples
    # @example Export method
    #   item_key(:export_pub_date) #=> :pub_date
    #
    # @example Get method
    #   item_key(:get_pub_date) #=> :pub_date
    #
    # @example Special handling if the symbol is already an item key.
    #   item_key(:pub_date) #=> :pub_date (not :date)
    #
    def item_key(caller)
      caller = caller.to_sym
      if DEFAULT.key?(caller)
        caller
      else
        item_name = caller.to_s.sub(/^[^_]+_/, '')
        item_name.to_sym if item_name.present?
      end
    end

    # Get a copy of DEFAULT option hash associated with the caller.
    #
    # @param [Symbol] caller          Typically, the value of __method__ in the
    #                                   caller.
    #
    # @return [Hash]                  The default settings for the item.
    # @return [nil]                   Return from get_* method, or *caller* was
    #                                   not valid.
    #
    # @see self#DEFAULT
    #
    # === Examples
    # @example Export method
    #   item_defaults(:export_pub_date) #=> DEFAULT[:pub_date]
    #
    # @example Get method
    #   item_defaults(:get_pub_date) #=> DEFAULT[:pub_date]
    #
    # @example Special handling if the symbol is already an item key.
    #   item_defaults(:pub_date) #=> DEFAULT[:pub_date]
    #
    def item_defaults(caller)
      item = item_key(caller)
      result = item && DEFAULT[item]
      result.dup if result.present?
    end

    # Invoke the proper get_* function on behalf of the caller.
    #
    # @param [Symbol] caller          Typically, the value of __method__ in the
    #                                   caller.
    # @param [Array]  args            Optional arguments to be passed to the
    #                                   get_* method.
    #
    # @return [Array<String>]         Return from the get_* method that is
    #                                   associated with *caller*.
    # @return [nil]                   Either the actual return from the get_*
    #                                   method no get_* method could be found
    #                                   that is associated with the *caller*.
    #
    # === Examples
    # @example Export method
    #   item_value(:export_pub_date, arg1) #=> pub_date(arg1)
    #
    # @example Get method
    #   item_value(:get_pub_date, arg1) #=> pub_date(arg1)
    #
    # @example Special handling if the symbol is already an item key.
    #   item_value(:pub_date, arg1) #=> pub_date(arg1)
    #
    def item_value(caller, *args)
      item = item_key(caller)
      send("get_#{item}".to_sym, *args) if item
    end

    # =========================================================================
    # :section: Test and development
    # =========================================================================

    public

    # Format a Hash value for verbose debug output.
    #
    # @param [Hash]    hash
    # @param [String]  newline
    # @param [Boolean] expanded
    # @param [Fixnum]  max_size
    #
    # @return [String]
    #
    def inspect_hash(hash, newline = NEWLINE, expanded = true, max_size = 80)
      hash_frozen  = hash.frozen? ? '[frozen] ' : nil
      hash_display =
        if expanded
          hash.pretty_inspect
            .sub(/\A{/, "{\n ")
            .sub(/}[\s\n]*\Z/, "\n}")
            .gsub(/=>/, ' \0 ')
            .gsub(/\n/, "#{newline}")
        else
          hash.sort_by { |field, _content| field.to_s }.map { |pair|
            field, content = pair
            lbracket, rbracket =
              case content
                when Hash  then %w({ })
                when Array then %w([ ])
              end
            content =
              case content
                when Hash
                  content.empty? ? '' : "(#{content.size} entries)"
                when Array
                  case content.size
                    when 0    then ''
                    when 1, 2 then content.map(&:inspect).join(LIST_SEPARATOR)
                    else           "(#{content.size} elements)"
                  end
                else
                  content.inspect
              end
            "#{field} => #{lbracket}#{content.truncate(max_size)}#{rbracket}"
          }.join(newline).prepend("{#{newline}").concat("#{newline}}")
        end
      "(#{hash.size} elements) #{hash_frozen}#{hash_display}"
    end

  end

end
