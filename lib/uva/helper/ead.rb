# lib/uva/helper/ead.rb

require 'uva'

module UVA::Helper

  # UVA::Helper::Ead
  #
  # @see UVA::Ead
  #
  module Ead

    include UVA

    # Link to an EAD component - series, subseries, or item.
    #
    # @param [Component] component
    # @param [String]    link_label
    #
    # @return [ActiveSupport::SafeBuffer]
    #
    def ead_component_link(component, link_label = nil)
      link_label ||= component.head_unit_title
      path = catalog_path(component.component_id)
      link_to(link_label, path)
    end

    # Render the description of the given EAD component.
    #
    # @param [Component]    component
    # @param [String]       start_tag
    # @param [String]       end_tag
    # @param [Boolean]      full_description
    # @param [SolrDocument] doc
    #
    # @return [ActiveSupport::SafeBuffer]
    #
    def ead_description(
      component,
      start_tag,
      end_tag,
      full_description = false,
      doc = nil
    )
      return ''.html_safe if component.p_count.zero?
      paragraphs =
        if full_description && doc
          doc.scope_content_display
        else
          component.scope_content.p.take(1)
        end
      content_tag(:div, class: 'ead-description') do
        paragraphs.map { |p| "#{start_tag}#{p}#{end_tag}" }.join.html_safe
      end
    end

    # Produce EAD breadcrumbs as a sequence of links.
    #
    # @param [SolrDocument] doc
    # @param [Boolean]      include_self
    # @param [String]       separator
    # @param [String]       before
    # @param [String]       after
    #
    # @return [ActiveSupport::SafeBuffer]
    #
    def breadcrumb_links(
      doc,
      include_self = true,
      separator    = SPACE,
      before       = nil,
      after        = nil
    )
      ancestors = doc && doc.ancestors
      return if ancestors.blank?
      links =
        ancestors.map do |ancestor|
          link_to(ancestor.title, catalog_path(ancestor.ancestor_id))
        end
      if include_self
        title = doc.show_heading_title
        links << content_tag(:strong, title, class: 'breadcrumbs-self')
      end
      "#{before}#{links.join(separator)}#{after}".html_safe
    end

    # Format EAD breadcrumbs.
    #
    # @param [UVA::IndexDoc] doc
    # @param [Symbol]        context
    #
    # @return [ActiveSupport::SafeBuffer]
    #
    def render_breadcrumbs(doc, context = :index)
      separator = ' <em class="step">&rsaquo;</em>'
      if context == :index
        before =  '<p class="breadcrumbs">'
        before << '<span class="breadcrumbs-label">Found in:</span> '
      else # if context == :show
        before =  '<p class="ead-breadcrumbs">'
        before << '<em>Found in</em> '
      end
      after = ' </p>'
      breadcrumb_links(doc, false, separator, before, after)
    end

    # Generate a recursive hierarchy of nodes.
    #
    # @param [Container]   node
    # @param [String]      id           ID of *node*.
    # @param [Breadcrumbs] breadcrumbs
    # @param [String]      selected     ID of selected node
    #
    # @return [Array<(Array<Hash>,Hash)>]  Return [children, parent].
    #
    #--
    # rubocop:disable Metrics/MethodLength # [58/35]
    #++
    def recursive_hierarchy(node, id, breadcrumbs, selected)
      # rubocop:disable Metrics/BlockNesting
      children =
        if id.blank?
          []
        else
          node.components.map do |c|
            cid = c.component_id
            is_selected = (cid == selected)
            type =
              if c.component_count.nonzero?
                'folder'
              elsif c.component_type == 'item'
                'item'
              else
                'archive'
              end
            child = {
              'data' => {
                'title' => c.short_unit_title,
                'attr'  => { 'href' => catalog_path(cid) }
              },
              'attr' => { 'id' => cid },
              'icon' => (is_selected ? "selected #{type}" : type),
            }
            if c.component_count.nonzero?
              is_open =
                is_selected || (breadcrumbs && breadcrumbs.has_ancestor?(cid))
              if is_open
                doc     = get_solr_response_for_doc_id(cid).last
                c_item  = doc.ead_component(:self)
                grandchildren, _root =
                  c_item &&
                    recursive_hierarchy(c_item, cid, breadcrumbs, selected)
                child['children'] = grandchildren if grandchildren
                child['state'] = 'open'
              else
                child['state'] = 'closed'
              end
            end
            child
          end
        end
      # rubocop:enable Metrics/BlockNesting
      type = 'collection'
      is_selected   = (id == selected)
      is_collection = node.is_a?(UVA::Ead::Xml::Collection)
      title = is_collection ? node.short_title : node.short_unit_title
      parent = {
        'data'     => {
          'title' => title,
          'attr'  => { 'href' => catalog_path(id) }
        },
        'attr'     => { 'id' => id },
        'icon'     => (is_selected ? "selected #{type}" : type),
        'state'    => 'open',
        'children' => children
      }
      return children, parent
      # rubocop:enable Metrics/MethodLength
    end

  end

end
