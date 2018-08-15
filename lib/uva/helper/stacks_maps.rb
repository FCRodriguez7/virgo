# lib/uva/helper/stacks_maps.rb

require 'uva'

module UVA::Helper

  # UVA::Helper::StacksMaps
  #
  module StacksMaps

    include UVA

    # =========================================================================
    # :section:
    # =========================================================================

    public

    # The link to a map for the item's physical location.
    #
    # @param [Firehose::Holding] holding
    # @param [Firehose::Copy]    copy
    # @param [Boolean]           na_map   Show "N/A" for missing map.
    #
    # @return [ActiveSupport::SafeBuffer]
    # @return [nil]                       If there was no map for the item and
    #                                       *na_map* was set to *false*.
    #
    def link_to_map(holding, copy, na_map = true)
      map = copy && copy.stacks_map(holding)
      if map
        out_link('Map', map.url, class: 'map-link', title: 'Map')
      elsif na_map
        content_tag(:span, 'N/A', class: 'map-indicator no-map')
      end
    end

  end

end
