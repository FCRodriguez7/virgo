# app/controllers/concerns/access_repository_concern.rb

require 'active_support/concern'
require 'uva'

# Support for controller actions involving repository items.
#
# @see UVA::Helper::Fedora
#
module AccessRepositoryConcern

  extend ActiveSupport::Concern

  include AccessAnyConcern

  include UVA::Helper::Fedora

  # ===========================================================================
  # :section:
  # ===========================================================================

  public

  # Returns the id values for the previous and next siblings, returning a nil
  # value when, due to position in the list of siblings, a previous or next
  # doesn't exist.
  #
  # @param [SolrDocument] doc
  #
  # @return [void]
  #
  def setup_next_and_prev_components(doc)
    ancestors = doc && doc.ancestors
    return if ancestors.blank?

    this_id    = doc.doc_id
    parent_id  = ancestors.last.ancestor_id
    parent     = get_solr_response_for_doc_id(parent_id).last
    component  = parent && parent.ead_component(:self)
    components = component && component.components
    components = Array(components).reject(&:blank?)
    index      = components.index { |c| c.component_id == this_id }
    return unless index

    min_index = 0
    max_index = components.length - 1
    @prev_component = components[index - 1].component_id if index > min_index
    @next_component = components[index + 1].component_id if index < max_index
  end

  # Generate a recursive hierarchy of nodes.
  #
  # @param [SolrDocument] doc
  #
  # @return [Array<(Array<Hash>,Hash)>]  Return [children, parent].
  #
  def get_hierarchy_children(doc)
    item = doc.ead_component
    id   = doc.doc_id

    focus_id    = params[:expand_to_include]
    doc         = focus_id && get_solr_response_for_doc_id(focus_id).last
    breadcrumbs = doc && doc.breadcrumbs
    selected    = focus_id || id

    recursive_hierarchy(item, id, breadcrumbs, selected)
  end

end
