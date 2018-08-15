# config/initializers/uri_common.rb

require 'uri/common'

module URI

  # Override `URI#decode_www_form_component` to process Unicode values encoded
  # with the non-standard form of "%u" followed by a hex-digit string by
  # replacing those sequences with the indicated UTF-8 codepoint.
  #
  # @param [String]   str
  # @param [Encoding] enc             Default: `Encoding::UTF_8`.
  #
  # @return [String]
  #
  # @raise [ArgumentError]            If *str* has invalid %-encoding.
  #
  # === Implementation Notes
  # Virgo cookies themselves do not contain the non-standard "%u" encodings --
  # nor do they need them -- but, because all cookies from the "virginia.edu"
  # domain are lumped together, foreign-generated values (apparently propagated
  # via InCommon) can end up causing certain requests to fail without this
  # translation.
  #
  def self.decode_www_form_component(str, enc = Encoding::UTF_8)
    str = str.to_s.gsub(/%u(\h{4})/) { $1.hex.chr(enc) }
    valid_encoding = (str =~ /\A[^%]*(?:%\h\h[^%]*)*\z/)
    raise ArgumentError, "invalid %-encoding (#{str})" unless valid_encoding
    str.gsub(/\+|%\h\h/, TBLDECWWWCOMP_).force_encoding(enc)
  end

end
