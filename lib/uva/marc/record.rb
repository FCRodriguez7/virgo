# lib/uva/marc/record.rb

require 'uva'
require 'uva/marc/relator'

# Methods for assembling bibliographic information from MARC records.
#
# === References
# @see https://www.loc.gov/marc/bibliographic/
# @see https://www.oclc.org/bibformats/en.html
#
#--
# rubocop:disable Metrics/ClassLength # [748/300]
#++
class UVA::Marc::Record

  include UVA
  include UVA::Marc::Relator
  include UVA::Util::HtmlMethods
  include UVA::Util::Dev

  Debug.setup(
    active:              Virgo.desktop_development?,
    initialize:          false,
    publisher:           false,
    get_author_list:     false,
    get_related_names:   false,
    get_fields:          false,
    get_subfield_values: false,
  )

  # Even when implicitly gathering all available subfields of a MARC field,
  # these subfields are not included by default they do not contain information
  # which is directly part of the data of the field.
  IGNORED_SUBFIELDS = %w(w 0 5 6 8).deep_freeze

  # The selection of subfields of MARC 100, 110, 111, 700, 710, and 711 used to
  # extract just the name without any other ancillary information (year of
  # birth, year of death, etc).
  NAME_SUBFIELDS = 'abc'.freeze

  # If *true* Marc::Record will be frozen after creation.
  #
  # === Implementation Notes
  # The strategy of freezing Marc::Record is test/development environments can
  # be problematic in conjunction with caching.  For now this will be disabled.
  #
  MARC_DEEP_FREEZE = false

  # ===========================================================================
  # :section:
  # ===========================================================================

  public

  # @return [MARC::Record]
  attr_reader :record

  # @param [String, Array] marc_src
  # @param [Symbol]        format
  #
  # @option format [Symbol] :xml
  # @option format [Symbol] :raw
  #
  def initialize(marc_src, format = :raw)
    @record =
      if marc_src.is_a?(MARC::Record)
        marc_src
      elsif (marc_src = marc_src.to_s)
        # Mirrors logic of Blacklight::Solr::Document::Marc#load_marc.
        case format.to_s
          when 'xml', 'marcxml'
            MARC::XMLReader.new(StringIO.new(marc_src)).first
          when 'raw', 'marc21'
            MARC::Record.new_from_marc(marc_src, forgiving: true)
        end
      end

    # In all non-production environments, freeze the extracted MARC values to
    # discover any situations in which the data is inadvertently modified.
    deep_freeze if deep_freeze_enabled?
    debug_self(__method__) if Debug[__method__]
  end

  # ===========================================================================
  # :section: MARC fields
  # ===========================================================================

  public

  # == MARC 010$a - LCCN - "Library of Congress Control Number" (NR)
  #
  # These often have leading spaces; also, some appear to have cruft after the
  # number, so take the number before a space.
  #
  # The method returns an array for consistency with similar methods, but the
  # array should have only a single element.  (If there are multiple elements
  # that would indicate the MARC record is not well-formed.)
  #
  # @return [Array<String>]
  #
  # @example
  #   <subfield code="a">   63009960 //r64</subfield>
  #
  # === References
  # @see https://www.loc.gov/marc/bibliographic/bd010.html
  #
  def lc_control_number
    values_of('010', 'a').map { |v| v.split(SPACE).first }
  end

  # == MARC 020 - ISBN - "International Standard Book Number" (R)
  #
  # @return [Array<String>]
  #
  # === References
  # @see https://www.loc.gov/marc/bibliographic/bd020.html
  #
  def isbn
    get_fields('020').flat_map { |field|
      get_subfield_values(field, 'az')
    }.clean_uniq(PHRASE_END)
  end

  # == MARC 022 - ISSN - "International Standard Serial Number" (R)
  #
  # @return [Array<String>]
  #
  # === References
  # @see https://www.loc.gov/marc/bibliographic/bd022.html
  #
  def issn
    get_fields('022').flat_map { |field|
      get_subfield_values(field, 'az')
    }.clean_uniq(PHRASE_END)
  end

  # == MARC 024$a - UPC - "Other Standard Identifier" (R)
  # Universal Product Code.
  #
  # @return [Array<String>]
  #
  # === References
  # @see https://www.loc.gov/marc/bibliographic/bd024.html
  #
  def upc
    values_of('024', 'a', indicator1: 1)
  end

  # == MARC 028 - "Publisher Number" (R)
  #
  # @return [Array<String>]
  #
  # === References
  # @see https://www.loc.gov/marc/bibliographic/bd028.html
  #
  def label_no
    values_of('028')
  end

  # == MARC 035$a - OCLC numbers [a.k.a OCN] - "System Control Number" (R)
  #
  # If the value begins with "(OCoLC)" strip OCoLC to get the actual number.
  # Values that do not have "(OCoLC)" are not OCLC numbers and are not included
  # in the returned array.  For example:
  #
  #   <subfield code="a">(OCoLC)00328354</subfield>
  #
  # Variants (e.g., OCoLC-C, OCoLC-D, etc.) are accepted; entries with codes
  # from other organizations are ignored.
  #
  # @return [Array<String>]
  #
  # === References
  # @see https://www.loc.gov/marc/bibliographic/bd035.html
  # @see https://www.oclc.org/bibformats/en/0xx/035.html
  # @see https://www.loc.gov/marc/organizations/org-search.php
  #
  def oclc_number
    values_of('035', 'a').map { |v|
      case v
        when /^\s*\(OCoLC(-[A-Z]+)?\)/, /^\s*ocm0*/, /^\s*ocn/
          v.sub($LAST_MATCH_INFO.regexp, '')
      end
    }.compact
  end

  # == MARC 035$a - OCN (OCLC Control Number) - "System Control Number" (R)
  # The "proper" term for an OCLC number is "OCN" (OCLC Control Number).
  #
  alias_method(:ocn, :oclc_number)

  # == MARC 050 - "Library of Congress Call Number" (R)
  # == MARC 090 - "Local LOC Call Number Entry" (R)
  # == MARC 999 - "Local Per-Item Call Number Entry" (R)
  #
  # Subfields for each field are combined so that there is exactly one space
  # between them.  For example:
  #
  #   <subfield code="a">QA123</subfield><subfield code="b"> .B45</subfield>
  #   <subfield code="a">QA123</subfield><subfield code="b">.B45</subfield>
  #
  # would both be returned as
  #
  #   "QA123 .B45"
  #
  # This method is consulted for non-catalog items for virtual shelf browse.
  #
  # @return [Array<String>]
  #
  # === References
  # @see https://www.loc.gov/marc/bibliographic/bd050.html
  # @see https://www.oclc.org/bibformats/en/0xx/090.html
  # @see https://www.oclc.org/bibformats/en/9xx.html
  #
  def call_number

    # Get local LOC call number(s) followed by standard LOC call numbers(s).
    fields = get_fields('090') + get_fields('050')
    result =
      fields.map { |field|
        v = get_subfield_values(field, 'ab').join(SPACE).squeeze(SPACE)
        v unless v.blank? || (v =~ /^[IOWXY]/)
      }.clean_uniq
    return result if result.present?

    # If no call numbers were found in the standard fields, get number(s) from
    # the local holdings information.  (This may be problematic because there
    # are plenty of cases where )
    get_fields('999').map { |field|
      number = ignore_field = nil
      field.subfields.each do |sf|
        value = sf.value
        value = value.strip if value
        next if value.blank?
        case sf.code
          when 'w'
            # Ignore explicit non-LC schemes (e.g. ALPHANUM, LCPER, SUDOC,
            # SUDOC-SER, WEB, WEB-SERL).
            ignore_field = !%w(LC MONO-SER).include?(value)
          when 'l'
            # Ignore non-existent copies.
            ignore_field = %w(WITHDRAWN).include?(value)
          when 'a'
            # Ignore patently non-LC numbers.
            ignore_field =
              value.blank? || (value =~ /^[IOWXY]/) || (value =~ /^[^A-Z]/)
            number = value
        end
        if ignore_field
          number = nil
          break
        end
      end
      number
    }.clean_uniq

  end

  # == MARC 086 - "Government Document Classification Number" (R) [SuDoc]
  # Also referred to as the "SuDoc" (Superintendent of Documents) number for
  # U.S. government documents.
  #
  # @param [Boolean] us_only          Only Superintendent of Documents numbers.
  #
  # @return [Array<String>]
  #
  # === References
  # @see https://www.loc.gov/marc/bibliographic/bd086.html
  #
  # === Notes
  # NOTE: Many of things in the catalog classified as "Government Document"
  # are missing this MARC field and should probably not be classified that way.
  #
  def sudoc_number(us_only = true)
    opt = {}
    opt[:indicator1] = 0 if us_only
    values_of('086', 'a', opt)
  end

  # == MARC 100$a - "Main Entry-Personal Name" (NR)
  # This MARC field is present if the primary author is a person.
  #
  # MARC 100, 110, and 111 are mutually exclusive; a well-formed MARC record
  # will only have a single instance of one of these fields.
  #
  # The method returns an array for consistency with similar methods, but the
  # array should have only a single element.  (If there are multiple elements
  # that would indicate the MARC record is not well-formed.)
  #
  # @return [Array<String>]
  #
  # @see self#get_primary_author
  #
  # === References
  # @see https://www.loc.gov/marc/bibliographic/bd100.html
  #
  def main_entry_personal_name
    values_of('100', 'a').map { |v| v.sub(PHRASE_END, '') }
  end

  # == MARC 110 - "Main Entry-Corporate Name" (NR)
  # This MARC field is present if the primary author is a company or other
  # corporate body.
  #
  # MARC 100, 110, and 111 are mutually exclusive; a well-formed MARC record
  # will only have a single instance of one of these fields.
  #
  # The method returns an array for consistency with similar methods, but the
  # array should have only a single element.  (If there are multiple elements
  # that would indicate the MARC record is not well-formed.)
  #
  # @return [Array<String>]
  #
  # @see self#get_primary_author
  #
  # === References
  # @see https://www.loc.gov/marc/bibliographic/bd110.html
  #
  def main_entry_corporate_body
    values_of('110')
  end

  # == MARC 111 - "Main Entry-Meeting Name" (NR)
  # This MARC field is present if the primary author is a conference or other
  # named event.
  #
  # MARC 100, 110, and 111 are mutually exclusive; a well-formed MARC record
  # will only have a single instance of one of these fields.
  #
  # The method returns an array for consistency with similar methods, but the
  # array should have only a single element.  (If there are multiple elements
  # that would indicate the MARC record is not well-formed.)
  #
  # @return [Array<String>]
  #
  # @see self#get_primary_author
  #
  # === References
  # @see https://www.loc.gov/marc/bibliographic/bd111.html
  #
  def main_entry_conference
    values_of('111')
  end

  # == MARC 130 - "Main Entry-Uniform Title" (NR)
  # == MARC 240 - "Uniform Title" (NR)
  #
  # 240$a = Uniform title for an item when the bibliographic description is
  #         entered under a main entry field that contains a
  #         personal (field 100), corporate (110), or meeting (111) name.
  #
  # There can be only one instance each of MARC 130 and MARC 240.  (The method
  # attempts to avoid duplication, so if this method returns more than one
  # value, there is some possibility that the MARC record is not well-formed.)
  #
  # @return [Array<String>]
  #
  # === References
  # @see https://www.loc.gov/marc/bibliographic/bd130.html
  # @see https://www.loc.gov/marc/bibliographic/bd240.html
  #
  def uniform_title
    get_fields('130', '240').map { |field|
      get_subfield_values(field, '!l').join(SPACE)
    }.clean_uniq(TRAILING_PERIOD)
  end

  # == MARC 210 - "Abbreviated Title" (R)
  #
  # @return [Array<String>]
  #
  # === References
  # @see https://www.loc.gov/marc/bibliographic/bd210.html
  #
  def abbreviated_title
    values_of('210', 'ab')
  end

  # == MARC 245$a - "Title" (NR)
  # The title proper (and optionally alternative title).
  #
  # If formulated according to ISBD principles, it may end with a with the
  # first mark of ISBD punctuation, i.e., an equal sign (=), a colon (:), a
  # semicolon (;) or a slash (/).
  #
  # @return [String]
  # @return [nil]
  #
  # === References
  # @see https://www.loc.gov/marc/bibliographic/bd245.html
  #
  def title
    v = value_of('245', 'a')
    v.sub(TRAILING_SLASH, '') if v.present?
  end

  # == MARC 245$b - "Remainder of title" (NR) [subtitle]
  # If present, this is the subtitle of the work.
  #
  # If formulated according to ISBD principles, it may end with a with a mark
  # of ISBD punctuation: slash (/) if preceding the first statement of
  # responsibility or a period if preceding the name/number of a part/section
  # of a work.
  #
  # @return [String]
  # @return [nil]
  #
  # === References
  # @see https://www.loc.gov/marc/bibliographic/bd245.html
  #
  def subtitle
    v = value_of('245', 'b')
    v.sub(TRAILING_SLASH, '') if v.present?
  end

  # == MARC 245$c - "Statement of responsibility, etc." (NR)
  # This is essentially the author(s)/editor(s)/creator(s) in a style that is
  # well-suited for display.  For programmatic access, use MARC 100, 110, 111
  # for primary author and 700, 710, 711 for secondary author(s).
  #
  # If properly created, this should be the final subfield of the field.
  #
  # @return [String]
  # @return [nil]
  #
  # === References
  # @see https://www.loc.gov/marc/bibliographic/bd245.html
  #
  def responsibility_statement
    value_of('245', 'c')
  end

  # == MARC 245$f - "Inclusive Dates" (NR)
  # For archival materials, the time span over which the described materials
  # were created.
  #
  # @return [String]
  # @return [nil]
  #
  # @see self#bulk_dates
  #
  # === References
  # @see https://www.loc.gov/marc/bibliographic/bd245.html
  #
  def inclusive_dates
    value_of('245', 'f')
  end

  # == MARC 245$g - "Bulk Dates" (NR)
  # For archival materials, the time span over which the majority of the
  # described materials were created.
  #
  # @return [String]
  # @return [nil]
  #
  # @see self#inclusive_dates
  #
  # === References
  # @see https://www.loc.gov/marc/bibliographic/bd245.html
  #
  def bulk_dates
    value_of('245', 'g')
  end

  # == MARC 245$h - "Medium" (NR)
  # E.g. "[videorecording]".
  #
  # If formulated according to ISBD principles, the value will be all lowercase
  # and enclosed in square brackets ([]).
  #
  # @return [String]
  # @return [nil]
  #
  # === References
  # @see https://www.loc.gov/marc/bibliographic/bd245.html
  #
  def medium
    v = value_of('245', 'h')
    v.sub(TRAILING_SLASH, '') if v.present?
  end

  # == MARC 245$k - "Form" (R)
  # For archival materials, a term which is descriptive of the form of the
  # described materials.
  #
  # Returned as a string for consistency with similar methods related to the
  # construction of the "full title"; if there are multiple values they will
  # be separated by LIST_SEPARATOR.
  #
  # @return [String]
  # @return [nil]
  #
  # === References
  # @see https://www.loc.gov/marc/bibliographic/bd245.html
  #
  def form
    v = values_of('245', 'k')
    v.join(LIST_SEPARATOR).sub(FIELD_END, '') if v.present?
  end

  # == MARC 245$n - "Number of part/section of a work" (R)
  # == MARC 245$p - "Name of part/section of a work" (R)
  #
  # If there is both a $n and $p subfield, they will be returned in the result
  # string joined by a SPACE.
  #
  # @return [String]
  # @return [nil]
  #
  # === References
  # @see https://www.loc.gov/marc/bibliographic/bd245.html
  #
  def part
    field = get_fields('245').first
    v = field && get_subfield_values(field, 'np')
    v.join(SPACE).sub(FIELD_END, '') if v.present?
  end

  # == MARC 246 - "Varying Form of Title" (R)
  #
  # @return [Array<String>]
  #
  # === References
  # @see https://www.loc.gov/marc/bibliographic/bd246.html
  #
  def variant_title
    values_of('246')
  end

  # == MARC 250 - "Edition Statement" (R)
  # Each entry includes the edition number (from 250$a) and any additional
  # information (250$b).
  #
  # @return [Array<String>]
  #
  # For only the edition numbers:
  # @see self#edition
  #
  # === References
  # @see https://www.loc.gov/marc/bibliographic/bd250.html
  #
  def edition_statement
    values_of('250').map do |v|
      strip_brackets(v.sub(PHRASE_END, ''))
    end
  end

  # == MARC 250 - "Edition Statement" (R)
  # Each entry includes only the edition number (from 250$a).
  #
  # @return [Array<String>]
  #
  # For display of the edition number along with information about the edition:
  # @see self#edition_statement
  #
  # === References
  # @see https://www.loc.gov/marc/bibliographic/bd250.html
  #
  def edition
    values_of('250', 'a').map do |v|
      strip_brackets(v.sub(FIELD_END, ''))
    end
  end

  # == MARC 255 - "Cartographic Mathematical Data" (R)
  #
  # @return [Array<String>]
  #
  # === References
  # @see https://www.loc.gov/marc/bibliographic/bd255.html
  #
  def cartographic_math_data
    values_of('255')
  end

  # == MARC 260 - "Publication, Distribution, etc. (Imprint)" (R)
  # == MARC 264 - "Production, Publication, ... and Copyright Notice" (R)
  # A phrase describing the publisher and place of publication.
  #
  # @return [Array<String>]
  #
  # === References
  # @see https://www.loc.gov/marc/bibliographic/bd260.html
  # @see https://www.loc.gov/marc/bibliographic/bd264.html
  #
  def publication_statement
    get_fields('260', '264').map { |field|
      get_subfield_values(field, nil, indicator2: ['#', 0, 1, 2]).join(SPACE)
    }.clean_uniq
  end

  # For now, we're going to ignore $e, $f, and $g, and we're going to assume
  # that a single record has information about one publication event.
  #
  # @return [Array<String>]
  #
  def parse_pub_fields(target_code)
    get_fields('260', '264').map { |field|
      next unless match_indicator?(field.indicator2, '#', 0, 1, 2)
      result = []
      current_code = 'a'
      field.subfields.each do |sf|
        value = sf.value
        value = value.strip if value
        next if value.blank?
        code = sf.code
        result << value.sub(PHRASE_END, '') if code == target_code
        case code
          when 'a'
            case value[-1]
              when ';' then # next subfield is still $a
              when ':' then current_code = 'b'
              when ',' then current_code = 'c'
              else          current_code = nil
            end
          when 'b'
            case value[-1]
              when ':' then # next subfield is still $b
              when ',' then current_code = 'c'
              else          current_code = nil
            end
          when 'c'
            case value[-1]
              when ',' then # next subfield is still $c
              when '.' then current_code = nil
              else          current_code = nil
            end
        end
        break if current_code.nil?
      end
      result.join(LIST_SEPARATOR)
    }.compact
  end

  # == MARC 260 - "Publication, Distribution, etc. (Imprint)" (R)
  # == MARC 264 - "Production, Publication, ... and Copyright Notice" (R)
  # == MARC 502 - "Dissertation Note" (R)
  # Place(s) of publication.
  #
  # A frequent cataloging practice is to use the abbreviation "s.l."
  # ("sine loco" = "without place") as a positive indication that the value is
  # missing (as opposed to overlooked).  These instances are removed from the
  # result.
  #
  # @return [Array<String>]
  #
  # === References
  # @see https://www.loc.gov/marc/bibliographic/bd260.html
  # @see https://www.loc.gov/marc/bibliographic/bd264.html
  # @see https://www.loc.gov/marc/bibliographic/bd502.html
  #
  def publication_place
    result = parse_pub_fields('a') + values_of('502', 'c')
    result.map { |v|
      v = strip_brackets(v.to_s.sub(FIELD_END, ''))
      v unless v =~ /^s\.\s*l\.$/i # "s.l. = sine loco = without place"
    }.clean_uniq
  end

  # == MARC 260 - "Publication, Distribution, etc. (Imprint)" (R)
  # == MARC 264 - "Production, Publication, ... and Copyright Notice" (R)
  # == MARC 502 - "Dissertation Note" (R)
  # Name(s) of the publisher/producer.
  #
  # A frequent cataloging practice is to use the abbreviation "s.n."
  # ("sine nomine" = "without name") as a positive indication that the value is
  # missing (as opposed to overlooked).  These instances are removed from the
  # result.
  #
  # @return [Array<String>]
  #
  # === References
  # @see https://www.loc.gov/marc/bibliographic/bd260.html
  # @see https://www.loc.gov/marc/bibliographic/bd264.html
  # @see https://www.loc.gov/marc/bibliographic/bd502.html
  #
  def publisher
    result = parse_pub_fields('b') + values_of('502', 'c')
    result.map { |v|
      v = strip_brackets(v.to_s.sub(FIELD_END, ''))
      v unless v =~ /^s\.\s*n\.$/i # "s.n. = sine nomine = without name"
    }.clean_uniq
      .tap { |res| Debug.show(__method__) { ">>>> #{res}" } }
  end

  # == MARC 260 - "Publication, Distribution, etc. (Imprint)" (R)
  # == MARC 264 - "Production, Publication, ... and Copyright Notice" (R)
  # == MARC 502 - "Dissertation Note" (R)
  # Publication date(s).
  #
  # A frequent cataloging practice is to use the abbreviation "s.d."
  # ("sine die" = "without day") as a positive indication that the value is
  # missing (as opposed to overlooked).  These instances are removed from the
  # result.
  #
  # @return [Array<String>]
  #
  # === References
  # @see https://www.loc.gov/marc/bibliographic/bd260.html
  # @see https://www.loc.gov/marc/bibliographic/bd264.html
  # @see https://www.loc.gov/marc/bibliographic/bd502.html
  #
  def publication_date
    result = parse_pub_fields('c') + values_of('502', 'd')
    result.map { |v|
      v = strip_brackets(v.to_s.delete(COPYRIGHT).sub(FIELD_END, ''))
      v unless v =~ /^s\.\s*d\.$/i # "s.d. = sine die = without day"
    }.clean_uniq
  end

  # == MARC 300 - "Physical Description" (R)
  #
  # @return [Array<String>]
  #
  # === References
  # @see https://www.loc.gov/marc/bibliographic/bd300.html
  #
  def physical_description
    values_of('300')
  end

  # == MARC 310 - "Current Publication Frequency" (NR)
  #
  # The method returns an array for consistency with similar methods, but the
  # array should have only a single element.  (If there are multiple elements
  # that would indicate the MARC record is not well-formed.)
  #
  # @return [Array<String>]
  #
  # === References
  # @see https://www.loc.gov/marc/bibliographic/bd310.html
  #
  def journal_frequency
    values_of('310')
  end

  # == MARC 351 - "Organization and Arrangement of Materials" (R)
  #
  # @return [Array<String>]
  #
  # === References
  # @see https://www.loc.gov/marc/bibliographic/bd351.html
  #
  def organization_and_arrangement
    values_of('351')
  end

  # == MARC 362 - "Dates of Publication and/or Sequential Designation" (R)
  #
  # @return [Array<String>]
  #
  # === References
  # @see https://www.loc.gov/marc/bibliographic/bd362.html
  #
  def publication_history
    values_of('362')
  end

  # == MARC 410$a - "Series Statement/Added Entry-Corporate Name" (R)
  # == MARC 411$a - "Series Statement/Added Entry Meeting Name" (R)
  # == MARC 440$a - "Series Statement/Added Entry-Title" (R)
  #
  # @return [Array<String>]
  #
  # === References
  # @see https://www.loc.gov/marc/bibliographic/bd410.html
  # @see https://www.loc.gov/marc/bibliographic/bd411.html
  # @see https://www.loc.gov/marc/bibliographic/bd440.html
  #
  def series_subfields
    get_fields('410', '411', '440').flat_map { |field|
      get_subfield_values(field, 'a')
    }.clean_uniq(PHRASE_END)
  end

  # == MARC 440 - "Series Statement/Added Entry-Title" (R) [Obsolete, 2008]
  # == MARC 490 - "Series Statement" (R)
  # == MARC 800 - "Series Added Entry - Personal Name" (R)
  # == MARC 830 - "Series Added Entry - Uniform Title" (R)
  #
  # @return [Array<String>]
  #
  # === References
  # @see https://www.loc.gov/marc/bibliographic/bd440.html
  # @see https://www.loc.gov/marc/bibliographic/bd490.html
  # @see https://www.loc.gov/marc/bibliographic/bd800.html
  # @see https://www.loc.gov/marc/bibliographic/bd830.html
  #
  def series_statement
    get_fields('440', '490', '800', '830').map { |field|
      get_subfield_values(field).join(SPACE)
    }.clean_uniq(TRAILING_PERIOD)
  end

  # == MARC 500 - "General Note" (R)
  #
  # @return [Array<String>]
  #
  # === References
  # @see https://www.loc.gov/marc/bibliographic/bd500.html
  #
  def note
    values_of('500')
  end

  # == MARC 501 - "With Note" (R)
  #
  # @return [Array<String>]
  #
  # === References
  # @see https://www.loc.gov/marc/bibliographic/bd501.html
  #
  def with_note
    values_of('501')
  end

  # == MARC 502 - "Dissertation Note" (R)
  #
  # @return [Array<String>]
  #
  # === References
  # @see https://www.loc.gov/marc/bibliographic/bd502.html
  #
  def dissertation_note
    values_of('502')
  end

  # == MARC 504 - "Bibliography, etc. Note" (R)
  #
  # @return [Array<String>]
  #
  # === References
  # @see https://www.loc.gov/marc/bibliographic/bd504.html
  #
  def bibliography_note
    values_of('504')
  end

  # == MARC 505 - "Formatted Contents Note" (R)
  # For books this is a table of contents or similar listing; for musical
  # recordings this is the track list.
  #
  # Each field instance may contain a number of separate entries; each entry
  # is comprised of several subfields; the last subfield of an entry ends with
  # the string '--'.
  #
  # @return [Array<String>]
  #
  # === References
  # @see https://www.loc.gov/marc/bibliographic/bd505.html
  #
  # === Implementation Notes
  # Since there may be multiple fields and each field may have multiple entries
  # the simplest approach is to combine everything into a single string and
  # then split on the entry separator '--'.
  #
  def contents_note
    lines = values_of('505')
    isbd_list(lines).clean_uniq
  end

  # == MARC 506 - "Restrictions on Access Note" (R)
  #
  # @return [Array<String>]
  #
  # === References
  # @see https://www.loc.gov/marc/bibliographic/bd506.html
  #
  def access_restriction
    values_of('506')
  end

  # == MARC 508 - "Creation/Production Credits Note" (R)
  #
  # @return [Array<String>]
  #
  # === References
  # @see https://www.loc.gov/marc/bibliographic/bd508.html
  #
  def credits
    values_of('508')
  end

  # == MARC 510 - "Citation/References Note" (R)
  #
  # @return [Array<String>]
  #
  # === References
  # @see https://www.loc.gov/marc/bibliographic/bd510.html
  #
  def cited_in
    values_of('510')
  end

  # == MARC 511 - "Participant or Performer Note" (R)
  #
  # @return [<Array<String>]
  #
  # === References
  # @see https://www.loc.gov/marc/bibliographic/bd511.html
  #
  def performers
    values_of('511')
  end

  # == MARC 518 - "Date/Time and Place of an Event Note" (R)
  #
  # @return [Array<String>]
  #
  # === References
  # @see https://www.loc.gov/marc/bibliographic/bd518.html
  #
  def recording_information
    values_of('518')
  end

  # == MARC 520 - "Summary, Etc." (R)
  # With no "first indicator", the record is interpreted as a "summary" (e.g.,
  # plot summary).
  #
  # @return [Array<String>]
  #
  # === References
  # @see https://www.loc.gov/marc/bibliographic/bd520.html
  #
  def plot_summary
    values_of('520', 'ab', indicator1: '#', separator: nil)
  end

  # == MARC 520-3 - "Summary, Etc." (R)
  # With "first indicator" equal to "3", the record is interpreted as an
  # "abstract".
  #
  # @return [Array<String>]
  #
  # === References
  # @see https://www.loc.gov/marc/bibliographic/bd520.html
  #
  def abstract
    values_of('520', 'ab', indicator1: 3, separator: nil)
  end

  # == MARC 521 - "Target Audience Note" (R)
  #
  # @return [Array<String>]
  #
  # === References
  # @see https://www.loc.gov/marc/bibliographic/bd521.html
  #
  def target_audience
    values_of('521', 'a')
  end

  # == MARC 524 - "Preferred Citation of Described Materials Note" (R)
  #
  # @return [Array<String>]
  #
  # === References
  # @see https://www.loc.gov/marc/bibliographic/bd524.html
  #
  def citation_note
    values_of('524')
  end

  # == MARC 530 - "Additional Physical Form available Note" (R)
  #
  # @return [Array<String>]
  #
  # === References
  # @see https://www.loc.gov/marc/bibliographic/bd530.html
  #
  def other_forms
    values_of('530')
  end

  # == MARC 533 - "Reproduction Note" (R)
  #
  # @return [Array<String>]
  #
  # === References
  # @see https://www.loc.gov/marc/bibliographic/bd533.html
  #
  def reproduction_note
    values_of('533')
  end

  # == MARC 534 - "Original Version Note" (R)
  #
  # @return [Array<String>]
  #
  # === References
  # @see https://www.loc.gov/marc/bibliographic/bd534.html
  #
  def original_version
    values_of('534', 'ptcnle')
  end

  # == MARC 535 - "Location of Originals/Duplicates Note" (R)
  #
  # @return [Array<String>]
  #
  # === References
  # @see https://www.loc.gov/marc/bibliographic/bd535.html
  #
  def location_of_originals
    values_of('535')
  end

  # == MARC 538 - "System Details Note" (R)
  #
  # @return [Array<String>]
  #
  # === References
  # @see https://www.loc.gov/marc/bibliographic/bd538.html
  #
  def technical_details
    values_of('538')
  end

  # == MARC 540 - "Terms Governing Use and Reproduction Note" (R)
  #
  # @return [Array<String>]
  #
  # === References
  # @see https://www.loc.gov/marc/bibliographic/bd540.html
  #
  def terms_of_use
    values_of('540')
  end

  # == MARC 544 - "Location of Other Archival Materials Note" (R)
  #
  # @return [Array<String>]
  #
  # === References
  # @see https://www.loc.gov/marc/bibliographic/bd544.html
  #
  def other_archival_materials
    values_of('544')
  end

  # == MARC 545 - "Biographical or Historical Data" (R)
  #
  # @return [Array<String>]
  #
  # === References
  # @see https://www.loc.gov/marc/bibliographic/bd545.html
  #
  def biographical_note
    values_of('545')
  end

  # == MARC 546 - "Language Note" (R)
  #
  # @return [Array<String>]
  #
  # === References
  # @see https://www.loc.gov/marc/bibliographic/bd546.html
  #
  def language
    values_of('546')
  end

  # == MARC 555 - "Cumulative Index/Finding Aids Note" (R)
  #
  # @return [Array<String>]
  #
  # === References
  # @see https://www.loc.gov/marc/bibliographic/bd555.html
  #
  def finding_aid_note
    values_of('555')
  end

  # == MARC 580 - "Linking Entry Complexity Note" (R)
  #
  # @return [Array<String>]
  #
  # === References
  # @see https://www.loc.gov/marc/bibliographic/bd580.html
  #
  def title_history_note
    values_of('580', 'a')
  end

  # == MARC 586 - "Awards Note" (R)
  #
  # @return [Array<String>]
  #
  # === References
  # @see https://www.loc.gov/marc/bibliographic/bd586.html
  #
  def awards_note
    values_of('586', 'a')
  end

  # == MARC 590 - "Local Note" (R)
  #
  # @return [Array<String>]
  #
  # === References
  # @see https://www.oclc.org/bibformats/en/5xx/590.html
  #
  def local_note
    values_of('590')
  end

  # == MARC 600 - "Subject Added Entry - Personal Name" (R)
  #
  # @return [Array<String>]
  #
  # === References
  # @see https://www.loc.gov/marc/bibliographic/bd600.html
  #
  def personal_name_as_subject
    values_of('600')
  end

  # == MARC 610 - "Subject Added Entry - Corporate Name" (R)
  #
  # @return [Array<String>]
  #
  # === References
  # @see https://www.loc.gov/marc/bibliographic/bd610.html
  #
  def corporate_name_as_subject
    values_of('610')
  end

  # == MARC 611 - "Subject Added Entry - Meeting Name" (R)
  #
  # @return [Array<String>]
  #
  # === References
  # @see https://www.loc.gov/marc/bibliographic/bd611.html
  #
  def conference_as_subject
    values_of('611')
  end

  # == MARC 630 - "Subject Added Entry - Uniform Title" (R)
  #
  # @return [Array<String>]
  #
  # === References
  # @see https://www.loc.gov/marc/bibliographic/bd630.html
  #
  def title_as_subject
    values_of('630')
  end

  # == MARC 650 - "Subject Added Entry-Topical Term" (R)
  # == MARC 655 - "Index Term - Genre/Form" (R)
  #
  # @return [Array<String>]
  #
  # === References
  # @see https://www.loc.gov/marc/bibliographic/bd650.html
  # @see https://www.loc.gov/marc/bibliographic/bd655.html
  #
  def subjects
    subject_field('650', '655')
  end

  # == MARC 650 - "Subject Added Entry-Topical Term" (R)
  # == MARC 651 - "Subject Added Entry - Geographic Name" (R)
  # Just the geographic place names.
  #
  # @return [Array<String>]
  #
  # === References
  # @see https://www.loc.gov/marc/bibliographic/bd650.html
  # @see https://www.loc.gov/marc/bibliographic/bd651.html
  #
  def place_names
    result = []
    result += values_of('650', 'cz')
    result += values_of('651', 'az')
    result.clean_uniq(PHRASE_END)
  end

  # == MARC 650 - "Subject Added Entry - Topical Term" (R)
  #
  # @return [Array<String>]
  #
  # === References
  # @see https://www.loc.gov/marc/bibliographic/bd650.html
  #
  def lc_subject_heading
    subject_field('650')
  end

  # == MARC 651 - "Subject Added Entry - Geographic Name" (R)
  #
  # @return [Array<String>]
  #
  # === References
  # @see https://www.loc.gov/marc/bibliographic/bd651.html
  #
  def lc_geo_subject_heading
    subject_field('651')
  end

  # == MARC 655 - "Index Term - Genre/Form" (R)
  #
  # @return [Array<String>]
  #
  # === References
  # @see https://www.loc.gov/marc/bibliographic/bd655.html
  #
  def lc_genre_subject_heading
    subject_field('655')
  end

  # == MARC 690 - "Local Subject Access Field" (R)
  #
  # @return [Array<String>]
  #
  # === References
  # @see https://www.oclc.org/bibformats/en/6xx/690.html
  #
  def local_subject_heading
   subject_field('690')
  end

  # == MARC 730 - "Added Entry-Uniform Title" (R)
  # == MARC 740 - "Added Entry-Uncontrolled Related/Analytical Title" (R)
  #
  # @return [Array<String>]
  #
  # === References
  # @see https://www.loc.gov/marc/bibliographic/bd730.html
  # @see https://www.loc.gov/marc/bibliographic/bd740.html
  #
  def related_title
    get_fields('730', '740').map { |field|
      get_subfield_values(field).join(SPACE)
    }.clean_uniq(nil)
  end

  # == MARC 773 - "Host Item Entry" (R)
  #
  # @return [Array<String>]
  #
  # === References
  # @see https://www.loc.gov/marc/bibliographic/bd773.html
  #
  def located_in
    values_of('773', 'astbdgh')
  end

  # == MARC 780 - "Preceding Entry" (R)
  #
  # @return [Array<String>]
  #
  # === References
  # @see https://www.loc.gov/marc/bibliographic/bd780.html
  #
  def previous_title
    values_of('780', 'abtx', indicator1: 0)
  end

  # == MARC 785 - "Succeeding Entry" (R)
  #
  # @return [Array<String>]
  #
  # === References
  # @see https://www.loc.gov/marc/bibliographic/bd785.html
  #
  def later_title
    values_of('785', 'abtx', indicator1: 0)
  end

  # == MARC 856 4 0 - "Electronic Location and Access" (R)
  # URL of the electronic resource (where the item itself is only online).
  #
  # @return [Array<String>]
  #
  # === References
  # @see https://www.loc.gov/marc/bibliographic/bd856.html
  #
  def electronic_resource
    values_of('856', 'u', indicator1: [nil, 1, 4], indicator2: 0)
  end

  # == MARC 856 4 1 - "Electronic Location and Access" (R)
  # URL of an electronic version of the resource (where the item itself is
  # printed but has an electronic version on the Internet).
  #
  # @return [Array<String>]
  #
  # === References
  # @see https://www.loc.gov/marc/bibliographic/bd856.html
  #
  def electronic_version
    values_of('856', 'u', indicator1: [nil, 1, 4], indicator2: 1)
  end

  # == MARC 856 4 2 - "Electronic Location and Access" (R)
  # URL of a related item in electronic form.
  #
  # This also covers a set of erroneous Special Collections records that should
  # have had ind1 == 7, ind2 == 2 but instead have ind1 == nil, ind2 == 7.
  #
  # @return [Array<String>]
  #
  # === References
  # @see https://www.loc.gov/marc/bibliographic/bd856.html
  #
  def electronic_related_resource
    valid     = values_of('856', 'u', indicator1: ['#', 1, 4], indicator2: 2)
    sc_errors = values_of('856', 'u', indicator1: '#',         indicator2: 7)
    (valid + sc_errors).uniq
  end

  # == MARC 866 - "Textual Holdings - Basic Bibliographic Unit" (R)
  # == MARC 868 - "Textual Holdings - Indexes" (R)
  #
  # @return [Array<String>]
  #
  # === References
  # @see https://www.oclc.org/bibformats/en/8xx/84x-87x.html
  #
  def textual_holdings
    get_fields('866', '868').map { |field|
      get_subfield_values(field, 'axz26').join(SPACE)
    }.clean_uniq(nil)
  end

  # == MARC 946 - Locally defined location notes (R)
  #
  # @return [Array<String>]
  #
  # === References
  # @see https://www.oclc.org/bibformats/en/9xx/945-949.html
  #
  def location_notes
    values_of('946')
  end

  # ===========================================================================
  # :section: MARC fields
  # ===========================================================================

  protected

  # Splits a string into an array of entries based on the the ISBD practice of
  # inserting ' -- ' at the end of a subfield to indicate the boundary between
  # one list element and the next.
  #
  # @param [String, Array<String>] items
  #
  # @return [Array<String>]
  #
  # === Implementation Notes
  # Since there may be multiple fields and each field may have multiple entries
  # the simplest approach is to combine everything into a single string and
  # then split on the entry separator '--'.
  #
  # Ideally, the split would be on ' -- ', but some records have been observed
  # to have patterns where there isn't a space character to one side or the
  # other; the algorithm attempts to take that into account for some observed
  # usage patterns. However other records have been observed to have the
  # pattern 'WORD -- WORD' where '--' is simply used as a stand-in for an
  # em-dash; those records will probably produced bad results.
  #
  def isbd_list(items)
    # Combine the parts into one string.
    list_parts = items.is_a?(Array) ? items.join(' -- ') : items.dup

    # Normalize cases like:
    # 'v1. First item.--v2. Second item.' or
    # 'First item;-- Second item':
    list_parts.gsub!(/(?<=[.,;])--(?=[\s\w])/, ' -- ')

    # Normalize cases like:
    # '1. First item --2. Second item' or
    # '[1] First item --[2] Second item':
    list_parts.gsub!(/\s*--(?=[\d[[:punct:]]])/, ' -- ')

    # Return the list elements as an array.
    list_parts.split(/\s+--\s+/)
  end

  # Combine each instance of the indicated subfields into a "hierarchical"
  # string with sub-categories separated by ' -- '.
  #
  # @param [Array<String>] tags
  #
  # @return [Array<String>]
  #
  def subject_field(*tags)
    get_fields(*tags).map { |field|
      get_subfield_values(field, '!0!2').join(' -- ')
    }.clean_uniq(PHRASE_END)
  end

  # ===========================================================================
  # :section: Names and roles
  # ===========================================================================

  public

  # Get the primary author, preferring personal over corporate names.
  #
  # @return [String]
  # @return [nil]                     No MARC 100, 110, or 111 field present.
  #
  # @see self#get_author_list
  # @see self#NAME_SUBFIELDS
  #
  # === References
  # @see https://www.loc.gov/marc/bibliographic/bd100.html
  # @see https://www.loc.gov/marc/bibliographic/bd110.html
  # @see https://www.loc.gov/marc/bibliographic/bd111.html
  #
  def get_primary_author
    get_fields('100', '110', '111').find do |field|
      name = get_subfield_values(field, NAME_SUBFIELDS)
      return name.join(SPACE).sub(PHRASE_END, '') if name.present?
    end
  end

  # Get all personal/corporate authors from the MARC metadata of this item for
  # use in citations.
  #
  # @return [Array<String>]
  #
  # @see self#get_primary_author
  # @see self#get_related_names
  # @see self#NAME_SUBFIELDS
  #
  def get_author_list
    # Get the primary author (if there is one).
    primary_author = get_primary_author

    # Get a list of zero or more secondary authors, excluding names with one or
    # more relators where none of the relators indicate that the entry could be
    # associated with a creator of the work for the purposes of citation.
    result =
      get_fields('700', '710', '711').map { |field|
        name, relators = get_name_and_relators(field, NAME_SUBFIELDS)
        Debug.show(__method__) {
          ">>>> name #{name.inspect}; relators #{relators.inspect}"
        }
        next if name.blank?
        next if primary_author && name.include?(primary_author)
        name if relators.blank? || relators.any? { |r| creator?(r) }
      }.reject(&:blank?)

    # Prepend the primary author to return the entire list of authors.
    result.unshift(primary_author) if primary_author
    result.clean_uniq(nil)
      .tap { |res| Debug.show(__method__) { ">>>> #{res}" } }
  end

  # Get all the proper name added entries and their role names.
  #
  # @param [Boolean, String] display  If *true* (the default), names are
  #                                     generated for display; if *false* then
  #                                     the same MARC subfields used by
  #                                     self#get_authors are used here; if a
  #                                     String then it is interpreted as the
  #                                     subfields to be used.
  #
  # @return [Array<String>]
  #
  # @see self#get_name_and_roles
  # @see self#NAME_SUBFIELDS
  #
  # === References
  # @see https://www.loc.gov/marc/bibliographic/bd100.html
  # @see https://www.loc.gov/marc/bibliographic/bd110.html
  # @see https://www.loc.gov/marc/bibliographic/bd111.html
  # @see https://www.loc.gov/marc/bibliographic/bd700.html
  # @see https://www.loc.gov/marc/bibliographic/bd710.html
  # @see https://www.loc.gov/marc/bibliographic/bd711.html
  #
  def get_related_names(display = true)
    codes =
      case display
        when true  then nil
        when false then NAME_SUBFIELDS
        else            display
      end
    get_fields('100', '110', '111', '700', '710', '711').flat_map { |field|
      name, relators = get_name_and_relators(field, codes)
      Debug.show(__method__) {
        "MARC #{field.tag} name = '#{name}', relators = #{relators.inspect}"
      }
      name_without_role = relators.empty?
      names =
        relators.map { |relator|
          is_author  = author?(relator)
          is_advisor = advisor?(relator)
          name_without_role = true if is_author || is_advisor
          "#{name} (#{get_role(relator)})" unless is_author
        }.compact
      names.unshift(name) if name_without_role
      names
    }.clean_uniq(PHRASE_END)
  end

  # ===========================================================================
  # :section: Names and roles
  # ===========================================================================

  protected

  # For a given name field, the name and the role(s).
  #
  # @param [MARC::DataField] field
  # @param [String]          codes
  #
  # @return [Array<(String,Array<String>)>]
  #
  # === References
  # @see https://www.loc.gov/marc/relators/relacode.html
  # @see https://www.loc.gov/marc/relators/relaterm.html
  #
  def get_name_and_roles(field, codes = nil)
    get_name_and_relators(field, codes, true)
  end

  # For a given name field, the name and the role(s).
  #
  # Any role that could be mapped to a MARC relator is returned as a Symbol
  # (RELATOR_MAP key); otherwise the role is the original String with
  # punctuation removed.
  #
  # @param [MARC::DataField] field
  # @param [String]          codes
  # @param [Boolean]         return_roles
  #
  # @return [Array<(String,Array<Symbol,String>)>]
  # @return [Array<(String,Array<String>)>]  If *return_roles* set to *true*.
  #
  # @see UVA::Marc::Relator#get_relator
  # @see UVA::Marc::Relator#get_role
  #
  # === References
  # @see https://www.loc.gov/marc/relators/relacode.html
  # @see https://www.loc.gov/marc/relators/relaterm.html
  #
  def get_name_and_relators(field, codes = nil, return_roles = false)

    tag = field.tag
    person    = %w(100 700).include?(tag)
    corporate = %w(110 111 710 711).include?(tag)

    # Prepare storage areas for the intended subfields.  The order of the codes
    # defines the order in which they appear in the resulting name string.
    # MARC relator subfields are handled separately and cannot be included in
    # the name itself.
    name_codes = %w(a q b n d c)
    role_codes = %w(e 4)
    codes =
      if codes
        normalize_codes(codes).reject { |code| role_codes.include?(code) }
      else
        name_codes
      end
    name_parts = codes.map { |code| [code, []] }.to_h
    lookup = return_roles ? :get_role : :get_relator

    relators  = []
    get_subfields(field).each do |subfield|
      # Skip empty subfields.
      value = subfield.value.strip
      next if value.blank?
      # Accumulate a relator/role value if this is a relator subfield.
      code = subfield.code
      phrase = value.sub(PHRASE_END, '')
      case code
        when 'e' then relators << send(lookup, phrase)
        when '4' then relators << send(lookup, phrase.to_sym)
      end
      # Skip subfields that are not part of the name.
      next unless name_parts[code]
      # Accumulate a part of the name.
      case code
        when 'a' then name_parts[code] << value.delete('.')
        when 'q' then name_parts[code] << value if person
        when 'b' then name_parts[code] << value.delete('.')
        when 'n' then name_parts[code] << value if corporate
        when 'd' then name_parts[code] << value
        when 'c' then name_parts[code] << value
      end
    end

    name = name_parts.values.flatten.reject(&:blank?).join(SPACE)
    name.sub!(PHRASE_END, '')
    relators.delete_if(&:blank?)
    return name, relators
  end

  # ===========================================================================
  # :section: Generic access methods
  # ===========================================================================

  public

  # Retrieve all instances of the indicated field(s).
  #
  # This is preferable to `@record[tag]` because that mechanism performs a
  # linear search through the array of fields and only returns the first
  # matching instance. This method uses the MARC::Record's field hash and
  # returns all instances of fields matching the given tag(s).
  #
  # @param [Array<String>] tags
  #
  # @option tags [Boolean] :no_linked_fields
  #
  # @return [Array<MARC::DataField>]
  #
  def get_fields(*tags)
    Debug.show(__method__, prefix: '>>>') {
      "#{erase_root(caller[2])} -> #{self.class}::#{__method__}(#{tags})"
    }
    opt = tags.last.is_a?(Hash) ? tags.pop : {}
    tags = normalize_tags(*tags)
    linked_fields = (@record.fields('880') unless opt[:no_linked_fields])
    if linked_fields.blank?
      @record.fields(tags)
    else
      tags.flat_map do |tag|
        @record.fields(tag) +
          linked_fields.select { |lf| lf['6'].to_s.start_with?("#{tag}-") }
      end
    end
  end

  # Retrieve the value of the first instance of the indicated subfield.
  #
  # If *tag* indicates a repeatable field, only the first instance of the field
  # is used.  If *code* indicates a repeatable subfield, only the first
  # instance of the subfield will be returned.
  #
  # @param [String] tag
  # @param [String] code
  #
  # @return [String]
  # @return [nil]
  #
  def value_of(tag, code)
    raise "tag: #{tag.class}" unless tag.is_a?(String)
    field = get_fields(tag, no_linked_fields: true).first
    value = field && field[code]
    value.strip if value.present?
  end

  # This methods returns a single dimensional array of values for subfields
  # (it also removes blank values).
  # if subs is specified, only the matching subfields are returned
  # if subs is nil, the all subfields are returned
  # the value_regx can be used to match the value of the subfield
  # not_subs is for listing subfields that should not be returned, if nil no
  # restriction will be placed
  #
  # If only a single subfield is being requested, then each instance of the
  # given subfield is treated as a separate element in the result array, even
  # if the instances are from the same field. Otherwise, the result array
  # has one element for every instance of the requested field; each element is
  # a string made from the subfield components of that field.
  #
  # If :separator is *nil* then all subfields are treated in the same way that
  # are not concatenated and each one
  # becomes its own element in the result array.
  #
  # @param [String]                tag           '045' etc.
  # @param [String, Array<String>] codes         [:a, :b] etc.
  # @param [Hash]                  opt
  #
  # @option opt [String] :indicator1
  # @option opt [String] :indicator2
  # @option opt [String] :separator
  #
  # @return [Array<String>]
  #
  # === Usage
  #
  # @example All subfields of each data field found in the MARC record
  #   values_of('700')
  #   values_of(700)
  #   values_of('050')
  #   values_of(50)
  #   values_of('006')
  #   values_of(6)
  #
  # @example All instances of subfield 700$a found in the MARC record.
  #   values_of('700', :a)
  #   values_of('700', [:a])
  #   values_of('700', 'a')
  #
  # @example For each 700 field, strings made of their $a, $e, $q subfields.
  #   values_of('700', :a, :e, :q)
  #   values_of('700', [:a, :e, :q])
  #   values_of('700', 'a', 'e', 'q')
  #   values_of('700', 'aeq')
  #
  # @example For each 700 field, strings made of all subfields except $a.
  #   values_of('700', '!a')
  #
  # @example For each 700 field, strings made of all subfields except $e or $q.
  #   values_of('700', '!e!q')
  #
  #--
  # rubocop:disable Metrics/ParameterLists
  #++
  def values_of(tag, codes = nil, opt = nil)
    unless tag.is_a?(String)
      tag = normalize_tags(tag)
      raise "tag: multiple tags not allowed: #{tag}" if tag.size != 1
      tag = tag.first
      raise "tag: not a String: #{tag}" unless tag.is_a?(String)
    end
    codes = normalize_codes(codes)
    opt = opt ? opt.dup : {}

    # If :separator is *nil* then each subfield becomes its own element in the
    # result array.  If multiple subfields are being requested (implicitly or
    # explicitly) then the default is to concatenate all of the subfields so
    # that each element of the result array is a representation of a field.
    single_field = codes && (codes.size == 1)
    sep =
      if opt.key?(:separator)
        opt[:separator]
      elsif !single_field
        SPACE
      end

    # Create a result element string comprised of the requested subfields for
    # every instance of "tag".
    result =
      get_fields(tag).flat_map { |field|
        values = get_subfield_values(field, codes, opt)
        sep ? values.join(sep) : values
      }
    (sep || single_field) ? result.clean_uniq : result
    # rubocop:enable Metrics/ParameterLists
  end

  # Get selected subfields from a specific DataField instance.
  #
  # If *codes* is *nil* then all subfields of *field* are returned.  If *codes*
  # contains any fields of the form "!x", these are added to the list of codes
  # to reject.
  #
  # @param [MARC::DataField]       field
  # @param [String, Array<String>] codes
  # @param [Hash]                  opt
  #
  # @option opt [String] :indicator1
  # @option opt [String] :indicator2
  #
  # @return [Array<String>]           The result will be empty if :indicator1
  #                                     or :indicator2 is specified and the
  #                                     record does not match the indicator.
  #
  def get_subfield_values(field, codes = nil, opt = nil)
    Debug.show(__method__, prefix: '>>>') {
      msg = "#{erase_root(caller[2])} -> #{self.class}::#{__method__}("
      msg << (field.respond_to?(:tag) ? field.tag : field.inspect)
      msg << ", codes = #{codes.inspect}"
      msg << ", ind1 = #{opt[:indicator1]}" if opt && opt[:indicator1]
      msg << ", ind2 = #{opt[:indicator2]}" if opt && opt[:indicator2]
      msg << ')'
    }
    get_subfields(field, codes, opt).map { |subfield|
      subfield.value.strip
    }.reject(&:blank?)
  end

  # Get selected subfields from a specific DataField instance.
  #
  # If *codes* is *nil* then all subfields of *field* are returned.  If *codes*
  # contains any fields of the form "!x", these are added to the list of codes
  # to reject.
  #
  # @note Iterating over get_subfields(field) is better than `field.subfields`
  # in most circumstances because it automatically ignores non-data subfields.
  #
  # @param [MARC::DataField]       field
  # @param [String, Array<String>] codes
  # @param [Hash]                  opt
  #
  # @option opt [String] :indicator1
  # @option opt [String] :indicator2
  #
  # @return [Array<MARC::Subfield>]   If *indicator1* or *indicator2* is
  #                                     specified and the record does match the
  #                                     indicator then the result will be an
  #                                     empty array.
  #
  def get_subfields(field, codes = nil, opt = nil)
    Debug.show(__method__, prefix: '>>>') {
      msg = "#{erase_root(caller[2])} -> #{self.class}::#{__method__}("
      msg << (field.respond_to?(:tag) ? field.tag : field.inspect)
      msg << ", codes = #{codes.inspect}"
      msg << ", ind1 = #{opt[:indicator1]}" if opt && opt[:indicator1]
      msg << ", ind2 = #{opt[:indicator2]}" if opt && opt[:indicator2]
      msg << ')'
    }
    if field && !field.is_a?(MARC::DataField)
      raise "#{field.class}: expected MARC::DataField"
    end
    opt ||= {}

    # Validate arguments.
    return [] unless field
    return [] unless match_indicator?(field.indicator1, *opt[:indicator1])
    return [] unless match_indicator?(field.indicator2, *opt[:indicator2])

    # Extract not_codes from codes.  All of the MARC "Control Subfields" will
    # be rejected by default unless explicitly requested in *codes*.  If no
    # codes were explicitly requested this implies requesting "all codes".
    codes = normalize_codes(codes)
    added_not_codes, codes = codes.partition { |v| v.start_with?('!') }
    added_not_codes.map! { |v| v.delete('!') }
    codes = nil if codes.blank?

    # Rectify *not_codes* first by removing any codes that were explicitly
    # requested then by including any codes that were explicitly rejected
    # (using logical-OR to append only codes that are not already present).
    not_codes = IGNORED_SUBFIELDS.dup
    not_codes -= codes if codes
    not_codes |= added_not_codes
    not_codes = nil if not_codes.blank?

    # Collect all of the subfields, discarding any are not in the set of
    # requested codes or *are* in the set of rejected codes.
    field.subfields.reject { |subfield|
      (codes     && !codes.include?(subfield.code)) ||
      (not_codes && not_codes.include?(subfield.code))
    }

  end

  # Evaluate whether the target indicator value matches the provided indicator
  # values.  If no values are provided then there is always a match.
  #
  # In keeping with the Library of Congress MARC documentation:
  #
  # - If the indicator is given as empty (''), blank (' ') or pound sign ('#'),
  # then there is a match only if the *target* is blank.
  #
  # - If the indicator is given as *nil* then there is a match for any *target*
  # value.
  #
  # @param [String]                     target
  # @param [Array<nil, Fixnum, String>] values
  #
  def match_indicator?(target, *values)
    return true if values.blank?
    target = target.to_s.strip
    values.any? do |value|
      value = value.to_s.strip
      value = '' if value == '#'
      value == target
    end
  end

  # ===========================================================================
  # :section: Generic access methods
  # ===========================================================================

  protected

  # Given one or more MARC tag specifiers, return an array with the tags in a
  # usable form with elements that are three-character strings indicating MARC
  # field tags.
  #
  # If any argument is a Fixnum, its string representation will be zero-filled
  # to make it a valid MARC field tag.  Unless you intend to use octal (for
  # some reason), make sure that the literal number is given as a decimal (with
  # no leading zeros).
  #
  # @param [Array<String,Fixnum,Range,Array>] tags
  #
  # @return [Array<String>]
  #
  def normalize_tags(*tags)
    # Flatten *tags* to deal only with Strings, Fixnums and/or Ranges.
    tags.flat_map { |tag|
      # Coerce *tag* into an array to process scalars and Range values alike.
      Array(tag).map do |v|
        # Non-digit characters are eliminated; overly-long strings are skipped.
        v = v.to_s.delete('^0-9')
        case v.length
          when 1 then '00' + v
          when 2 then '0' + v
          when 3 then v
        end
      end
    }.reject(&:blank?).uniq
  end

  # Given one or more MARC subfield code specifiers, return an array with the
  # specifiers in a usable form with elements that are either single character
  # strings (indicating MARC subfield codes to get) and/or strings of the form
  # "!x", indicating MARC subfield codes to ignore.
  #
  # @param [Array<String,Fixnum,Range,Array>] codes
  #
  # @return [Array<String>]
  #
  # @note Numbers above 9 will be interpreted as multiple subfield codes.
  #
  def normalize_codes(*codes)
    # Flatten *codes* to deal only with Strings, Fixnums and/or Ranges.
    codes.map { |code|
      # Coerce *code* into an array to process scalars and Range values alike.
      Array(code).map do |v|
        # Multiple-character strings are tokenized.
        v = v.to_s.downcase
        case v.length
          when 0 then next
          when 1 then v
          else        v.scan(/!?\w/)
        end
      end
    }.flatten.reject(&:blank?).uniq
  end

  # ===========================================================================
  # :section: Test and development
  # ===========================================================================

  public

  # Format a self object for verbose output.
  #
  # @param [Array<Field>] fields
  #
  # @option fields [Fixnum]  :index     Defaults to 0.
  # @option fields [String]  :newline   Defaults to "\n".
  # @option fields [Boolean] :expanded  If *true*, the result is expanded to
  #                                       include subfield values.  By default
  #                                       only counts of the MARC fields will
  #                                       be given.
  #
  # @return [String]
  #
  def pretty_inspect(*fields)
    opt = fields.last.is_a?(Hash) ? fields.pop : {}
    index    = opt[:index] || 0
    newline  = opt[:newline] || NEWLINE
    expanded = opt[:expanded]
    fields   = @record.fields if fields.empty?
    if expanded
      fields.map { |field|
        prefix =
          '%3d  ' % (index += 1)
        tag =
          case field
            when MARC::ControlField, MARC::DataField
              'MARC ' + format_subfield_part(field.tag)
            else
              "UNEXPECTED #{field.class} = "
          end
        value =
          case field
            when MARC::ControlField
              ' value ' + format_subfield_part(field.value)
            when MARC::DataField
              inspect_subfields(field, prefix, newline)
            else
              field.pretty_inspect
          end
        "#{prefix}#{tag}#{value}"
      }.join(newline)
    else
      field_counts = {}
      fields.each do |field|
        next unless field && field.respond_to?(:tag)
        tag = format_subfield_part(field.tag).delete(SQUOTE)
        if field_counts.key?(tag)
          field_counts[tag] += 1
        else
          field_counts[tag] = 1
        end
      end
      count_table = {}
      field_counts.sort_by { |tag, _count| tag }.map { |pair|
        tag, count = pair
        if count_table.key?(count)
          count_table[count] << tag
        else
          count_table[count] = [tag]
        end
      }
      count_table.sort_by { |count, _tags| count }.map { |pair|
        count = '%5d' % pair.shift
        tags  = pair.shift.join(LIST_SEPARATOR)
        "#{count} - #{tags}"
      }.unshift('Count - MARC fields').join(newline)
    end
  end

  # Format MARC subfields for verbose debug output.
  #
  # @param [Field]  field
  # @param [String] prefix
  # @param [String] newline
  #
  # @return [String]
  #
  def inspect_subfields(field, prefix = '', newline = NEWLINE)
    newline +
      field.subfields.map { |sf|
        code  = format_subfield_part(sf.code)
        value = format_subfield_part(sf.value)
        "#{prefix}-  code #{code} value #{value}"
      }.join(newline)
  end

  # ===========================================================================
  # :section: Test and development
  # ===========================================================================

  protected

  # Display the self object on debugging output.
  #
  # @param [Symbol] calling_method
  #
  # @return [void]
  #
  def debug_self(calling_method = nil)
    return unless calling_method ? Debug[calling_method] : Debug.this_class
    calling_method =
      if calling_method
        "#{self.class}::#{calling_method}"
      else
        caller[0]
      end
    leader = "\n>>> #{calling_method} [#{@record.fields.size} fields]"
    values = self.pretty_inspect + NEWLINE
    Debug.show(leader, caller_index: 3)
    Debug.show(values)
  end

  # Format a part of a MARC subfield for verbose debug output.
  #
  # @param [Object] part
  #
  # @return [String]
  #
  def format_subfield_part(part)
    result = ''
    result << "[#{part.class}] " unless part.is_a?(String)
    result <<
      case part
        when String then "'#{part}'"
        when Symbol then ":#{part}"
        else             part.inspect
      end
  end

  # Indicate whether instances should be frozen after creation.
  #
  def deep_freeze_enabled?
    MARC_DEEP_FREEZE && !Virgo.deployed_production?
  end

  # In all non-production environments, freeze the extracted MARC values to
  # discover any situations in which the data is inadvertently modified.
  #
  # (In the deployed production environment, don't risk throwing an error --
  # in principle any potential bugs caused by overwriting these values should
  # have already been eliminated in development/test).
  #
  # @return [self]
  #
  def deep_freeze
    @record.deep_freeze
    self
  end

  # rubocop:enable Metrics/ClassLength
end
