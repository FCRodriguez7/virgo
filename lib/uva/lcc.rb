# lib/uva/lcc.rb

require 'yaml'
require 'uva'

module UVA

  # Library of Congress Classification
  #
  # === LCC Call Numbers
  # Consists of two main parts: a classification number and a book number.
  # The classification number is taken from the LCC Outline; the book number
  # organizes works on one subject reflecting an alphabetical arrangement by
  # the MARC 1xx and/or MARC 245 fields.
  #
  # 1. Classification numbers: 1-3 capital letters followed by up to four
  #     Arabic numerals
  #
  #   a. Class letters: The first letter cannot be I, O, W, X, Y; the second
  #       letter cannot be O; any letter may be used in the third position.
  #       Only two classes (D and K) use three letters -- DAW, DJK; in KE and
  #       KF, the third letter represents a province or state name.
  #
  #   b. Numerals: Whole numbers arranged in ascending order.
  #
  #   c. Decimals: Decimals may follow numbers of any length; there is no limit
  #       on the length of a decimal number.
  #
  #   d. Cutter numbers: Represent topics or places and may occur after numbers
  #       of any length, including decimal numbers.  The format will be a
  #       single capital letter and one or more decimal digits, e.g.: ".P47".
  #
  #   e. Two Cutter numbers: A second Cutter number may occur, e.g.: ".Z9C6"
  #
  # 2. Book numbers: Added to classification numbers, normally to represent the
  #     main entry or the title, if no main entry is present.
  #
  #   a. Single Cutter number for main entry: If the class number consists of
  #     letters and numerals only, one Cutter number will usually be added,
  #     which is based on the MARC 1xx and/or MARC 245 fields.  E.g.: ".B845".
  #
  #   b. Double Cutters: If the class number contains a Cutter representing the
  #     subject matter or a single reserved Cutter, then a second Cutter number
  #     for the main entry or title is added.  E.g.: ".C42K87".
  #
  #   c. Book number in the final digits: If the class number requires two
  #     Cutters to represent the subject matter, the the works are arranged
  #     alphabetically but main entries are reflected in digits added to the
  #     second Cutter.
  #
  # OBSERVATIONS:
  # - Double Cutters should not be separated by periods ('.').
  # - There doesn't appear to be any automatic way to distinguish between a
  #     Cutter that is part of the classification number versus a Cutter that
  #     represents a book number.
  #
  # === Test Cases
  # @see https://xxx.virginia.edu/xxx
  #   *u6947238* DG260.A1 P53 2017 "The Age of Caesar: Five Roman Lives"
  #   This is is in one of the deepest call number ranges in the LCC hierarchy.
  #
  # === References
  # @see https://www.loc.gov/aba/publications/FreeCSM/G055.pdf
  #
  module Lcc

    include UVA

    # Location of LCCO YAML files.
    LCCO_DIR   = Rails.root.join('lib/config/lcco').freeze

    # Wildcards specifying the LCCO YAML file names.
    LCCO_FILES = File.join(LCCO_DIR, 'lcco_*.yml').freeze

    # =========================================================================
    # :section: Classes
    # =========================================================================

    public

    # A call number analyzed into a form which is suitable for comparisons.
    #
    # === Usage Notes
    # Note that #valid? may be
    #
    class LccNum

      include Comparable
      include Enumerable
      include UVA

      # =======================================================================
      # :section:
      # =======================================================================

      protected

      # Used to handle the decimal portion of the call number.
      #
      class Fraction

        attr_accessor :digits

        def initialize(value)
          @digits = value.to_i
        end

        def to_s
          @digits.to_s
        end

        def to_f
          "0.#{@digits}".to_f
        end

        def <=>(other)
          other = Fraction.new(other) unless other.is_a?(Fraction)
          to_f <=> other.to_f
        end

        def method_missing(name, *args, &block)
          @digits.send(name, *args, &block)
        end

      end

      # =======================================================================
      # :section:
      # =======================================================================

      public

      MAX_CALL_LETTERS = 3

      CLASS_PATTERN =
        /^
          ([A-Z]{1,#{MAX_CALL_LETTERS}})\s* # Call letter(s)
        $/x.freeze

      # This expression matches *valid* LC call numbers.
      VALID_NUMBER_PATTERN =
        /^
          ([A-Z]{1,#{MAX_CALL_LETTERS}})\s* # Call letter(s)
          (\d+)\s*                          # Call number
          \.?(\d*)\s*                       # Decimal number
          \.?\s*([A-Z]*)(\d*)\s*            # Cutter 1
          \.?\s*([A-Z]*)(\d*)\s*            # Cutter 2
          (.*)                              # Additional information
        $/x.freeze

      # This expression matches *valid* LC call numbers while relaxing the rule
      # that there has to be at least one digit after the call letters.  Many
      # UVA catalog items have a decimal point directly after the call letters.
      NUMBER_PATTERN =
        /^
          ([A-Z]{1,#{MAX_CALL_LETTERS}})\s* # Call letter(s)
          (\d*)\s*                          # Call number
          \.?(\d*)\s*                       # Decimal number
          \.?\s*([A-Z]*)(\d*)\s*            # Cutter 1
          \.?\s*([A-Z]*)(\d*)\s*            # Cutter 2
          (.*)                              # Additional information
        $/x.freeze

      # Note that the :decimal_number field is stored as an integer but
      # compared as the digits to the right of the decimal place in a floating
      # point number.
      FIELDS = {
        class_letters:   String,
        class_number:    Fixnum,
        decimal_number:  Fraction,
        cutter_1_letter: String,
        cutter_1_number: Fraction,
        cutter_2_letter: String,
        cutter_2_number: Fraction,
        remainder:       String,
      }.freeze

      # Call letter sequences and patterns that are known to indicate a non-LC
      # call number.
      NON_LC_CALL_LETTERS = [
        'MSS',      # Manuscripts
        /^[IOWXY]/, # No LC ranges start with these letters
      ].deep_freeze

      # =======================================================================
      # :section:
      # =======================================================================

      public

      # @return [Array<String,Fixnum,nil>]
      attr_accessor :field

      # The original call number
      # @return [String]
      attr_reader :display

      # Initialize a self instance.
      #
      # @param [String, LccNum, Array<String>] call_number
      #
      def initialize(call_number = nil)
        @field =
          case call_number
            when LccNum then call_number.dup if call_number.valid?
            when Array  then call_number.dup unless call_number.empty?
            else             parse(call_number)
          end
        unless @field
          Rails.logger.warn { "LccNum: invalid #{call_number.inspect}" }
          @field = []
        end
        @display ||= (call_number.dup if call_number.is_a?(String))
      end

      # =======================================================================
      # :section:
      # =======================================================================

      protected

      # Analyze a call number string into parts.
      #
      # @param [String, LccNum, Array<String>] call_number
      #
      def parse(call_number)
        result = nil

        # Clean up number.
        call_number = call_number.to_s.strip

        # Handle numbers like "ALD/HB501 .P4149 2003" by stripping away the
        # invalid leading "ALD/".
        call_number.sub!(%r{^[^/\s]*/}, '')

        # Deal with call number ranges that have been generated as partial
        # shelfkeys.
        call_number.gsub!(/\s+0+/, ' ')
        call_number.gsub!(/\.(\d*[1-9])0+(\s+|$)/, '.\1 ')
        call_number.gsub!(/\.0+(\s+|$)/, ' ')
        call_number.sub!(/^([A-Z]+)\s+(\d)/, '\1\2')
        call_number.strip!

        # Use the cleaned-up number as the displayable call number.
        @display = call_number.dup
        call_number.upcase!

        # Match against valid call number patterns.
        case call_number
          when CLASS_PATTERN
            # LCC classes or subclasses treated as call number ranges.
            result = [$1]

          when NUMBER_PATTERN
            # Normal generic call number pattern.
            class_letters   = str($1)
            class_number    = int($2)
            decimal_number  = fraction($3)
            cutter_1_letter = str($4)
            cutter_1_number = fraction($5)
            cutter_2_letter = str($6)
            cutter_2_number = fraction($7)
            remainder       = str($8.gsub(/\s/, ''))

            # Adjust interpretation.
            if cutter_2_letter && !cutter_2_number
              remainder = "#{cutter_2_letter}#{remainder}"
              cutter_2_letter = nil
            elsif !cutter_2_letter && (cutter_2_number.to_i > 1000)
              remainder = "#{cutter_2_number}#{remainder}"
              cutter_2_number = nil
            end

            # Trim away trailing *nil* elements.
            result = [
              class_letters,
              class_number,
              decimal_number,
              cutter_1_letter,
              cutter_1_number,
              cutter_2_letter,
              cutter_2_number,
              remainder
            ]
        end

        # Trim away trailing *nil* elements.
        result.reverse.drop_while(&:nil?).reverse if result
      end

      # Return nil unless *value* can be expressed as a string.
      #
      # @param [Object] value
      #
      # @return [String]
      # @return [nil]
      #
      def str(value)
        value.to_s if value.present?
      end

      # Return nil unless *value* can be expressed as an integer.
      #
      # @param [Object] value
      #
      # @return [Fixnum]
      # @return [nil]
      #
      def int(value)
        value.to_i if value.present?
      end

      # Return nil unless *value* can be expressed as integer to be used as
      # fractional digits.
      #
      # @param [Object] value
      #
      # @return [Fixnum]
      # @return [nil]
      #
      def fraction(value)
        Fraction.new(value) if value.present?
      end

      # =======================================================================
      # :section: Object overrides
      # =======================================================================

      public

      def to_s
        display(true)
      end

      # Show the contents of the field vector.
      #
      # @return [Array<String, Fixnum, nil>]
      #
      def inspect
        @field.inspect
      end

      # Indicate whether *other* has the same value as *self*, ignoring spaces
      # but checking all elements.
      #
      # Where "==" will return true if the items have differing numbers of
      # elements, this method will return true only if the items have the same
      # number of elements.
      #
      # @param [LccNum, String] other
      #
      def eql?(other)
        other = LccNum[other]
        (self.size == other.size) && compare_with(other).zero?
      end

      # Compare the current number with another.
      #
      # @param [LccNum, String] other
      #
      # @return [-1]                  If *self* collates after *other*.
      # @return [0]                   If *self* matches *other*.
      # @return [+1]                  If *self* collates before *other*.
      #
      def <=>(other)
        compare_with(other)
      end

      # Create a copy of the instance.
      #
      # @return [LccNum]
      #
      def dup
        self.class.new(self.field)
      end

      # =======================================================================
      # :section: Comparable overrides
      # =======================================================================

      public

      # Indicate whether the current number is contained in the range indicated
      # by the two boundary values.
      #
      # @param [LccNum, String] min
      # @param [LccNum, String] max
      #
      def between?(min, max)
        self.valid? && (LccNum[min] <= self) && (self <= LccNum[max])
      end

      # =======================================================================
      # :section: Enumerable overrides
      # =======================================================================

      public

      def to_a
        @field
      end

      def each(&block)
        @field.each(&block)
      end

      def [](index)
        return unless (index = field_index(index))
        @field[index]
      end

      def []=(index, value)
        return unless (index = field_index(index))
        @display = nil
        @field[index] = value
      end

      def size
        @field.size
      end

      def empty?
        @field.empty?
      end

      # =======================================================================
      # :section:
      # =======================================================================

      public

      # Indicate whether there is at least one field present.
      #
      # NOTE: Even if the instance is not valid, @display may hold a meaningful
      # value for display purposes (just not an LCC call number).
      #
      def valid?
        !empty?
      end

      # Return a string version of this item.
      #
      # @param [Boolean] show_all
      # @param [Boolean] regenerate
      #
      # @return [String]
      #
      def display(show_all = true, regenerate = false)
        non_blank_remainder =
          @field && (@field.size == FIELDS.size) && @field.last.present?
        if !show_all && non_blank_remainder
          all_but_last = @field.size - 1
          lc_format(@field.take(all_but_last))
        elsif regenerate || @display.blank?
          @display = lc_format(@field)
        else
          @display
        end
      end

      # A sortable representation of the LCC number parts.
      #
      # @return [String]
      #
      def to_shelfkey
        digits = 7  # A '.' and six zero-filled decimal digits.
        parts = @field.dup
        parts[0] = sprintf('%-3s',  parts[0].to_s)
        parts[1] = sprintf(' %04d', parts[1].to_i)
        parts[2] = sprintf('.%d',   parts[2].to_i).ljust(digits, '0')
        parts[3] = sprintf(' %s0',  parts[3].to_s)
        parts[4] = sprintf('.%d',   parts[4].to_i).ljust(digits, '0')
        parts[5] = sprintf(' %s0',  parts[5].to_s)
        parts[6] = sprintf('.%d',   parts[6].to_i).ljust(digits, '0')
        parts[7] =
          parts[7].to_s
            .gsub(/(\.)(\d)/, '\1 \2')
            .gsub(/(\d)\s*-\s*(\d)/, '\1-\2')
            .gsub(/(\d+)/) { |match| '%06d' % match.sub(/^0+/, '').to_i }
        parts.join
      end

      # A representation of the LCC number parts for reverse sorting.
      #
      # @return [String]
      #
      def to_reverse_shelfkey
        result = ''
        to_shelfkey.each_char { |c| result << (REVERSE_KEY_MAP[c] || '~') }
        result << ('~' * (50 - result.size))
      end

      # Compare the current number with another.
      #
      # @param [LccNum, String] other
      # @param [Hash]           opt
      #
      # @return [-1]                  If *self* collates after *other*.
      # @return [0]                   If *self* matches *other*.
      # @return [+1]                  If *self* collates before *other*.
      #
      def compare_with(other, opt = nil)
        other = LccNum[other]
        if self.empty? && other.empty?
          return 0
        elsif self.empty?
          return 1
        elsif other.empty?
          return -1
        end

        default_opt = { ignore_case: true, ignore_space: true }
        opt = opt ? default_opt.merge(opt) : default_opt
        max_index = [self.size, other.size].min - 1

        FIELDS.each_with_index do |attr_type, index|
          _attr, type = attr_type
          result = compare(self[index], other[index], opt.merge(type: type))
          return result unless result.zero?
          return result unless index < max_index
        end

        raise 'control never reaches here'
      end

      # =======================================================================
      # :section:
      # =======================================================================

      protected

      # Data fields can be addressed by index or by the associated symbol from
      # LccNum#FIELDS.
      #
      # @param [Fixnum, Symbol, String] index
      #
      # @return [Fixnum]
      # @return [nil]
      #
      def field_index(index)
        index = index.to_sym if index.is_a?(String)
        index = FIELDS.find_index { |k, _| k == index } if index.is_a?(Symbol)
        index if index.is_a?(Fixnum)
      end

      # Return the field array in LC format.
      #
      # @return [String]
      #
      def lc_format(data)
        data ||= @field || []
        s = ''
        s <<  "#{data[0]}"            if data[0]            # class_letters
        s <<  "#{data[1]}"            if data[1]            # class_number
        s << ".#{data[2]}"            if data[2]            # class_decimal
        s << " .#{data[3]}#{data[4]}" if data[3] || data[4] # cutter 1
        s << " .#{data[5]}#{data[6]}" if data[5] || data[6] # cutter 2
        s << " #{data[7]}"            if data[7]            # remainder
        s
      end

      # Compare two scalar values.
      #
      # @param [Object]  lhs
      # @param [Object]  rhs
      # @param [Hash]    opt          It is assumed that the caller has set the
      #                                 intended options explicitly.
      #
      # @return [Fixnum]              -1, 0 or +1
      #
      def compare(lhs, rhs, opt)
        lhs, rhs =
          [lhs, rhs].map do |value|
            if opt[:type] == Fraction
              value ? value.to_f : -1
            elsif opt[:type] == Fixnum
              value ? value.to_i : -1
            else
              value = value.to_s.dup
              value.upcase!      if opt[:ignore_case]
              value.tr!(' ', '') if opt[:ignore_space]
              value
            end
          end
        lhs <=> rhs
      end

      # =======================================================================
      # :section: Class methods
      # =======================================================================

      public

      # Convenience for allowing `LccNum[value]` to be used to create a new
      # instance only if necessary.
      #
      # @param [String, LccNum] call_number
      #
      # @return [LccNum]
      #
      def self.[](call_number)
        call_number.is_a?(LccNum) ? call_number : LccNum.new(call_number)
      end

      # from_shelfkey
      #
      # @param [String] shelfkey
      #
      # @return [LccNum]
      #
      # === Implementation Notes
      # If there isn't a second cutter then *shelfkey* will split into 6 parts
      # instead of 8 parts.
      #
      def self.from_shelfkey(shelfkey)

        shelfkey_parts = shelfkey.to_s.split(' ')
        result = []

        # Class letters, class number and decimal number.
        letters = shelfkey_parts.shift
        result << (letters if letters.present?)
        result += shelfkey_numbers(shelfkey_parts.shift)

        # Cutter 1 - may or may not be present.
        letter, number =
          if shelfkey_parts.first.to_s.include?('.')
            shelfkey_cutter(shelfkey_parts.shift)
          end
        result << letter
        result << number

        # Cutter 2 - may or may not be present.
        letter, number =
          if shelfkey_parts.first.to_s.include?('.')
            shelfkey_cutter(shelfkey_parts.shift)
          end
        result << letter
        result << number

        # The remainder is whatever is left in *shelfkey_parts*.
        remainder = shelfkey_parts.join(' ').split('.')
        remainder = remainder.map { |v| v.sub(/^0+/, '') if v }.join('.')
        result << (remainder if remainder.present?)

        LccNum.new(result)
      end

      # Use heuristics to determine whether the provided number really is an
      # LC call number.
      #
      # The logic of self#parse is somewhat naive and will analyze a string
      # into parts that may resemble an LC call number but are not actually
      # valid.  This method uses known exceptions to indicate whether the
      # number should really be considered an LC call number.
      #
      # @param [String, LccNum] number
      #
      def self.lc_format?(number)
        number = LccNum[number]
        cl = number[:class_letters]
        cn = number[:class_number]
        dn = number[:decimal_number]
        number.valid? &&
          lc_call_letters?(cl) &&                        # Non-LC letter(s)
          (cn || dn) &&                                  # No call number
          (!cn || (cn <= 9999)) &&                       # Too big for LC
          (!dn || (dn <= 9999)) &&                       # Too big for LC
          (number[:remainder] !~ /^:([A-Z]+[\s-]*)?\d+/) # SuDoc number
      end

      # Indicate that the given call letters do not match any known non-LC
      # call letter sequences or patterns.
      #
      # @param [String] letters
      #
      # === Implementation Notes
      # This does not exclude letter combinations that might be potentially
      # erroneous (e.g. "AA", "AB", "BE", etc.) -- only letter combinations
      # that do not have the right form (more than 3 letters) or are known to
      # be non-LC (e.g. "MSS").
      #
      def self.lc_call_letters?(letters)
        return unless letters =~ CLASS_PATTERN
        NON_LC_CALL_LETTERS.none? do |pattern|
          pattern.is_a?(Regexp) ? (letters =~ pattern) : (letters == pattern)
        end
      end

      # =======================================================================
      # :section: Class methods
      # =======================================================================

      protected

      # Extract the class number and/or decimal number from the string.
      #
      # @param [String] numbers
      #
      # @return [Array<(Fixnum,Fixnum)>]  Class number and decimal number;
      #                                     either value may be *nil*.
      #
      def self.shelfkey_numbers(numbers)
        numbers ||= ''
        class_number, decimal_number = numbers.split('.')
        class_number.sub!(/^0+/, '')   if class_number.present?
        decimal_number.sub!(/0+$/, '') if decimal_number.present?
        class_number   = (class_number.to_i   if class_number.present?)
        decimal_number = (decimal_number.to_i if decimal_number.present?)
        return class_number, decimal_number
      end

      # Extract a letter and optional number from the string.
      #
      # @param [String] cutter
      #
      # @return [Array<(String,Fixnum)>]  Cutter letter and cutter number;
      #                                     either value may be *nil*.
      #
      def self.shelfkey_cutter(cutter)
        cutter ||= ''
        letter, number = cutter.split('.').map { |v| v.sub(/0+$/, '') if v }
        letter = nil if letter.blank?
        number = (number.to_i if number.present?)
        return letter, number
      end

      # Generate the right-most call number value for a given class letter.
      #
      # @param [String] class_max
      # @param [String] cutter1_max
      # @param [String] cutter2_max
      #
      # @return [LccNum]
      #
      def self.max_num(class_max = 'Z', cutter1_max = 'Z', cutter2_max = 'Z')
        class_max   << 'Z' while class_max.length   < MAX_CALL_LETTERS
        cutter1_max << 'Z' while cutter1_max.length < MAX_CALL_LETTERS
        cutter2_max << 'Z' while cutter2_max.length < MAX_CALL_LETTERS
        number_max  = 999999
        LccNum.new([
          class_max,   number_max, number_max,
          cutter1_max, number_max,
          cutter2_max, number_max,
          ('Z' * MAX_CALL_LETTERS * 10)
        ])
      end

      # Set up the mapping to translate a shelfkey into a reverse shelfkey.
      #
      # @return [Hash]
      #
      def self.reverse_key_map
        chars = Array('0'..'9') + Array('A'..'Z')
        chars_max = chars.size - 1
        pairs = (0..chars_max).map { |i| [chars[i], chars[chars_max - i]] }
        pairs << [' ', '~']
        pairs << ['.', '}']
        Hash[pairs]
      end

      # =======================================================================
      # :section: Constants
      # =======================================================================

      public

      # The right-most call number.  Used as a template for creating call
      # numbers which specify the very last number of a range.
      MAX_NUM = self.max_num.freeze

      # Used as a template for creating reverse shelfkeys.
      REVERSE_KEY_MAP = self.reverse_key_map.deep_freeze

    end

    # The common aspects of a node in the LCC hierarchy.
    #
    class LccBase

      include Enumerable

      # @return [String]
      attr_reader :name

      # @return [String]
      attr_reader :ascii_name

      # @return [String]
      attr_reader :range

      # @return [String]
      attr_reader :range_start

      # @return [String]
      attr_reader :range_end

      # @return [String]
      attr_reader :note

      # @return [Boolean]
      attr_reader :artificial

      # @return [Array<LccBase>]
      attr_reader :branch

      # @return [Fixnum]
      attr_accessor :depth

      # Initialize a new self instance.
      #
      # @param [Array] args
      #
      # @option args [Fixnum]  :depth     Default 0.
      # @option args [Boolean] :recursive Default `true`.
      #
      # === Usage
      # new(depth, *args)
      # new(*args)
      #
      def initialize(*args)
        opt = ((args.size > 1) && args.last.is_a?(Hash)) ? args.pop.dup : {}
        opt[:recursive] = true unless opt.key?(:recursive)
        case args.first
          when Array
            args = prepare(args.first)
          when Hash
            hash = prepare(args.first)
            args = [
              hash[:name],
              hash[:sort_as],
              (hash[:range] || hash[:class] || hash[:subclass]),
              hash[:start],
              hash[:end],
              hash[:note],
              (!hash[:lcco] if hash.key?(:lcco)),
              hash[:sections],
            ]
          when LccBase
            other = args.first
            args = [
              other.name,
              other.ascii_name,
              other.range,
              other.range_start,
              other.range_end,
              other.note,
              other.artificial,
              (other.branch.rdup if opt[:recursive])
            ]
        end
        initialize_fields(*args.push(opt))
      end

      # =======================================================================
      # :section:
      # =======================================================================

      protected

      # prepare
      #
      # @return [src.class]
      #
      def prepare(src)
        case src
          when Hash  then src.map { |k, v| [k.to_sym, prepare(v)] }.to_h
          when Array then src.map { |v| prepare(v) }
          else            src
        end
      end

      # Initialize member variables.
      #
      # @param [Array] args
      #
      # @return [void]
      #
      def initialize_fields(*args)
        opt = args.last.is_a?(Hash) ? args.pop.dup : {}
        opt[:recursive] = true unless opt.key?(:recursive)

        @name        ||= args.shift
        @ascii_name  ||= args.shift
        @range       ||= args.shift
        @range_start ||= args.shift
        @range_end   ||= args.shift
        @note        ||= args.shift
        @artificial  ||= args.shift
        @branch      ||= []
        @start_num   ||= nil
        @end_num     ||= nil
        @depth       ||= opt[:depth].to_i

        # Remove "down-translated" non-ASCII characters.
        @ascii_name.sub!(/\s+[?.\s]+$/, '') if @ascii_name

        args.push(opt)
        eager_initialize(*args)  if opt[:eager]
        branch_initialize(*args) if opt[:recursive]
        validate                 if opt[:validate]
      end

      # Extra initialization actions if the :eager option is supplied as an
      # option to the initializer.
      #
      # @return [void]
      #
      def eager_initialize(*)
        start_num
        end_num
      end

      # Extra initialization actions if the :recursive option is supplied as an
      # option to the initializer.
      #
      # @return [void]
      #
      def branch_initialize(*args)
        opt = args.last.is_a?(Hash) ? args.pop.dup : {}
        opt[:depth] = @depth + 1
        nodes = args.shift
        nodes.each { |node| add_child(node, opt) } if nodes.present?
      end

      # Create an LccNum which can be used to represent the first of the set
      # of call numbers that could be represented by this node.
      #
      # @return [LccNum]
      # @return [nil]
      #
      def make_start_num
        LccNum[@range_start] if @range_start.present?
      end

      # Create an LccNum which can be used to represent the last of the set
      # of call numbers that could be represented by this node.
      #
      # @return [LccNum]
      # @return [nil]
      #
      def make_end_num
        LccNum[@range_end] if @range_end.present?
      end

      # Create a new node that can be used as a child of this node.
      #
      # @param [Array] args
      #
      # @return [LccBase]
      #
      def new_child(*args)
        raise "subclass must define #{__method__}(#{args})"
      end

      # Verify that the hierarchy of nodes is well-formed.
      #
      # Error messages are stored in `LccBase.problem` for summation.
      #
      def validate

        # Check self integrity.
        unless start_num <= end_num
          report = []
          report << "#{self.class} [#{@range}]"
          report << "start=#{start_num.inspect}"
          report << "end=#{end_num.inspect}"
          report << '- backwards range'
          LccBase.problem(report.join(' ').gsub(/UVA::Lcc::Lcc/, ''))
        end

        # Check child integrity.
        previous = nil
        @branch.each do |node|
          good_start = contains?(node.start_num)
          good_end   = contains?(node.end_num)
          error =
            if !good_start && !good_end
              :stray
            elsif !good_start
              :bad_start
            elsif !good_end
              :bad_end
            elsif previous && !(previous.end_num <= node.start_num)
              :overlap unless %w(DAW DJK KBM KWX).include?(node.lcc_subclass)
            end
          if error
            problem = []
            problem << "#{self.class} [#{@range}]"
            problem << "start=#{start_num.inspect}"
            problem << "end=#{end_num.inspect}"
            problem << '-'
            problem << "child #{node.class} [#{node.range}]"
            problem << "start=#{node.start_num.inspect}"
            problem << "end=#{node.end_num.inspect}"
            case error
              when :stray
                problem << 'completely out of range'
              when :bad_start
                problem << 'start is out of range'
              when :bad_end
                problem << 'end is out of range'
              when :overlap
                problem << 'overlaps'
                problem << "previous #{previous.class} [#{previous.range}]"
                problem << "start=#{previous.start_num.inspect}"
                problem << "end=#{previous.end_num.inspect}"
            end
            LccBase.problem(problem.join(' ').gsub(/UVA::Lcc::Lcc/, ''))
          end
          previous = node
        end

      end

      # =======================================================================
      # :section:
      # =======================================================================

      public

      # Description of this type of node.
      #
      # @return [String]
      #
      def type
        raise "subclass must define #{__method__}()"
      end

      # Name of the LCC class (valid only for LccClass instances).
      #
      # @return [String]
      # @return [nil]
      #
      def lcc_class
        @range if @depth == 1
      end

      # Name of the LCC subclass (valid only for LccSubclass instances).
      #
      # @return [String]
      # @return [nil]
      #
      def lcc_subclass
        @range if @depth == 2
      end

      # Start of the call number range covered by this node.
      #
      # @return [LccNum]
      #
      def start_num
        @start_num ||= make_start_num
      end

      # End of the call number range covered by this node.
      #
      # @return [LccNum]
      #
      def end_num
        @end_num ||= make_end_num
      end

      # Usually a subclass doesn't have a name of its own -- it has to be
      # constructed from its first child node (or all of its children).
      #
      # The base version of this method simply returns the name.
      #
      # @return [String]
      #
      def effective_name(*)
        @name
      end

      # Add a child node.
      #
      # @param [Array] args
      #
      # @return [LccBase]
      #
      def add_child(*args)
        node = args.first.is_a?(LccBase) ? args.first : new_child(*args)
        @branch << node
        node
      end

      # Indicate whether the call number is within the range represented by
      # this node.
      #
      # @param [LccNum, String] call_number
      #
      def contains?(call_number)
        raise "subclass must define #{__method__}(#{call_number})"
      end

      # Apply the given block to each subtree.
      #
      def each(&block)
        @branch.each(&block)
      end

      # Convert the node to a hash value.
      #
      # @param [Hash] opt
      #
      # @option opt [Boolean] :recursive      Default: *true*.
      # @option opt [Boolean] :include_blank  Default: *false*.
      #
      # @return [Hash]
      #
      def to_hash(opt = nil)
        opt ||= {}
        recursive = !opt.key?(:recursive) || opt[:recursive]
        include_blank = true_value?(opt[:include_blank])

        result = {
          name:       @name,
          ascii_name: @ascii_name,
          note:       @note,
          lcco:       artificial,
          class:      lcc_class,
          subclass:   lcc_subclass,
          range:      @range,
          start:      @range_start,
          end:        @range_end,
        }

        # Don't include items with empty values *except* for :lcco.
        # This item should only be included if it's *false*.
        unless include_blank
          result.delete_if do |k, v|
            [:lcco, :class, :subclass].include?(k) ? v.nil? : v.blank?
          end
        end

        # Include child nodes.
        if recursive && @branch.present?
          result[:sections] = @branch.map { |v| v.to_hash(opt) }
        end

        result
      end

      # Render the node as JSON.
      #
      # @param [Hash] opt             @see self#to_hash
      #
      # @return [String]
      #
      def to_json(opt = nil)
        hash = as_json(opt)
        if opt && true_value?(opt[:formatted])
          require 'json'
          JSON.pretty_generate(hash)
        else
          hash.to_json
        end
      end

      # Render the node as XML.
      #
      # @param [Hash] opt
      #
      # @option opt [Boolean] :recursive      Default: *true*.
      # @option opt [Boolean] :include_blank  Default: *false*.
      # @option opt [Boolean] :formatted      Default: *false*.
      #
      # @return [String]
      #
      def to_xml(opt = nil)
        opt ||= {}
        recursive = !opt.key?(:recursive) || opt[:recursive]
        formatted = true_value?(opt[:formatted])

        nl     = formatted ? "\n" : ''
        tab    = formatted ? '  ' : ''
        indent = tab * depth

        # Start of current node.
        if depth.zero?
          node_name = nil
          node = '<?xml>'
        else
          node_name = self.class.to_s.sub(/^.*Lcc/, '').downcase
          node = [node_name]
          node +=
            to_hash(opt.merge(recursive: false)).map do |k, v|
              v = v.to_s.tr('"', "'")
              %Q(#{k}="#{v}")
            end
          node = '<' + node.join(' ') + '>'
        end
        result = "#{indent}#{node}"

        # Child nodes.
        if recursive && branch.present?
          result << nl
          result << branch.map { |child| child.to_xml(opt) }.join
          result << indent
        end

        # End of current node.
        result << "</#{node_name}>#{nl}" if node_name

        result
      end

      # Render the node as HTML.
      #
      # @param [Hash] opt
      #
      # @option opt [Boolean] :recursive
      # @option opt [Boolean] :include_blank
      # @option opt [Boolean] :formatted
      #
      # @return [ActiveSupport::SafeBuffer]
      #
      def to_html(opt = nil)
        opt ||= {}
        recursive = !opt.key?(:recursive) || opt[:recursive]
        formatted = true_value?(opt[:formatted])

        nl     = formatted ? "\n" : ''
        tab    = formatted ? '  ' : ''
        indent = tab * depth

        # Start of current node.
        if depth.zero?
          node = '<div class="lcc-root">'
        else
          node_name = self.class.to_s.sub(/^.*Lcc/, 'lcc-').downcase
          node = ["<dl class=\"#{node_name} level#{depth}\">"]
          node +=
            to_hash(opt.merge(recursive: false)).map do |k, v|
              k = ERB::Util.h(k)
              v = ERB::Util.h(v)
              "#{indent}#{tab}<dt>#{k}</dt><dd>#{v}</dd>"
            end
          node = node.join(nl)
        end
        result = "#{indent}#{node}#{nl}"

        # Child nodes
        if recursive && branch.present?
          result << branch.map { |child| child.to_html(opt) }.join
        end

        # End of current node.
        if depth.zero?
          result << '</div>'
        else
          result << "#{indent}</dl>#{nl}"
        end
        result.html_safe
      end

      # =======================================================================
      # :section: Enumerable overrides
      # =======================================================================

      public

      def to_a
        @branch
      end

      # Generate a hash that will be serialized as JSON.
      #
      # @param [Hash] opt             @see self#to_hash
      #
      # @return [Hash]
      #
      def as_json(opt = nil)
        to_hash(opt)
      end

      # =======================================================================
      # :section: Object overrides
      # =======================================================================

      public

      def dup(recursive = true)
        self.class.new(self, depth: @depth, recursive: recursive)
      end

      # =======================================================================
      # :section: Class methods
      # =======================================================================

      public

      # Validation problems identified via #validate.
      #
      # @param [Array<String>] args   Line(s) to add to the problem list.
      #
      # @return [Array<String>]       If there were no problems the result will
      #                                 be an empty array.
      #
      def self.problem(*args)
        @problem ||= []
        @problem += args
      end

    end

    # For convenience, Lcc#hierarchy as a node with each LCC class as a branch.
    #
    class LccRoot < LccBase

      def initialize(path)
        initialize_fields(path: path)
      end

      # =======================================================================
      # :section: LccBase overrides
      # =======================================================================

      protected

      # Extra initialization actions if the :recursive option is supplied as an
      # option to the initializer.
      #
      # @param [Array] args
      #
      # @option args [String] :path   Glob pattern for source files.
      #
      # @return [void]
      #
      def branch_initialize(*args)
        opt = args.last.is_a?(Hash) ? args.pop.dup : {}
        path = opt.delete(:path) || LCCO_FILES
        opt[:eager]    = true unless opt.key?(:eager)
        opt[:validate] = true if Virgo.development? && !opt.key?(:validate)

        # Each YAML file is the hierarchy rooted under a specific LCC
        # classification letter.
        Rails.logger.debug { "LccRoot: GENERATE LCC DATA #{path} - BEGIN" }
        Dir[path].sort.each do |filename|
          hash = YAML.load_file(filename)
          quietly { add_child(hash, opt) } if hash.present?
        end
        Rails.logger.debug { "LccRoot: GENERATE LCC DATA #{path} - END" }

        # If validating, report any inconsistencies.
        if opt[:validate] && LccBase.problem.present?
          Rails.logger.warn {
            "WARNING: LccRoot: LCCO PROBLEMS:\n" + LccBase.problem.join("\n")
          }
        end
      end

      # Create a new node that can be used as a child of this node.
      #
      # @param [Array] args
      #
      # @return [LccClass]
      #
      def new_child(*args)
        LccClass.new(*args).tap { |result| result.depth = @depth + 1 }
      end

      # =======================================================================
      # :section: LccBase overrides
      # =======================================================================

      public

      # Description of this type of node.
      #
      # @return [String]
      #
      def type
        'root'
      end

      # Indicate whether the call number is within the range represented by
      # this node.
      #
      # @param [LccNum, String] call_number
      #
      def contains?(call_number)
        LccNum[call_number].valid?
      end

    end

    # An LCC class.  Usually this is just the :class value and a :name.
    #
    class LccClass < LccBase

      def initialize(*args)
        opt = ((args.size > 1) && args.last.is_a?(Hash)) ? args.pop.dup : {}
        opt[:depth] = 1
        args.push(opt)
        super
      end

      # =======================================================================
      # :section: LccBase overrides
      # =======================================================================

      protected

      # Create an LccNum which can be used to represent the first of the set
      # of call numbers that could be represented by this subclass.
      #
      # @return [LccNum]
      #
      def make_start_num
        super || LccNum[lcc_class]
      end


      # Create an LccNum which can be used to represent the last of the set
      # of call numbers that could be represented by this subclass.
      #
      # @return [LccNum]
      #
      def make_end_num
        super || LccNum::MAX_NUM.dup.tap do |num|
          end_letters = lcc_class.dup
          end_letters << 'Z' while end_letters.size < LccNum::MAX_CALL_LETTERS
          num[0] = end_letters
        end
      end

      # Create a new node that can be used as a child of this node.
      #
      # @param [Array] args
      #
      # @return [LccSubclass]
      #
      def new_child(*args)
        LccSubclass.new(*args).tap { |result| result.depth = @depth + 1 }
      end

      # =======================================================================
      # :section: LccBase overrides
      # =======================================================================

      public

      # Description of this type of node.
      #
      # @return [String]
      #
      def type
        'class'
      end

      # Indicate whether the call number is within the range represented by
      # this node.
      #
      # @param [LccNum, String] call_number
      #
      def contains?(call_number)
        LccNum[call_number][:class_letters].to_s.start_with?(lcc_class)
      end

    end

    # An LCC subclass.
    #
    class LccSubclass < LccBase

      def initialize(*args)
        opt = ((args.size > 1) && args.last.is_a?(Hash)) ? args.pop.dup : {}
        opt[:depth] = 2
        args.push(opt)
        super
      end

      # =======================================================================
      # :section: LccBase overrides
      # =======================================================================

      protected

      # Create an LccNum which can be used to represent the first of the set
      # of call numbers that could be represented by this subclass.
      #
      # Usually subclasses are one to three letters but there is a single case
      # where the subclass is given as "KJ-KKZ".  In this case, the substring
      # before the hyphen is used to construct the LccNum.
      #
      # UPDATE: The data has been refactored so that separate subclass nodes
      # have been created for "KJ" and "KK"; although the previous logic is
      # still in place, it shouldn't be engaged because subclass names now only
      # contain uppercase alphabetic characters.
      #
      # @return [LccNum]
      #
      def make_start_num
        super || LccNum[lcc_subclass.split('-')[0]]
      end

      # Create an LccNum which can be used to represent the last of the set
      # of call numbers that could be represented by this subclass.
      #
      # Usually subclasses are one to three letters but there is a single case
      # where the subclass is given as "KJ-KKZ".  In this case, the substring
      # after the hyphen is used to construct the LccNum.
      #
      # UPDATE: The data has been refactored so that separate subclass nodes
      # have been created for "KJ" and "KK"; although the previous logic is
      # still in place, it shouldn't be engaged because subclass names now only
      # contain uppercase alphabetic characters.
      #
      # @return [LccNum]
      #
      def make_end_num
        super || LccNum::MAX_NUM.dup.tap do |num|
          end_letters = lcc_subclass.split('-')[1] || lcc_subclass.dup
          unless end_letters.size == 1
            end_letters << 'Z' while end_letters.size < LccNum::MAX_CALL_LETTERS
          end
          num[0] = end_letters
        end
      end

      # Create a new node that can be used as a child of this node.
      #
      # @param [Array] args
      #
      # @return [LccSubclass]
      #
      def new_child(*args)
        LccRange.new(*args).tap { |result| result.depth = @depth + 1 }
      end

      # =======================================================================
      # :section: LccBase overrides
      # =======================================================================

      public

      # Description of this type of node.
      #
      # @return [String]
      #
      def type
        'subclass'
      end

      # Usually a subclass doesn't have a name of its own -- it has to be
      # constructed from its first child node (or all of its children).
      #
      # @param [Boolean] all_children
      #
      # @return [String]
      #
      def effective_name(all_children = true)
        name = super
        if name.present?
          name
        elsif all_children
          branch.map(&:name).reject(&:blank?).join('. ')
        else
          branch.first.name.to_s
        end
      end

      # Indicate whether the call number is within the range represented by
      # this node.
      #
      # @param [LccNum, String] call_number
      #
      # === Implementation Notes
      # Most call numbers have only one or two call letters; there are a
      # limited number of exceptional cases:
      #
      # - Subclasses 'DAW', 'DJK', 'KBM', 'KBP', 'KBR', 'KBU', and 'KDZ' all
      #   contain three-letter call numbers beginning with their respective
      #   names.
      #
      # - Subclass 'KWX' has been artificially inserted to separate the topic
      #   'Antarctica' from the rest of the 'KW' ('Pacific Area') topics.
      #
      # - Otherwise, the two-letter subclasses /K[D-Z]/ contain three-letter
      #   call numbers beginning with their respective names.
      #
      def contains?(call_number)
        call_number = LccNum[call_number]
        return unless call_number.valid?
        letters = call_number[:class_letters]
        if %w(DAW DJK KBM KBP KBR KBU KDZ KWX).include?(letters)
          lcc_subclass == letters
        else
          call_number.between?(start_num, end_num)
        end
      end

    end

    # A named LCC call number range.
    #
    class LccRange < LccBase

      # =======================================================================
      # :section: LccBase overrides
      # =======================================================================

      protected

      # Create a new node that can be used as a child of this node.
      #
      # @param [Array] args
      #
      # @return [LccRange]
      #
      def new_child(*args)
        LccRange.new(*args).tap { |result| result.depth = @depth + 1 }
      end

      # =======================================================================
      # :section:
      # =======================================================================

      public

      # Description of this type of node.
      #
      # @return [String]
      #
      def type
        'range'
      end

      # Indicate whether the call number is within the range represented by
      # this node.
      #
      # @param [LccNum, String] call_number
      #
      def contains?(call_number)
        LccNum[call_number].between?(start_num, end_num)
      end

    end

    # =========================================================================
    # :section:
    # =========================================================================

    public

    # lcc_number
    #
    # @param [String, LccNum] call_number
    #
    # @return [LccNum]
    #
    # === Usage Notes
    # Needed for view templates; otherwise the shorthand `LccNum[call_number]`
    # can be used.
    #
    def lcc_number(call_number)
      LccNum[call_number]
    end

    # =========================================================================
    # :section: Module methods
    # =========================================================================

    public

    # The entire LCC outline hierarchy loaded from the YAML files.
    #
    # @return [LccRoot]
    #
    def self.hierarchy
      LCCO_OUTLINE
    end

    # The root of the LCC hierarchy.
    #
    # @return [LccRoot]
    #
    def self.root_node
      Lcc.hierarchy
    end

    # All LCC classes.
    #
    # @return [Array<LccClass>]
    #
    def self.classes
      root_node.branch
    end

    # All LCC subclasses.
    #
    # @return [Array<LccSubclass>]
    #
    def self.subclasses
      classes.flat_map { |class_node| class_node.branch }
    end

    # The tree rooted at the LCC class with the given identifier.
    #
    # @param [String] identifier
    #
    # @return [LccClass]
    # @return [nil]
    #
    def self.class_tree(identifier)
      classes.find { |node| node.lcc_class == identifier }
    end

    # The tree rooted at the LCC subclass with the given identifier.
    #
    # @param [String] identifier
    #
    # @return [LccSubclass]
    # @return [nil]
    #
    def self.subclass_tree(identifier)
      result = nil
      classes.find do |class_node|
        result =
          class_node.branch.find { |node| node.lcc_subclass == identifier }
      end
      result
    end

    # The tree rooted at the LCC node with the given identifier.
    #
    # @param [String] range
    #
    # @return [LccSubclass]
    # @return [nil]
    #
    def self.range_tree(range)
      number = LccNum[range.split('-').first]
      return unless number.valid?
      classes.find do |class_node|
        next unless class_node.contains?(number)
        return class_node if range == class_node.lcc_class
        class_node.branch.find do |subclass_node|
          next unless subclass_node.contains?(number)
          return subclass_node if range == subclass_node.lcc_subclass
          subclass_node.branch.find do |node|
            result = find_node(node, range, number)
            return result if result
          end
        end
      end
    end

    # find_node
    #
    # @param [LccBase] node
    # @param [String]  range
    # @param [LccNode] number
    #
    # @return [LccBase]
    # @return [nil]
    #
    def self.find_node(node, range, number)

      # Check whether *call_number* is within the bounds of this node.
      quietly { return unless node && node.contains?(number) }

      # Return this node if there is an exact match on the range.
      return node if range == node.range

      # Attempt to find the branch where this call number fits more precisely.
      child_node = nil
      node.branch.find do |branch_node|
        child_node = node(branch_node, range, number)
      end
      return child_node || node
    end

    # Return the portion of the LCC hierarchy tree at the indicated *level*
    # which contains the given *call_number*.
    #
    # @param [Fixnum]         level
    # @param [String, LccNum] call_number
    #
    # @return [LccBase]
    # @return [nil]
    #
    def self.tree(level, call_number)
      call_number = LccNum[call_number]
      return unless call_number.valid?
      level = level.to_i - 1
      node  = (level > 0) ? tree(level, call_number) : root_node
      return if node.blank? || node.branch.blank?
      node.branch.find do |branch_node|
        branch_node.contains?(call_number)
      end
    end

    # A vector of nodes which the path through the hierarchy from the root to
    # the call number range that most narrowly contains the call number.
    #
    # @param [LccNum, String] call_number
    #
    # @return [Array<LccBase>]
    #
    def self.node_path(call_number)
      call_number = LccNum[call_number]
      result = []
      if call_number.valid?
        curr = root_node
        while curr
          result << curr
          curr = curr.branch.find { |node| node.contains?(call_number) }
        end
      end
      result
    end

    # Get a copy of the node at *level* depth that contains *call_number*,
    # and all of its descendents that contain *call_number*.
    #
    # @param [Fixnum]         level
    # @param [LccNum, String] call_number
    #
    # @return [LccBase]
    # @return [nil]
    #
    def self.tree_copy(level, call_number)
      call_number = LccNum[call_number]
      return unless call_number.valid?
      level = [1, level].max
      copy = nil
      classes.find do |branch_node|
        copy = node_copy(branch_node, call_number)
      end
      while copy && ((level -= 1) > 0)
        copy = copy.branch.first
      end
      copy
    end

    # If *node* contains *call_number*, get a copy of it and all of its
    # descendents that contain *call_number*.
    #
    # @param [LccBase]        node
    # @param [LccNum, String] call_number
    #
    # @return [LccBase]
    # @return [nil]
    #
    def self.node_copy(node, call_number)

      # Check whether *call_number* is within the bounds of this node.
      quietly { return unless node && node.contains?(call_number) }

      # Attempt to find the branch where this call number fits more precisely.
      copy = nil
      node.branch.find do |branch_node|
        copy = node_copy(branch_node, call_number)
      end

      # Return with a copy of the branch (if any) attached to a copy of the
      # tree node.
      node.dup(false).tap do |result|
        result.add_child(copy) if copy
      end
    end

    # Load the LCC outline hierarchy from the YAML files.
    #
    # @param [String] path
    #
    # @return [Array<Hash>]
    #
    def self.generate(path = nil)
      LccRoot.new(path || LCCO_FILES)
    end

    # =========================================================================
    # :section:
    # =========================================================================

    public

    # This constant is "eager loaded" so that it only needs to be resolved when
    # the system initializes (to avoid incurring the cost of processing the
    # YAML files with each client request).
    LCCO_OUTLINE = self.generate

  end

end
