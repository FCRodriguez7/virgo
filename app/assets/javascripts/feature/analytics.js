// app/assets/javascripts/feature/analytics.js

//= depends_on //analytics.lib.virginia.edu/xxx

//= require shared/definitions

/**
 * The Piwik script is loaded via the <head> section of the page.
 *
 * @external Piwik
 * @requires https://xxx.virginia.edu/xxx
 */

/**
 * Add Piwik analytics to the page.
 *
 * Each top-level (layout) script should run `Analytics.updatePage()` as the
 * final action of the .ready() handler.  Functions which load asynchronous
 * content into the Virgo page should `Analytics.updatePage($new_element)`,
 * where $new_element is the root of the hierarchy of added content.
 *
 * @type {object}
 *
 * @property {function} updatePage
 * @property {function} defaultRoot
 * @property {function} defaultSelector
 * @property {function} suppress
 * @property {function} enabled
 */
var Analytics = (function() {

    /**
     * @constant
     * @type {string}
     */
    var PIWIK_URL = Rails.Piwik.TRACKER_URL;

    /**
     * @constant
     * @type {string}
     */
    var PIWIK_SITE = Rails.Piwik.SITE;

    /**
     * @constant
     * @type {boolean}
     */
    var FEATURE_ENABLED = PIWIK_URL && PIWIK_SITE && Rails.Piwik.ENABLED;

    /**
     * If *true*, add LINK_CLASS to any links which are being tracked.
     *
     * @constant
     * @type {boolean}
     */
    var MARK_LINKS = true;

    /**
     * CSS class to identify a link which is being tracked.
     *
     * @constant
     * @type {string}
     */
    var LINK_CLASS = 'piwik_link';

    /**
     * Elements with these CSS classes aren't tracked.
     *
     * @constant
     * @type {string[]}
     */
    var IGNORE_CLASSES = [
        'submit-form'       // Don't track star/unstar links.
    ];

    /**
     * Elements with these CSS classes should be noted as downloads.
     *
     * @constant
     * @type {string[]}
     */
    var DOWNLOAD_CLASSES = [
        'download-button'   // Article PDF links.
    ];

    // ========================================================================
    // Variables
    // ========================================================================

    /** @type {boolean} */
    var suppressed = !FEATURE_ENABLED;

    /** @type {Piwik} */
    var piwik_tracker;

    // ========================================================================
    // Internal function definitions
    // ========================================================================

    /**
     * Create a selector from an array of CSS class names.
     *
     * @param {string[]} class_names
     *
     * @return {string}
     */
    function classSelector(class_names) {
        return class_names.map(function(class_name) {
            return '.' + class_name;
        }).join(', ');
    }

    /**
     * Track links on the page, even if they are within invisible elements.
     *
     * Although, normally, repeated calls to `enableLinkTracking()` is
     * sufficient to incorporate new links as they are added to the page, this
     * function allows for two extensions that Piwik does not seem to support
     * natively:
     *
     * - Handling of links which are in invisible elements (needed for virtual
     *    shelf browse).
     *
     * - Allowing '[data-path]' elements to be treated as links.  (Piwik's own
     *    code ignores elements unless they have '[href]' element, but many
     *    virtual shelf browse "links" are actually non-anchor elements with
     *    a "data-path" attribute instead of an "href" attribute.)
     *
     * @param {Selector} [root]       Default: {@link defaultRoot}()
     * @param {Selector} [selector]   Default: {@link defaultSelector}()
     */
    function addListener(root, selector) {
        if (piwik_tracker) {
            var $root   = root ? $(root) : defaultRoot();
            var $links  = $root.find(selector || defaultSelector());
            var ignored = classSelector(IGNORE_CLASSES);
            $links.not(ignored).each(function() {
                var $this = $(this);
                var href  = $this.attr('href') || $this.attr('data-path');
                if (href && !href.match(/^javascript:/)) {
                    var name = this.className;
                    if (MARK_LINKS && (!name || !name.match(LINK_CLASS))) {
                        if (name) { this.className += ' '; }
                        this.className += LINK_CLASS;
                    }
                    piwik_tracker.addListener(this);
                }
            });
            piwik_tracker.enableLinkTracking();
        }
    }

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
        return '[href], [data-path]';
    }

    /**
     * Initiate Piwik tracking for the current page and setup Piwik click
     * handlers on page links.
     *
     * This will be called automatically when the page is ready.  If DOM
     * element(s) are added asynchronously, this must be called again to track
     * any added links.
     *
     * @param {Selector} [root]       Default: {@link defaultRoot}()
     * @param {Selector} [selector]   Default: {@link defaultSelector}()
     */
    function updatePage(root, selector) {
        if (!enabled()) {
            //console.log('Piwik.updatePage skipped - not enabled');
        } else if (piwik_tracker) {
            // Subsequent calls (explicitly as `Analytics.updatePage()`).
            addListener(root, selector);
        } else {
            // First call (via the ready() handler).
            try {
                piwik_tracker = Piwik.getTracker(PIWIK_URL, PIWIK_SITE);
                piwik_tracker.trackPageView();
                piwik_tracker.setIgnoreClasses(IGNORE_CLASSES);
                piwik_tracker.setDownloadClasses(DOWNLOAD_CLASSES);
                addListener(root, selector);
            } catch (err) {
                console.error('Piwik: ' + err);
                piwik_tracker = null;
            }
        }
    }

    // ========================================================================
    // Feature initialization
    // ========================================================================

    $(document).ready(function() {
        //console.log('Analytics ' + (enabled() ? 'enabled' : 'disabled'));
    });

    // ========================================================================
    // Exposed definitions
    // ========================================================================

    return {
        updatePage:       updatePage,
        defaultRoot:      defaultRoot,
        defaultSelector:  defaultSelector,
        suppress:         suppress,
        enabled:          enabled
    };

})();
