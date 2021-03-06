# lib/ext/array.rb

require_relative 'object'

class Array

  # Recursively freeze an Array and all of its elements so that the contents of
  # the elements cannot be modified.
  #
  # @return [self]
  #
  # @see Hash#deep_freeze
  #
  # === Usage Notes
  # This should not be used in any situation where the elements are live
  # objects subject to active updating (which would be unusable if frozen).
  #
  def deep_freeze
    each(&:deep_freeze)
    freeze
  end

  # Recursive duplication.
  #
  # @return [Array]
  #
  # @see Hash#rdup
  #
  # === Usage Notes
  # A deeply-nested array may reference objects that cannot or should not be
  # duplicated. To avoid that situation, a class may redefine #duplicable? to
  # return *false* (so that Object#rdup returns *self*), or a class may define
  # #rdup with customized behaviors.
  #
  def rdup
    map(&:rdup)
  end

  # Recursive merge.
  #
  # @param [Array] other
  #
  # @return [Array]
  #
  def rmerge(other)
    rdup.rmerge!(other)
  end

  # Recursive merge into self.
  #
  # If *other* is an Array, then duplicates of its elements are appended to
  # *self* unless they are already present.  If *other* is any other non-nil
  # value then a duplicate of *other* is appended to *self* unless it is
  # already present.
  #
  # @param [Array, Object] other
  #
  # @return [self]
  #
  # === Usage Notes
  # It is assumed that *other* is a flat array (that is, that its elements are
  # not arrays); if it is not flat, any sub-arrays will be duplicated and
  # appended to *self* unconditionally.
  #
  def rmerge!(other)
    if other.is_a?(Array)
      other.each { |v| self << v.rdup unless include?(v) }
    elsif other
      self << other.rdup unless include?(other)
    end
    self
  end

  # Converts an array to a hash.  The array must be comprised of elements which
  # are [key, value] pairs.
  #
  # @return [Hash]
  #
  # === Implementation Notes
  # This was introduced to allow code to be written in the style of later
  # versions of Rails where this method is supplied by ActiveSupport.
  #
  def to_h
    Hash[self]
  end

end
