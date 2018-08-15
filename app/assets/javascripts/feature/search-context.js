// app/assets/javascripts/feature/search-context.js

//= require shared/definitions

/**
 * Add search context to links on the page with the data-counter attribute so
 * that the resulting item details show page will show the page in the context
 * of the originating search:
 *
 *  "Item N of M"   - The position of the current item in the result set and
 *                      the total number of results.
 *
 *  "<< Previous"   - Link to previous item in the search results
 *
 *  "Next >>"       - Link to next item in the search results.
 *
 * @type {object}
 *
 * @property {function} updatePage
 * @property {function} defaultRoot
 * @property {function} defaultSelector
 * @property {function} suppress
 * @property {function} enabled
 */
var SearchContext = (function() {

    /**
     * @constant
     * @type {boolean}
     */
    var FEATURE_ENABLED = true;

    // ========================================================================
    // Variables
    // ========================================================================

    /**
     * Links in print view should not be adjusted for search context.
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
     * The default selector for elements that require search context.
     *
     * @return {string}
     */
    function defaultSelector() {
        return 'a[data-counter]';
    }

    /**
     * Update all item links on the page so that they actually submit a hidden
     * form to include search context information rather than simply performing
     * a GET on the link URL.
     *
     * @param {Selector} [root]       Default: {@link defaultRoot}()
     * @param {Selector} [selector]   Default: {@link defaultSelector}()
     */
    function updatePage(root, selector) {

        if (!enabled()) { return; }

        var $root       = root ? $(root) : defaultRoot();
        var $links      = $root.find(selector || defaultSelector());
        var $properties = $root.find('.search-properties');
        var search      = $properties.attr('data-search');

        $links.click(function(event) {

            var $link   = $(this);
            var href    = $link.attr('href');
            var counter = $link.attr('data-counter');

            var f = document.createElement('form');
            f.method = 'POST';
            f.action = href;
            f.style.display = 'none';
            if (event.metaKey || event.ctrlKey) {
                f.target = '_blank';
            }

            var attributes = {
                _method:  'PUT',
                search:   search,
                counter:  counter
            };
            attributes[getCsrfParam()] = getCsrfToken();

            $.each(attributes, function(name, value) {
                if (value) {
                    var e = document.createElement('input');
                    e.setAttribute('type', 'hidden');
                    e.setAttribute('name',  name);
                    e.setAttribute('value', value);
                    f.appendChild(e);
                }
            });

            this.parentNode.appendChild(f);
            f.submit();

            return false;
        });

    }

    // ========================================================================
    // Feature initialization
    // ========================================================================

    $(document).ready(function() {
        //console.log('SearchContext ' + (enabled() ? 'enabled' : 'disabled'));
    });

    // ========================================================================
    // Exposed definitions
    // ========================================================================

    return {
        updatePage:      updatePage,
        defaultRoot:     defaultRoot,
        defaultSelector: defaultSelector,
        suppress:        suppress,
        enabled:         enabled
    };

})();
