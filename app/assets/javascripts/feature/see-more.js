// app/assets/javascripts/feature/see-more.js

//= require shared/definitions

/**
 * Show/hide metadata fields on the item details show page.
 *
 * @type {object}
 *
 * @property {function} updatePage
 * @property {function} setupShowDetails
 * @property {function} hideShowDetails
 * @property {function} defaultRoot
 * @property {function} defaultSelector
 * @property {function} suppress
 * @property {function} enabled
 */
var SeeMore = (function() {

    /**
     * @constant
     * @type {boolean}
     */
    var FEATURE_ENABLED = Rails.SeeMore.ENABLED;

    /**
     * @constant
     * @type {number}
     */
    var INITIAL_FIELDS = Rails.SeeMore.INITIAL_DETAILS;

    /**
     * @constant
     * @type {Selector}
     */
    var CONTROLS_SELECTOR = '.' + Rails.SeeMore.CSS_SHOW_DETAILS;

    /**
     * @constant
     * @type {Selector}
     */
    var ALWAYS_SHOW_SELECTOR = '.' + Rails.SeeMore.CSS_ADD_TO_INITIAL;

    /**
     * @constant
     * @type {Selector}
     */
    var SEE_MORE_SELECTOR = '.' + Rails.SeeMore.CSS_SEE_MORE_CONTROL;

    /**
     * @constant
     * @type {Selector}
     */
    var SEE_MORE = '.' + Rails.SeeMore.CSS_SEE_MORE;

    /**
     * @constant
     * @type {Selector}
     */
    var SEE_LESS = '.' + Rails.SeeMore.CSS_SEE_LESS;

    /**
     * Options for jQuery slideUp()/slideDown().
     *
     * @constant
     * @type {object}
     *
     * @property {string|number} duration
     * @property {boolean}       queue
     */
    var SLIDE_OPTIONS = { duration: 'fast' };

    // ========================================================================
    // Variables
    // ========================================================================

    /**
     * Not present in print view.
     *
     * @type {boolean}
     */
    var suppressed = !FEATURE_ENABLED || inPrintView();

    // ========================================================================
    // Function definitions
    // ========================================================================

    /**
     * Disable this feature temporarily.
     *
     * @param {boolean} [setting]     Default: true.
     */
    function suppress(setting) {
        suppressed = (typeof setting === 'undefined') || setting;
    }

    /**
     * Indicate whether this feature is (currently) enabled.
     *
     * @return {boolean}
     */
    function enabled() {
        return FEATURE_ENABLED && !suppressed;
    }

    /**
     * defaultRoot
     *
     * @return {jQuery}
     */
    function defaultRoot() {
        return $('body');
    }

    /**
     * defaultSelector
     *
     * @return {string}
     */
    function defaultSelector() {
        return '.item-fields';
    }

    /**
     * Set up "See more"/"See less"/"Always show" controls and initialize the
     * state of the "extra" metadata fields.
     *
     * @param {Selector} [root]             Default: {@link defaultRoot}()
     * @param {Selector} [selector]         Default: {@link defaultSelector}()
     * @param {number}   [initial_fields]   Default: {@link INITIAL_FIELDS}
     */
    function setupShowDetails(root, selector, initial_fields) {

        if (!enabled()) { return; }

        var $root         = root ? $(root) : defaultRoot();
        var $fields       = $root.find(selector || defaultSelector());
        var $show_details = $fields.find(CONTROLS_SELECTOR);
        if (isMissing($show_details)) { return; }

        var $toggles     = $show_details.children(SEE_MORE_SELECTOR);
        var $see_more    = $toggles.filter(SEE_MORE);
        var $see_less    = $toggles.filter(SEE_LESS);
        var $always_show = $show_details.children('.always-show-link');

        // Set up the click handler and treat carriage returns as clicks.
        $show_details.click(toggleSeeMore).each(treeHandleKeypressAsClick);

        // Initialize the state of the display details and controls.
        $show_details.click();

        // ====================================================================
        // Functions
        // ====================================================================

        /**
         * Change the display of metadata fields and the state of the controls
         * for "See more", "See less", and "Always show full record".
         *
         * @param {Event} event
         *
         * @return {boolean}
         */
        function toggleSeeMore(event) {
            // Determine the state of the details entries.
            var expanded = $show_details.hasClass('open');
            var initially_opened;
            var initially_closed;
            var opening;

            if ($see_more.is(':visible') && $see_less.is(':visible')) {

                // If both labels are displayed then this is the pseudo-click
                // that initializes the state.  In this case, whether details
                // are displayed is indicated by the classes of $show_details.
                initially_opened = expanded;
                initially_closed = !expanded;
                opening = expanded;

            } else if (!event.target.className.match(/details-/)) {

                // If the full_view link was clicked, don't process the event
                // or change the display -- just follow the link to make the
                // server update the `session` variable.
                return true;

            } else {

                // During normal operation, the state of the secondary details
                // lines (pairs of <dt/><dd/>) is toggled based on which label
                // is currently being displayed.
                opening = !expanded;

            }

            // Update attributes for the display and the controls.
            updateAttributes(opening);

            // If the details are initially specified to be displayed then
            // there is nothing more to do -- the page is generated with all
            // details displayed by default.  Otherwise, the display must be
            // transitioned according to the new state.
            if (!initially_opened) {
                updateDisplay(opening, initial_fields, initially_closed);
            }

            return false;
        }

        /**
         * Update attributes which indicate the state of the display and the
         * controls.
         *
         * @param {boolean} opening   Expanding if *true*
         */
        function updateAttributes(opening) {

            // NOTE:  Microsoft IE doesn't implement "display: initial;" so the
            // value is explicitly defined here.  If any of these elements are
            // changed then this will have to change also.
            var initial = 'inline-block';

            // Update toggle by displaying the appropriate label and hiding the
            // other one.
            $see_more.css('display', (opening ? 'none' : initial));
            $see_less.css('display', (opening ? initial : 'none'));

            // Only show "Always show full record" if details are open, but
            // show "Don't always show full record" unconditionally.
            var as_show = opening || $always_show.hasClass('active');
            $always_show.css('display', (as_show ? initial : 'none'));

            // Update attributes which indicate the state of the display.
            $see_more.attr('aria-expanded', opening);
            $see_less.attr('aria-expanded', opening);
            $show_details.toggleClass('open', opening);
        }

        /**
         * Update the display of the metadata fields.
         *
         * @param {boolean} opening             Expanding if *true*
         * @param {number}  [initial_fields]    Default: {@link INITIAL_FIELDS}
         * @param {boolean} [initially_closed]  Default: *false*.
         */
        function updateDisplay(opening, initial_fields, initially_closed) {

            var $extra_fields = secondaryFields(initial_fields);
            var $focus_element;

            if (opening) {
                // Expose secondary fields and reposition focus on the first
                // previously-hidden link (or on "See less" if there are no
                // links in the secondary fields).
                $extra_fields.slideDown(SLIDE_OPTIONS);
                $focus_element =
                    firstActiveLink($extra_fields) ||
                    firstActiveLink($root.find('.technical-details')) ||
                    $see_less;

            } else if (initially_closed) {
                // Normally the page is created with the secondary fields
                // hidden.
                $extra_fields.hide();

            } else {
                // Hide secondary fields and reposition focus on the
                // previously-hidden "See more" button.
                $extra_fields.slideUp(SLIDE_OPTIONS);
                $focus_element = $see_more;
            }

            // Reposition the focus, but only maintain the focused state if the
            // "See more"/"See less" transition was initiated by a key press
            // (carriage return) rather than a mouse click.
            if (isPresent($focus_element)) {
                $focus_element.focus();
                var sm_kpc = $see_more.prop(KEYPRESS_PROP);
                var sl_kpc = $see_less.prop(KEYPRESS_PROP);
                if (sm_kpc || sl_kpc) {
                    $see_more.removeProp(KEYPRESS_PROP);
                    $see_less.removeProp(KEYPRESS_PROP);
                } else {
                    $focus_element.blur();
                }
            }

        }

        /**
         * This returns the <dt/><dd/> pairs for all fields after the initial
         * (always-visible) fields, excluding fields that are marked as always
         * visible.
         *
         * @param {number} [initial_fields]   Default: {@link INITIAL_FIELDS}
         *
         * @return {jQuery}}
         */
        function secondaryFields(initial_fields) {
            var last_initial = (initial_fields || INITIAL_FIELDS) - 1;
            var later_fields = 'dt:gt(' + last_initial + ')';
            var hidden = 'not(' + ALWAYS_SHOW_SELECTOR + ')';
            var labels = later_fields + ':' + hidden;
            return $root.find(labels + ', ' + labels + ' ~ dd:' + hidden);
        }
    }

    /**
     * Remove "See more"/"See less"/"Always show" controls from the display.
     *
     * @param {Selector} [root]       Default: {@link defaultRoot}()
     * @param {Selector} [selector]   Default: {@link defaultSelector}()
     */
    function hideShowDetails(root, selector) {
        if (enabled()) {
            var $root   = root ? $(root) : defaultRoot();
            var $fields = $root.find(selector || defaultSelector());
            $fields.find(CONTROLS_SELECTOR).css('display', 'none');
        }
    }

    /**
     * updatePage
     *
     * @param {Selector} [root]       Default: {@link defaultRoot}()
     * @param {Selector} [selector]   Default: {@link defaultSelector}()
     */
    function updatePage(root, selector) {
        setupShowDetails(root, selector);
    }

    // ========================================================================
    // Feature initialization
    // ========================================================================

    $(document).ready(function() {
        //console.log('SeeMore ' + (enabled() ? 'enabled' : 'disabled'));
    });

    // ========================================================================
    // Exposed definitions
    // ========================================================================

    return {
        updatePage:       updatePage,
        setupShowDetails: setupShowDetails,
        hideShowDetails:  hideShowDetails,
        defaultRoot:      defaultRoot,
        defaultSelector:  defaultSelector,
        suppress:         suppress,
        enabled:          enabled
    };

})();
