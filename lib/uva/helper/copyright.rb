# lib/uva/helper/copyright.rb

require 'uva'

module UVA::Helper

  # UVA::Helper::Copyright
  #
  module Copyright

    include UVA
    include UVA::Accessibility

    # =========================================================================
    # :section:
    # =========================================================================

    public

    # Label for the copyright/permission metadata field.
    #
    # @see self#copyright_label
    # @see self#copyright_field
    #
    FIELD_LABEL = 'Copyright & Permissions'.freeze

    # Text displayed in the descriptive text the copyright field.
    #
    # @see self#copyright_info
    #
    COPYRIGHT_INFO_TEXT = %q(
      Rights statements and licenses provide information about copyright and
      reuse associated with individual items in the collection.
      <br/><br/>
      Additional information about rights, reuse of Library materials,
      suggested citation forms, and related issues can be found on the "%s"
      page.
    ).squish.html_safe.freeze

    CC_LICENSE = {
      'publicdomain' => 'Public Domain',
      'cc-zero'      => 'Public Domain Dedication'
    }.deep_freeze

    CC_CLAUSES = {
      'by' => 'Attribution',
      'sa' => 'Share-alike',
      'nc' => 'Non-commercial',
      'nd' => 'No Derivative Works'
    }.deep_freeze

    RIGHTS_STATEMENTS = {
      # rubocop:disable Metrics/LineLength
      'InC'       => 'In Copyright',
      'InC-OW-EU' => 'In Copyright - EU Orphan Work',
      'InC-EDU'   => 'In Copyright - Education Use Permitted',
      'InC-NC'    => 'In Copyright - Non-Commercial Use Permitted',
      'InC-RUU'   => 'In Copyright - Rights-Holder(s) Unlocatable or Unidentifiable',
      'NoC-CR'    => 'No Copyright - Contractual Restrictions',
      'NoC-NC'    => 'No Copyright - Non-Commercial Use Only',
      'NoC-OKLR'  => 'No Copyright - Other Known Legal Restrictions',
      'NoC-US'    => 'No Copyright - United States',
      'CNE'       => 'Copyright Not Evaluated',
      'UND'       => 'Copyright Undetermined',
      'NKC'       => 'No Known Copyright'
      # rubocop:enable Metrics/LineLength
    }.deep_freeze

    CNE_URL = 'http://rightsstatements.org/vocab/CNE/1.0/'.freeze

    # =========================================================================
    # :section:
    # =========================================================================

    public

    # copyright_field
    #
    # @param [Hash] opt               HTML options.
    #
    # @return [ActiveSupport::SafeBuffer]
    #
    def copyright_field(opt = nil)
      html_opt = { class: 'copyright-field' }
      html_opt.merge!(opt) if opt.present?
      label = ERB::Util.h(copyright_label)
      label << copyright_info unless print_view?
      content_tag(:div, label, html_opt)
    end

    # copyright_label
    #
    # @return [String]
    #
    def copyright_label
      FIELD_LABEL
    end

    # copyright_info
    #
    # @param [Hash] opt               HTML options.
    #
    # @return [ActiveSupport::SafeBuffer]
    #
    # @see self#COPYRIGHT_INFO_TEXT
    # @see app/assets/javascripts/feature/copyright
    #
    def copyright_info(opt = nil)
      html_opt =
        dialog_button_opts(
          class: 'cc-info-link',
          title: 'Click for details.',
        )
      html_opt.merge!(opt) if opt.present?
      html_opt[ARIA_LABEL] ||= html_opt[:title]

      icon = help_symbol('', class: 'cc-info-icon')

      close =
        content_tag(:div, class: 'button-tray', role: 'navigation') do
          close_opt = {
            class:        'cc-info-close',
            ARIA_LABEL => 'Close this overlay',
            role:         'button',
            tabindex:     0
          }
          content_tag(:div, '', close_opt)
        end

      text = (COPYRIGHT_INFO_TEXT % terms_of_use_link).html_safe

      container_opt = modal_dialog_opts(class: 'cc-info-container')

      content_tag(:div, html_opt) do
        icon + content_tag(:div, (close + text), container_opt)
      end
    end

    # terms_of_use_path
    #
    # @return [String]
    #
    def terms_of_use_path
      "#{root_path}terms.html"
    end

    # terms_of_use_link
    #
    # @return [ActiveSupport::SafeBuffer]
    #
    def terms_of_use_link
      out_link('Permission to Use Library Materials', terms_of_use_path)
    end

    # Produces a link (with icon) to a copyright or rights statement that
    # reflects the known copyright or rights statement for the specified
    # document.
    #
    # @param [UVA::IndexDoc] doc
    # @param [Hash]          opt
    #
    # @option opts [Fixnum] :height
    #
    # @return [ActiveSupport::SafeBuffer]
    # @return [nil]
    #
    def copyright_and_permissions(doc, opt = nil)
      uri = permission_uri(doc)
      return unless uri.present?
      html_opt = dialog_button_opts(class: 'copyright-popup', height: 30)
      html_opt.merge!(opt) if opt.present?
      height = html_opt.delete(:height)
      if (code = cc_type(uri))
        html_opt[:rel] = 'license'
        name = cc_license_name(code)
        path = cc_icon(code)
      else
        code = rs_type(uri) || 'CNE'
        name = rs_rights_name(code)
        path = rs_icon(code)
      end
      label = ERB::Util.h(name)
      alt   = ERB::Util.h("Logo for #{name}")
      image = image_tag(path, alt: alt, height: height)
      external_link((image + label), uri, html_opt)
    end

    # permission_uri
    #
    # @param [UVA::IndexDoc] doc
    #
    # @return [String]
    # @return [nil]
    #
    def permission_uri(doc)
      return unless doc.is_a?(UVA::IndexDoc)
      doc.get_copyright_and_permissions.first || (CNE_URL if doc.online?)
    end

    # cc_type
    #
    # @param [String] uri
    #
    # @return [String]
    # @return [nil]
    #
    def cc_type(uri)
      uri = uri.to_s.strip
      return unless uri.include?('//creativecommons.org/')
      case uri
        when %r{/licenses/([^/]+)/.*}i    then $1
        when %r{/publicdomain/mark/1.0/}i then 'publicdomain'
        when %r{/publicdomain/zero/1.0/}i then 'cc-zero'
      end
    end

    # Path for the image asset associated with the given Creative Commons code.
    #
    # @param [String] code
    #
    # @return [String]
    #
    def cc_icon(code)
      type = code.to_s.downcase
      asset_path("rights-status/cc/#{type}.png")
    end

    # cc_license_name
    #
    # @param [String] code
    #
    # @return [String]
    #
    def cc_license_name(code)
      code = code.to_s.downcase
      case code
        when 'publicdomain' then 'Public Domain'
        when 'cc-zero'      then 'Public Domain Dedication'
        else
          clauses = CC_CLAUSES.map { |k, v| v if code.include?(k) }.compact
          license = ''
          license << clauses.join(', ') << ' ' if clauses.present?
          license << 'License'
          "Creative Commons #{license}"
      end
    end

    # rs_type
    #
    # @param [String] uri
    #
    # @return [String]
    # @return [nil]
    #
    def rs_type(uri)
      uri.to_s.strip.match(%r{//rightsstatements.org/vocab/([^/]+)/.*}i) && $1
    end

    # Path for the image asset associated with the given RightsStatement.org
    # code.
    #
    # @param [String] code
    #
    # @return [String]
    #
    def rs_icon(code)
      type = code.to_s.sub(/-.*/, '')
      type = 'Other' unless %w(InC NoC).include?(type)
      asset_path("rights-status/rightsstatements/#{type}.Icon-Only.dark.png")
    end

    # rs_rights_name
    #
    # @param [String] code
    #
    # @return [String]
    #
    def rs_rights_name(code)
      RIGHTS_STATEMENTS[code] || RIGHTS_STATEMENTS['CNE']
    end

  end

end
