// app/assets/javascripts/feature/articles.js

//= require shared/colorbox
//= require feature/analytics
//= require feature/search-context
//= require feature/starred-items

/**
 * Article search access functions.
 *
 * This module is only used by the home and combined results pages.
 *
 * @type {object}
 *
 * @property {function} loadArticles
 * @property {function} addArticleEngineSwitch
 * @property {function} rootSelector
 * @property {function} suppress
 * @property {function} enabled
 */
var Articles = (function() {

    /**
     * @constant
     * @type {boolean}
     */
    var FEATURE_ENABLED = true;

    /**
     * @constant
     * @type {string}
     */
    var ENGINE_SWITCH_PATH = '/articles/change_engine';

    /**
     * @constant
     * @type {string}
     */
    var COMBINED_LOAD_PATH = '/articles?catalog_select=all';

    // ========================================================================
    // Variables
    // ========================================================================

    /** @type {boolean} */
    var suppressed = !FEATURE_ENABLED;

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
     * Selector for the element on the combined results page where asynchronous
     * article results are displayed.
     *
     * @return {string}
     */
    function rootSelector() {
        return '.article-results-container';
    }

    /**
     * Asynchronously get article results for the combined results page.
     *
     * @param {Selector} [root]       Default: `rootSelector()`.
     */
    function loadArticles(root) {

        if (!enabled()) { return; }

        var $root = $(root || rootSelector());
        if (isMissing($root)) { return; }

        // Modify load path if currently in print view.
        var params = getUrlParameters();
        var print_view = (params['view'] === 'print');

        // Look for hidden parameters in the current element; if present, these
        // are used to construct the article search to perform.  Otherwise,
        // fall back to checking URL parameters
        var load_path     = COMBINED_LOAD_PATH;
        var $properties   = $root.find('.search-properties');
        var search_params = $properties.attr('data-search-params');
        if (search_params) {
            search_params = $('<div>').html(search_params).text()
                .replace(/^\?/, '&')
                .replace(/^/, '&')
                .replace(/catalog_select=[^&]*/g, '')
                .replace(/&&+/g, '&');
            if (print_view && !search_params.match(/view=print/)) {
                search_params = addParameter(search_params, 'view', 'print');
            }
            load_path += search_params;
        } else {
            search_params = params;
            if (print_view) {
                search_params['view'] = 'print';
            }
            load_path = addParameter(load_path, search_params);
        }

        // Load the results, then update item links with Piwik analytics and
        // modify them so that instead of GET they use PUT with additional
        // context information.
        $.ajax({
            url:      load_path,
            type:     'GET',
            dataType: 'html',

            success: function(data) {
                //console.log('ARTICLES: ' + data.length + ' bytes');
                $root.css('background', 'white');
                $root.html(data);
                $root.show(0, function() {
                    StarredItems.updatePage($root);
                    SearchContext.updatePage($root);
                    Analytics.updatePage($root);
                    AppColorbox.updatePage(); // Have to re-do the whole page
                });
            },

            error: function(xhr, status, error) {
                console.warn('ARTICLES: ' + status + ': ' + error);
                $root.css('background', 'white');
                $root.html('Articles are temporarily unavailable.');
            }
        });
    }

    /**
     * Used on the home page and only when testing multiple article search
     * providers.
     */
    function addArticleEngineSwitch() {

        if (!enabled()) { return; }

        $('#AE_ON').change(function() {
            $('.ae-selection').toggleClass('hidden');
        });

        // Hook up the article provider radio buttons change event so that an
        // AJAX post is done via the articles controller change_engine route.
        // Send the new engine identifier value as the parameter.
        $('[name|="ae"]').change(function() {
            $.ajax({
                url:  ENGINE_SWITCH_PATH,
                type: 'POST',
                data: { new_ae: $('[name|="ae"]:checked').val() }
            });
        });
    }

    // ========================================================================
    // Feature initialization
    // ========================================================================

    $(document).ready(function() {
        //console.log('Articles ' + (enabled() ? 'enabled' : 'disabled'));
    });

    // ========================================================================
    // Exposed definitions
    // ========================================================================

    return {
        loadArticles:           loadArticles,
        addArticleEngineSwitch: addArticleEngineSwitch,
        rootSelector:           rootSelector,
        suppress:               suppress,
        enabled:                enabled
    };

})();
