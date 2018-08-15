// app/assets/javascripts/feature/requests.js

//= require shared/colorbox

/**
 * Create popups for request links.
 *
 * @type {object}
 *
 * @property {function} updatePage
 * @property {function} updateLinks
 * @property {function} defaultRoot
 * @property {function} defaultSelector
 * @property {function} suppress
 * @property {function} enabled
 */
var Requests = (function() {

    /**
     * @constant
     * @type {boolean}
     */
    var FEATURE_ENABLED = true;

    // ========================================================================
    // Variables
    // ========================================================================

    /** @type {boolean} */
    var suppressed = !FEATURE_ENABLED;

    /**
     * Table of currently active event handlers where the key is a string of
     * the form "event ['/' selector]" and the value is a function.  This is
     * used to avoid re-assigning handlers which are already bound.
     *
     * @type {{ string: function }}
     */
    var handler_table = {};

    // ========================================================================
    // Internal function definitions
    // ========================================================================

    /**
     * Add an event handler if not already added.
     *
     * @param {string}     name         Event name.
     * @param {jQuery}     [$elements]
     * @param {function|*} func         Function to bind or a placeholder to
     *                                    prevent future binding.
     */
    function addHandler(name, $elements, func) {
        var key, fn;
        if (typeof $elements === 'function') {
            key = name;
            fn  = $elements;
        } else {
            key = '' + name + '/' + $elements.selector;
            fn  = func;
        }
        if (key && !handler_table[key]) {
            handler_table[key] = fn;
            if (typeof fn === 'function') { $(window).bind(name, fn); }
        }
    }

    /**
     * Add a window resize event handler if not already added.
     *
     * @param {jQuery}   $elements
     * @param {function} fn           Function to bind.
     */
    function onWindowResize($elements, fn) {
        addHandler('resize', $elements, fn);
    }

    /**
     * createLinks
     *
     * @param {jQuery} $links
     */
    function createLinks($links) {
        var _func_ = arguments.callee.name;
        var height = shortScreen()  ? '90%' : FRAME_POPUP_HEIGHT;
        var width  = narrowScreen() ? '90%' : FRAME_POPUP_WIDTH;
        var cbox_settings =
            AppColorbox.settings(_func_, {
                iframe:      true,
                innerHeight: height,
                innerWidth:  width,
                rel:         'nofollow'
            });
        $links.each(handleKeypressAsClick).colorbox(cbox_settings);
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
     * The default selector for elements that require search context.
     *
     * @return {string}
     */
    function defaultSelector() {
        return 'a.initiate-request:not(.no-popup)';
    }

    /**
     * Update all request links on the page.
     *
     * @param {Selector} [root]       Default: {@link defaultRoot}()
     * @param {Selector} [selector]   Default: {@link defaultSelector}()
     */
    function updateLinks(root, selector) {
        if (enabled()) {
            var $root  = root ? $(root) : defaultRoot();
            var $links = $root.find(selector || defaultSelector());
            if (isPresent($links)) {
                var action = function() { createLinks($links); };
                onWindowResize($links, action);
                action();
            }
        }
    }

    /**
     * Update all relevant elements on the page.
     *
     * @param {Selector} [root]       Default: {@link defaultRoot}()
     * @param {Selector} [selector]   Default: {@link defaultSelector}()
     */
    function updatePage(root, selector) {
        updateLinks(root, selector);
    }

    // ========================================================================
    // Feature initialization
    // ========================================================================

    $(document).ready(function() {
        //console.log('Requests ' + (enabled() ? 'enabled' : 'disabled'));
    });

    // ========================================================================
    // Exposed definitions
    // ========================================================================

    return {
        updatePage:      updatePage,
        updateLinks:     updateLinks,
        defaultRoot:     defaultRoot,
        defaultSelector: defaultSelector,
        suppress:        suppress,
        enabled:         enabled
    };

})();
