// app/assets/javascripts/maps/index.js
//
// Definitions to support management of stacks maps.

//= require shared/definitions

$(document).ready(function() {

    /** @type {jQuery} */
    var $libraries = $('.library-map-container');

    // Only perform these actions on the appropriate pages.
    if (isMissing($libraries)) { return; }

    /** @type {jQuery} */
    var $library_toggles = $('.toggle-library-maps');

    /** @type {jQuery} */
    var $toggle_all = $('.expand-contract .btn');

    // ========================================================================
    // Event handlers
    // ========================================================================

    $library_toggles.click(function() {
        var $toggle  = $(this);
        var $library = $toggle.parent().parent();
        if (isOpen($library)) {
            closeLibrary($library, $toggle);
            if (allClosed()) {
                toggleShowAll();
            }
        } else {
            openLibrary($library, $toggle);
            if (allOpen()) {
                toggleHideAll();
            }
        }
    });

    $toggle_all.click(function() {
        if ($toggle_all.hasClass('open')) {
            closeLibrary($libraries);
            toggleShowAll();
        } else {
            openLibrary($libraries);
            toggleHideAll();
        }
    });

    // ========================================================================
    // Functions
    // ========================================================================

    /**
     * Indicate whether the library section is expanded.
     *
     * @param {Selector} library
     *
     * @return {boolean}
     */
    function isOpen(library) {
        return $(library).hasClass('open');
    }

    /**
     * Indicate whether any library sections are expanded.
     *
     * @return {boolean}
     */
    function anyOpen() {
        return isOpen($libraries);
    }

    /**
     * Indicate whether all library sections are expanded.
     *
     * @return {boolean}
     */
    function allOpen() {
        return $libraries.not('.open').length === 0;
    }

    /**
     * Indicate whether all library sections are expanded.
     *
     * @return {boolean}
     */
    function allClosed() {
        return !anyOpen();
    }

    /**
     * Expand library sections.
     *
     * @param {Selector} library
     * @param {Selector} [toggle]
     */
    function openLibrary(library, toggle) {
        var $library = $(library);
        var $toggle  = $(toggle || $library.find('.toggle-library-maps'));
        $toggle.html('Hide').attr('aria-expanded', true);
        $library.addClass('open');
    }

    /**
     * Contract library sections.
     *
     * @param {Selector} library
     * @param {Selector} [toggle]
     */
    function closeLibrary(library, toggle) {
        var $library = $(library);
        var $toggle  = $(toggle || $library.find('.toggle-library-maps'));
        $toggle.html('Show').attr('aria-expanded', false);
        $library.removeClass('open');
    }

    /**
     * Update global toggle to hide all libraries.
     */
    function toggleHideAll() {
        $toggle_all
            .html('Hide All')
            .attr('aria-expanded', true)
            .addClass('open');
    }

    /**
     * Update global toggle to show all libraries.
     */
    function toggleShowAll() {
        $toggle_all
            .html('Show All')
            .attr('aria-expanded', false)
            .removeClass('open');
    }

});
