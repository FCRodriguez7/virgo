# app/models/call_number_range.rb

require 'uva'

# A map plus a combination of a location and/or call number range.
#
# This class derives from the schema of the *call_number_ranges* database
# table.
#
# @see Map
# @see Location
# @see CreateCallNumberRanges
#
class CallNumberRange < ActiveRecord::Base

  include UVA
  include UVA::Util::Dev

  Debug.setup(
    active:                         Virgo.desktop_development?,
    location_and_call_number_match: false,
  )

  belongs_to :map

  has_many :locations

  # ===========================================================================
  # :section: Validations
  # ===========================================================================

  validates :map_id, presence: true

  # ===========================================================================
  # :section: Class Methods
  # ===========================================================================

  public

  # Takes in a call number and parses it into tokens grouped based on whether
  # they are alphabetical tokens (ignoring case, including spaces and periods)
  # or numeric tokens (integer or floating point number) converted to numbers.
  #
  # @param [String] call_number
  #
  # @return [Array<Array<String>,Array<Numeric>>]
  #                                   Alpha tokens as the first item, numeric
  #                                     values as the second item.
  #
  def self.call_number_parse(call_number)
    alpha_parts   = call_number.scan(/[a-z][. a-z]*/i)
    numeric_parts = call_number.scan(/[0-9]+\.?[0-9]*/)
    numeric_parts.map! do |n|
      i = n.to_i
      f = n.to_f
      (i == f) ? i : f
    end
    return alpha_parts, numeric_parts
  end

  # This method takes in a prefix (one half of the range), a call number, and
  # lower (if true then prefix is lower bound, if false then upper bound).
  #
  # It returns true if the call number is bounded by the range based on the
  # directionality implied by lower.
  #
  # @param [String] prefix            One half of the range.
  # @param [String] call_number
  # @param [Symbol] side              If :lower then *prefix* is a lower bound;
  #                                   if :upper then *prefix* is an upper bound
  #
  def self.bounded?(prefix, call_number, side = :lower)
    lower = (side == :lower)
    # Analyze the values into arrays of components to be compared.
    bound = call_number_parse(prefix)
    call_number_parts = call_number_parse(call_number)

    # Switch between comparing "alpha" parts and "numeric" parts, starting with
    # the "alpha" side.
    alpha   = 0
    numeric = 1
    side = alpha

    # Each side has its own cursor.
    a_idx = 0                         # alpha index
    n_idx = 0                         # numeric index
    a_max = bound[alpha].length - 1   # final bound alpha part
    n_max = bound[numeric].length - 1 # final bound numeric part

    # Compare the components of bound and call_number_parts, starting by
    # comparing the first "alpha" part of *bound* with the first "alpha" part
    # of *call_number_parts*, then switching sides to compare the first
    # "numeric" part of *bound* with the first "numeric" part of
    # *call_number_parts*, then switching back to the "alpha" side, and so on.
    while (side == alpha) ? (a_idx <= a_max) : (n_idx <= n_max)

      # Get the parts to compare at the index cursor for the current side.
      idx = (side == alpha) ? a_idx : n_idx
      bound_part = bound[side][idx]
      call_number_part = call_number_parts[side][idx] || SPACE

      # The comparison ends here if the parts are not equal.
      if lower
        return false if bound_part > call_number_part
        return true  if bound_part < call_number_part
      else
        return false if bound_part < call_number_part
        return true  if bound_part > call_number_part
      end

      # If the parts were equal, advance the index cursor for current side then
      # switch sides.
      if side == alpha
        a_idx += 1
        side = numeric
      else
        n_idx += 1
        side = alpha
      end

    end

    # Control reaches here if all parts of *bound* and *call_number_parts* were
    # the same.
    true
  end

  # Given a call number and a list of map guides, returns a list of map guides
  # where the given call number is bounded by the call number range in the
  # given map guide.
  #
  # @param [String]                 call_number
  # @param [Array<CallNumberRange>] ranges
  #
  # @return [Array<CallNumberRange>]
  #
  def self.call_number_match(call_number, ranges)
    return [] if call_number.blank?
    ranges.select { |range|
      call_number_range = range.call_number_range.split('-')
      case call_number_range.size
        when 1
          # We're going to need to return just this one if it works, because
          # it's a better match than a range match.
          return [range] if call_number =~ /^#{call_number_range.first}/i
        when 2
          # Include *range* if it bounds *call_number*.
          bounded?(call_number_range.first, call_number, :lower) &&
            bounded?(call_number_range.second, call_number, :upper)
      end
    }
  end

  # location_match
  #
  # @param [String]                 location_value
  # @param [Array<CallNumberRange>] raw_ranges
  #
  # @return [Array<CallNumberRange>]
  #
  def self.location_match(location_value, raw_ranges)
    raw_ranges.select { |raw_range| raw_range.location == location_value }
  end

  # location_and_call_number_match
  #
  # @param [Firehose::Holding] holding
  # @param [Firehose::Copy]    copy
  #
  # @return [Array<CallNumberRange>]
  #
  def self.location_and_call_number_match(holding, copy)
    Debug.show(__method__) {
      "HOLDING #{holding.inspect}, COPY #{copy.inspect}"
    }
    ranges =
      CallNumberRange.joins(:map => :library)
        .where('libraries.name = ?', holding.library.name)
    Debug.show(__method__) { "RANGES (#{ranges.size}) #{ranges.inspect}" }

    # Match on all call numbers.
    all_cn = call_number_match(holding.call_number, ranges)
    Debug.show(__method__) { "ALL_CN (#{all_cn.size}) #{all_cn.inspect}" }

    # Match on location and call number.
    loc_and_cn = location_match(copy.current_location.code, all_cn)
    Debug.show(__method__) {
      "LOC_AND_CN (#{loc_and_cn.size}) #{loc_and_cn.inspect}"
    }
    return loc_and_cn unless loc_and_cn.empty?

    # Match on locations with no call number ranges.
    loc_matches =
      location_match(copy.current_location.code, ranges).select do |val|
        val.call_number_range.blank?
      end
    Debug.show(__method__) {
      "LOC (#{loc_matches.size}) #{loc_matches.inspect}"
    }
    return loc_matches unless loc_matches.empty?

    # Finally, match on all call numbers with no location.
    all_cn.select { |val| val.location.blank? }
  end

end
