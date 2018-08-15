# lib/ext/string.rb

class String

  # Returns a TrueClass if the string matches and a FalseClass if it doesn't.
  #
  # @param [Regexp] regex
  #
  # @return [Boolean]
  #
  # === Implementation Notes
  # Introduced in Ruby 2.4.
  #
  def match?(regex)
    !!match(regex)
  end

end
