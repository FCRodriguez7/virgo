# lib/uva/blacklight_override.rb

require 'blacklight'
require 'uva'

module UVA

  # Blacklight overrides
  #
  module BlacklightOverride

    include Blacklight::BlacklightHelperBehavior
    include Blacklight::SearchFields

    include UVA
    include UVA::Portal

    # =========================================================================
    # :section:
    # =========================================================================

    public

    # application_name
    #
    # @return [String]
    #
    def application_name
      Rails.application.config.application_name
    end

    # =========================================================================
    # :section: Templates
    # =========================================================================

    public

    # Overrides the Blacklight method to use the document type determined when
    # the document is initialized.
    #
    # @param [UVA::IndexDoc] doc
    #
    # @return [String]
    #
    # @see Blacklight::BlacklightHelperBehavior#document_partial_name
    #
    # @see self#render_document_partial
    # @see self#render_document_row
    #
    def document_partial_name(doc)
      (video_search_results? && !print_view?) ? 'lib_video' : doc.doc_type.to_s
    end

    # Overrides the Blacklight method to use partials specific to the current
    # portal, falling back to catalog partials.
    #
    # @param [UVA::IndexDoc] doc
    # @param [Symbol]        action
    # @param [Hash]          locals
    #
    # @return [ActiveSupport::SafeBuffer]
    #
    # @see Blacklight::BlacklightHelperBehavior#render_document_partial
    #
    def render_document_partial(doc, action, locals = nil)
      template_opt = { document: doc, counter: 0, offset: 0 }
      template_opt.merge!(locals) if locals.present?
      portals = [portal_controller, 'catalog'].uniq
      render_portal_template(portals, action, doc, template_opt)
    end

    # This is for the folder rows -- not an override, but here because it's so
    # similar to the other render_document-* methods
    #
    # @param [UVA::IndexDoc] doc
    # @param [Hash]          locals
    #
    # @return [ActiveSupport::SafeBuffer]
    #
    def render_document_row(doc, locals = nil)
      template_opt = { document: doc, counter: 0, offset: 0 }
      template_opt.merge!(locals) if locals.present?
      render_portal_template('catalog', 'row', doc, template_opt)
    end

    # =========================================================================
    # :section: Templates
    # =========================================================================

    protected

    # Attempt to render a template by trying each combination until a valid
    # template is found.
    #
    # @param [String, Array<String>]                portals
    # @param [String, Array<String>]                actions
    # @param [String, Array<String>, UVA::IndexDoc] formats
    #
    # @return [ActionSupport::SafeBuffer]
    #
    # @raise [ActionView::MissingTemplate]  If no template could be found.
    #
    def render_portal_template(portals, actions, formats, template_opt)

      portals = Array(portals).map(&:to_s).reject(&:blank?).uniq
      actions = Array(actions).map(&:to_s).reject(&:blank?).uniq
      formats = document_partial_name(formats) if formats.is_a?(UVA::IndexDoc)
      formats = [*formats, 'default'].uniq
      template_opt ||= {}

      portals.each do |portal|
        actions.each do |action|
          action_path = portal
          action_path += "/#{action}" if action.present?
          formats.each do |format|
            template_path = action_path
            template_path += "/#{format}" if format.present?
            begin
              return render(template_path, template_opt)
            rescue ActionView::MissingTemplate => e
              exception = e
            end
          end
        end
      end

      # Control reaches here only if no acceptable template was found.
      raise exception
    end

    # =========================================================================
    # :section: Configuration
    # =========================================================================

    public

    # Get the current Blacklight configuration, defaulting to the configuration
    # for CatalogController if the current context is not clear.
    #
    # @param [String, Symbol, Hash] controller
    #
    # @return [Blacklight::Configuration]
    #
    # @see Blacklight::Configurable#blacklight_config
    #
    def current_blacklight_config(controller = nil)
      if controller.blank? && self.respond_to?(:blacklight_config)
        controller = self
      elsif !controller.respond_to?(:blacklight_config)
        controller_mapping = {
          articles_portal => ArticlesController,
          catalog_portal  => CatalogController,
          classic_portal  => ClassicController,
          music_portal    => MusicController,
          video_portal    => VideoController,
        }
        p = nil
        p ||= controller if controller.is_a?(Hash)
        p ||= params     if !controller && defined?(params)
        p ||= {}
        c = p[:controller] || controller
        controller = controller_mapping[c.to_s] || CatalogController
      end
      controller.blacklight_config
    end

    # spell_check_max
    #
    # @param [String, Symbol, Hash] controller
    #
    # @return [Numeric]
    #
    def spell_check_max(controller = nil)
      current_blacklight_config(controller).spell_max
    end

    # =========================================================================
    # :section: Configuration - facet fields
    # =========================================================================

    public

    # Facet field settings of the current Blacklight configuration.
    #
    # @param [String, Symbol, Hash] controller
    #
    # @return [Hash{String=>Blacklight::Configuration::FacetField}]
    #
    # @see Blacklight::Configuration::SolrField
    # @see Blacklight::Configuration::Fields::ClassMethods#define_field_access
    # @see RSolr::Ext::Response::Facets#facet_fields
    #
    def facet_fields_config(controller = nil)
      current_blacklight_config(controller).facet_fields
    end

    # =========================================================================
    # :section: Configuration - sort fields
    # =========================================================================

    public

    # sort_fields
    #
    # @param [String, Symbol, Hash] controller
    #
    # @return [Array<Array<(String,Symbol)>>]
    #
    # @see Blacklight::BlacklightHelperBehavior#sort_fields
    # @see self#sort_fields_config
    #
    def sort_fields(controller = nil)
      sort_fields_config(controller).map do |_, field_def|
        [field_def.label, field_def.sort_key]
      end
    end

    # Sort field settings of the current Blacklight configuration.
    #
    # @param [String, Symbol, Hash] controller
    #
    # @return [Hash{String=>Blacklight::Configuration::SortField}]
    #
    def sort_fields_config(controller = nil)
      current_blacklight_config(controller).sort_fields
    end

    # The sort key for the first sort field setting of the current Blacklight
    # configuration.
    #
    # @param [String, Symbol, Hash] controller
    #
    # @return [String]
    #
    def default_sort_key(controller = nil)
      sort_fields_config(controller).first.last.sort_key
    end

    # The sort key associated with relevancy sort for the current Blacklight
    # configuration.
    #
    # @return [String]
    # @return [nil]                   If no configured sort field matches.
    #
    def relevancy_sort_key
      target = 'relevancy'
      sort_fields_config.find do |_, fld_def|
        return fld_def.sort_key if fld_def.label.to_s.downcase.include?(target)
      end
    end

    # The sort key associated with date-received sort for the current
    # Blacklight configuration.
    #
    # @return [String]
    # @return [nil]                   If no configured sort field matches.
    #
    def date_received_sort_key
      target = 'date'
      sort_fields_config.find do |_, fld_def|
        return fld_def.sort_key if fld_def.label.to_s.downcase.include?(target)
      end
    end

    # Lookup the Solr sort from the config for this sort_key.
    #
    # @param [String, Symbol] sort_key
    #
    # @return [String]
    # @return [nil]                   No entry for *sort_key*.
    #
    def solr_sort_value(sort_key)
      sort_key = sort_key.to_s
      sort_fields_config.find do |_, field_def|
        return field_def.sort if sort_key == field_def.sort_key
      end
    end

    # =========================================================================
    # :section: Configuration - search fields
    # =========================================================================

    public

    # search_fields
    #
    # @param [String, Symbol, Hash] controller
    #
    # @return [Hash{String=>Blacklight::Configuration::SearchField}]
    #
    # @see Blacklight::BlacklightHelperBehavior#search_fields
    # @see self#search_fields_config
    #
    def search_fields(controller = nil)
      search_fields_config(controller)
    end

    # Advanced search field settings of the current Blacklight configuration.
    #
    # @param [String, Symbol, Hash] controller
    #
    # @return [Hash{String=>Blacklight::Configuration::SearchField}]
    #
    def search_fields_config(controller = nil)
      current_blacklight_config(controller).search_fields
    end

    # search_field_list
    #
    # @param [String, Symbol, Hash] controller
    #
    # @return [Array<String>]
    #
    # @see Blacklight::SearchFields#search_field_list
    #
    def search_field_list(controller = nil)
      search_fields_config(controller).values
    end

    # search_field_options_for_select
    #
    # @param [String, Symbol, Hash] controller
    #
    # @return [Array<(String, String)>]
    #
    # @see Blacklight::SearchFields#search_field_options_for_select
    #
    def search_field_options_for_select(controller = nil)
      search_fields_config(controller).map { |_, field_def|
        next if false_value?(field_def.include_in_simple_select)
        [field_def.label, field_def.key]
      }.compact
    end

    # search_field_def_for_key
    #
    # @param [String, Symbol]       key
    # @param [String, Symbol, Hash] controller
    #
    # @return [Blacklight::Configuration::SearchField]
    #
    # @see Blacklight::SearchFields#search_field_def_for_key
    #
    def search_field_def_for_key(key, controller = nil)
      search_fields_config(controller)[key]
    end

    # default_search_field
    #
    # @param [String, Symbol, Hash] controller
    #
    # @return [String]
    #
    # @see Blacklight::SearchFields#default_search_field
    # @see Blacklight::Configuration#default_search_field
    #
    def default_search_field(controller = nil)
      current_blacklight_config(controller).default_search_field ||
        search_field_list(controller).first
    end

    # label_for_search_field
    #
    # @param [String, Symbol]       key
    # @param [String, Symbol, Hash] controller
    #
    # @return [String]
    #
    # @see Blacklight::SearchFields#label_for_search_field
    #
    def label_for_search_field(key, controller = nil)
      field_def = search_field_def_for_key(key)
      (field_def && field_def.label) || 'Keyword'
    end

  end

end
