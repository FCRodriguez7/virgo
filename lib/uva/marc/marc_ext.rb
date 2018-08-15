# lib/uva/marc/marc_ext.rb
#
# Extensions to MARC gem classes to accommodate "deep_freeze".

require 'marc'

# Ensure that MARC::XMLReader uses Nokogiri or other XML parser instead of the
# default (REXML).
MARC::XMLReader.best_available!

# Overrides to support "deep_freeze".
#
# @see ::MARC::DataField
#
class MARC::DataField

  # Freeze a DataField so that the contents of its elements cannot be modified.
  #
  # @return [self]
  #
  def deep_freeze
    @subfields.deep_freeze
    freeze
  end

  # A string representation of the item (primarily for development).
  #
  # @return [String]
  #
  # Compare with:
  # @see ::MARC::DataField#to_s
  #
  def to_s
    "#{tag} #{indicator1}#{indicator2} " + @subfields.join('')
  end

end

# Overrides to support "deep_freeze".
#
# @see ::MARC::FieldMap
#
class MARC::FieldMap

  # Freeze a DataField so that the contents of its elements cannot be modified.
  #
  # @return [self]
  #
  def deep_freeze
    reindex unless @clean
    @tags.deep_freeze
    freeze
  end

end

# Overrides to support "deep_freeze".
#
# @see ::MARC::Record
#
class MARC::Record

  # Freeze a DataField so that the contents of its elements cannot be modified.
  #
  # @return [self]
  #
  def deep_freeze
    @fields.deep_freeze
    freeze
  end

  # A string representation of the item (primarily for development).
  #
  # @return [String]
  #
  # Compare with:
  # @see ::MARC::Record#to_s
  #
  def to_s
    "LEADER #{@leader}\n" + @fields.join("\n")
  end

  # Access to the fields contained in the record.
  #
  # @param [String, Array, Range] filter  Tag(s) specifying the MARC field(s)
  #                                         to return.
  #
  # @return [Array<MARC::ControlField, MARC::DataField>]
  # * If *filter* is *nil*, this is the entire FieldMap array.
  # * Otherwise, this is an array of the fields whose tags match *filter* in
  #   the order that they appear in the record.
  #
  # Compare with:
  # @see ::MARC::Record#fields
  #
  def fields(filter = nil)
    if filter.blank?
      @fields.clean = false unless frozen?
      @fields
    else
      @fields.reindex unless @fields.clean || frozen?
      indices =
        case filter
          when Array, Range
            @fields.tags.values_at(*filter).flatten.compact.sort
          when String
            @fields.tags[filter]
        end
      @fields.values_at(*indices)
    end
  end

end
