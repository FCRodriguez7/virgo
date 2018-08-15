// app/assets/javascripts/feature/sticky-sidebar.js

//= require shared/definitions

$(document).ready(function() {

    /** @type {jQuery} */
    var $sidebar = $('.page-sidebar.sticky');

    // Only perform these actions on the appropriate pages.
    if (isMissing($sidebar)) { return; }

    // ========================================================================
    // Actions
    // ========================================================================

    // Attempt to set "position: sticky"; if the position setting really
    // changes then the browser must support that feature.  (The only
    // significant browser that does not is Microsoft Internet Explorer.)

    $sidebar.css('position', 'sticky');

    if ($sidebar.css('position') === 'sticky') {

        // If the position is sticky, "top" needs to be set in order for that
        // to work -- so it's set here if it hadn't already been set.

        var sb_vertical_offset = parseInt($sidebar.css('top')) || 0;
        $sidebar.css('top', sb_vertical_offset);

    } else if (!$sidebar.hasClass('optional')) {

        // If the position is not sticky but a sticky sidebar is required then
        // it is assumed that this event handler is needed to reposition the
        // sidebar based on the current scroll position of the window.

        /** @type {number} */
        var sb_height = $sidebar.height();

        /** @type {number} */
        var sb_top = $sidebar.offset().top;

        $(window).scroll(function() {

            var $window = $(this);

            var max   = $('.page-content').height() - sb_height - sb_top;
            var ideal = $window.scrollTop() - sb_top;
            var min   = 0;

            if ($window.height() > sb_height) {
                $sidebar.stop().animate({
                    marginTop: Math.max(Math.min(ideal, max), min)
                }, 'fast');
            }
        });
    }

});
