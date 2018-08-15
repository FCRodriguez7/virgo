# app/models/map.rb

require 'uva'

# A map is a description and URL of a map image that can be associated with a
# map guide.
#
# This class derives from the schema of the *maps* database table.
#
# @see CallNumberRange
# @see Library
# @see MapsUser
# @see CreateMaps
#
class Map < ActiveRecord::Base

  include UVA
  include UVA::Util::Dev

  Debug.setup(
    active:        Virgo.desktop_development?,
    find_best_map: false,
  )

  belongs_to :library

  has_many :call_number_ranges, dependent: :destroy, order: :call_number_range

  # ===========================================================================
  # :section: Validations
  # ===========================================================================

  validates :url,         presence: true
  validates :description, presence: true
  validates :library_id,  presence: true

  # ===========================================================================
  # :section: Class Methods
  # ===========================================================================

  public

  # Locate the physical map associated with the given item copy.
  #
  # @param [Firehose::Holding] holding
  # @param [Firehose::Copy]    copy
  #
  # @return [Map]
  # @return [nil]                     If there was no map for the item.
  #
  def self.find_best_map(holding, copy)
    Debug.show(__method__) { "HOLDING #{holding}, COPY #{copy}" }
    ranges = CallNumberRange.location_and_call_number_match(holding, copy)
    Debug.show(__method__) { "FOUND RANGES (#{ranges.size}) #{ranges}" }
    map = ranges && ranges.first && ranges.first.map
    return map if map
    # Fall back to whole library match.
    maps = Map.all(
      joins:
        'INNER JOIN libraries on maps.library_id = libraries.id ' \
        'LEFT JOIN call_number_ranges on call_number_ranges.map_id = maps.id',
      conditions: [
        'libraries.name = ? AND call_number_range IS NULL',
        holding.library.code
      ]
    )
    Debug.show(__method__) { "FALLBACK #{maps.inspect}" }
    maps && maps.first
  end

end
