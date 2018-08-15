// app/assets/javascripts/feature/ead.js

//= require shared/definitions

$(document).ready(function() {

    /**
     * @constant
     * @type {string}
     */
    var SECTIONS = [
        '.ead-descgrp',
        '.ead-bioghist',
        '.ead-scopecontent',
        '.ead-arrangement'
    ].join(', ');

    /** @type {jQuery} */
    var $sections = $(SECTIONS);

    /** @type {jQuery} */
    var $section_heads = $sections.children('.ead-head');

    // Only perform these actions on the appropriate pages.
    if (isMissing($section_heads)) { return; }

    /**
     * Class of the dynamically-generated button.
     *
     * @constant
     * @type {string}
     */
    var TOGGLE = 'toggle-button';

    /**
     * Class on a section indicated that it is not expanded.
     *
     * @constant
     * @type {string}
     */
    var COLLAPSED_MARKER = 'collapsed-to-header';

    // ========================================================================
    // Variables
    // ========================================================================

    /**
     * Create toggle buttons for each section head.
     *
     * @type {jQuery}
     */
    var $section_toggles =
        $('<div>')
            .addClass(TOGGLE)
            .attr('tabindex', 0)
            .appendTo($section_heads);

    // ========================================================================
    // Event handlers
    // ========================================================================

    $section_toggles.click(function() {
        toggleSection(this);
        return false;
    }).each(handleKeypressAsClick);

    // ========================================================================
    // Actions
    // ========================================================================

    // Initialize sections as collapsed.
    $section_toggles.click();

    // ========================================================================
    // Functions
    // ========================================================================

    /**
     * toggleSection
     *
     * @param {Selector} selector   May be the button, section head or section.
     */
    function toggleSection(selector) {
        var $button;
        if (selector === TOGGLE) {
            $button = $(selector);
        } else if (selector.className === TOGGLE) {
            $button = $(selector);
        } else if (selector.hasClass(TOGGLE)) {
            $button = selector;
        } else {
            $button = selector.children('.' + TOGGLE);
        }
        var $section = $button.parent().parent();
        if ($section.hasClass(COLLAPSED_MARKER)) {
            $button.attr('aria-label', 'Close this section');
            $section.removeClass(COLLAPSED_MARKER).attr('aria-expanded', true);
        } else {
            $button.attr('aria-label', 'Open this section');
            $section.addClass(COLLAPSED_MARKER).attr('aria-expanded', false);
        }
    }

});
