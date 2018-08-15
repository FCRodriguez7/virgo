// app/assets/javascripts/feature/video-popup.js

//= require jquery.hoverIntent.minified
//= require shared/definitions

$(document).ready(function() {

    /** @type {jQuery} */
    var $see_more_info = $('.see-more-info');

    // Only perform these actions on the appropriate pages.
    if (isMissing($see_more_info)) { return; }

    // ========================================================================
    // Constants
    // ========================================================================

    /**
     * @constant
     * @type {number}
     */
    var TIMEOUT = 750 * MILLISECONDS;

    /**
     * @constant
     * @type {number}
     */
    var INTERVAL = 375 * MILLISECONDS;

    // ========================================================================
    // Variables
    // ========================================================================

    /**
     * Timer to keep info bubble open after mouseout.
     *
     * @type {number}
     */
    var info_timer;

    /** @type {boolean} */
    var info_hide = true;

    // ========================================================================
    // Event handlers
    // ========================================================================

    // Make bubble visible after the mouse has hovered long enough to be sure
    // that the user's intent is to see the information bubble (as opposed to
    // the mouse simply passing over the element to point somewhere else).
    $see_more_info.hoverIntent({
        timeout:     TIMEOUT,
        interval:    INTERVAL,
        sensitivity: 6,
        over:        showVideoInfo,
        out:         hideVideoInfo
    });

    // Show the bubble when tabbing to the title.
    $see_more_info.children('a').focus(showVideoInfo);

    // ========================================================================
    // Actions
    // ========================================================================

    // Keep bubble visible if hovering and hide after a short delay after the
    // mouse leaves.
    $('.more-info').hover(startHover, endHover);

    // ========================================================================
    // Internal function definitions
    // ========================================================================

    /**
     * showVideoInfo
     *
     * @param {Event} event
     */
    function showVideoInfo(event) {

        var $this = $(event.target);
        var focus;
        if ($this.parent().hasClass('see-more-info')) {
            focus = $this.is(':focus');
            $this = $this.parent();
        }
        var $info_bubble = $this.siblings('.more-info');

        // Position the video info bubble, calculating position based on
        // element position and mouse position, plus a little offset.
        var offset = $this.offset();
        var pos    = $this.position();
        $info_bubble.css({
            top:  (event.pageY - offset.top  + pos.top  - 30),
            left: (event.pageX - offset.left + pos.left + 10)
        });

        // Reveal bubble.
        showBubble($info_bubble);

        // Move focus if the bubble was revealed by tabbing to the title.
        // Tabbing out of the last link in the bubble closes it.
        if (focus) {
            var $links = activeLinks($info_bubble);
            $links.first().focus();
            $links.last().blur(function() { hideBubble($info_bubble); });
        }
    }

    /**
     * hideVideoInfo
     *
     * @param {Event} event
     */
    function hideVideoInfo(event) {
        var $this = $(event.target);
        if ($this.hasClass('more-info')) {
            hideBubble($this);
        } else if (info_hide) {
            hideBubble($this.siblings('.more-info'));
        }
    }

    /**
     * On mouse enter.
     *
     * @param {Event} event
     */
    function startHover(event) {
        info_hide = false;
        if (info_timer) {
            clearTimeout(info_timer);
            info_timer = 0;
        }
    }

    /**
     * On mouse leave.
     *
     * @param {Event} event
     */
    function endHover(event) {
        info_hide = true;
        var $info_bubble = $(event.target);
        info_timer = setTimeout(function() {
            hideBubble($info_bubble);
        }, TIMEOUT);
    }

    /**
     * Show the video info bubble; parent z-index must be higher than bubble
     * and other divs.
     *
     * @param {jQuery} $info_bubble
     */
    function showBubble($info_bubble) {
        $info_bubble.parent().css('z-index', 9999);
        $info_bubble.show();
    }

    /**
     * Hide the video info bubble and return parent's z-index to default value.
     *
     * @param {jQuery} $info_bubble
     */
    function hideBubble($info_bubble) {
        $info_bubble.hide();
        $info_bubble.parent().css('z-index', 10);
    }

});
