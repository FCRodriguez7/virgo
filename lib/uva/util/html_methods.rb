# encoding: UTF-8 # lib/uva/util/html_methods.rb

require 'erb'
require 'htmlentities'
require 'rexml/document'
require 'rexml/text'
require 'sanitize'
require 'unicode'
require 'uva/util'

module UVA::Util

  # UVA::Util::HtmlMethods
  #
  # === Implementation Note
  # This module does not use "extend self" so that the data items stored with
  # the module class do not show up as instance variables in classes that
  # include this module.
  #
  # (This is particularly relevant for classes that export themselves as JSON
  # by enumerating over their instance variables, but also can cause problems
  # with Rails.cache.)
  #
  module HtmlMethods

    include UVA::Util::TextConstants

    # HTML break element.
    #
    # @see self#has_embedded_html?
    # @see HtmlMethods#html_truncate
    # @see HtmlMethods#html_multiline
    #
    BREAK = '<br/>'.freeze

    # The characters to be appended when truncating a string.
    #
    # @see HtmlMethods#html_truncate
    #
    TRUNCATE_OMISSION = '... [more]'.freeze

    # Default length when truncating a string.
    #
    # @see HtmlMethods#html_truncate
    #
    TRUNCATE_LENGTH = 80

    # HTML entities that typically occupy the width of two characters when
    # displayed.
    #
    # @see HtmlMethods#html_truncate
    #
    DOUBLE_WIDTH_ENTITY = %w(
      ctdots
      hellip
    ).map { |v| "&#{v};" }.deep_freeze

    # A pattern for matching self#DOUBLE_WIDTH_ENTITY.
    #
    # @see HtmlMethods#html_truncate
    #
    DOUBLE_WIDTH_ENTITIES = Regexp.union(*DOUBLE_WIDTH_ENTITY)

    # HTML elements which are allowed with relaxed sanitization.
    #
    # @see HtmlMethods#sanitize_html
    #
    ALLOWED_TAGS = %w(a b br em i p sub sup string strong u).deep_freeze

    # HTML attributes which are allowed with relaxed sanitization.
    #
    # @see HtmlMethods#sanitize_html
    #
    ALLOWED_ATTRS = { 'a' => %w(href title) }.deep_freeze

    # Default options for relaxed sanitization.
    #
    # @see HtmlMethods#sanitize_html
    # @see self#ALLOWED_TAGS
    # @see self#ALLOWED_ATTRS
    #
    SANITIZE_DEF_OPTS = { elements: ALLOWED_TAGS, attributes: ALLOWED_ATTRS }

    # Transliterations of Unicode special characters to one or more characters
    # that could be expressed in 7-bit ASCII.
    #
    # @see HtmlMethods#strip_html
    #
    ASCII_EQUIV = {
      '►' => '>',
      '▶' => '>',
      '•' => '*',
      '·' => '*',
      '–' => '-',
      '—' => '--',
      '→' => '->',
      '←' => '<-',
      '↔' => '<->',
      '⇒' => '=>',
      '⇐' => '<=',
      '⇔' => '<=>',
      '≤' => '<=',
      '≦' => '<=',
      '≥' => '>=',
      '≧' => '>=',
      '©' => '(c)',
      '®' => '(R)',
      '’' => %q('),
      '‹' => %q('),
      '›' => %q('),
      '«' => %q("),
      '»' => %q("),
    }.deep_freeze

    # Characters that can be expressed in the basic GSM alphabet, which can be
    # encoded in one byte.
    #
    # @see UVA::Helper::TextMessages
    # @see https://en.wikipedia.org/wiki/GSM_03.38
    #
    # === Implementation Notes
    # Due to the inability to successfully transmit SMS texts with non-ASCII
    # characters, this constant currently contains only ASCII-compatible
    # characters.
    #
    GSM_BASIC_CHARS = (
      %q{@$!"#%&'()*+,-./:;<=>?} <<
        "\n\r\s" << ['0'..'9', 'a'..'z', 'A'..'Z'].flat_map(&:to_a).join
    ).freeze
    # GSM_BASIC_CHARS = (
    # %q{@£$¥èéúìòÇØøÅåΔΦΓΛΩΠΨΣΘΞÆæβÉ!"#¤%&'()*+,-./:;<=>?¡ÄÖÑÜ§¿äöñüà} <<
    #   "\n\r\s" << ['0'..'9', 'a'..'z', 'A'..'Z'].flat_map(&:to_a).join
    # ).freeze

    # Characters that can be expressed in the extended GSM alphabet.  Because
    # these must be prefixed with an ESC (escape character), takes up two bytes
    # of output.
    #
    # @see UVA::Helper::TextMessages
    # @see https://en.wikipedia.org/wiki/GSM_03.38
    #
    # === Implementation Notes
    # This is supposed to include the euro symbol (€) but there are conversion
    # problems when using that.
    #
    GSM_EXT_CHARS = %q(^{}\[~]|).freeze

    # For building regular expression to match characters that can be expressed
    # in the GSM alphabet.
    GSM_CHAR_PATTERN =
      (GSM_BASIC_CHARS + GSM_EXT_CHARS).gsub(/[\[\]\-\\]/, '\\\\\&').freeze

    # Regular expression matching characters that can be expressed in the GSM
    # alphabet.
    GSM_EXPR = /[#{GSM_CHAR_PATTERN}]/.freeze

    # Regular expression matching characters that cannot be expressed in the
    # GSM alphabet.
    NON_GSM_EXPR = /[^#{GSM_CHAR_PATTERN}]/.freeze

    # Used to prevent #html_multiline from translating newlines within HTML
    # attributes into "<br/>".
    ESCAPED_NEWLINE = '@nl@'#.freeze

    # =========================================================================
    # :section:
    # =========================================================================

    public

    # Create plain text by removing HTML tags surrounding text and by
    # replacing HTML entities with plain-text equivalents.
    #
    # @param [String] value
    # @param [Hash]   opt
    #
    # @return [String]
    #
    # @see HtmlMethods#strip_html
    #
    def strip_html(value, opt = nil)
      HtmlMethods.strip_html(value, opt)
    end

    # For a string with embedded HTML elements, remove unwanted HTML tags
    # while retaining the text they enclose.
    #
    # @param [String] value
    # @param [Hash]   opt
    #
    # @return [String]
    #
    # @see HtmlMethods#sanitize_html
    #
    def sanitize_html(value, opt = nil)
      HtmlMethods.sanitize_html(value, opt)
    end

    # Replace newlines with HTML breaks, insert HTML breaks before bullets,
    # and eliminate extra HTML breaks.
    #
    # @param [String] value
    #
    # @return [String]
    #
    # @see HtmlMethods#html_multiline
    #
    def html_multiline(value)
      HtmlMethods.html_multiline(value)
    end

    # HTML decoder.
    #
    # @param [String, Array<String>] value
    #
    # @return [String]                If *value* is a String.
    # @return [Array<String>]         If *value* is an Array.
    #
    # @see HtmlMethods#html_decode
    #
    def html_decode(value)
      HtmlMethods.html_decode(value)
    end

    # Determine quickly (heuristically) whether a string has an HTML fragment.
    #
    # @param [String]  value
    # @param [Boolean] count_breaks   Don't count #BREAK by default -- this
    #                                   allows the method to be meaningful for
    #                                   a value returned from #sanitize_html.
    #
    # @return [ActiveSupport::SafeBuffer]
    #
    # @see HtmlMethods#html_multiline
    #
    def has_embedded_html?(value, count_breaks = false)
      return unless value.present?
      value = value.gsub(%r{#{BREAK}}, '') unless count_breaks
      value.match?(/<[a-zA-Z]+[^>]*?>/)
    end

    # Safely truncates a string that may contain embedded HTML element(s) by
    # ensuring that HTML tags remain balanced even if text characters are
    # removed.
    #
    # @param [String] value           String to truncate.
    # @param [Hash]   opt             Options (see below).
    #
    # === Options
    # @option opt [Fixnum]  :length   Maximum limit on the number of characters
    #                                   in the result string.
    #
    # @option opt [String]  :omission Characters to append to a truncated
    #                                   result in place of the default
    #                                   self#TRUNCATE_OMISSION.
    #
    # @option opt [Boolean] :literal  If *true* then the characters that make
    #                                   up HTML breaks and entities are counted
    #                                   literally (e.g.: '&nbsp;' would take up
    #                                   6 characters); by default these count
    #                                   as a single character in the result.
    #
    # @return [ActiveSupport::SafeBuffer]
    #
    # @see self#html_truncate_node
    #
    # === Implementation Notes
    # This method uses REXML to partition the string in a tree of XML nodes
    # where spans of text become REXML::Text nodes and HTML elements become
    # REXML::Element nodes.  Only the characters within the Text nodes are
    # counted against the target *length*.  Because REXML wants to deal with
    # valid XML trees, the *value* string is wrapped in a temporary root
    # element (which does not appear in the result).
    #
    # If the string is not a legal HTML fragment (e.g., it has a literal '&')
    # then REXML will raise an exception and the method will fall back to
    # truncating the HTML-escaped string.
    #
    def html_truncate(value, opt = nil)
      opt ||= {}
      length   = opt[:length]   || TRUNCATE_LENGTH
      omission = opt[:omission] || TRUNCATE_OMISSION
      literal  = opt[:literal]
      result = nil
      # If *omission* contains HTML entities, compensate for the fact that the
      # each "&...;" pattern will only consume one character width.
      omission_length = 0
      unless literal
        omission_length += omission.scan(DOUBLE_WIDTH_ENTITIES).length
        omission = html_decode(omission)
      end
      omission_length += omission.length
      # If *value* contains HTML fragment(s), wrap it in a fake root element
      # to process via #html_truncate_node.
      if has_embedded_html?(value)
        root  = "TMP_ROOT_#{$$}"
        rex   = REXML::Document.new("<#{root}>#{value}</#{root}>")
        limit = length - omission_length
        result, truncated, _count = html_truncate_node(rex.root, limit)
        result << omission if truncated
        result = result.html_safe
      end
    rescue => e
      Rails.logger.debug { "#{__method__}: #{e}: #{e.message}" }
      result = nil
    ensure
      # If *value* did not contain HTML (or if #html_truncate_node failed) then
      # process the string directly.  However, we still want to honor "<br/>"
      # as a mechanism for causing the display to go to the next line, so
      # breaks will be reconstituted.
      unless result
        unless literal
          value = html_decode(value)
          as_displayed = value.gsub(%r{#{BREAK}|#{ESCAPED_NEWLINE}}i, '_')
          length += (value.length - as_displayed.length)
          length += (omission.length - omission_length)
        end
        result = value.truncate(length, omission: omission)
        result = strip_html(result)
      end
      return html_multiline(result)
    end

    # =========================================================================
    # :section:
    # =========================================================================

    protected

    # Recursively accumulate the contents of the tree (including HTML element
    # tags), returning the number of text characters (not counting those in the
    # HTML element tags).
    #
    # @param [REXML::Node] node
    # @param [Fixnum]      length
    #
    # @return [Array<(String, Boolean, Fixnum)>]
    #
    # === Implementation Notes
    # This algorithm isn't quite right in cases where an HTML element is near
    # the end of the truncated string, which results in the final result being
    # too long by up to three characters (the length of '...').
    #
    def html_truncate_node(node, length)
      result    = ''
      truncated = false
      count     = 0

      if length <= 0
        # If the remaining *length* isn't sufficient to produce a properly
        # truncated string then truncation will happen now, since whatever the
        # *node* may contain can't be usefully appended to the result.
        truncated = true

      elsif node.is_a?(REXML::Text)
        # Extract the text from the node and truncate it if it is too large to
        # fit in the remaining *length*.
        encoded = node.to_s.tr(NL, SP)
        chars   = node.value.tr(NL, SP)
        c_count = chars.length
        if c_count == encoded.length
          # There are no HTML entities in the text.
          truncated = (c_count > length)
          result    = chars[0, length]
          c_count   = result.length
        else
          # Make sure that HTML entities are completely included or completely
          # truncated.
          c_count = 0
          remainder = encoded
          until remainder.length.zero?
            plain_text, html_entity, remainder = remainder.partition(/&[^;]+;/)
            unless plain_text.length.zero?
              c_count += plain_text.length
              if c_count > length
                c_count -= plain_text.length
                truncated = true
                break
              else
                result << plain_text
              end
            end
            unless html_entity.length.zero?
              entity_width = DOUBLE_WIDTH_ENTITY.include?(html_entity) ? 2 : 1
              c_count += entity_width
              if c_count > length
                c_count -= entity_width
                truncated = true
                break
              else
                result << html_entity
              end
            end
          end
        end
        count = c_count

      else
        # For a REXML::Element, accumulate the text from its children.  If a
        # child indicates that truncation occurred within it, then sibling
        # nodes after it are ignored.
        node.children.each do |child|
          next unless child
          s, truncated, s_count = html_truncate_node(child, length)
          result << s
          count  += s_count
          break if truncated
          length -= s_count
        end

        # Since the root node is a fake, only rebuild the surrounding element
        # tags if this is not the root node.  Escape newlines within attributes
        # to keep #html_multiline from translating them into breaks.
        unless node.parent.is_a?(REXML::Document)
          tag = node.expanded_name
          attrs =
            node.attributes.map { |k, v|
              v = v.gsub(/\n/, ESCAPED_NEWLINE)
              %Q(#{k}="#{v}")
            }.join(SPACE)
          attrs.prepend(SPACE) unless attrs.blank?
          result = "<#{tag}#{attrs}>#{result}</#{tag}>"
        end
      end

      return result, truncated, count
    end

    # =========================================================================
    # :section: Module methods
    # =========================================================================

    public

    class << self

      # Create plain text by removing HTML tags surrounding text and by
      # replacing HTML entities with plain-text equivalents.
      #
      # @param [String] value         String with embedded HTML elements and/or
      #                                 HTML entities (e.g. '&amp;').
      # @param [Hash]   opt
      #
      # @option opt [Symbol]  :mode   Either :ascii or :gsm.
      #
      # @option opt [Boolean] :ascii  Translate some extended characters into
      #                                 acceptable 7-bit ASCII equivalents; the
      #                                 result has encoding 'US-ASCII'.
      #
      # @option opt [Boolean] :gsm    Removes characters that cannot be
      #                                 expressed in the GSM alphabet. (Takes
      #                                 precedence over :ascii if both are
      #                                 present.)
      #
      # @option opt [String]  :encoding Apply this encoding before converting
      #                                   HTML entities.
      #
      # @return [String]              Plain text with HTML tags removed and
      #                                 HTML entities replaced with plain text
      #                                 equivalents (e.g. '&amp;' => '&').
      #
      def strip_html(value, opt = nil)
        opt ||= {}
        mode     = opt[:mode] || (:gsm if opt[:gsm]) || (:ascii if opt[:ascii])
        encoding = opt[:encoding]
        @sanitize_strict ||= Sanitize.new
        value = @sanitize_strict.fragment(value.to_s.dup)
        original_encoding = value.encoding
        encoding = nil if encoding == original_encoding
        case mode
          when :ascii
            # Ensure that Unicode characters are converted to composites (where
            # possible) so that accents can be stripped, leaving behind the
            # base alphabetic characters.
            value = Unicode.nfkd(value)

            # Strip out non-ASCII-compatible characters, except where they can
            # be replaced with ASCII-friendly equivalents.
            strip = encoding || 'US-ASCII'
            value.encode!(strip, fallback: lambda { |c| ASCII_EQUIV[c] || '' })
            value = CGI.unescape_html(value)

          when :gsm
            # Ensure that composite Unicode characters have been converted to
            # single characters (where possible) so that accented characters in
            # the GSM alphabet can be retained.
            value = Unicode.nfc(value)
            value.gsub!(NON_GSM_EXPR) { |c| ASCII_EQUIV[c] || Unicode.nfkd(c) }

            # Strip out non-GSM-compatible characters.  (This makes the
            # assumption that there is no overlap between the target encoding
            # and the non-alphanumeric characters that #nfkd may let through.)
            strip = encoding || 'ISO-8859-1'
            value.encode!(strip, replace: '')
            value = CGI.unescape_html(value)

          else
            value = html_decode(value)
            value.encode!(encoding, replace: '') if encoding

        end
        # Unless the encoding was requested via *opt*, undo the encoding that
        # was performed for the sake of stripping out unwanted characters.
        value.encode!(original_encoding) unless encoding
        value
      end

      # For a string with embedded HTML elements, remove unwanted HTML tags
      # while retaining the text they enclose.
      #
      # Additionally, HTML breaks are inserted before bullet characters so that
      # they appear as the start of a list item.
      #
      # @param [String] value         String with embedded HTML elements and/or
      #                                 HTML entities (e.g. '&amp;').
      # @param [Hash]   opt           If present, these options are merged with
      #                                 the default Sanitize config options.
      #
      # @option opt [Array<(Regexp, String)>] :translate
      #                               Translation pairs (see Usage Notes).
      #
      # @return [ActiveSupport::SafeBuffer]
      #                               String ready for display, possibly
      #                                 containing a limited set of HTML
      #                                 elements and/or HTML entities like
      #                                 '&amp;'.
      #
      # === Usage Notes
      # The :translate option specifies pre-processing translations, which
      # support the ability to turn foreign element tags into recognizable HTML
      # element tags.
      #
      # Each element of the array supplied through :translate should be a pair
      # (two-element array) where the first is a regular expression pattern and
      # the second is the replacement string for any parts of *value* which
      # match that pattern.  As a convenience, if both elements are strings,
      # the method will assume that the pair represents a tag name translation,
      # and will use the first element to create a Regexp which matches start
      # and end tags, and will use the second element as part of the pattern
      # match replacement.
      #
      # @example [/pat/, 'rep']
      #   Turns 'one_and_pat_and_two' into 'one_and_rep_and_two'
      #
      # @example [%r{<(/?)#{oldtag}(\s+[^>]*)?>}, "<\\1#{new_tag}\\2>"]
      #   Turns '<oldtag attr="xyz">' into '<newtag attr="xyz">'
      #   Turns '<oldtag>'  into '<newtag>'
      #   Turns '</oldtag>' into '</newtag>'
      #
      # @example ['oldtag', 'newtag']
      #   Turns '<oldtag attr="xyz">' into '<newtag attr="xyz">'
      #   Turns '<oldtag>'  into '<newtag>'
      #   Turns '</oldtag>' into '</newtag>'
      #
      # === Implementation Notes
      # Sanitize seems to incorrectly turn "<br/>" into "<br>" [invalid XHTML],
      # but #html_multiline corrects that in the process of normalizing HTML
      # breaks.
      #
      def sanitize_html(value, opt = nil)
        opt = opt ? opt.dup : {}

        # Perform translations first if requested.  The :translate option is
        # removed so any remaining values in *opt* can be passed directly to
        # `Sanitize.new`.
        if (translations = opt.delete(:translate))
          value = CGI.unescape_html(value)
          translations.each do |pattern_and_replacement|
            pattern, replace = pattern_and_replacement
            unless pattern.is_a?(Regexp)
              pattern = %r{<(/?)#{pattern}(\s+[^>]*)?>}
              replace = "<\\1#{replace}\\2>" unless replace.include?('\2')
            end
            value.gsub!(pattern, replace)
          end
        end

        # Select the default sanitizer or create a new one if sanitizer options
        # were specified.
        sanitizer =
          if opt.blank?
            @sanitize_relaxed ||= Sanitize.new(SANITIZE_DEF_OPTS)
          else
            Sanitize.new(SANITIZE_DEF_OPTS.rmerge(opt))
          end

        # Remove undesirable HTML tags and apply post-processing translations.
        # NOTE: This removes an extraneous newline seen with ICPSR content.
        value = sanitizer.fragment(value).gsub(%r{(</?li>)\n}, '\1')
        html_multiline(value)
      end

      # Replace newlines with HTML breaks, insert HTML breaks before bullets,
      # and eliminate extra HTML breaks.
      #
      # @param [String] value
      #
      # @return [ActiveSupport::SafeBuffer]
      #
      def html_multiline(value)
        result = value.is_a?(String) ? value.dup : value.to_s

        # === Normalize break variants
        # Turn "<br></br>" and non-XHMTL "<br>" into "<br/>".
        result.gsub!(%r{<br\s*/?>}, '@br@')
        result.gsub!(%r{@br@\s*</br>}, BREAK)
        result.gsub!(%r{@br@}, BREAK)

        # === Translate newlines into breaks
        # Seen in some repository metadata.  Restore newlines in attributes
        # that were escaped by #html_truncate_node.
        result.gsub!(/\n/, BREAK)
        result.gsub!(/#{ESCAPED_NEWLINE}/, "\n")

        # === Translate LaTex bullet list styles into HTML bullets
        # (Seen in abstracts from some article content providers, either as
        # "$\bullet$" or "<tex-math>$\\bullet$</tex-math>".)
        result.gsub!(%r{\s*<[^>]+>\s*\$\\\\bullet\$\s*</[^>]+>\s*}, '&bullet;')
        result.gsub!(/\s*\$\\\\bullet\$\s*/, '&bullet;')
        result.gsub!(/\s*\$\\bullet\$\s*/, '&bullet;')

        # === Start bullet list items on a new line
        # Separate the ensuing text with a space.
        result.gsub!(/\s*(►|▶|•|&bullet;)\s*/, (BREAK + '\1 '))

        # === Remove extraneous lines
        # Ensure that there are no blank lines at the start of the text.
        result.gsub!(%r{(\s*#{BREAK}\s*){2,}}, BREAK)
        result.sub!( %r{^\s*#{BREAK}\s*}, '')

        result.html_safe
      end

      # Replace HTML entities with an equivalent character.
      #
      # @param [String] value
      #
      # @return [String]
      #
      def html_decode(value)
        @html_decoder ||= HTMLEntities::Decoder.new('expanded')
        @html_decoder.decode(value)
      end

    end

  end

end
