// app/assets/javascripts/feature/marc-view.js

//= require shared/definitions

$(document).ready(function() {

    /** @type {jQuery} */
    var $toggle = $('.marc-view-switch');

    // Only perform these actions on the appropriate pages.
    if (isMissing($toggle)) { return; }

    // ========================================================================
    // Internal functions
    // ========================================================================

    /**
     * Get the MARC view display container.
     *
     * @param {Selector} [this_toggle]      Default: $('.marc-view-switch')
     *
     * @return {jQuery}}
     */
    function getContainer(this_toggle) {
        var $this = this_toggle ? $(this_toggle) : $toggle;
        return $this.siblings('.marc-view-container');
    }

    // ========================================================================
    // Event handlers
    // ========================================================================

    // Click to open/close MARC view (a.k.a. librarian view).
    $toggle.click(function() {
        var $this = $(this);
        var $view = getContainer($this);
        $view.toggle({
            duration: 0,
            complete: function() {
                $this.attr('aria-expanded', $view.is(':visible'));
            }
        });
        return false;
    });

});
