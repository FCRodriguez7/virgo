# lib/uva/util/date_methods.rb

require 'uva/util'

module UVA::Util

  module DateMethods

    include UVA::Util::TextConstants

    extend self

    # Matches date patterns like "MM/DD/YYYY" or "M-D-YY", where the month may
    # be one or two digits, the day may be one or two digits, the year may be
    # one through four digits, and arbitrary text may follow the year.
    DATE_MM_DD_YY = /^\s*
        (#{MONTH_DIGITS})#{DATE_SEPARATOR}  # $LAST_MATCH_INFO[1]
        (#{DAY_DIGITS})#{DATE_SEPARATOR}    # $LAST_MATCH_INFO[2]
        (#{YEAR_DIGITS})\s*                 # $LAST_MATCH_INFO[3]
        (.*?)\s*$/x.freeze                  # $LAST_MATCH_INFO[4]

    # Matches date patterns like "YYYY/MM/DD" or "YY-M-D", where the year may
    # be one through four digits, the month may be one or two digits, and
    # arbitrary text may follow the day.  (This regular expression is checked
    # after DATE_MM_DD_YY so that "01/02/03" is interpreted as "1903/01/02" and
    # not "1901/02/03".)
    DATE_YY_MM_DD = /^\s*
        (#{YEAR_DIGITS})#{DATE_SEPARATOR}   # $LAST_MATCH_INFO[1]
        (#{MONTH_DIGITS})#{DATE_SEPARATOR}  # $LAST_MATCH_INFO[2]
        (#{DAY_DIGITS})\s*                  # $LAST_MATCH_INFO[3]
        (.*?)\s*$/x.freeze                  # $LAST_MATCH_INFO[4]

    # Matches date patterns like "MM/YYYY" or "M-YY", where the month may be
    # one or two digits, the year may be one through four digits, and arbitrary
    # text may follow the year.
    DATE_MM_YY = /^\s*
        (#{MONTH_DIGITS})#{DATE_SEPARATOR}  # $LAST_MATCH_INFO[1]
        (#{YEAR_DIGITS})\s*                 # $LAST_MATCH_INFO[2]
        (.*?)\s*$/x.freeze                  # $LAST_MATCH_INFO[3]

    # Matches date patterns like "YYYY/MM" or "YY-M", where the year may be one
    # through four digits, the month may be one or two digits, and arbitrary
    # text may follow the month. (This regular expression is checked after
    # DATE_MM_YY so that "01/03" is interpreted as "1903/01" and not
    # "1901/03".)
    DATE_YY_MM = /^\s*
        (#{YEAR_DIGITS})#{DATE_SEPARATOR}   # $LAST_MATCH_INFO[1]
        (#{MONTH_DIGITS})\s*                # $LAST_MATCH_INFO[2]
        (.*?)\s*$/x.freeze                  # $LAST_MATCH_INFO[3]

    # Matches patterns with a one- to four-digit year with optional text
    # following the year value.
    DATE_YY = /^\s*
        (#{YEAR_DIGITS})\s*                 # $LAST_MATCH_INFO[1]
        (.*?)\s*$/x.freeze                  # $LAST_MATCH_INFO[2]

    # =========================================================================
    # :section:
    # =========================================================================

    public

    # Given a string containing a date, extract the year.
    #
    # @param [String] value
    #
    # @return [String]
    # @return [nil]
    #
    def extract_year(value)
      return unless (value =~ LEADING_YEAR) || (value =~ TRAILING_YEAR)
      $LAST_MATCH_INFO[1]
    end

    # Format a date string for use with export formats.
    #
    # @param [String] value
    # @param [Hash]   opt
    #
    # @option opt [String]  :separator
    # @option opt [Boolean] :allow_extra_text
    # @option opt [Boolean] :default_20th_century
    # @option opt [Boolean] :month_names
    #
    # @return [String]
    # @return [nil]                 If the string did not have a date value.
    #
    def export_date(value, opt = {})
      yy = mm = dd = xx = nil
      case value
        when DATE_MM_DD_YY then mm, dd, yy, xx = $LAST_MATCH_INFO[1,4]
        when DATE_YY_MM_DD then yy, mm, dd, xx = $LAST_MATCH_INFO[1,4]
        when DATE_MM_YY    then mm, yy, xx = $LAST_MATCH_INFO[1,3]
        when DATE_YY_MM    then yy, mm, xx = $LAST_MATCH_INFO[1,3]
        when DATE_YY       then yy, xx = $LAST_MATCH_INFO[1,2]
      end
      return if yy.blank?
      opt = {
        separator:            '/',
        allow_extra_text:     false,
        default_20th_century: true,
        month_names:          false,
      }.merge(opt)
      if mm.blank?
        mm = nil
      elsif opt[:month_names]
        mm = Date.const_get(:MONTHNAMES)[mm.to_i]
      end
      dd = nil if dd.blank?
      xx = xx.delete(opt[:separator]) if xx.present?
      xx = nil if xx.blank? || !opt[:allow_extra_text]

      # Adjust year, with the heuristic that two-digit years are actually
      # years from the 20th century.
      result =
        case yy.length
          when 3 then "0#{yy}"
          when 2 then opt[:default_20th_century] ? "19#{yy}" : "00#{yy}"
          when 1 then "000#{yy}"
          else        yy
        end

      # Zero-fill the month; if there is extra text a slash is needed even if
      # the value is missing.
      result << opt[:separator] if mm || xx
      result << ((mm.length == 1) ? "0#{mm}" : mm) if mm

      # Zero-fill the day; if there is extra text a slash is needed even if the
      # value is missing.
      result << opt[:separator] if dd || xx
      result << ((dd.length == 1) ? "0#{dd}" : dd) if dd

      # Append the extra text if present.
      result << "#{opt[:separator]}#{xx}" if xx
      result
    end

  end

end
