# encoding: UTF-8 # lib/uva/util/string_methods.rb

require 'uva/util'

module UVA::Util

  module StringMethods

    include UVA::Util::TextConstants

    extend self

    # =========================================================================
    # :section:
    # =========================================================================

    public

    # Given a string capitalize just the first letter (as opposed to
    # String#capitalize, which forces the rest of the letters to lowercase).
    #
    # The original is returned if the string does not need capitalization,
    # which includes some cases where the first alphabetic character is
    # lowercase.  E.g. "n/a" will be untouched.
    #
    # @param [String, Array<String>] s
    #
    # @return [String]                If *s* is a String.
    # @return [Array<String>]         If *s* is an Array.
    # @return [nil]                   If *s* is *nil*.
    #
    def capitalize(s)
      case s
        when String
          (s =~ /^[a-z][a-z\s]/) ? (s[0].upcase + s[1..-1]) : s
        when Array
          s.map { |element| capitalize(element) }
        else
          raise "#{s.class}: unexpected type for #{s.inspect}"
      end
    end

    # Given a string, capitalize just the first letter (as opposed to
    # String#capitalize, which forces the rest of the letters to lowercase).
    #
    # If the string does not need capitalization then *nil* is returned.
    # Otherwise the contents of the string are replaced.
    #
    # @param [String, Array<String>] s
    #
    # @return [String]                If *s* is a String and was modified.
    # @return [Array<String>]         If *s* is an Array and was modified.
    # @return [nil]                   If *s* did not need to be capitalized.
    #
    # @see self#capitalize
    #
    def capitalize!(s)
      case s
        when String
          s.replace(s[0].upcase + s[1..-1]) if s =~ /^[a-z][a-z\s]/
        when Array
          s if s.count { |element| capitalize!(element) }.nonzero?
        else
          raise "#{s.class}: unexpected type for #{s.inspect}"
      end
    end

    # Put a string in "titlecase".
    #
    # Unlike String#titleize, this method:
    #   * Preserves non-word characters,
    #   * Capitalizes words within parentheses and quotes,
    #   * Makes certain acronyms all-uppercase unconditionally,
    #   * Makes certain connector words all-lowercase except when they appear
    #       at the start of a phrase.
    #
    # @param [Array<String>] args     One or more phrases which make up the
    #                                   complete title; multiple arguments will
    #                                   be joined with spaces.
    #
    # @option args [Boolean] :force   If *true* then unconditionally apply
    #                                   capitalization rules, even to strings
    #                                   with mixed-case.
    #
    # @option args [Boolean] :names   If *true* then modify rules to support
    #                                   capitalization of proper names (avoid
    #                                   matching single-letter :upcase or
    #                                   :downcase terms).
    #
    # @option args [String,Array,Regexp] :upcase
    #                                 Words that should always be uppercase.
    #
    # @option args [String,Array,Regexp] :downcase
    #                                 Words that should always be lowercase
    #                                   (except at the beginning of a phrase).
    #
    # @option args [String,Array,Regexp] :preserve
    #                                 Words that should always be as given.
    #
    # @return [String]
    #
    # For the :upcase and :downcase options:
    # @see self#make_regex
    #
    # === Example
    # @example Via arguments
    #   titleize("(don't stop)", 'believing') #=> "(Don't Stop) Believing"
    #
    # @example Via arguments with options
    #   titleize("(don't stop) believing", upcase: 'stop')
    #     #=> "(Don't STOP) Believing"
    #
    # @example Via block
    #   titleize do
    #     'one (is the loneliest number)'
    #   end #=> "One (Is the Loneliest Number)"
    #
    # @example Via block with options
    #   titleize(upcase: ['one', 'is'], downcase: ['two', 'number']) do
    #     'one (is the loneliest number)'
    #   end #=> "ONE (IS the Loneliest number)"
    #
    # === Caveats
    # This method cannot handle strings containing embedded HTML.  (A specific
    # use-case would be titles of works with embedded subscripts [<sub>] or
    # superscripts [<sup>].)
    #
    # === Implementation Notes
    # The input string is assembled from *args* and/or the block yield and
    # handled one space-delimited "word" at a time (where "word" may include
    # leading and/or trailing non-word characters like punctuation).
    #
    # There are two basic scenarios for the input string:
    #
    #   * If the string all uppercase or all lowercase the words are
    #     are capitalized according to simple rules
    #
    #   * Otherwise, some words may be all-uppercase, all-lowercase, or
    #     mixed-case.  All-lowercase words are handled according to the rules
    #     but all-uppercase words or mixed-case words are assumed to have been
    #     capitalized that way intentionally and are kept as-is.
    #
    # Because some EBSCO article titles have the pattern of a title in all
    # uppercase followed by an annotation like "<i>(French)</i>", testing is
    # against a sample of the string where the first  lowercase substring is
    # removed -- if any lowercase letters remain in the sample, then the actual
    # title is probably mixed-case.
    #
    def titleize(*args)

      # Extract options leaving only an array of string(s) in *args*.
      # If a block was given, append its results to the array of string(s).
      opt = args.last.is_a?(Hash) ? args.pop : {}
      block_yield = block_given? && yield
      case block_yield
        when String then args << block_yield
        when Array  then args += block_yield
      end
      uniform = opt[:force]
      mixed   = opt[:preserve]
      mixed   = [mixed] if mixed && !mixed.is_a?(Array)
      upper   = opt[:upcase]
      upper   = [upper] if upper && !upper.is_a?(Array)
      lower   = opt[:downcase]
      lower   = [lower] if lower && !upper.is_a?(Array)
      space_words =
        if upper || lower || mixed
          words =  (mixed || MIXEDCASE_WORDS)
          words += (upper || UPPERCASE_WORDS)
          words += (lower || LOWERCASE_WORDS)
          words.select { |word| word =~ /[\p{Space}]/u }
        else
          SPACE_WORDS
        end
      placeholder = nil

      # If there are no uppercase or lowercase characters in the string then
      # return it immediately since it can't be titleized.  If the string is
      # all lowercase or all uppercase then its handling is slightly different
      # than if it is mixed-case.
      source = args.join(SPACE)
      string =
        if space_words.present?
          space_words = space_words.join('|')
          placeholder = '}}}!!!{{{'
          source.gsub(/(?<![\p{Alnum}])(#{space_words})(?![\p{Alnum}])/i) {
            $&.gsub!(/[\p{Space}]/u, placeholder)
          }
        else
          source
        end.mb_chars
      words = string.split(/[\p{Space}]+/u)
      sample =
        if !uniform && (words.size > 1)
          string.sub(/[\p{Lower}]+\)\s*$/u, '')
        else
          string
        end
      no_lower = (sample !~ /[\p{Lower}]/u)
      no_upper = (sample !~ /[\p{Upper}]/u)
      return source if no_lower && no_upper
      uniform ||= (no_lower ^ no_upper) && (words.size > 1)

      # Get patterns for lists of always-uppercase and always-lowercase words.
      re_mixed =
        if mixed
          StringMethods.make_regex(mixed)
        else
          TITLEIZE_MIXEDCASE
        end
      re_upper =
        if upper
          StringMethods.make_regex(upper)
        elsif opt[:names]
          TITLEIZE_NAME_UPPERCASE
        else
          TITLEIZE_UPPERCASE
        end
      re_lower =
        if lower
          StringMethods.make_regex(lower)
        elsif opt[:names]
          TITLEIZE_NAME_LOWERCASE
        else
          TITLEIZE_LOWERCASE
        end

      # Handle each space-delimited word separately.
      new_phrase = true
      words.map { |word|
        # Restore preserved spaces.
        word = word.gsub(placeholder, SPACE) if placeholder

        # Determine handling for the first "always-lowercase" word part.
        capitalize_lowercase = new_phrase || word.start_with?(*%w(` ' "))

        # Set up for next *word* iteration.
        new_phrase = word.end_with?(*%w(: ; / ? .))

        # Capitalize each part of a multi-part word separately.
        word.gsub(%r{[^:;/+-]+}u) do |part|
          # Determine how this part will be modified.
          transform =
            case part
              when re_mixed
                nil
              when re_upper, TITLEIZE_INITIALS
                :upcase
              when re_lower, TITLEIZE_ORDINAL
                capitalize_lowercase ? :capitalize : :downcase
              when TITLEIZE_ALL_UPPERCASE
                :capitalize if uniform
              when TITLEIZE_ALL_LOWERCASE
                :capitalize
            end

          # This is not applicable to subsequent parts of a multi-part word:
          capitalize_lowercase = false

          # Generate the substitution for the *part*.  If *transform* was *nil*
          # then *part* is used without modification.
          case transform
            when :capitalize then $1 + $2.mb_chars.capitalize + $3
            when :downcase   then $1 + $2.mb_chars.downcase + $3
            when :upcase     then $1 + $2.mb_chars.upcase + $3
            else                  part
          end
        end
      }.join(SPACE)

    end

    # @see self#titleize
    #
    # If the string does not need to change then *nil* is returned.
    # Otherwise the contents of the string are replaced.
    #
    # @param [String] s
    # @param [Hash]   opt
    #
    # @return [String]
    # @return [nil]
    #
    def titleize!(s, opt = nil)
      opt ||= {}
      result = titleize(s, opt)
      s.replace(result) unless result == s
    end

    # Remove pairs of matching brackets from the ends of a string.
    #
    # To avoid situations like "[5th ed.] New York [2016]" resulting in
    # "5th ed.] New York [2016", the algorithm will give up if there would be
    # unmatched pairs within the resulting string.
    #
    # @param [String]                s
    # @param [Symbol, Array<Symbol>] type   Default: [:parens, :brackets]
    #
    # @return [String]
    #
    def strip_brackets(s, type = nil)
      s = s.to_s.strip
      type ||= [:parens, :brackets]
      Array(type).each do |t|

        # Look for the indicated pair of symbols at the ends of the string.
        l_char, r_char =
          case t
            when :parens   then %w< ( ) >
            when :brackets then %w< [ ] >
            when :braces   then %w< { } >
            else raise "#{type}: unexpected"
          end
        next unless s.start_with?(l_char) && s.end_with?(r_char)

        # Check for unbalanced pairs of symbols within the remainder of the
        # string.
        inner_chars = s[1..-2]
        balance = 0
        inner_chars.each_char do |c|
          case c
            when l_char then balance += 1
            when r_char then balance -= 1
          end
        end
        next unless balance.zero?

        # Update the current version of the string.
        s = inner_chars.strip
      end

      # Return with the final version of the string.
      s
    end

    # Find a pattern whether a value
    #
    # @param [String] value
    # @param [Array]  patterns
    #
    # @return [String, Regexp]        The matching pattern.
    # @return [nil]                   If *value* matched none of the patterns.
    #
    def match_any(value, patterns)
      return if value.blank? || patterns.blank?
      value    = value.to_s unless value.is_a?(String)
      patterns = [patterns] unless patterns.is_a?(Array)
      patterns.find do |pattern|
        case pattern
          when Regexp then value =~ pattern
          when String then value == pattern
        end
      end
    end

    # Used within comparisons of strings where spaces and the case of the
    # alphabetic characters are ignored.
    #
    # @param [String]         s       Target string.
    # @param [String, Regexp] remove  Characters to remove.
    #
    # @return [String]
    #
    # === Examples
    # @example Elimination of near duplicates in an array
    #   [' Thing', 'thing ', 'ThiNG']
    #     .uniq { |v| non_blank_chars(v) } #=> [' Thing']
    #
    # @example Elimination of near duplicates in an array
    #   [' Thing', 'thing ', 'ThiNG']
    #     .uniq { |v| non_blank_chars(v) } #=> [' Thing']
    #
    def non_blank_chars(s, remove = /[[:space:]]/)
      s.to_s.gsub(remove, '').downcase
    end

    # If there is an uneven number of double quote characters, the Parslet gem
    # used by Blacklight will choke on parsing. This method determines that
    # condition and 'fixes' it using this set of steps:
    #
    #   1. Compress any adjacent double quotes to a single double quote.
    #   2. If there are an odd number of double quotes, continue with the
    #       following steps:
    #   3. If there is a double quote at the head and not the tail, append one
    #       to the tail.
    #   4. Else if there is double quote at the tail and not the head, prepend
    #       one to the head.
    #   5. Else just take out the first double quote encountered (that's the
    #       best we can guess).
    #
    # @param [String] query
    #
    # @return [String]
    #
    def balance_double_quotes(query)
      result = query.to_s
      unless result.count(DQUOTE).zero?
        result = result.squeeze(DQUOTE)
        if result.count(DQUOTE).odd?
          quote_at_head = (result[0]  == DQUOTE)
          quote_at_tail = (result[-1] == DQUOTE)
          if quote_at_head && !quote_at_tail
            result.concat(DQUOTE)
          elsif !quote_at_head && quote_at_tail
            result.prepend(DQUOTE)
          else
            result.sub!(DQUOTE, '')
          end
        end
      end
      result
    end

    # =========================================================================
    # :section:
    # =========================================================================

    public

    TRUE_TERMS  = %w(true yes on).deep_freeze
    FALSE_TERMS = %w(false no off).deep_freeze

    # Indicate whether the item is explicitly set to *true*, either a Boolean
    # or a String with the case-insensitive value of "true", "yes" or "on".
    #
    # === Usage Notes
    # Used in places where a flag for a positive condition may be passed
    # through URL parameters and the condition holds only if the flag is
    # explicitly *true* (otherwise the condition is treated as *false*).
    #
    def true_value?(s)
      TRUE_TERMS.include?(s.to_s.downcase)
    end

    # Indicate whether the item is explicitly set to *false*, either a Boolean
    # or a String with the case-insensitive value of "false", "no" or "off".
    #
    # === Usage Notes
    # Used in places where a flag for a negative condition may be passed
    # through URL parameters and the condition holds only if the flag is
    # explicitly *false* (otherwise the condition is treated as *true*).
    #
    def false_value?(s)
      FALSE_TERMS.include?(s.to_s.downcase)
    end

    # =========================================================================
    # :section: Module methods
    # =========================================================================

    protected

    # Construct an array of terms from a multi-line string.
    #
    # Each term is on its own line and may be followed by a comment that begins
    # with '#'.  Leading and trailing spaces (including comments) are discarded
    # from the resulting array.
    #
    # @param [String] lines
    #
    # @return [Array<String>]
    #
    def self.make_word_list(lines)
      lines.to_s.gsub(/(?<!\\)#.*$/, '').split("\n").map(&:strip)
    end

    # Form an expression for matching a list of words.
    #
    # @param [Array<String>, String, Regexp] expr
    #
    # @return [Regexp]
    # @return [nil]                   If *words* was *nil* or empty.
    #
    # @see self#titleize
    #
    # === Usage Notes
    # If a Regexp is given, it must conform to the same structure that is used
    # to create a Regexp for a word or array of words by having three capture
    # groups:
    #   $1 - matching zero or more leading characters
    #   $2 - matching the target characters
    #   $3 - matching zero or more trailing characters
    #
    def self.make_regex(expr)
      if expr.is_a?(Regexp)
        expr
      else
        re_opt = Regexp::FIXEDENCODING        # Like `/expr/u`
        if expr.is_a?(Array)
          re_opt |= Regexp::IGNORECASE        # Like `/expr/i`
          expr = expr.join('|')
        end
        pattern = '^([^\p{Alnum}]*?)'         # $1 - leading characters
        pattern << "(#{expr})"                # $2 - target characters
        pattern << '([^\p{Alnum}]*)$'         # $3 - trailing characters
        Regexp.new(pattern, re_opt)
      end
    end

    # =========================================================================
    # :section:
    # =========================================================================

    public

    # Words that should normally appear just as they appear in this list.
    #
    # @see self#TITLEIZE_MIXEDCASE
    #
    # === Maintenance
    # Add words one per line, from longest to shortest.  Everything after a
    # comment character (#) is ignored.
    #
    # TODO: This should be maintained in a YAML file or other external config.
    #--
    # NOTE:
    # [1] Avoid lower-casing of Spanish articles in proper names.
    # [2] Technically this should be "VA" (and moved into UPPERCASE_WORDS) but
    #     SolrDocument#get_related_names appears to be improperly stripping out
    #     interior periods so examples like u2048658 and u3896239 would not
    #     be displayed as expected.
    #++
    MIXEDCASE_WORDS = make_word_list(<<-'EOS').deep_freeze
      da Vinci
      Los Angeles # [1]
      Va\.        # Virginia
      Va          # [2]
    EOS

    # Words that should always be in uppercase.
    #
    # === Maintenance
    # Add words one per line, from longest to shortest.  Everything after a
    # comment character (#) is ignored.
    #
    # TODO: This should be maintained in a YAML file or other external config.
    #
    # === Implementation Notes
    # Select Roman numerals are included but they would probably be better
    # handled algorithmically.
    #
    # @see self#TITLEIZE_UPPERCASE
    #
    UPPERCASE_WORDS = make_word_list(<<-'EOS').deep_freeze
      TAHPERD
      ICASE
      ICPSR
      JSTOR
      NIOSH
      USITC
      XVIII     # Roman numeral
      AHRQ
      DHEW
      DHHS
      IEEE
      ISBN
      ISSN
      NASA
      NATO
      NCAA
      NIMH
      NTIA
      PLOS
      SPIE
      USAF
      USMC
      VIII      # Roman numeral
      VTRC
      XIII      # Roman numeral
      XVII      # Roman numeral
      A\ &\ E
      ABA
      ABC
      AEI
      ASI
      BMJ
      CBO
      CLE
      CMH
      CNN
      DNA
      HHS
      IBM
      III       # Roman numeral
      MIT
      NAA
      NIH
      OCS
      PBS
      R&D
      SSA
      USA
      USN
      VII       # Roman numeral
      WTO
      XII       # Roman numeral
      XIV       # Roman numeral
      XIX       # Roman numeral
      XVI       # Roman numeral
      DA
      II        # Roman numeral
      IV        # Roman numeral
      IX        # Roman numeral
      UK
      XI        # Roman numeral
      XV        # Roman numeral
      XX        # Roman numeral
      I
    EOS

    # Words that should normally be in lowercase (except when at the start of a
    # phrase).
    #
    # @see self#TITLEIZE_LOWERCASE
    #
    # === Maintenance
    # Add words one per line, from longest to shortest.  Everything after a
    # comment character (#) is ignored.
    #
    # @see https://www.gpo.gov/fdsys/pkg/GPO-STYLEMANUAL-2008/html/GPO-STYLEMANUAL-2008-5.htm
    #
    # NOTE: The language "comments" are informational only.
    # The algorithm is not actually language-aware. If it turns out that this
    # approach is too aggressive in determining "lowercase-only" words, then
    # either this list should be trimmed or the method should be modified to
    # support selecting a language-specific word list.
    #
    # TODO: This should be maintained in a YAML file or other external config.
    #
    LOWERCASE_WORDS = make_word_list(<<-'EOS').deep_freeze
      van der
      van den
      and
      ca\.      # "circa"
      del       # Spanish
      des       # French
      etc
      for
      les       # French
      los       # Spanish
      nor
      pp\.      # "pages"
      the
      und       # German
      van       # German
      von       # German
      vs\.      # "versus"
      an
      as
      at
      by
      de        # Spanish
      di        # Italian
      du        # French
      el        # Spanish
      et        # French
      in
      la        # Spanish
      le        # French
      of
      on
      or
      to
      v\.       # "versus"
      a
      à         # Portuguese
      e         # Portuguese
      o         # Portuguese
      y         # Spanish
    EOS

    # Words matching ordinal numbers where the trailing characters should be
    # in lowercase.
    #
    # @see self#TITLEIZE_ORDINAL
    #
    ORDINAL_PATTERNS = make_word_list(<<-'EOS').deep_freeze
      1st
      2nd
      3rd
      [04-9]th          # 0th, 4th..9th
      \d*1\dth          # 10th..19th, 111th..119th, etc.
      \d*[2-9]1st       # 21st, 31st, 141st, etc.
      \d*[2-9]2nd       # 22nd, 32nd, 142nd, etc.
      \d*[2-9]3rd       # 23rd, 33rd, 143rd, etc.
      \d*[2-9][4-9]th   # 24th, 35th, 146th, etc.
    EOS

    # A list of words with spaces in them that should undergo capitalization as
    # a unit.
    SPACE_WORDS =
      (MIXEDCASE_WORDS + UPPERCASE_WORDS + LOWERCASE_WORDS + ORDINAL_PATTERNS)
        .select { |word| word =~ /[\p{Space}]/u }.deep_freeze

    # Words matching a suffix that may follow a personal name after a comma.
    #
    NAME_SUFFIX_WORDS = make_word_list(<<-'EOS').deep_freeze
      B.A.      # Bachelor of Arts
      BA
      B.S.      # Bachelor of Science
      BS
      D.D.      # Doctor of Divinity
      DD
      D.Phil.   # Doctor of Philosophy
      DPhil
      D.D.S.    # Doctor of Dental Surgery
      DDS
      Ed.D.     # Doctor of Education
      EdD
      Esquire
      Esq.
      J.D.      # Doctor of Jurisprudence
      JD
      Junior
      Jnr       # (British usage)
      Jr.
      Jr
      LL.D.     # Legum Doctor
      LLD
      M.B.A.    # Master of Business Administration
      MBA
      M.D.      # Medical Doctor
      MD
      M.A.      # Master of Arts
      MA
      Ph.D.     # Doctor of Philosophy
      PhD
      R.N.      # Registered Nurse
      RN
      Senior
      Snr       # (British usage)
      Sr.
      Sr
    EOS

    # =========================================================================
    # :section:
    # =========================================================================

    protected

    # Regular expression matching words that should normally appear just as
    # they appear in this list.
    #
    # @see self#titleize
    #
    TITLEIZE_MIXEDCASE = make_regex(MIXEDCASE_WORDS).freeze

    # Regular expression matching words that should always be in uppercase.
    #
    # @see self#titleize
    #
    TITLEIZE_UPPERCASE = make_regex(UPPERCASE_WORDS).freeze

    # Regular expression matching proper name components that should always be
    # in uppercase.
    #
    # @see self#titleize
    #
    TITLEIZE_NAME_UPPERCASE =
      make_regex(UPPERCASE_WORDS.reject { |v| v.length == 1 }).freeze

    # Regular expression matching words that should normally be in lowercase
    # (except when at the start of a phrase).
    #
    # @see self#titleize
    #
    TITLEIZE_LOWERCASE = make_regex(LOWERCASE_WORDS).freeze

    # Regular expression matching proper name components that should normally
    # be in lowercase (except when at the start of a phrase).
    #
    # @see self#titleize
    #
    TITLEIZE_NAME_LOWERCASE =
      make_regex(LOWERCASE_WORDS.reject { |v| v.length == 1 }).freeze

    # Regular expression matching ordinal numbers where the trailing characters
    # should be in lowercase.
    #
    # @see self#TITLEIZE_ORDINAL
    #
    TITLEIZE_ORDINAL = make_regex(ORDINAL_PATTERNS).freeze

    # Regular expression matching a sequence of initials, e.g.:
    #
    #   E.
    #   s.l.
    #   U.S.A.
    #   N.A.A.C.P.
    #
    # @see self#titleize
    #
    # === Implementation Notes
    # The construct '(?:...)' allows regular expression grouping without adding
    # the group to the set of capture groups. That way the group of trailing
    # characters generated by #make_regex can still be referenced with `$3`.
    # (Without the '?:' part, `$3` would refer to this group and the trailing
    # characters would be `$4`.)
    #
    TITLEIZE_INITIALS = make_regex('(?:[\p{Alpha}]\.)+').freeze

    # Regular expression matching a sequence of uppercase (and/or underscore)
    # characters.
    #
    # @see self#titleize
    #
    TITLEIZE_ALL_UPPERCASE = make_regex('[\p{Upper}][^\p{Lower}]*?').freeze

    # Regular expression matching a sequence of lowercase (and/or underscore)
    # characters.
    #
    # @see self#titleize
    #
    TITLEIZE_ALL_LOWERCASE = make_regex('[\p{Lower}][^\p{Upper}]*?').freeze

  end

end
