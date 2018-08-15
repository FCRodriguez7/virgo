// app/assets/javascripts/feature/facets-popup.js

//= require shared/colorbox

$(document).ready(function() {

    /** @type {jQuery} */
    var $facet_links = $('a.facet-list-link');

    // Only perform these actions on the appropriate pages.
    if (isMissing($facet_links)) { return; }

    // ========================================================================
    // Event handlers
    // ========================================================================

    // Re-create Colorbox popups if window dimensions change.
    $(window).resize(function() {
        updateLinks($facet_links);
    });

    // ========================================================================
    // Actions
    // ========================================================================

    // Load facet list in iframe for toggling between sorting modes.
    updateLinks($facet_links);

    // ========================================================================
    // Internal function definitions
    // ========================================================================

    /**
     * Load facet list in iframe for toggling between sorting modes.
     *
     * @param {jQuery} $links
     *
     * NOTE: Does not work properly for small (short) windows.
     *
     * While the Colorbox itself will fit into the display, the height of the
     * two-column item listing cannot be controlled from here because it is in
     * an iframe.  As a stop-gap, Colorbox scrolling is turned on so that the
     * user can at least access the whole two-column listing (which means there
     * are two scroll bars when the listing itself scrolls).
     *
     * TODO: Refactor to avoid using an iframe.
     */
    function updateLinks($links) {
        var _func_ = arguments.callee.name;
        var small  = shortScreen();
        var narrow = narrowScreen();
        var height = small  ? '90%' : FRAME_POPUP_HEIGHT;
        var width  = narrow ? '90%' : FRAME_POPUP_WIDTH;
        var cbox_settings =
            AppColorbox.settings(_func_, {
                iframe:      true,
                innerHeight: height,
                innerWidth:  width,
                scrolling:   (small || narrow),
                rel:         'nofollow'
            });
        $links.colorbox(cbox_settings);
    }

});
