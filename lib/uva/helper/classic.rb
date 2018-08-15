# lib/uva/helper/classic.rb

require 'uva'

module UVA::Helper

  # "Virgo Classic" lens settings.
  #
  # @see lib/doc/virgo_classic.md
  #
  module Classic

    include UVA
    include UVA::Classic
    include UVA::Helper::AdvancedSearch

    # =========================================================================
    # :section:
    # =========================================================================

    public

    # Generate an input widget for doing a browse search.
    #
    # @param [String, Symbol] mode      Browse search mode.
    # @param [String]         label
    # @param [Hash]           opt
    #
    # @return [ActiveSupport::SafeBuffer]
    #
    # TODO: This doesn't work...
    #
    def browse_search(mode, label = nil, opt = nil)
      mode  ||= params[:browse_mode]
      mode    = mode.to_s.to_sym unless mode.is_a?(Symbol)
      label ||= "Browse by #{mode}"
      form_id = "browse-by-#{mode}"
      hidden_fields = {}
      hidden_fields.merge!(opt) if opt.present?
      button_label = UVA::Classic.search_button_label
      button_class = UVA::Classic.search_button_class
      form_tag(classic_browse_path, id: form_id, role: 'search') do
        s = ''.html_safe
        s << label_tag(mode, label)
        s << text_field_tag(mode)
        s << search_as_hidden_fields(hidden_fields)
        s << submit_tag(button_label, class: button_class)
      end
    end

  end

end
