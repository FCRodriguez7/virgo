# lib/uva/helper/text_messages.rb

require 'uva'

module UVA::Helper

  # UVA::Helper::TextMessages
  #
  # @see UVA::Helper::TextMessages#SMS_PROP
  #
  module TextMessages

    include UVA
    include UVA::Util::Json
    include UVA::Helper::Email

    # Character encoding to use for sending SMS text messages by e-mail.
    #
    # This is chosen to optimize the behavior of the SMS gateway, which will
    # select the character set to send to the SMS receiver.
    #
    # === Implementation Notes
    # For the GSM character set this probably should be 'ISO-8859-1' but that
    # has not been verified.
    #
    SMS_ENCODING = 'UTF-8'

    # Target character set for display on the SMS receiver.
    #
    # The actual selection cannot be controlled by the SMS sender, but this
    # value is used by the module to limit the characters that will be
    # generated to make it possible for the SMS gateway to choose the intended
    # character set for transmission.
    #
    # @see self#SMS_PROP
    #
    SMS_CHARACTER_SET = :gsm

    # Wireless carrier SMS email gateways.
    #
    # @see https://en.wikipedia.org/wiki/SMS_gateway#Email_clients
    #
    SMS_GATEWAY = {
      'Alltel'        => 'sms.alltelwireless.com',  # [1]
      'AT&T'          => 'txt.att.net',
      'Boost'         => 'sms.myboostmobile.com',
      'Cricket'       => 'mms.cricketwireless.net', # [2], [3]
      'Google Fi'     => 'msg.fi.google.com',       # [3]
      'Metro PCS'     => 'mymetropcs.com',          # [3]
      'Nextel'        => 'messaging.nextel.com',
      'Sprint'        => 'messaging.sprintpcs.com',
      'T-Mobile'      => 'tmomail.net',             # [3]
      'Ting'          => 'tmomail.net',             # [4]
      'U.S. Cellular' => 'email.uscc.net',
      'Verizon'       => 'vtext.com',
      'Virgin Mobile' => 'vmobl.com',
      #
      # NOTE:
      # [1] Previously 'message.alltel.com'
      # [2] Previously 'mms.mycricket.com'
      # [3] Valid for both SMS and MMS.
      # [4] Verified for the GSM network; not yet verified for the CDMA network
      #
    }.deep_freeze

    # The string to use in the rare event that an item has a blank title.
    #
    # @see self#sms_entry
    #
    SMS_EMPTY_TITLE = '(no title)'.freeze

    # The string to generate a new line in the text.
    #
    # @see self#sms_entry
    #
    SMS_NEWLINE = "\n".freeze

    # Google URL shortener.
    #
    # @see self#short_url
    #
    GOOGLE_SHORTENER = 'https://www.googleapis.com/urlshortener/v1/url'.freeze

    # For the Google URL shortener.
    #
    # @see self#short_url
    #
    GOOGLE_API_KEY = 'xxx'.freeze

    # =========================================================================
    # :section:
    # =========================================================================

    public

    # SMS character set properties.
    #
    # === Character sets
    # :gsm          An alphabet which includes alphanumeric characters,
    #               selected punctuation, and selected accented characters.
    #
    # :ucs2         A precursor to UTF-16, where each character has a fixed
    #               length of 16 bits.
    #
    # === Values
    # :max_length   The maximum number of characters in an SMS text message
    #               for the given character set.
    #
    # :udh_length   The number of character slots consumed by the
    #               "User Data Header" for multi-part SMS text messages.
    #
    # Note that both of these values are in terms of character counts and *not*
    # byte counts.
    #
    # === Multi-part messages
    # Only the first message can use the full :max_length number of characters;
    # the second message maximum size is reduced by 2 * :udh_length; third and
    # subsequent messages are reduced by 1 * :udh_length.
    #
    # That's what all of the references say -- but when I tried this out
    # sending to Verizon, the message was truncated after 143 characters...
    #
    # === References
    # @see https://en.wikipedia.org/wiki/SMS#Message_size
    # @see https://www.textmagic.com/docs/api/encoding/
    # @see https://www.twilio.com/engineering/2012/11/08/adventures-in-unicode-sms
    #
    SMS_PROP = {
      #gsm:  { max_length: 160, udh_length: 7 },
      gsm:  { max_length: 143, udh_length: 7 },
      ucs2: { max_length: 70,  udh_length: 3 }
    }.deep_freeze

    # Validation of the character set selection.
    UVA.assert SMS_PROP.keys.include?(SMS_CHARACTER_SET) do
      "Invalid SMS_CHARACTER_SET #{SMS_CHARACTER_SET.inspect} - " \
      "must be one of #{SMS_PROP.keys.inspect}."
    end

    # Validation of the encoding selection.
    UVA.assert Encoding.name_list.include?(SMS_ENCODING) do
      "Invalid SMS_ENCODING #{SMS_ENCODING.inspect} - " \
      "must be one of #{Encoding.name_list.inspect}."
    end

    # Maximum number of characters for an SMS text.
    #
    # @see self#SMS_CHARACTER_SET
    # @see self#SMS_PROP
    #
    SMS_MAX_LENGTH = SMS_PROP[SMS_CHARACTER_SET][:max_length]

    # Number of characters consumed by the "User Data Header" for multi-part
    # SMS text messages.
    #
    # @see self#SMS_CHARACTER_SET
    # @see self#SMS_PROP
    #
    SMS_UDH_LENGTH = SMS_PROP[SMS_CHARACTER_SET][:udh_length]

    # Number of digits for the phone number of the SMS recipient.
    SMS_PHONE_DIGITS = 10

    # =========================================================================
    # :section:
    # =========================================================================

    public

    # Return a validated phone number for SMS texts.
    #
    # @param [String] number          Either a phone number or a full e-mail
    #                                   address.
    #
    # @return [String]                The validated e-mail address.
    # @return [nil]                   If *addr* was invalid.
    #
    def valid_sms_recipient(number)
      return unless number.present?
      number, domain = number.split('@')
      number = number.gsub(/[^\d]/, '')
      if number.length == SMS_PHONE_DIGITS
        domain ? valid_email_address("#{number}@#{domain}") : number
      end
    end

    # =========================================================================
    # :section:
    # =========================================================================

    public

    # Generate one or more entries to be sent as SMS text message(s).
    #
    # @param [Array<UVA::IndexDoc>] docs
    # @param [Hash]                 opt   @see self#sms_entry
    #
    # @return [ActiveSupport::SafeBuffer]
    # @return [nil]                   If *docs* had no documents.
    #
    # @see self#SMS_PROP
    #
    # === Implementation Notes
    # This attempts to put the entries into as few SMS messages as possible.
    # To ensure than an entry is not split between messages (especially so that
    # the URL is not split), spaces are used where needed to pad to an integral
    # multiple of SMS_MAX_LENGTH characters so that an entry does not fit into
    # the current message will be pushed to the start of the next message.
    #
    # @see UVA::Util::HtmlMethods#GSM_BASIC_CHARS
    # @see UVA::Util::HtmlMethods#GSM_EXT_CHARS
    # @see https://en.wikipedia.org/wiki/GSM_03.38
    # @see https://en.wikipedia.org/wiki/UTF-16#UCS-2
    # @see https://blog.burstsms.com.au/sms-marketing/2016/4/11/sms-character-count-and-the-process-of-concatenation
    #
    def sms_entries(docs, opt = nil)

      # For each document, create a pair which is the SMS text entry and the
      # number of SMS text characters that the entry consumes.
      total_length = 0
      entry_pairs = docs &&
        docs.map { |doc|
          next unless doc.is_a?(UVA::IndexDoc)
          entry  = sms_entry(doc, opt)
          length = sms_length(entry)
          total_length += length
          [entry, length]
        }.compact
      return if total_length.zero?
      newline = SMS_NEWLINE
      newline_length = sms_length(newline)

      # Return early if there is only one entry and it fits within a single
      # SMS text message.
      if entry_pairs.size == 1
        entry, length = entry_pairs.first
        return entry << newline if length <= (SMS_MAX_LENGTH - newline_length)
        Rails.logger.warn { "#{__method__}: splitting single entry" }
      end

      # Accumulate two or more entries into as few messages as possible.
      message_count = 0
      buffer = ''
      messages =
        entry_pairs.map do |pair|
          entry, length = pair
          new_length = length
          new_length += sms_length(buffer) + newline_length if buffer.present?
          max_length =
            case message_count
              when 0 then SMS_MAX_LENGTH
              when 1 then SMS_MAX_LENGTH - (2 * SMS_UDH_LENGTH)
              else        SMS_MAX_LENGTH - SMS_UDH_LENGTH
            end
          if new_length < max_length
            # There is enough room for the entry in the buffer.  Because there
            # is room left over, nothing is emitted yet in this round.
            buffer << newline if buffer.present?
            buffer << entry
            next

          elsif new_length == max_length
            # There is just enough room for the entry in the buffer.  Because
            # the buffer is now full, it will be emitted in this round and
            # emptied for the next round.
            buffer << newline if buffer.present?
            buffer << entry
            message = buffer
            buffer = ''

          else
            # There is not enough room for the entry in the current message.
            # Pad out the remainder of the message with spaces so that the next
            # entry will begin at the start of the next message.
            padding = max_length - (buffer.length % max_length) - 1
            message = buffer << (SPACE * padding) << newline
            buffer = entry

          end
          message_count += 1
          message
        end

      # Add any unresolved entry as the final message.
      messages << buffer if buffer.present?

      # Apply encoding at this point.
      result = messages.compact.join
      result.encode!(SMS_ENCODING) unless SMS_ENCODING == 'UTF-8'
      result.html_safe
    end

    # Generate a single entry to be sent as an SMS text.
    #
    # To ensure that the entry fits in a single message, title, author, and
    # call number fields are truncated selectively.  (The URL at the end of the
    # entry is never truncated.)
    #
    # There have been reports of situations where the delivered SMS text
    # message has appeared with "(END)" appended in such a way that it appears
    # to the part of the short URL -- which, of course, renders it unclickable.
    # For that reason, a newline will be appended to the message (so the
    # potential max_length is reduced by one).
    #
    # @param [UVA::IndexDoc] doc
    # @param [Hash]          opt
    #
    # @option opt [String] :host
    # @option opt [String] :leader      Default: *nil*.
    # @option opt [String] :separator   Default: #SPACE.
    # @option opt [String] :empty_title Default: self#SMS_EMPTY_TITLE.
    # @option opt [Fixnum] :limit_step  Default: 5.
    # @option opt [Fixnum] :max_length  Default: self#SMS_MAX_LENGTH.
    #
    # @return [ActiveSupport::SafeBuffer]
    # @return [nil]
    #
    def sms_entry(doc, opt = nil)

      return unless doc.is_a?(UVA::IndexDoc)
      default_opt = {
        empty_title: SMS_EMPTY_TITLE,
        max_length:  SMS_MAX_LENGTH,
        newline:     SMS_NEWLINE,
        separator:   SPACE,
        limit_step:  1,
      }

      # Get options.  If a leading string was supplied, account for it by
      # deducting it from the number of available character slots.
      opt = opt ? default_opt.merge(opt) : default_opt
      host        = opt[:host]
      leader      = opt[:leader]
      newline     = opt[:newline]
      separator   = opt[:separator]
      max_length  = opt[:max_length]
      limit_step  = opt[:limit_step]
      empty_title = opt[:empty_title]
      gsm         = (SMS_CHARACTER_SET == :gsm)
      newline_length   = sms_length(newline)
      separator_length = sms_length(separator)

      # Prepare the result string, beginning with the leader if supplied.
      # Account for the leader and for the terminal newline that will be
      # supplied by #sms_entries.
      result = ''
      if leader.present?
        result << leader
        max_length -= leader.length
      end
      max_length -= newline_length

      # Get values parts of the message.  The URL is the one part that cannot
      # be truncated; if it exists, its length is deducted from the number of
      # available character slots.
      title   = doc.export_title.presence
      title   = nil if title && title.gsub(/[^a-z0-9]/i, '').blank?
      authors = doc.get_authors.first.presence
      authors = nil if authors && authors.gsub(/[^a-z0-9]/i, '').blank?
      callno  = doc.get_shelf_numbers.presence
      callno  = callno.first if callno.is_a?(Array)
      url     = short_url(doc, host) || ''

      # Accumulate and adjust the received fields.
      field = {}
      title ||= empty_title
      if title
        title = "#{title}." unless authors || title.end_with?('.')
        field[:title] = title
      end
      if authors
        authors = "by #{authors}"
        authors << '.' unless authors.end_with?('.')
        field[:authors] = authors
      end
      if callno
        callno = "#{callno}." unless callno.end_with?('.')
        field[:callno] = callno
      end
      max_length -= url.length if url.present?

      # Assemble the variable parts for easy iteration.
      #
      # Integer values are assumed to be in terms of the number of characters
      # within a GSM alphabet text message and will be scaled accordingly if
      # #SMS_CHARACTER_SET is not :gsm.
      #
      init_limit = { # Ratios of max_length unless there are missing fields.
        title:    (authors || callno) ? 0.75 : max_length,
        authors:  callno ? 0.50 : (max_length / 2),
        callno:   0.20
      }
      init_min = { # Fixed character lengths.
        title:    (authors || callno) ? 70 : max_length,
        authors:  callno ? 35 : (max_length / 2),
        callno:   25
      }
      [init_limit, init_min].each do |hash|
        hash.each_pair do |key, value|
          value = value * max_length if value.is_a?(Float)
          value /= 2 unless gsm
          hash[key] = value - separator_length
        end
      end
      total_length = 0
      part = {}
      field.each_pair do |key, value|
        text      = strip_html(value, gsm: gsm).squish
        length    = sms_length(text)
        limit     = init_limit[key]
        min_limit = init_min[key]
        limit     = min_limit unless limit > min_limit
        part[key] = [text, length, limit, min_limit]
        total_length += length + separator_length
      end

      # If the message contents will not fit into a single SMS message, whittle
      # away characters from each variable part until it does fit.
      limit_adjust = 0
      honor_min_limit = true
      while total_length > max_length
        beginning_total = total_length
        limits_frozen = 0
        part.reverse_each do |key, values|

          text, length, limit, min_limit = values

          # Reduce the limit with each round down to the minimum.
          limit -= limit_adjust
          if honor_min_limit && (limit <= min_limit)
            limit = min_limit
            limits_frozen += 1
          end

          # Truncate the text and adjust the total length accordingly.
          if length > limit
            total_length -= length
            text   = text.truncate(limit)
            length = sms_length(text)
            total_length += length
          end

          # Update the part values and break if the updated length is now
          # acceptable.
          part[key].replace([text, length, limit, min_limit])
          break if total_length <= max_length

        end
        # After the initial round, begin adjusting the limits for each field.
        # At the point where all fields are down to their desired minimums and
        # the message is still too long, stop honoring minimums.  Finally, for
        # later rounds, if nothing changed during round then nothing will ever
        # change, so just give up.
        if limit_adjust.zero?
          limit_adjust += limit_step
        elsif honor_min_limit
          honor_min_limit = false if limits_frozen == part.size
        elsif total_length == beginning_total
          Rails.logger.warn {
            "#{__method__}: total_length stuck at #{total_length}"
          }
          break
        end
      end

      # Append the URL part then return with the concatenated parts.
      part[:url] = [url] if url.present?
      result << part.values.map(&:first).join(separator)
      result.html_safe

    end

    # Use Google link shortener.
    #
    # @param [UVA::IndexDoc, String] doc
    # @param [String]                host
    #
    # @return [String]
    # @return [nil]
    #
    def short_url(doc, host)
      long_url = full_url(doc, host)
      return if long_url.blank?
      api_url  = "xxx"
      api_data = { 'longUrl' => long_url }.to_json
      response =
        Curl::Easy.http_post(api_url, api_data) do |curl|
          curl.headers['Accept']       = 'application/json'
          curl.headers['Content-Type'] = 'application/json'
          curl.headers['Api-Version']  = '2.2'
        end
      result = json_parse(response.body_str)
      result['id'] if result.is_a?(Hash)
    end

    # The URL associated with a document.
    #
    # @param [UVA::IndexDoc, String] doc
    # @param [String]                host
    #
    # @return [String]
    # @return [nil]
    #
    def full_url(doc, host = nil)
      result =
        case doc
          when SolrDocument
            canonical_url(doc, host)
          when UVA::ArticleDoc
            doc.links && doc.links.first && doc.links.first.url
          else
            doc
        end
      result if result.present?
    end

    # =========================================================================
    # :section:
    # =========================================================================

    protected

    GSM_EXT = UVA::Util::HtmlMethods::GSM_EXT_CHARS.chars.to_a.deep_freeze

    # Returns the number of characters that the string would consume with the
    # configured self#SMS_CHARACTER_SET.
    #
    # @param [String] s
    #
    # @return [Fixnum]
    #
    def sms_length(s)
      characters = s.length
      characters += s.count(*GSM_EXT) if SMS_CHARACTER_SET == :gsm
      characters
    end

  end

end
