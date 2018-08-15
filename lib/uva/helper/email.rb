# lib/uva/helper/email.rb

require 'uva'

module UVA::Helper

  # UVA::Helper::Email
  #
  module Email

    include UVA

    # =========================================================================
    # :section:
    # =========================================================================

    public

    EMAIL_ALPHANUM_CHARS = 'A-Za-z0-9'.freeze
    EMAIL_SPECIAL_CHARS  = %q(!#$%&'*+-/=?^_`{|}~).freeze
    EMAIL_COMMENT_CHARS  = %q{\([^)]*\)}.freeze

    EMAIL_HOST_CHARS = EMAIL_ALPHANUM_CHARS
    EMAIL_NAME_CHARS = (EMAIL_ALPHANUM_CHARS + EMAIL_SPECIAL_CHARS).freeze

    EMAIL_HOST_VALID =
      /^([#{EMAIL_HOST_CHARS}][#{EMAIL_HOST_CHARS}-]*\.)+[A-Za-z]{2,4}$/

    EMAIL_NAME_INVALID = /[^#{EMAIL_NAME_CHARS}]/

    EMAIL_DOMAIN_MAX_SIZE  = 255
    EMAIL_NAME_MAX_SIZE    = 64
    EMAIL_ADDRESS_MAX_SIZE = 254

    # =========================================================================
    # :section:
    # =========================================================================

    public

    # Return a validated e-mail address.
    #
    # @param [String] addr
    # @param [Hash]   opt
    #
    # @option opt [Boolean] :uva_only Limit to UVA e-mail addresses.
    #
    # @return [String]                The validated e-mail address.
    # @return [nil]                   If *addr* was invalid.
    #
    def valid_email_address(addr, opt = nil)

      opt ||= {}
      uva_only = opt[:uva_only]

      # The address must have a local-part and a domain part.  (An address with
      # quoted parts may have more than one '@' however.)
      parts = addr.to_s.split('@')
      return if parts.size < 2

      # Check the domain part (i.e. host name).
      domain = parts.pop.strip
      return unless domain =~ EMAIL_HOST_VALID
      return if uva_only && !domain.end_with?('virginia.edu')

      # Check the local-part (i.e., the recipient name).  The RFC allows for a
      # leading and/or trailing comment surrounded by parentheses; these will
      # be stripped out if present.  If the name is too long then it's invalid.
      recipient = parts.join('@').strip
      recipient.sub!(/^#{EMAIL_COMMENT_CHARS}/, '')
      recipient.sub!(/#{EMAIL_COMMENT_CHARS}$/, '')
      return if recipient.length > EMAIL_NAME_MAX_SIZE

      if recipient.start_with?(%q("))
        # Edge case: Fully-quoted name.
        return unless recipient.end_with?(%q("))
        quoted_part = recipient[1..-2]
        return if quoted_part.blank? || invalid_quoted?(quoted_part)

      elsif recipient.include?(%q("))
        # Edge case: One or more quoted segments separated by dots.
        parts = recipient.split('.')
        return if parts.size < 3
        in_quote = false
        parts.each do |part|
          starts = part.start_with?(%q("))
          ends   = part.end_with?(%q("))
          if starts && ends
            return if in_quote || invalid_quoted?(part[1..-2])
          elsif starts
            return if in_quote || invalid_quoted?(part[1..-1])
            in_quote = true
          elsif ends
            return unless in_quote && !invalid_quoted?(part[0..-2])
            in_quote = false
          elsif in_quote
            return if invalid_quoted?(part)
          else
            return if invalid_unquoted?(part)
          end
        end

      else
        # The local part is a simple name (the normal situation).
        return if recipient.blank? || invalid_unquoted?(recipient)

      end

      # Return with the validated e-mail address.
      addr = "#{recipient}@#{domain}"
      addr unless addr.length > EMAIL_ADDRESS_MAX_SIZE
    end

    # =========================================================================
    # :section:
    # =========================================================================

    private

    # All characters are valid through the closing quote except that double
    # quotes must be escaped with a backslash.
    #
    # @param [String] part
    #
    def invalid_quoted?(part)
      part.present? && ((part =~ /[^\\]"/) || (part =~ /\\[^"\\]/))
    end

    # Names may have certain special characters, including dots, but not two
    # dots together.
    #
    # @param [String] part
    #
    def invalid_unquoted?(part)
      part.present? && (part.include?('..') || (part =~ EMAIL_NAME_INVALID))
    end

  end

end
