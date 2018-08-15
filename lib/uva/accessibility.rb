# lib/uva/accessibility.rb

require 'uva'

module UVA

  # UVA::Accessibility
  #
  module Accessibility

    ARIA_CHECKED  = 'aria-checked'.to_sym
    ARIA_CONTROLS = 'aria-controls'.to_sym
    ARIA_EXPANDED = 'aria-expanded'.to_sym
    ARIA_HASPOPUP = 'aria-haspopup'.to_sym
    ARIA_HIDDEN   = 'aria-hidden'.to_sym
    ARIA_LABEL    = 'aria-label'.to_sym
    ARIA_MODAL    = 'aria-modal'.to_sym
    ARIA_ROLE     = :role

    ARIA_SWITCH = {
      role:           'switch',
      tabindex:       0,
      ARIA_CHECKED => false
    }.deep_freeze

    ARIA_EXPAND_BUTTON = {
      role:            'button',
      tabindex:        0,
      ARIA_EXPANDED => false
    }.deep_freeze

    ARIA_DIALOG_BUTTON =
      ARIA_EXPAND_BUTTON.merge(ARIA_HASPOPUP => 'dialog').deep_freeze

    ARIA_MODAL_DIALOG = {
      role:         'dialog',
      style:        'display: none;',
      ARIA_MODAL => true
    }.deep_freeze

    # =========================================================================
    # :section:
    # =========================================================================

    public

    # Options hash settings for a stateful (on/off) switch element.
    #
    # @param [Hash, nil] opt
    #
    # @option opt [Boolean] :on       Use *true* to indicate that the element
    #                                   is initially in the "on" state.
    #
    # @return [Hash]
    #
    def switch_opts(opt = nil)
      opt = opt.is_a?(Hash) ? opt.dup : {}
      opt[ARIA_CHECKED] = true if opt.delete(:on)
      ARIA_SWITCH.merge(opt)
    end

    # Options hash settings for the toggle which controls the expansion of an
    # area.
    #
    # @param [Hash, nil] opt
    #
    # @option opt [Boolean] :open     Use *true* to indicate that the element
    #                                   will have been initialized expanded.
    #
    # @return [Hash]
    #
    def expand_button_opts(opt = nil)
      opt = opt.is_a?(Hash) ? opt.dup : {}
      opt[ARIA_EXPANDED] = true if opt.delete(:open)
      ARIA_EXPAND_BUTTON.merge(opt)
    end

    # Options hash settings for an element is the toggle for a modal dialog.
    #
    # @param [Hash, nil] opt
    #
    # @option opt [Boolean] :open     Use *true* to indicate that the dialog
    #                                   will have been initialized as visible.
    #
    # @return [Hash]
    #
    def dialog_button_opts(opt = nil)
      opt = { ARIA_HASPOPUP => 'dialog' }.merge(opt || {})
      expand_button_opts(opt)
    end

    # Options hash settings for an element which acts as a modal dialog.
    #
    # @param [Hash, nil] opt
    #
    # @option opt [Boolean] :open     If *true*, the dialog is initialized as
    #                                   visible.
    #
    # @return [Hash]
    #
    def modal_dialog_opts(opt = nil)
      opt = opt.is_a?(Hash) ? opt.dup : {}
      opt[:style] ||= '' if opt.delete(:open)
      ARIA_MODAL_DIALOG.merge(opt)
    end

  end

end

