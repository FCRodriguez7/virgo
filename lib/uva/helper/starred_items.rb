# lib/uva/helper/starred_items.rb

require 'uva'

module UVA::Helper

  # UVA::Helper::StarredItems
  #
  module StarredItems

    include UVA
    include UVA::StarredItems
    include UVA::Helper::Articles

    # =========================================================================
    # :section:
    # =========================================================================

    public

    # Path for "unstarring" an item by removing it from the folder.
    #
    # @note Must be used with HTML option { method: :delete }.
    #
    # @param [UVA::IndexDoc] doc
    #
    # @return [String]
    #
    def unstar_path(doc)
      key = (doc.doc_type == :article) ? :article_id : :id
      destroy_folders_path(key => doc.doc_id)
    end

    # =========================================================================
    # :section:
    # =========================================================================

    public

    # star_counter
    #
    # @param [Hash] opt
    #
    # @option opt [Boolean] :plain    Default: *false*.
    # @option opt [Boolean] :no_hide  Default: *false*.
    #
    # @return [ActiveSupport::SafeBuffer]
    #
    def star_counter(opt = nil)
      html_opt = { class: 'star-counter' }
      html_opt.merge!(opt) if opt.present?
      plain   = html_opt.delete(:plain)
      no_hide = html_opt.delete(:no_hide)
      html_opt[:class] += ' no-hide' if no_hide
      count = starred_item_count.to_s
      count = "(#{count})" unless plain
      content_tag(:span, count, html_opt)
    end

    # menu_items
    #
    # @param [Hash]   menu_hash
    # @param [String] suffix
    #
    # @return [ActiveSupport::SafeBuffer]
    #
    def menu_items(menu_hash, suffix = 'starred')
      menu_hash.map { |action, value|
        next unless value.present?
        action = action.to_s.tr('_', '-')
        css_class = "#{action}-#{suffix}"
        label, path, opts = value
        aside = nil
        link_method = :link_to
        case opts
          when Hash
            aside = opts[:aside]
            link_method = :out_link if aside || (opts[:target] == '_blank')
          when String, Symbol
            aside = (opts.to_s == 'aside')
            link_method = :out_link if aside || true_value?(opts)
          when true
            link_method = :out_link
        end
        opts = opts.is_a?(Hash) ? opts.dup : {}
        opts[:aside] = aside if aside
        opts[:class] ||= css_class
        content_tag(:li, class: css_class, role: 'menuitem') do
          send(link_method, label, path, opts)
        end
      }.compact.join(NEWLINE).html_safe
    end

  end

end
