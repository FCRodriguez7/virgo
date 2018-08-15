# app/controllers/concerns/blacklight_config_concern.rb

require 'active_support/concern'
require 'uva'

# Support methods for use within the block passed to `configure_blacklight`.
#
# @see Blacklight::Configurable::ClassMethods#configure_blacklight
# @see Blacklight::Configuration::Fields#add_solr_field
#
module BlacklightConfigConcern

  extend ActiveSupport::Concern

  # ===========================================================================
  # :section:
  # ===========================================================================

  public

  NO_FACET_LIMIT = -1

  # ===========================================================================
  # :section:
  # ===========================================================================

  public

  # configure_facets
  #
  # @param [Blacklight::Configuration] config
  # @param [Hash{String=>Array}]       facets
  # @param [Hash]                      opt
  #
  # @return [Array]                   The subset of facets marked for inclusion
  #                                     on the advanced search form.
  #
  # @see Blacklight::Configuration::Fields#add_solr_field
  #
  def configure_facets(config, facets, opt = nil)
    facets.map { |field, properties|
      label, advanced, optional, properties =
        extract(field, properties, :advanced, :optional)
      config.add_facet_field(field.to_s) do |f|
        f.label    = label
        f.optional = optional unless optional.nil?
      end
      [field, properties] if advanced
    }.compact.tap do |adv_search_facets|
      configure_advanced_search(config, adv_search_facets, opt)
    end
  end

  # Configure facet selections for the advanced search form.
  #
  # @param [Blacklight::Configuration] config
  # @param [Array<String>]             adv_search_facets
  # @param [Hash]                      opt
  #
  def configure_advanced_search(config, adv_search_facets, opt = nil)

    opt ||= {}
    fields = []
    field_properties = {}

    # From each pair of entries, extract the facet field that is to be shown
    # in the advanced facet form sidebar and the hash of properties that will
    # be translated into Solr parameters specific to the acquisition of the
    # values for that field.
    adv_search_facets.each do |entry|
      field, properties = entry
      fields << field.to_s
      next unless properties.present?
      %w(limit sort missing).each do |field_property|
        next unless (value = properties[field_property.to_sym])
        field_properties[:"f.#{field}.facet.#{field_property}"] = value
      end
    end

    config.advanced_search = {
      url_key: 'advanced',
      form_solr_parameters: {
        :'facet.field' => fields,
        :'facet.limit' => NO_FACET_LIMIT, # return all facet values
        :'facet.sort'  => 'index',        # sort by byte order of values
      }.merge(field_properties)
    }.merge(opt)

  end

  # Configure search fields for the advanced search form.
  #
  # @param [Blacklight::Configuration] config
  # @param [Hash{String=>Array}]       fields
  #
  def configure_search_fields(config, fields)
    fields.each_pair do |field, properties|

      label, advanced, range, facet =
        extract(field, properties, :advanced, :range, :facet)

      config.add_search_field(field.to_s) do |f|
        f.label = label
        f.range = range unless range.nil?
        f.include_in_advanced_search = advanced unless advanced.nil?
        if !facet.nil? # Articles
          f.facet = facet
        elsif range # Solr
          f.solr_field = 'year_multisort_i'
        else # Solr
          field = 'journal_title' if field == 'journal'
          f.solr_local_parameters = { qf: "$qf_#{field}", pf: "$pf_#{field}" }
        end
      end

    end
  end

  # configure_sort_fields
  #
  # @param [Blacklight::Configuration] config
  # @param [Hash{String=>Array}]       fields
  #
  def configure_sort_fields(config, fields)
    fields.each_pair do |sort_key, properties|
      label, sort = extract(sort_key, properties, :sort)
      config.add_sort_field(sort.to_s) do |f|
        f.label    = label
        f.sort_key = sort_key.to_s
      end
    end
  end

  # ===========================================================================
  # :section:
  # ===========================================================================

  private

  def extract(field, properties, *option_keys)
    case properties
      when Array
        label      = properties[0]  # First element is the label string.
        properties = properties[1]  # Final element may be an option hash.
        properties = properties ? properties.dup : {}
        properties[:label] ||= label
      when Hash
        properties = properties.dup
      else
        properties = { label: properties.to_s.presence }
    end
    properties[:label] ||= field.to_s.sub(/_facet$/, '').titleize
    option_keys.unshift(:label) unless option_keys.first == :label
    extracted = properties.extract!(*option_keys)
    return *extracted.values, properties
  end

end
