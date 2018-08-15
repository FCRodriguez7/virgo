# lib/uva/helper/shelf_browse.rb

require 'action_view/helpers'
require 'uva'

module UVA::Helper

  # Methods to support virtual shelf browse.
  #
  # === Library of Congress call numbers
  #
  # Comprised of
  #   - An optional location (e.g. "Ref." for "reference room")
  #   - The "class", one or two capital letters which indicate the subject.
  #   - The "subclass", a whole or floating-point number.
  #   - The "cutter", which has the form /\.([A-Z][0-9]+)+/.
  #   - An optional annotation which may include a combination of:
  #       Year (e.g. "1999")
  #       Volume number (e.g. "v.1")
  #       Copy number (e.g. "c.2")
  #       Other (e.g. "plates")
  #
  # === References
  # @see https://www.amnh.org/our-research/research-library/library-catalog/library-of-congress-call-numbers/
  #
  module ShelfBrowse

    include ActionView::Helpers::TagHelper

    include UVA
    include UVA::ShelfBrowse
    include UVA::Helper::Accessibility
    include UVA::Helper::KlugeRuhe

    extend self

    # =========================================================================
    # :section:
    # =========================================================================

    public

    # Characteristic parameters.
    PARAMS = [
      :page, :width, :origin, :start, :offset,
      :popup, :redirect
    ].freeze

    # Display orientations.
    ORIENTATIONS = [:horizontal, :vertical].freeze

    # Currently the only implemented orientation is horizontal.
    DEFAULT_ORIENTATION = :horizontal

    # Root of the LCC tree
    ROOT_ID = 'ROOT'.freeze

    # HTML attribute containing a shelfkey value
    SHELFKEY_ATTR = 'data-shelfkey'.to_sym

    # === Button labels
    # These are used on the server and in the client (feature/shelf-browse.js).
    LABEL = {

      # ==== Links
      link: 'Browse the virtual shelf for related items near this title.',

      # ==== Display - top row
      lcc_open:  'Browse by topic',
      lcc_close: 'Close topics',

      # ==== Display - LCC tree browser
      lcc_root:  'Library of Congress Classifications',

    }.deep_freeze

    # === Tooltip text
    # These are used on the server and in the client (feature/shelf-browse.js).
    TOOLTIP = {

      # ==== Display - top row
      help:     'Click for help and tips.',
      origin:   'This is the call number of the initially selected item.',
      return:   'Center the virtual shelf on the initial item.',
      close:    'Close the virtual shelf.',

      # ==== Display - item tile
      item:     'Click to make this item the focus' \
                  "\nor navigate with Home, End, or arrow keys.",
      cover:    nil,
      status:   nil,
      no_item:  'This is not a missing catalog item -- see details below.',

      # ==== Display - item details panel
      splitter: 'Drag to resize; double-click to reset.',

      # ==== Display - overlays
      close_dropdown: 'Click to close this overlay.',

      # ==== Display - LCC tree browser
      lcc:
        'Browse the Library of Congress Classifications to find the section ' \
        'of the virtual shelf with titles related by topic.',
      lcc_root:
        'Find similar items based on their Library of Congress call numbers.',
      lcc_root_icon:
        'Click to close all tree branches.',
      range:
        'Browse the virtual shelf for items in this call number range.',

    }.deep_freeze

    # === Message text
    # These are used on the server and in the client (feature/shelf-browse.js).
    MESSAGE = {
      lcc_loading:
        'Loading Library of Congress Classifications...' << ('&nbsp;' * 20),
    }.deep_freeze

    # === Other values
    # These are only used in the client (feature/shelf-browse.js).
    CONFIG = {
      orientation:    DEFAULT_ORIENTATION,
      root_id:        ROOT_ID,
      feature_path:   '/shelf_browse',
      lcc_tree_path:  '/shelf_browse/hierarchy.json',
      shelfkey_attr:  SHELFKEY_ATTR
    }.merge(UVA::ShelfBrowse.option).deep_freeze

    # =========================================================================
    # :section: Display - Item tile
    # =========================================================================

    public

    DEFAULT_MAX_TITLE  = 40
    DEFAULT_MAX_NUMBER = 14
    DEFAULT_OMISSION   = '&ctdot;'.html_safe.freeze

    # Status marker values (@see ".item" in shelf-browse.css.scss).  Note that
    # these will be used to dynamically generate the associated help display,
    # so entries that are not currently relevant should be commented-out to
    # prevent them from showing up in help.

    # rubocop:disable Metrics/LineLength
    STATUS_MARKER = {
      audio:          ['audio',       'A',  'Audio recording'],
      empty:          ['empty',       nil,  nil],
      error:          ['error',       nil,  nil],
      equipment:      ['equipment',   'E',  'Equipment for loan'],
      focus:          ['focus',       nil,  nil],
      shadowed:       ['shadowed',    '?',  'ERROR: hidden/shadowed'],
      non_circ:       ['non-circ',    'N',  'Non-circulating - for use within the library'],
      non_english:    ['non-english', 'L',  nil],
      pda:            ['pda',         'O',  'Available to order'],
      reserve:        ['reserve',     'R',  'One or more copies on course reserve'],
      # site_at_sea:  ['site',        'A',  'Semester-at-Sea only'],
      site_blandy:    ['site',        'B',  "Blandy Experimental Farm\n(available by request)"],
      site_kluge:     ['site',        'K',  'Kluge-Ruhe Study Center only'],
      site_mt_lake:   ['site',        'M',  "Mountain Lake Biological Station\n(available by request)"],
      site_cnhi:      ['site',        'N',  'Bjoring Center for Nursing Historical Inquiry only'],
      site_spec_coll: ['site',        'S',  'Special Collections Reading Room only'],
      unavailable:    ['unavailable', 'U',  'Unavailable - all copies are in use'],
      undiscoverable: ['error',       'X',  'ERROR: undiscoverable'],
      video:          ['video',       'V',  'Video recording'],
    }.deep_freeze
    # rubocop:enable Metrics/LineLength

    # =========================================================================
    # :section: Display - Item details
    # =========================================================================

    public

    FULL_RECORD_BUTTONS = {
      record_tab:  {
        label:  'See full record',
        title:  'Open a new browser tab with the Virgo page for this item.' \
                "\n(The virtual shelf will remain open in this browser tab.)",
        aside:  true # Open in a separate browser tab.
      },
      record_exit: {
        label:  'Exit to full record',
        title:  'Continue on to the Virgo page for this item.' \
                "\n(The virtual shelf will be closed;\n" \
                'the browser "back" button will not return to it.)',
      },
    }.deep_freeze

    # =========================================================================
    # :section: Display - Help
    # =========================================================================

    public

    # Help topic combinations and their initial visibility.
    #
    #   :visible  Initially displayed topic
    #   :hidden   Topic not displayed initially
    #   :unused   Topic unused
    #   nil       Same as :unused
    #
    HELP_TOPIC_COMBO = {
      lcc:     :hidden,
      default: :visible,
      unused:  :unused,
      nil =>   :unused,
    }.deep_freeze

    # Help topics and their membership in a topic combo.
    #
    # NOTE: This also defines the order of topics displayed from the
    # app/views/shelf_browse/shared/_help_content.html.erb template.
    #
    # @see changeHelpTopics() in feature/shelf-browse.js
    #
    HELP_TOPIC = {
      help_overview:   :default,
      help_layout:     nil,
      help_markers:    :default,
      help_keys:       :default,
      help_scroll:     :default,
      help_tips:       :default,
      help_lcc_browse: :lcc,
      help_background: :default,
      help_discussion: :default,
      help_lcc_about:  :lcc,
      help_lcc_impl:   :lcc
    }.deep_freeze

    # Help topics when viewed from the Special Collections lens.
    #
    SC_HELP_TOPIC = {
      help_special_collections: :default
    }.merge(HELP_TOPIC).deep_freeze

    # The CSS classes to use with each help topic.
    #
    HELP_TOPIC_CSS =
      HELP_TOPIC.map { |key, combo|
        visibility = HELP_TOPIC_COMBO[combo] || :unused
        [key, "topic #{key} #{visibility}"]
      }.to_h.deep_freeze

    # The CSS classes to use with each help topic when viewed from the
    # Special Collections lens.
    #
    SC_HELP_TOPIC_CSS =
      SC_HELP_TOPIC.map { |key, combo|
        visibility = HELP_TOPIC_COMBO[combo] || :unused
        [key, "topic #{key} #{visibility}"]
      }.to_h.deep_freeze

    # =========================================================================
    # :section:
    # =========================================================================

    public

    # The basis for links within the views.
    #
    # @return [String]
    #
    def base_path
      CONFIG[:feature_path]
    end

    # Indicates whether the request specified popup behavior.
    #
    # @param [String, Boolean] value
    #
    # @return [Boolean]
    #
    def popup(value = nil)
      case value
        when TrueClass, FalseClass
          @popup = value
        when String
          @popup = true_value?(value)
        else
          @popup = params_value(:popup, true) unless defined?(@popup)
          @popup
      end
    end

    # The number of the current window into the virtual shelf.
    #
    # @param [String, Fixnum] value
    #
    # @return [Fixnum]
    #
    def window(value = nil)
      if value
        @window = value.to_i
      else
        @window ||=
          params_value(:page, Fixnum) || UVA::SolrBrowseNearby::DEFAULT_PAGE
      end
    end

    # The width of the current window into the virtual shelf.
    #
    # @param [String, Fixnum] value
    #
    # @return [Fixnum]
    #
    def window_size(value = nil)
      if value
        @window_size = value.to_i
      else
        @window_size ||=
          params_value(:width, Fixnum) ||
          (UVA::SolrBrowseNearby::DEFAULT_HITS if popup) ||
          UVA::SolrBrowseNearby::FULL_VIEW_DEFAULT_HITS
      end
    end

    # The document in window 0 that is the "center" of the current virtual
    # shelf.
    #
    # @param [UVA::IndexDoc] value
    #
    # @return [UVA::IndexDoc]
    #
    def origin_doc(value = nil)
      if value
        @origin = value
      else
        @origin ||=
          (@document if defined?(@document)) ||
          (@document_list.first if @document_list.is_a?(Array))
      end
    end

    # The document ID of the item in window 0 that is the "center" of the
    # current virtual shelf.
    #
    # @param [String] value
    #
    # @return [String]
    #
    def origin_id(value = nil)
      if value
        @origin_id = value
      else
        @origin_id ||= origin_doc ? origin_doc.doc_id : params_value(:id)
      end
    end

    # The call number of the item in window 0 that is the "center" of the
    # current virtual shelf.
    #
    # @param [String] value
    #
    # @return [String]
    #
    def origin_call_number(value = nil)
      if value
        @origin_call_number = value
      else
        @origin_call_number ||= start || shelf_browse_number(origin_doc)
      end
    end

    # The page of the results requested from Solr.
    #
    # @param [String, Fixnum] value
    #
    # @return [String]
    #
    def page(value = nil)
      window(value).to_s
    end

    # The size of the page of results requested from Solr.
    #
    # @param [String, Fixnum] value
    #
    # @return [String]
    #
    def per_page(value = nil)
      window_size(value).to_s
    end

    # The location of the focus item within the window.
    #
    # @param [String, Symbol] value
    #
    # @return [Symbol]
    #
    def offset(value = nil)
      if value
        @offset = value.to_sym
      else
        @offset ||= params_value(:offset, Symbol)
      end
    end

    # The starting call number -- if invoked with "?start=number" then this
    # supersedes *origin_id* when determining how to construct URLs relative to
    # the initial URL.
    #
    # @param [String] value
    #
    # @return [String]
    #
    def start(value = nil)
      if value
        @start = value
      else
        @start ||= params_value(:start)
      end
    end

    # For requests based on call number rather than document ID, this is the
    # default starting value if `params[:start]` is not supplied.
    #
    # Currently this is a constant, but it could be any function (for example
    # it could return a randomized value over the range 'A'..'Z').
    #
    # @return [String]
    #
    def default_start
      'M'
    end

    # Indicate whether we are in the Special Collections lens.
    #
    # @return [Boolean]
    # @return [nil]                   If SC lens support is not configured.
    #
    def in_sc_lens
      special_collections_lens? if UVA::ShelfBrowse.option[:sc_supported]
    end

    # =========================================================================
    # :section:
    # =========================================================================

    public

    # get_virtual_shelf_window
    #
    # @param [String] id
    # @param [Hash]   opt  @see UVA::SolrBrowseNearby
    #
    # @option opt [String] :base
    # @option opt [String] :id
    #
    # @return [Array<UVA::IndexDoc>]
    #
    def get_virtual_shelf_window(id, opt = nil)
      opt = opt ? opt.dup : {}
      opt[:page]    = window(opt[:page])
      opt[:width]   = window_size(opt[:width])
      opt[:offset]  = offset(opt[:offset])
      opt[:origin]  = origin_id(id || opt[:origin])
      opt[:params]  = params.except(:page, :width, :offset, :origin).rdup
      opt[:session] = session.to_hash
      unless Virgo.deployed_production?
        raise "id = #{id} & :start = #{opt[:start]}" if id && opt[:start]
      end
      browse = UVA::SolrBrowseNearby.new(id, opt)
      validate(browse) unless Virgo.deployed_production?
      @origin = browse.origin # TODO: origin history stack
      @start  = browse.start
      @offset = browse.offset
      browse.documents || []
    end

    # get_lcc_hierarchy
    #
    # @param [Hash] opt
    #
    # @option opt [String] :class     Identifier of an LCC class.
    # @option opt [String] :subclass  Identifier of an LCC subclass.
    # @option opt [String] :range     An LCC call number range.
    #
    # @return [LccClass]              If opt[:class] was specified.
    # @return [LccSubclass]           If opt[:subclass] was specified.
    # @return [LccRange]              If opt[:range] was specified.
    # @return [LccRoot]               Otherwise.
    #
    def get_lcc_hierarchy(opt = nil)
      opt ||= {}
      if opt[:class]
        Lcc.class_tree(opt[:class])
      elsif opt[:subclass]
        Lcc.subclass_tree(opt[:subclass])
      elsif opt[:range]
        Lcc.range_tree(opt[:range])
      else
        Lcc.hierarchy
      end
    end

    # Return the LCC hierarchy in the form expected by jstree.
    #
    # If *node* is the root node (or not given) then the pre-generated JSON
    # for the entire hierarchy is returned.
    #
    # @param [LccBase] node
    #
    # @option opt [Fixnum] :effective_depth
    #
    # @return [Hash]
    #
    # @see self#to_jstree
    #
    def get_jstree(node = nil)
      if !node || node.is_a?(LccRoot)
        JSTREE_HIERARCHY
      else
        to_jstree(node).to_json
      end
    end

    # Transform the LCC hierarchy into the form expected by jstree.
    #
    # @param [LccBase] node
    # @param [Hash]    opt
    #
    # @option opt [Fixnum] :effective_depth
    #
    # @return [Hash]
    #
    def to_jstree(node, opt = nil)

      # If an effective tree depth has been provided, use it to change what
      # #lcc_name reports.
      effective_depth = opt && opt[:effective_depth].presence
      lcc_name_opt = effective_depth && { effective_depth: effective_depth }

      # Adjust display properties based on the type of node.
      type = node.type
      id = type.upcase
      if id == ROOT_ID
        label = lcc_name(LABEL[:lcc_root], title: TOOLTIP[:lcc_root])
      else
        range = node.range.tr('()', '')
        id    = node.is_a?(LccRange) ? range : "#{id}_#{range}"
        label = lcc_range(range, class: type) + lcc_name(node, lcc_name_opt)
      end
      label = content_tag(:div, label, class: "lcc-#{type}")

      # Generate the data for this node.
      result = {
        'data' => {
          'title' => label,
        },
        'attr' => {
          'id'    => id,
          'class' => "lcc-#{type}-node",
        },
      }

      # Generate the data for subtrees if there are any.
      branches = []
      if node.branch.present?
        effective_depth ||= node.depth
        child_opt = { effective_depth: effective_depth + 1 }
        child_opt.reverse_merge!(opt) if opt.present?
        # In two cases, the first child's children are taken in place of the
        # child itself because the child is essentially redundant.
        children = node.branch
        first_child = children.first
        descendants =
          if node.is_a?(LccClass) && first_child.name.blank?
            first_child
          elsif node.is_a?(LccSubclass) && (children.size == 1)
            lde = (node.range =~ /^L[DE]$/)
            n = first_child
            while (n.branch.size == 1) && (lde || n.branch.first.artificial)
              n = n.branch.first
            end
            n
          end
        if descendants
          branches += descendants.map { |child| to_jstree(child, child_opt) }
          children = children[1..-1]
        end
        branches += children.map { |child| to_jstree(child, child_opt) }
      end
      result['children'] = branches if branches.present?

      # Return with the completed tree.
      result
    end

    # Remove parameters specific to the virtual shelf browse controller.
    #
    # @param [Hash] url_params
    #
    # @return [Hash]
    #
    def remove_shelf_browse_params(url_params = nil)
      url_params ||= (defined?(params) && params.is_a?(Hash)) ? params : {}
      url_params.reject { |key, _| PARAMS.include?(key.to_sym) }
    end

    # =========================================================================
    # :section:
    # =========================================================================

    protected

    # Raise an exception if the search object has not been set up as expected.
    #
    # @param [UVA::SolrBrowseNearby] browse
    #
    # @raise [StandardError]
    #
    def validate(browse)
      error = []
      if browse.nil?
        error << 'SolrBrowseNearby: instance missing'
      elsif browse.documents.nil?
        error << 'SolrBrowseNearby: documents nil'
      elsif browse.documents.empty?
        error << 'SolrBrowseNearby: zero documents'
      end
      unless window == browse.requested_page
        error << "window #{window.inspect} != page #{browse.requested_page}"
      end
      unless window_size == browse.hits_requested
        error << "size #{window_size.inspect} != hits #{browse.hits_requested}"
      end
      if error.present?
        error.unshift('*** Shelf browse validation failures ***')
        raise error.join("\n")
      end
    end

    # =========================================================================
    # :section:
    # =========================================================================

    private

    # params_value
    #
    # @param [Symbol, String] item
    # @param [Class]          type
    #
    # @return [String]
    # @return [nil]
    #
    def params_value(item, type = String)
      return unless defined?(params) && params.is_a?(Hash)
      result = params[item]
      case type
        when String                then result.to_s
        when Symbol                then result.to_sym
        when Numeric               then result.to_i
        when TrueClass, FalseClass then true_value?(result)
        else                            result
      end
    end

    # =========================================================================
    # :section: Display - First row
    # =========================================================================

    public

    # HTML for a button to expose the help panel.
    #
    # @param [Hash] opt               HTML options passed to the element plus
    #                                   the following:
    #
    # @option opt [String] :label     The visible component of the button; by
    #                                   default this is a question mark in a
    #                                   circle.
    #
    # @option opt [String, Array<String>] :class
    #                                 One or more CSS classes to be included
    #                                   with the definition.
    #
    # @return [ActiveSupport::SafeBuffer]
    #
    # === Usage Notes
    # CSS class(es) passed in through *opt* are appended to the button class.
    #
    def help_button(opt = nil)
      default_opt =
        dialog_button_opts(
          class: 'help-button',
          title: TOOLTIP[:help],
          label: help_symbol
        )
      html_opt = html_options(opt, default_opt)
      label = html_opt.delete(:label)
      html_opt[ARIA_LABEL] ||= html_opt[:title] || strip_html(label)
      content_tag(:div, label, html_opt)
    end

    # HTML for a button to expose the LCC browser panel.
    #
    # @param [Hash] opt               HTML options passed to the element plus
    #                                   the following:
    #
    # @option opt [String] :label    The visible component of the button; by
    #                                   default this is self#LABEL[:lcc_open].
    #
    # @option opt [String, Array<String>] :class
    #                                 One or more CSS classes to be included
    #                                   with the definition.
    #
    # @return [ActiveSupport::SafeBuffer]
    #
    def lcc_browser_button(opt = nil)
      default_opt =
        dialog_button_opts(
          class:           'lcc-button',
          title:           TOOLTIP[:lcc],
          label:           LABEL[:lcc_open],
          ARIA_HASPOPUP => 'tree'
        )
      html_opt = html_options(opt, default_opt)
      label = html_opt.delete(:label)
      html_opt[ARIA_LABEL] ||= html_opt[:title] || strip_html(label)
      content_tag(:div, label, html_opt)
    end

    # HTML for the feature title.
    #
    # @param [Hash] opt               HTML options passed to the element plus
    #                                   the following:
    #
    # @option opt [String] :label     Title text; default:
    #                                   UVA::ShelfBrowse.default_title.
    #
    # @option opt [String, Array<String>] :class
    #                                 One or more CSS classes to be included
    #                                   with the definition.
    #
    # @return [ActiveSupport::SafeBuffer]
    #
    def title_text(opt = nil)
      default_opt = {
        class: 'title-text',
        label: UVA::ShelfBrowse.default_title,
      }
      html_opt = html_options(opt, default_opt)
      label = html_opt.delete(:label)
      content_tag(:div, label, html_opt)
    end

    # HTML to display the origin call number or a button to return to the
    # origin call number.
    #
    # @param [Hash] opt               HTML options passed to the element plus
    #                                   the following:
    #
    # @option opt [String, Array<String>] :class
    #                                 One or more CSS classes to be included
    #                                   with the definition.
    #
    # @return [ActiveSupport::SafeBuffer]
    #
    # @see "Event handlers - Navigation" in feature/shelf-browse.js
    #
    def origin_button(opt = nil)
      default_opt = {
        class: 'origin',
        title: TOOLTIP[:origin],
        role:  'button'
      }
      html_opt = html_options(opt, default_opt)
      label = html_opt.delete(:label)
      label ||=
        if (number = origin_call_number).present?
          number = lcc_number(number)
          html_opt[SHELFKEY_ATTR] = number.to_shelfkey
          ERB::Util.h(number.display(false))
        end
      unless window.zero? || label.blank?
        html_opt[:title] = TOOLTIP[:return]
        html_opt[:class] << ' target'
        label_opt = { class: 'target' }
        label = 'Return to '.html_safe + content_tag(:span, label, label_opt)
      end
      page_link(label, html_opt)
    end

    # HTML for a button to close the shelf browse popup.
    #
    # @param [Hash] opt
    #
    # @return [ActiveSupport::SafeBuffer]
    #
    # @see self#close_button
    #
    def feature_close_button(opt = nil)
      close_button(html_options(opt, title: TOOLTIP[:close]))
    end

    # =========================================================================
    # :section: Display - Second row
    # =========================================================================

    public

    # HTML to display the call numbers of the first and last displayed items.
    #
    # @param [Array<UVA::IndexDoc>] docs
    # @param [Hash] opt               HTML options passed to the element plus
    #                                   the following:
    #
    # @option opt [String, Array<String>] :class
    #                                 One or more CSS classes to be included
    #                                   with the definition.
    #
    # @option opt [String] :connector
    #                                 Text to place between the call numbers.
    #
    # @return [ActiveSupport::SafeBuffer]
    #
    def current_range_area(docs, opt = nil)

      default_opt = {
        class:     'current-range-area',
        connector: '&nbsp;&nbsp;to&nbsp;&nbsp;'.html_safe
      }
      html_opt = html_options(opt, default_opt)
      connector = html_opt.delete(:connector)

      # Get the documents being displayed.
      docs  = shelf_browse_documents(docs)
      first = docs.first
      last  = (docs.last if docs.size > 1)

      # Trim the numbers to the shortest length where they appear distinct.
      first_number = first && first.get_call_numbers.first.presence
      last_number  = last  && last.get_call_numbers.first.presence
      first_number, last_number = range_numbers(first_number, last_number)

      # Call number range.
      range_parts = []
      range_parts <<
        if first_number.present?
          classes =  %w(start)
          classes << 'current-range-first'
          classes << 'current-range-last' unless last_number.present?
          number_opt = {
            class:           classes.join(' '),
            SHELFKEY_ATTR => first[:shelfkey]
          }
          content_tag(:div, first_number, number_opt)
        end
      range_parts <<
        if last_number.present?
          classes =  %w(end)
          classes << 'current-range-first' unless first_number.present?
          classes << 'current-range-last'
          number_opt = {
            class:           classes.join(' '),
            SHELFKEY_ATTR => last[:shelfkey]
          }
          content_tag(:div, last_number, number_opt)
        end
      range =
        content_tag(:div, class: 'range') do
          range_parts.compact.join(connector).html_safe
        end

      # Return the entire control.
      content_tag(:div, html_opt) do
        page_display + range
      end
    end

    # HTML to display the distance from the origin of the current set of
    # displayed items in terms of "pages".
    #
    # Page 0 is the set of items containing the origin item.
    # Page -1 is the set of items immediately preceding page 0.
    # Page +1 is the set of items immediately following page 0.
    #
    # @param [Hash]   opt             HTML options passed to the element plus
    #                                   the following:
    #
    # @option opt [String, Array<String>] :class
    #                                 One or more CSS classes to be included
    #                                   with the definition.
    #
    # @return [ActiveSupport::SafeBuffer]
    #
    # @see "Function definitions - Progress bar" in feature/shelf-browse.js
    #
    def page_display(opt = nil)

      default_opt = { class: 'page-display' }
      html_opt    = html_options(opt, default_opt)

      count = window.abs
      position, relative_to =
        case (window <=> 0)
          when +1 then %w(ahead beyond)
          when -1 then %w(behind before)
        end
      if position
        html_opt[:class] << " #{position}"
        label = count.to_s
      else
        label = ''
      end

      tooltip    = 'The virtual shelf is centered on the original item.'
      aria_label = tooltip
      if relative_to
        pages = (count == 1) ? 'One page' : "#{count} pages"
        tooltip    = "#{pages} #{relative_to} the original item."
        aria_label = "The virtual shelf is #{tooltip}"
      end
      html_opt[:title]     ||= tooltip
      html_opt[ARIA_LABEL] ||= aria_label

      content_tag(:div, label, html_opt)
    end

    # =========================================================================
    # :section: Display - Second row
    # =========================================================================

    protected

    # Trim the given call number range end points to the shortest values that
    # differentiate them.
    #
    # If *a* and *b* are the same or if one of them is *nil* then the values
    # are returned unchanged (with blank strings converted to *nil*).
    #
    # @param [String] a               First call number of range.
    # @param [String] b               Last call number of range.
    #
    # @return [Array<(String, String)>]   Minimized call number strings.
    # @return [Array<(nil, String)>]      If *a* is blank; *b* is unmodified.
    # @return [Array<(String, nil)>]      If *b* is blank; *a* is unmodified.
    #
    def range_numbers(a, b)
      if a.present? && b.present?
        a_parts = call_number_parts(a)
        b_parts = call_number_parts(b)
        tail_index = differing_index(a_parts, b_parts)
        if tail_index
          a_tail_index = b_tail_index = tail_index
          if tail_index.zero?
            next_index = tail_index + 1
            a_tail_index = next_index if a_parts[next_index].present?
            b_tail_index = next_index if b_parts[next_index].present?
          end
          a = a_parts[0..a_tail_index].join(' ')
          b = b_parts[0..b_tail_index].join(' ')
        end
      end
      return a.presence, b.presence
    end

    # Break a call number into chunks that can be compared to find the point
    # at which two call numbers differ.
    #
    # @param [String] number
    #
    # @return [Array<String>]
    #
    def call_number_parts(number)
      number
        .sub(/^([a-z]+)\s+(\d+)/i, '\1\2')  # Join call letters and numbers
        .gsub(/\.[a-z]\w+/i, ' \&')         # Separate cutter numbers
        .split(/\s+/)
    end

    # Find the index where two arrays of strings differ.
    #
    # @param [Array<String>] a
    # @param [Array<String>] b
    #
    # @return [Fixnum]                The index of *a* or *b*.
    # @return [nil]                   If *a* and *b* are the same.
    #
    def differing_index(a, b)
      max_index = [a.size, b.size].min - 1
      (0..max_index).find { |index| a[index].casecmp(b[index]).nonzero? }
    end

    # =========================================================================
    # :section: Display - Page scroller
    # =========================================================================

    public

    # Where the primary item is located in the shelf "window" (:first, :middle,
    # :last or a number from 0 [equivalent to :first] through *max_index*
    # [equivalent to :last].)
    #
    # @param [Array<UVA::IndexDoc>] items
    # @param [Symbol, Fixnum]       focus
    #
    # @return [Fixnum]
    #
    def focus_item_index(items = nil, focus = nil)

      items ||= @document_list || []
      focus ||= :first

      # Find the index expressed or implied by *focus*, within the bounds of
      # the array.
      count = items.size
      min   = 0
      max   = count - 1
      index =
        case focus
          when :first  then min
          when :middle then count / 2
          when :last   then max
          else              (focus < 0) ? (count + focus) : focus
        end
      index = min if index < min
      index = max if index > max

      # Ensure that focus is not on an empty item.  If they're all empty just
      # return the originally-determined index.
      forward = focus.is_a?(Numeric) ? (focus >= 0) : (focus == :first)
      indices = forward ? index.upto(max) : index.downto(min)
      indices.find { |i| items[i].is_a?(UVA::IndexDoc) } || index

    end

    # A control for moving forward in the virtual shelf.
    #
    # @param [Fixnum] page            Default *1* page forward.
    # @param [String] label
    # @param [Hash]   url_opt
    #
    # @return [ActiveSupport::SafeBuffer]
    #
    # @see "Event handlers - Navigation" in feature/shelf-browse.js
    #
    def page_forward_button(page = nil, label = nil, url_opt = nil)
      page ||= 1
      page = page.to_i.abs
      default_opt = { alt: (page == 1) ? '>' : '>>' }
      url_opt = url_opt ? default_opt.merge(url_opt) : default_opt
      page_button(page, label, url_opt)
    end

    # A control for moving backward in the virtual shelf.
    #
    # @param [Fixnum] page            Default *1* page backward.
    # @param [String] label
    # @param [Hash]   url_opt
    #
    # @return [ActiveSupport::SafeBuffer]
    #
    # @see "Event handlers - Navigation" in feature/shelf-browse.js
    #
    def page_reverse_button(page = nil, label = nil, url_opt = nil)
      page ||= 1
      page = -page.to_i.abs
      default_opt = { alt: (page == -1) ? '<' : '<<' }
      url_opt = url_opt ? default_opt.merge(url_opt) : default_opt
      page_button(page, label, url_opt)
    end

    # Page button icon image.
    #
    # @param [Fixnum] page            Negative for page backward.
    # @param [Hash]   opt
    #
    # @option opt [Boolean] :static   No 'mouseover'.
    # @option opt [Boolean] :hovered  Use the hover image; implies :static.
    #
    # @return [ActiveSupport::SafeBuffer]
    #
    def page_icon(page = 1, opt = nil)
      default_opt = {
        size: '32x32'
      }
      html_opt = html_options(opt, default_opt)
      hovered = html_opt.delete(:hovered)
      static  = html_opt.delete(:static) || hovered

      icon_base = 'shelf-browse/page/'
      icon_base << ((page >= 0) ? 'forward' : 'reverse')
      icon_base << '10x' unless page.abs == 1
      normal_icon = "#{icon_base}.png"
      hover_icon  = "#{icon_base}_hover.png"

      icon = hovered ? hover_icon : normal_icon
      html_opt[:mouseover] ||= hover_icon unless static
      image_tag(icon, html_opt)
    end

    # =========================================================================
    # :section: Display - Page scroller
    # =========================================================================

    protected

    # Create a control to move the virtual shelf window relative to the origin.
    #
    # @param [Fixnum] page            Negative for page backward.
    # @param [String] label
    # @param [Hash]   opt
    #
    # @return [ActiveSupport::SafeBuffer]
    # @return [nil]                   If *page* was invalid.
    #
    # @see app/assets/javascripts/feature/shelf-browse.js
    #
    def page_button(page, label = nil, opt = nil)

      page = page.to_i
      step = page.abs

      # Set CSS class based on the direction of the button.
      case (page <=> 0)
        when +1 then css_class = 'page-forward'
        when -1 then css_class = 'page-reverse'
        else
          return if Virgo.deployed_production?
          raise 'page zero is invalid'
      end
      default_opt = { class: css_class, role: 'button' }
      html_opt    = html_options(opt, default_opt)

      # By default the page buttons are images.
      image_opt = {}
      image_opt[:alt] = html_opt.delete(:alt) if html_opt.key?(:alt)
      label ||= page_icon(page, image_opt)

      # Create a tooltip explaining the function of the control.
      unless html_opt.key?(:title)
        single = (step == 1)
        pages  = single ? 'one page' : "#{step} pages"
        if page > 0
          direction = 'forward'
          value     = 'higher'
          kbd_keys  = single ? 'Shift+RightArrow' : 'Shift+PgUp'
        else
          direction = 'backward'
          value     = 'lower'
          kbd_keys  = single ? 'Shift+LeftArrow' : 'Shift+PgDn'
        end
        html_opt[:title] = [
          "Go #{direction} by #{pages}",
          "(to #{value} call numbers)",
          "[#{kbd_keys}]"
        ].join(NEWLINE).html_safe
      end

      # Attach a URL that defines the action of the control.
      html_opt[:'data-step'] = step
      html_opt[:page] = window + page
      page_link(label, html_opt)
    end

    # =========================================================================
    # :section: Display - Item tile
    # =========================================================================

    public

    # Generate HTML for the item portion of an item tile, followed by its
    # status marker tray.
    #
    # @param [UVA::IndexDoc, Symbol] item
    # @param [Hash]                  opt
    #
    # @option opt [Boolean] :focus
    # @option opt [String]  :item_tip
    # @option opt [String]  :cover_tip
    # @option opt [String]  :status_tip
    # @option opt [Fixnum]  :max_title
    # @option opt [Fixnum]  :max_number
    # @option opt [String, Array<String>] :item_css
    #
    # @return [ActiveSupport::SafeBuffer]
    #
    def item_element(item, opt = nil)

      default_opt = {
        class: 'item'
      }
      html_opt = html_options(opt, default_opt)

      # For empty/error items, adjust the default tooltip.
      item ||= :error
      is_doc = item.is_a?(UVA::IndexDoc)
      default_tip = is_doc ? TOOLTIP[:item] : TOOLTIP[:no_item]

      item_tip   = html_opt.delete(:item_tip)   || default_tip
      cover_tip  = html_opt.delete(:cover_tip)  || item_tip
      status_tip = html_opt.delete(:status_tip) || item_tip
      max_title  = html_opt.delete(:max_title)
      max_number = html_opt.delete(:max_number)

      # Add status markers and update styling based on the nature of the item.
      markers, item_css = make_status_markers(item, html_opt)

      # Generate the item element.
      classes = html_opt[:class] || []
      classes = classes.split(' ') unless classes.is_a?(Array)
      classes = (classes + item_css).reject(&:blank?).uniq.join(' ')
      item_html =
        content_tag(:div, class: classes, title: item_tip, tabindex: 0) do
          title_element(item, max_length: max_title) +
            cover_element(item, title: cover_tip) +
            call_number_element(item, max_length: max_number)
        end

      # Generate the status marker tray element.
      markers.delete_if(&:blank?)
      status_html = status_marker_tray(*markers, title: status_tip)

      # Return with both elements.
      item_html + status_html
    end

    # =========================================================================
    # :section: Display - Item tile
    # =========================================================================

    protected

    # title_element
    #
    # @param [UVA::IndexDoc,Symbol] item
    # @param [Array]                args
    #
    # @option args [Fixnum] :max_length
    #
    # @return [ActiveSupport::SafeBuffer]
    #
    def title_element(item, *args)
      default_opt = {
        class:      'title',
        max_length: DEFAULT_MAX_TITLE,
        omission:   DEFAULT_OMISSION
      }
      arg_opt  = (args.pop if args.last.is_a?(Hash))
      html_opt = html_options(arg_opt, default_opt)
      max_length = html_opt.delete(:max_length)
      omission   = html_opt.delete(:omission)

      title =
        case item
          when UVA::IndexDoc  then item.main_title
          when :error, :empty then ''
          else                     [item, *args].join(' ')
        end

      tooltip = html_opt[:title].presence
      tooltip ||=
        if item.is_a?(UVA::IndexDoc)
          item.basic_title(colon: ":\n")
        else
          title
        end
      tooltip = html_decode(tooltip)

      aria_label = html_opt[ARIA_LABEL].presence || tooltip.gsub(/\s+/, ' ')

      html_opt[:title]     = tooltip    if tooltip.present?
      html_opt[ARIA_LABEL] = aria_label if aria_label.present?

      content_tag(:div, html_opt) do
        html_truncate(title, length: max_length, omission: omission)
      end
    end

    # cover_element
    #
    # @param [UVA::IndexDoc,Symbol] item
    # @param [Array]                args
    #
    # @return [ActiveSupport::SafeBuffer]
    #
    def cover_element(item, *args)
      default_opt = {
        class:         'cover-container',
        ARIA_HIDDEN => true
      }
      arg_opt   = (args.pop if args.last.is_a?(Hash))
      html_opt  = html_options(arg_opt, default_opt)
      cover_opt = { title: html_opt[:title], no_link: true }

      content_tag(:div, html_opt) do
        case item
          when UVA::IndexDoc then link_to_document_from_cover(item, cover_opt)
          when Symbol        then "(<em>#{item}</em>)".html_safe
          else                    [item, *args].join(' ').html_safe
        end
      end
    end

    # call_number_element
    #
    # @param [UVA::IndexDoc,Symbol] item
    # @param [Array]                args
    #
    # @option args [Fixnum] :max_length
    #
    # @return [ActiveSupport::SafeBuffer]
    #
    def call_number_element(item, *args)
      default_opt = {
        class:      'call-number',
        max_length: DEFAULT_MAX_NUMBER,
        omission:   DEFAULT_OMISSION
      }
      arg_opt  = (args.pop if args.last.is_a?(Hash))
      html_opt = html_options(arg_opt, default_opt)
      max_length = html_opt.delete(:max_length)
      omission   = html_opt.delete(:omission)

      number =
        case item
          when UVA::IndexDoc then shelf_browse_number(item)
          when Symbol        then ''
          else                    [item, *args].join(' ')
        end
      number = h(number)
      html_opt[:title]     ||= number
      html_opt[ARIA_LABEL] ||= "Call number: #{number}" if number.present?

      content_tag(:div, html_opt) do
        number = html_truncate(number, length: max_length, omission: omission)
        number.gsub(/\s/, '&nbsp;').html_safe
      end
    end

    # status_marker_tray
    #
    # @param [Array] args
    #
    # @return [ActiveSupport::SafeBuffer]
    #
    def status_marker_tray(*args)
      default_opt = {
        class: 'item-status-tray',
        title: TOOLTIP[:status]
      }
      arg_opt  = (args.pop if args.last.is_a?(Hash))
      html_opt = html_options(arg_opt, default_opt)
      content_tag(:div, html_opt) do
        args << '&nbsp;' if args.empty?
        args.join(SPACE).html_safe
      end
    end

    # status_marker_element
    #
    # @param [Symbol, String] iclass
    # @param [String] marker
    # @param [String] tooltip
    #
    # @return [ActiveSupport::SafeBuffer]
    # @return [nil]
    #
    def status_marker_element(iclass, marker = nil, tooltip = nil)
      iclass, marker, tooltip = STATUS_MARKER[iclass] if iclass.is_a?(Symbol)
      return unless marker
      tooltip ||= iclass.capitalize
      html_opt = {
        class:        "item-status-marker #{iclass}",
        title:        tooltip,
        ARIA_LABEL => "Status: #{tooltip}"
      }
      content_tag(:div, marker, html_opt)
    end

    # make_status_markers
    #
    # @param [UVA::IndexDoc,Symbol] item
    # @param [Hash]                 opt
    #
    # @option opt [Boolean] :focus
    #
    # @return [Array,Array]
    #   - [0] Array of status markers.
    #   - [1] Array of CSS classes.
    #
    def make_status_markers(item, opt = nil)

      opt ||= {}
      item_css = Array(opt[:class])
      status_markers = []

      # A "macro" for updating item_css and status_markers.
      status = Proc.new { |iclass, marker, tooltip|
        item_css << iclass
        status_markers << status_marker_element(iclass, marker, tooltip)
      }

      # Based on its attributes, modify item styling and set status markers.
      if item.is_a?(Symbol)

        # ==== Error item or empty item
        status.call(item)

      else

        # Get information about the item and its copies.
        unique_site    = unique_site_type(item)
        shadowed       = item.hidden?
        undiscoverable = !item.discoverable?
        existing_copies = available_copies = 0
        availability = online_only = nil
        available =
          if unique_site || shadowed || undiscoverable
            true
          elsif !(availability = item.availability)
            (online_only = item.online_only?)
          elsif is_pda?(item) # PDA print (not e-books).
            :pda
          elsif (existing_copies = availability.existing_copies).zero?
            (online_only = !item.get_url.first.nil?)
          else
            !(available_copies = availability.available_copies).zero?
          end
        catalog_item = availability && !online_only

        # ==== Special sites
        # These are noted because the items must be used at the site (or, at
        # least, will require some time to request in the case of the
        # off-Grounds libraries).
        site_marker    = {}
        non_marked     = {}
        special_status = {}
        if catalog_item

          sc_holdings = (availability.special_collections_copies if in_sc_lens)
          if sc_holdings && sc_holdings.nonzero?

            # Within the Special Collections lens, the .item-display will
            # contain a request link if *any* of the existing copies are in
            # Special Collections. The tile needs to have a "[S]" marker (and
            # no other site marker) for these items even though there might be
            # copies at other libraries.
            site_marker[:site_spec_coll] = sc_holdings

          else

            # In the general case, annotate with a site marker if that site has
            # all copies of an item.
            availability.holdings_by_library.each_pair do |library, count|
              next if count.zero?
              key = "site_#{library}".underscore.to_sym
              if STATUS_MARKER.has_key?(key)
                site_marker[key] ||= 0
                site_marker[key] += count
              else
                non_marked[library] ||= 0
                non_marked[library] += count
              end
              unavailable = workflow_status_field(__method__, library).present?
              special_status[library] = true if unavailable
            end

          end

        elsif unique_site

          # Annotate unique sites like Kluge-Ruhe since the item must be used
          # on-site.  (Stored in *site_marker* as zero because it does not
          # contribute to circulating_copies).
          key = "site_#{unique_site}".underscore.to_sym
          site_marker[key] = 0 if STATUS_MARKER.has_key?(key)

        end
        # If there are holdings in any "non-marked" site, then markers will
        # not be shown.  If there are holdings only for special sites, then a
        # marker will be shown for each of them.
        if special_status.present? && (special_status.size == non_marked.size)
          available = false
        elsif non_marked.empty? && site_marker.present?
          site_marker.keys.sort.each { |key| status.call(key) }
        end

        # ==== Availability
        if !available
          status.call(:unavailable)
        elsif available.is_a?(Symbol)
          status.call(available)
        end

        # ==== Language
        language = nil
        in_english =
          if item.non_bibliographic?
            :equipment
          elsif (language = item.get_language).empty?
            # Assume that the "default" language is English.
            true
          else
            # All the various ways to state or imply the item is in English:
            language.any? do |lang|
              (lang == 'English') ||
                (lang =~ /English(\s*,| and | \(also in\))/i) ||
                (lang =~ /English (dialog|words)/i) ||
                (lang =~ /(,|and|in|text in|translated into) English/i) ||
                (lang =~ /^(Translated from|Translation in) /i) ||
                (lang =~ /^Closed?[\s-]+caption(ed)?$/i) ||
                (lang =~ /staff notation/i)

            end
          end
        if in_english.is_a?(Symbol)
          status.call(in_english)
        elsif !in_english
          iclass, marker, _tooltip = STATUS_MARKER[:non_english]
          language.delete_if { |lang| lang =~ /\(translated from\)/i }
          tooltip = 'Language: ' + language.join(' / ')
          status.call(iclass, marker, tooltip)
        end

        # ==== Item type
        item_type = item.reference_type(:ris)
        case item_type
          when 'SOUND' then status.call(:audio)
          when 'VIDEO' then status.call(:video)
        end

        # ==== Usage limitations
        # These come later so that any style modifications to the item element
        # are applied preferentially.
        if catalog_item

          # ===== Non-circulating
          # Only indicated if all copies are non-circulating.  To ensure that
          # edge cases, deduct items from sites like Special Collections whose
          # copies will be marked as circulating.
          cc = availability.circulating_copies
          cc -= site_marker.sum(&:last) unless non_marked.empty?
          status.call(:non_circ) if (cc <= 0) && (existing_copies > 0)

          # ===== Course reserve
          # If there are available copies that are not on reserve, only the 'R'
          # marker will be displayed but the item style will not be modified.
          reserve_copies = availability.reserve_copies
          unless reserve_copies.zero?
            status.call(:reserve)
            item_css.delete('reserve') if reserve_copies < available_copies
          end

        end

        # ==== Exceptional conditions
        # These shouldn't show in production; if one did this would probably
        # indicate a problem that would need to be corrected.
        status.call(:shadowed)       if shadowed
        status.call(:undiscoverable) if undiscoverable

      end

      # Modify styling and set status markers if this is a focus item.
      status.call(:focus) if opt[:focus]

      return status_markers, item_css
    end

    # =========================================================================
    # :section: Display - Item ranges
    # =========================================================================

    public

    # Generate the LCC hierarchy in a range frame.
    #
    # @param [Array<UVA::IndexDoc>] docs
    # @param [Hash]                 opt
    #
    # @option opt [Fixnum]  :max_levels
    # @option opt [Fixnum]  :first_level
    # @option opt [Fixnum]  :last_level
    #
    # @option opt [String]  :tab
    # @option opt [String]  :prefix
    # @option opt [Fixnum]  :indent
    # @option opt [String]  :connector
    # @option opt [Boolean] :allow_blank
    # @option opt [Boolean] :allow_no_name
    # @option opt [Boolean] :allow_no_lcco
    #
    # @return [ActiveSupport::SafeBuffer]
    # @return [nil]
    #
    def range_frame(docs, opt = nil)

      opt = opt ? opt.dup : {}
      first_level = opt.delete(:first_level) || 1
      last_level  = opt.delete(:last_level)
      max_levels  = opt.delete(:max_levels)

      # Get the first and last LCC values that are being displayed.
      cn_first = cn_last = nil
      shelf_browse_documents(docs).each do |doc|
        next unless doc && (call_number = shelf_browse_number(doc, true))
        if cn_first
          cn_last  = call_number
        else
          cn_first = call_number
        end
      end
      first_path = cn_first && Lcc.node_path(cn_first)
      last_path  = cn_last  && Lcc.node_path(cn_last)

      # Generate levels, managing indentation so that non-displayed levels
      # do not affect levels below them.
      opt[:indent] ||= 0
      count = 0
      levels = []
      level = first_level
      while (entry = range_frame_level(level, first_path, last_path, opt))

        # Skip to the next level, if directed, without changing the any of the
        # characteristics of the upcoming displayed level.
        level += 1
        next if entry == :skip

        # Prepare display characteristics for next level.
        count += 1
        opt[:indent] += 1
        opt[:effective_depth] = level

        # Emit the current level; stop if boundary conditions have been met.
        levels << entry
        break unless !last_level || (level < last_level)
        break unless !max_levels || (count < max_levels)

      end

      # Fodder for IE since it chops off the last line.
      ie_spacer = content_tag(:p, '&nbsp;'.html_safe)

      # Wrap the levels in a <div>.
      content_tag(:div, class: 'range-frame', role: 'navigation') do
        levels.compact.join.html_safe + ie_spacer
      end

    end

    # Generate content for a range-frame element.
    #
    # @param [String]         level
    # @param [Array<LccBase>] first_path
    # @param [Array<LccBase>] last_path
    # @param [Hash]           opt
    #
    # @option opt [String]  :tab            In 'em' units.
    # @option opt [String]  :prefix
    # @option opt [Fixnum]  :indent
    # @option opt [Fixnum]  :indent_offset  In 'em' units.
    # @option opt [String]  :connector
    # @option opt [Boolean] :allow_blank
    # @option opt [Boolean] :allow_no_name
    # @option opt [Boolean] :allow_no_lcco
    # @option opt [Symbol]  :only           Set internally to indicate that
    #                                         only the :first or :last call
    #                                         number should be used.  (Once a
    #                                         a level has been detected where
    #                                         the first and last levels differ,
    #                                         this avoids showing any more
    #                                         differences.
    #
    # @return [ActiveSupport::SafeBuffer]
    # @return [:skip]
    # @return [nil]
    #
    def range_frame_level(level, first_path, last_path, opt = nil)

      # Process arguments.
      level = [1, level].max
      level_type =
        case level
          when 1 then 'class'
          when 2 then 'subclass'
          else        'range'
        end
      level_opt = { class: "lcc-#{level_type}" }

      # Get options and determine the indentation depth based on the requested
      # LCC outline level.
      opt ||= {}
      tab             = opt[:tab]           || (popup ? 1 : 1.5) # em units
      prefix          = opt[:prefix]        || '&rdsh;&nbsp;'
      indent          = opt[:indent]        || (level - 1)
      indent_offset   = opt[:indent_offset] || (popup ? -0.6 : -0.5) # em units
      connector       = opt[:connector]     || 'to'
      allow_blank     = opt[:allow_blank]
      allow_no_name   = opt[:allow_no_name]
      allow_no_lcco   = opt[:allow_no_lcco]
      effective_level = opt[:effective_depth]

      lcc_name_opt = ({ effective_depth: effective_level } if effective_level)

      # Generate the entries for the first and last LCC classification.
      # If a previous invocation of this method has already determined that the
      # first or last call number should be ignored, remove that value now.
      level_present = false
      case opt[:only]
        when :first then last_path  = nil
        when :last  then first_path = nil
      end
      first, last =
        [first_path, last_path].map do |cn|
          node = cn && cn[level]
          next unless node
          level_present = true
          next if node.artificial && !allow_no_lcco
          next if (node.name == cn[level-1].name)

          # Create the name element.
          name = lcc_name(node, lcc_name_opt)
          next unless name || allow_no_name

          # Create the range element.
          range = lcc_range(node, class: level_type)
          next unless range || name

          # Finish the entry.
          [range, name].compact.join(SPACE).html_safe
        end
      if first == last
        # The values are the same for the first and last displayed items.
        last = nil
      elsif first && last
        # The differing values will be shown for this line only.  Lower levels
        # will only be shown for the first call number.
        opt[:only] = :first
      elsif first && !last
        # Presumably, the call number for the last displayed item has no more
        # levels so only levels for the first call number should be displayed
        # for the rest of the current-range-area.
        opt[:only] = :first
      elsif !first && last
        # Presumably, the call number for the first displayed item has no more
        # levels so only levels for the last call number should be displayed
        # for the rest of the current-range-area.
        opt[:only] = :last
      end

      # Combine the entries (if they are different) and prepend the indentation
      # and prefix characters.
      result = []
      if first || last
        indent = indent.to_f
        unless indent.zero? || tab.blank?
          units = tab.to_s.delete('.0-9')
          raise 'units must be "em"' unless units.blank? || (units == 'em')
          indent *= tab.to_f
          indent += indent_offset
          level_opt[:style] = "margin-left: calc(+#{indent}em);"
        end
        result << prefix unless indent.zero?
        result << content_tag(:div, first, class: 'start') if first
        if first && last
          unless connector.include?('<div')
            connector = connector.html_safe
            connector = content_tag(:div, connector, class: 'connector')
            opt[:connector] = connector
          end
          result << connector
        end
        result << content_tag(:div, last, class: 'end') if last

      elsif allow_blank
        result << '&nbsp;'

      end

      if result.present?
        content_tag(:div, result.join.html_safe, level_opt)
      elsif level_present
        :skip
      end
    end

    # =========================================================================
    # :section: Display - Item ranges
    # =========================================================================

    protected

    # lcc_depth_name
    #
    # @param [Fixnum] depth
    #
    # @return [String]
    #
    def lcc_depth_name(depth)
      case depth
        when 0 then 'Root'
        when 1 then 'Classification'
        when 2 then 'Sub-classification'
        when 3 then 'Topic'
        else        'Sub-topic'
      end
    end

    # Create an element for the textual name of an LCC node for use in trees.
    #
    # @param [String, LccBase] node
    # @param [Hash]            opt
    #
    # @option opt [Fixnum] :effective_depth   If present, used in place of
    #                                           `node.depth`.
    #
    # @return [ActiveSupport::SafeBuffer]
    # @return [nil]
    #
    def lcc_name(node, opt = nil)

      # Extract the name unless the argument is a string.
      if node.is_a?(String)
        name = node
        node = nil
      else
        name = node.effective_name
      end
      return if name.blank?

      # Process options.
      html_opt = html_options(opt)
      note  = node && node.note.presence
      label = (node && node.ascii_name.presence) || name
      depth = html_opt.delete(:effective_depth) || (node && node.depth) || 3
      level = lcc_depth_name(depth)

      # Set tooltip and aria-label.
      tip = html_opt[:title]
      if tip.blank?
        tip = "#{level}: #{label}"
        tip << "\n(#{note})" if note
        html_opt[:title] = tip = ERB::Util.h(tip)
      end
      aria_label = html_opt[ARIA_LABEL]
      html_opt[ARIA_LABEL] = aria_label ? "#{level}: #{aria_label}" : tip

      # Append an indicator if there is a note.
      name = ERB::Util.h(name).gsub(/\s+--\s+/, EM_DASH).html_safe
      name << content_tag(:span, '*', class: 'note') if note

      content_tag(:span, name, html_opt)
    end

    # Create an element for the call number range (identifier) of an LCC node
    # for use in trees.
    #
    # @param [String, LccBase] node
    # @param [Hash]            opt
    #
    # @return [ActiveSupport::SafeBuffer]
    # @return [nil]
    #
    def lcc_range(node, opt = nil)
      range = (node.is_a?(LccBase) ? node.range : node.to_s).tr('()', '')
      return if range.blank?
      default_opt = {
        title: TOOLTIP[:range],
        role: 'button'
      }
      html_opt = html_options(opt, default_opt)
      html_opt[:class] ||= node.is_a?(LccBase) ? node.type : 'range'
      label = html_opt.delete(:label)
      shelf_browse_index_link(range, label, html_opt)
    end

    # Generate a link to "/shelf_browse" with the given options.
    #
    # @param [String, LccNum] call_number
    # @param [String]         label
    # @param [Hash]           url_opt
    #
    # @return [ActiveSupport::SafeBuffer]
    #
    def shelf_browse_index_link(call_number, label = nil, url_opt = nil)
      case call_number
        when LccNum
          label ||= call_number.display
        when String
          label ||= call_number.dup
          call_number = call_number.to_s.split('-').first
          call_number = LccNum[call_number]
      end
      return ''.html_safe if call_number.blank?
      label.tr!('()', '')
      label.sub!(/-/, '&hairsp;-&hairsp;')
      opt = get_url_opt(url_opt)
      opt[:start] = call_number.to_shelfkey
      opt[:title] = "Browse the virtual shelf starting with #{call_number}"
      page_link(label.html_safe, opt)
    end

    # =========================================================================
    # :section: Display - Item details
    # =========================================================================

    public

    # full_record_buttons
    #
    # @param [UVA::IndexDoc] doc
    #
    # @return [ActiveSupport::SafeBuffer]
    # @return [nil]
    #
    def full_record_buttons(doc)
      return unless doc.is_a?(IndexDoc)
      FULL_RECORD_BUTTONS.map { |_action, options|
        link_to_document(doc, options.merge(link_class: 'full-record-button'))
      }.join.html_safe
    end

    # Generate a set of radio buttons.
    #
    # @param [String] option_name
    # @param [String] option_label
    # @param [Hash{Symbol=>Array<String>}] radio_selections
    # @param [Hash]   opt
    #
    # @return [ActiveSupport::SafeBuffer]
    #
    def radio_buttons(option_name, option_label, radio_selections, opt = nil)

      option_name      ||= 'radio-options'
      radio_selections ||= { true: 'Yes', false: 'No' }

      default_opt = { class: option_name, action: '', role: 'radiogroup' }
      html_opt    = html_options(opt, default_opt)

      option_label &&= content_tag(:label, option_label, class: 'radio-label')
      option_label ||= ''.html_safe

      option_buttons =
        radio_selections.map { |value, description|
          label, tooltip = description
          button = radio_button_tag(option_name, value)
          button << ERB::Util.h(label) if label.present?
          div_opt = { class: 'radio-option', role: 'radio' }
          div_opt[:title] = ERB::Util.h(tooltip) if tooltip.present?
          content_tag(:div, button, div_opt)
        }.join.html_safe

      content_tag(:form, html_opt) do
        option_label + option_buttons
      end
    end

    # Generate extra metadata for debugging purposes.
    #
    # @param [UVA::IndexDoc] doc
    # @param [Boolean]       in_popup
    #
    # @return [ActiveSupport::SafeBuffer]
    #
    # === Usage Notes
    # If `params[:extra_metadata]` is true, the result will be generated
    # unconditionally without regard to the configuration settings.
    #
    def extra_metadata(doc, in_popup = nil)
      return unless doc.is_a?(UVA::IndexDoc)
      unless params_value(:extra_metadata, true)
        in_popup ||= popup
        show_extra = in_popup ? :extra_metadata_popup : :extra_metadata_page
        return unless UVA::ShelfBrowse.option[show_extra]
      end
      content_tag(:dl) do
        UVA::View::FieldSet.new(
          '[MARC]'       => extra_metadata_field(doc.marc_call_numbers),
          '[Solr]'       => extra_metadata_field(doc.call_numbers),
          '[shelfkey]'   => extra_metadata_field(doc[:shelfkey]),
          '[reverse]'    => extra_metadata_field(doc[:reverse_shelfkey]),
          '[Virgo item]' => link_to_document(doc),
        ).render(:show, doc)
      end
    end

    # =========================================================================
    # :section: Display - Item details
    # =========================================================================

    protected

    # Format field value(s) for extra metadata.
    #
    # @param [String, Array<String>] field
    # @param [String] separator
    #
    # @return [ActiveSupport::SafeBuffer]
    #
    def extra_metadata_field(field, separator = nil)
      if field.blank?
        '-'
      elsif field.is_a?(Array)
        separator ||= '<strong>&thinsp;&boxV;&thinsp;</strong>'
        field.map { |value|
          ERB::Util.h(value) if value.present?
        }.compact.join(separator).html_safe
      else
        ERB::Util.h(field)
      end
    end

    # =========================================================================
    # :section: Display - Help
    # =========================================================================

    public

    # The keys for the defined help topics
    #
    # @param [Symbol] topic_combo     Optional
    #
    # @return [Array<Symbol>]
    #
    # @see self#HELP_TOPIC
    #
    def help_topics(topic_combo = nil)
      topic = in_sc_lens ? SC_HELP_TOPIC : HELP_TOPIC
      topic = topic.select { |_, combo| combo == topic_combo } if topic_combo
      topic.keys
    end

    # The CSS classes for the given help topic.
    #
    # @param [Symbol] topic
    #
    # @return [String]
    # @return [nil]                   If *topic* is not a help topic key.
    #
    # @see self#HELP_TOPIC_CSS
    #
    def help_topic_css(topic)
      (in_sc_lens ? SC_HELP_TOPIC_CSS : HELP_TOPIC_CSS)[topic]
    end

    # Names of the ERB templates under app/views/shelf_browse/ that are
    # associated with the defined help topics.
    #
    # @param [Symbol] topic_combo     Optional
    #
    # @return [Array<String>]
    #
    # @see self#help_topics
    #
    def help_templates(topic_combo = nil)
      help_topics(topic_combo).map do |topic|
        topic.to_s.sub(%r{^help_}, 'help/').sub(%r{/lcc_}, '/lcc/')
      end
    end

    # Options to be passed to a help template to provide :locals
    #
    # @return [Hash{Symbol=>Hash}]
    #
    def help_template_opts
      {}.tap do |result|

        # Inline pagination button images.
        page_icon_opts = { class: 'inline-button', size: '13x13' }
        result[:sb_button] = {
          fwd:    page_icon(+1,  page_icon_opts),
          rev:    page_icon(-1,  page_icon_opts),
          fwd10x: page_icon(+10, page_icon_opts),
          rev10x: page_icon(-10, page_icon_opts)
        }

        # Keycaps.
        result[:sb_key] = {
          right_arrow:        keycap('&rarr;'),
          left_arrow:         keycap('&larr;'),
          home_key:           keycap('Home'),
          end_key:            keycap('End'),
          shift_right_arrow:  keycap('Shift', '&rarr;'),
          shift_left_arrow:   keycap('Shift', '&larr;')
        }

        # Links.
        result[:sb_link] = {
          lcc: [
            'Library of Congress Classification',
            'https://www.loc.gov/catdir/cpso/lcc.html'
          ],
          lcc_pdf:[
            'Library of Congress Classification PDF Files',
            'https://www.loc.gov/aba/publications/FreeLCC/freelcc.html'
          ],
          feedback: [
            'feedback',
            feedback_path
          ],
        }.map { |key, entry|
          [key, out_link(*entry)]
        }.to_h
      end
    end

    # Produce a sequence of keyboard keys for display.
    #
    # @param [Array<String>] args
    #
    # @return [ActiveSupport::SafeBuffer]
    #
    def keycap(*args)
      args.map { |key|
        next if key.blank?
        chars = key.gsub(/&[^;]+;/, '_').length
        size  = (chars > 1) ? 'smaller' : 'larger'
        style = "font-size: #{size};"
        content_tag(:span, key.html_safe, class: 'keycap', style: style)
      }.compact.join('&thinsp;+&thinsp;').html_safe
    end

    # Each status marker label and its text.
    #
    # @param [Hash] opt
    #
    # @option opt [String,Symbol] :mode    One of :p, :table, :dl (default).
    # @option opt [String,Symbol] :marker_tag
    # @option opt [String,Symbol] :description_tag
    # @option opt [Boolean]       :site_only
    # @option opt [Boolean]       :status_only
    #
    # @return [ActiveSupport::SafeBuffer]
    # @return [Hash]                       If :mode explicitly set to *nil*.
    #
    def status_marker_list(opt = nil)

      # Extract formatting options.
      opt = opt ? opt.dup : {}
      hash_only   = opt.key?(:mode) && opt[:mode].nil?
      outer_tag   = opt.delete(:mode) || :dl
      marker_tag  = opt.delete(:marker_tag)
      tooltip_tag = opt.delete(:description_tag)
      site_only   = opt.delete(:site_only)
      status_only = opt.delete(:status_only)
      case outer_tag
        when :p
          marker_tag  ||= :p
          tooltip_tag ||= :p
        when :dl
          marker_tag  ||= :dt
          tooltip_tag ||= :dd
        when :table
          marker_tag  ||= :th
          tooltip_tag ||= :td
      end
      marker_class = 'item-status-marker'

      # Generate a hash of markers and labels and return directly if there are
      # no options.
      site_hash   = {}
      status_hash = {}
      STATUS_MARKER.each_pair do |_key, values|
        css_class, marker, tip = values
        tip ||= css_class.to_s.capitalize
        next if marker.blank? || tip.start_with?('ERROR')
        tip = tip.sub(/\n.*/, '')
        if css_class == 'site'
          site_hash[marker] = tip unless status_only
        else
          status_hash[marker] = tip unless site_only
        end
      end
      site_hash.sort_by { |key, _| key.to_s }
      status_hash.sort_by { |key, _| key.to_s }

      # No formatting explicitly requested.
      return site_hash.merge(status_hash) if hash_only

      # Produce HTML output that can be used within a template.
      sections = [
        [site_hash,   "#{marker_class} site"],
        [status_hash, marker_class]
      ]
      content_tag(outer_tag) do
        sections.flat_map { |section|
          hash, css_class = section
          hash.map do |marker, tooltip|
            marker  = content_tag(:div, marker, class: css_class)
            marker  = content_tag(marker_tag, marker)
            tooltip = content_tag(tooltip_tag, tooltip.html_safe)
            content_tag(:div, class: 'entry') do
              marker + tooltip
            end
          end
        }.join.html_safe
      end

    end

    # =========================================================================
    # :section: Display - Other
    # =========================================================================

    public

    # HTML for a button to close a dropdown overlay.
    #
    # @param [Hash] opt
    #
    # @return [ActiveSupport::SafeBuffer]
    #
    # @see self#close_button
    #
    def dropdown_close_button(opt = nil)
      close_button(html_options(opt, title: TOOLTIP[:close_dropdown]))
    end

    # =========================================================================
    # :section: Display - Other
    # =========================================================================

    protected

    # HTML for a button to close the popup.
    #
    # @param [Hash] opt               HTML options passed to the element plus
    #                                   the following:
    #
    # @option opt [String, Array<String>] :class
    #                                 One or more CSS classes to be included
    #                                   with the definition.
    #
    # @return [ActiveSupport::SafeBuffer]
    #
    def close_button(opt = nil)
      default_opt = {
        class:    'close-button',
        title:    'Click to close.',
        role:     'button',
        tabindex: 0
      }
      html_opt = html_options(opt, default_opt)
      label = html_opt.delete(:label)
      html_opt[ARIA_LABEL] ||= html_opt[:title] || strip_html(label)
      content_tag(:div, label, html_opt)
    end

    # Create an element which can be used by JavaScript as a linkage for
    # replacing the contents of the shelf browse display.
    #
    # @param [String] label
    # @param [Hash]   opt
    #
    # @return [ActiveSupport::SafeBuffer]
    #
    def page_link(label, opt)
      default_opt = {
        role:     'button',
        tabindex: 0
      }
      html_opt = html_options(opt, default_opt)
      html_opt[:'data-path']     ||= shelf_browse_link_path(html_opt)
      html_opt[:'data-shelfkey'] ||= html_opt[:start] if html_opt.key?(:start)
      html_opt = remove_shelf_browse_params(html_opt)
      content_tag(:div, label, html_opt)
    end

    # Generate a URL from the provided options that is appropriate for the
    # context (that is, show-page links from show-pages, index links from
    # index pages).
    #
    # @param [Hash] url_opt
    #
    # @return [String]
    #
    def shelf_browse_link_path(url_opt = nil)
      path    = base_path.dup
      url_opt = get_url_opt(url_opt)
      if url_opt[:start]
        url_opt[:origin] ||= origin_id
      elsif (id = url_opt.delete(:origin))
        path << "/#{id}"
      elsif start
        url_opt[:start] = start
      elsif origin_id
        path << "/#{origin_id}"
      end
      url_opt.delete_if { |k, v|
        v.blank? ||
        (k = k.to_s).start_with?('aria-', 'data-') ||
        %w(class role style tabindex title).include?(k)
      }
      path << '?' << url_opt.to_query if url_opt.present?
      path
    end

    # Generate the current URL options to be used on shelf browse links.
    #
    # @param [Hash] url_opt           May override defaults here.
    #
    # @return [Hash]                  Caller receives ownership of this object.
    #
    def get_url_opt(url_opt = nil)
      default_opt = {}
      default_opt[:start]  = start     if start
      default_opt[:origin] = origin_id if origin_id
      default_opt[:popup]  = true      if popup
      if url_opt.blank?
        default_opt
      else
        url_opt.reject { |k, _|
          k.to_s.start_with?('data-')
        }.reverse_merge(default_opt)
      end
    end

    # Construct a hash for use with an HTML tag.
    #
    # Similar to `opt.reverse_merge(default_opt)` except that `opt[:class]` is
    # appended to `default_opt[:class]`.
    #
    # @param [Hash] opt
    # @param [Hash] base_opt
    #
    # @return [Hash]
    #
    def html_options(opt, base_opt = nil)
      opt      = (opt.reject      { |_, v| v.blank? } if opt.present?)
      base_opt = (base_opt.reject { |_, v| v.blank? } if base_opt.present?)
      if opt && base_opt
        opt_classes  = Array(opt.delete(:class)).reject(&:blank?)
        base_classes = Array(base_opt[:class]).reject(&:blank?)
        unless base_classes.blank? && opt_classes.blank?
          base_opt[:class] = (base_classes + opt_classes).uniq.join(' ')
        end
        base_opt.merge!(opt)
      elsif opt || base_opt
        (opt || base_opt).dup
      else
        {}
      end
    end

    # =========================================================================
    # :section:
    # =========================================================================

    public

    # Produce JSON for the whole LCC hierarchy for use by the JavaScript jstree
    # plugin.
    #
    # @return [String]
    #
    def self.generate_jstree
      self.to_jstree(self.get_lcc_hierarchy).to_json
    end

    # This constant is "eager loaded" so that it only needs to be resolved when
    # the system initializes.
    JSTREE_HIERARCHY = self.generate_jstree.freeze

  end

end
