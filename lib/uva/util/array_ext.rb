# lib/uva/util/array_ext.rb

require 'uva/util'

class Array

  include UVA::Util::TextConstants
  include UVA::Util::StringMethods

  # Encapsulates common handling for multiple field values by eliminating
  # elements that are blank, removing terminating punctuation and ensuring
  # that near-identical items are eliminated.
  #
  # @param [Regexp, String] remove    Characters to remove from each element.
  #                                     If *nil* then none will be removed (it
  #                                     is assumed that the elements already
  #                                     have surrounding whitespace removed.)
  #
  # @return [Array]                   The new array.
  #
  def clean_uniq(remove = FIELD_END)
    remove = Regexp.new(remove) if remove.is_a?(String)
    if remove
      map { |v| v.sub(remove, '') if v }.reject(&:blank?)
    else
      reject(&:blank?)
    end.uniq { |v| non_blank_chars(v) }
  end

end
