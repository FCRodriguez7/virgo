# lib/uva/util/text_constants.rb

require 'uva/util'

module UVA::Util

  module TextConstants

    # A space.
    SP = SPACE = ' '.freeze

    # A newline.
    NL = NEWLINE = "\n".freeze

    # A single quotation mark.
    SQ = SQUOTE = %q(').freeze

    # A double quotation mark.
    DQ = DQUOTE = %q(").freeze

    # Copyright symbol (©).
    COPYRIGHT = '\u00A9'.freeze

    # Thin space.
    THIN_SP = '&thinsp;'.html_safe.freeze

    # Hair space (thinner than a thin space).
    HAIR_SP = '&#8202;'.html_safe.freeze

    # An en-dash for display.
    EN_DASH = (THIN_SP + '&ndash;' + THIN_SP).html_safe.freeze

    # An em-dash for display.
    EM_DASH = (THIN_SP + '&mdash;' + THIN_SP).html_safe.freeze

    # The default output separator for the parts of compound values.
    #
    LIST_SEPARATOR = ', '.freeze

    # The default output separator between multiple items.
    #
    ITEM_SEPARATOR = '; '.freeze

    # The default output separator between logical components when combined
    # into a single physical line (e.g. a track listing for citation export).
    #
    PART_DIVIDER = ' | '.freeze

    # The default output separator between logical lines when combined into
    # a single physical line (e.g. notes or abstracts for citation export).
    #
    INLINE_BREAK = ' / '.freeze

    # Regular expression for detecting extraneous spaces/punctuation at the
    # end of a phrase (a string formed from one or more subfields).
    PHRASE_END = /[.,;:\/\s]+$/.freeze

    # Regular expression for detecting extraneous spaces/punctuation at the
    # end of a string formed from one or more subfields.
    FIELD_END  = /[,;:\/\s]+$/.freeze

    # Regular expression for detecting line-ending punctuation and/or spaces
    # at the end of a string.
    TRAILING_PERIOD = /[.\s]+$/.freeze

    # Regular expression for detecting commas and/or spaces at the end of a
    # string.
    TRAILING_COMMA = /[,\s]+$/.freeze

    # Regular expression for detecting slashes and/or spaces at the end of a
    # string.
    TRAILING_SLASH = /[\/\s]+$/.freeze

    # Regular expression for detecting left square bracket(s) ('[') at the
    # start of a string.
    LEADING_SB = /^[\[\s]+/.freeze

    # Regular expression for detecting right square bracket(s) (']') at the
    # end of a string.
    TRAILING_SB = /[\]\s]+$/.freeze

    # Regular expression for editing a phrase surrounded by brackets.
    # E.g.: `sub(SURROUNDING_BRACKETS, '\1')`
    SURROUNDING_SQUARE_BRACKETS =
      /#{LEADING_SB.source}([^\[\]]*?)#{TRAILING_SB.source}/.freeze

    # Regular expression for detecting an opening paren/brace/bracket.
    LEADING_BRACKET = /^[{(\[\s]+/.freeze

    # Regular expression for detecting a closing paren/brace/bracket.
    TRAILING_BRACKET = /[})\]\s]+$/.freeze

    # Regular expression for editing a phrase surrounded by [], () or {}.
    # E.g.: `sub(SURROUNDING_BRACKETS, '\1')`
    SURROUNDING_BRACKETS =
      /#{LEADING_BRACKET.source}([^\[\]]*?)#{TRAILING_BRACKET.source}/.freeze

    # Regular expression for extracting the year from a date representation
    # that begins with a year value.
    # E.g.: `'1999-12-31'.sub(LEADING_YEAR_VALUE, '\1')`
    LEADING_YEAR = /^\s*(\d{1,4}).*?$/.freeze

    # Regular expression for extracting the year from a date representation
    # that ends with a year value.
    # E.g.: `'Dec. 31, 1999'.sub(LEADING_YEAR_VALUE, '\1')`
    TRAILING_YEAR = /^.*?(\d{1,4})\s*$/.freeze

    # A fragment of a regular expression for matching the separation between
    # the parts of a date.
    DATE_SEPARATOR = '[\s[[:punct:]]]+'.freeze

    # A fragment of a regular expression for matching the month part of a
    # date.
    MONTH_DIGITS = '1[0-2]|0[1-9]|[1-9]'.freeze

    # A fragment of a regular expression for matching the day part of a date.
    DAY_DIGITS = '3[01]|[12][0-9]|0[1-9]|[1-9]'.freeze

    # A fragment of a regular expression for matching the day part of a date.
    YEAR_DIGITS = '\d\d\d\d|\d\d'.freeze

  end

end
