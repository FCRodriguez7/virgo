// app/assets/javascripts/feature/google-preview.js

//= require shared/definitions

/**
 * Handle the Google Preview button.
 *
 * This feature avoids the poor practices of the official Google Preview widget
 * (namely using `document.write` to inject elements into the DOM tree), while
 * still performing all communication with Google from the browser client.
 *
 * If the item has at least one ISBN, OCLC or LCCN, the server will render the
 * item details show page with a Google Preview element bearing data attributes
 * needed to construct the request to the Google Books site which returns
 * information containing the preview URL.
 *
 * @see UVA::Helper::GooglePreview#google_preview_control
 *
 * @type {object}
 *
 * @property {function} updatePage
 * @property {function} updateControl
 * @property {function} defaultRoot
 * @property {function} defaultSelector
 * @property {function} suppress
 * @property {function} enabled
 */
var GooglePreview = (function() {

    /**
     * @constant
     * @type {boolean}
     */
    var FEATURE_ENABLED = Rails.GooglePreview.ENABLED;

    /**
     * If/when Google redirects, it redirects to HTTPS so make sure that the
     * initial request starts as HTTPS.
     *
     * @constant
     * @type {string}
     */
    var SCRIPT_PATH = Rails.GooglePreview.BASE_PATH;

    /**
     * There are two types of Google Books links that are useful:
     *
     *  - "Full preview" shows the full text of the item.  (This is typical for
     *      out-of-copyright materials; often this will be a HathiTrust item,
     *      in which case the "Google Preview" is just an alternative view of
     *      the same material.)
     *
     *  - "Partial preview" shows selected portions of the item.  (This is
     *      typical for in-print books that are commercially available.  Unless
     *      we have a direct or indirect relationship with the publisher, this
     *      may be the only electronic representation available through Virgo.)
     *
     * @constant
     * @type {string[]}
     */
    var PREVIEW_TYPES = ['full', 'partial'];

    // ========================================================================
    // Variables
    // ========================================================================

    /** @type {boolean} */
    var suppressed = !FEATURE_ENABLED;

    // ========================================================================
    // Internal function definitions
    // ========================================================================

    /**
     * Get the URL of the preview that is the most complete.
     *
     * @param {object} data
     *
     * @return {object|undefined}
     *
     * @property {string} type
     * @property {string} url
     */
    function getBestPreviewUrl(data) {
        var result;
        $.each(data, function(bibkey, entry) {
            if (entry && entry.preview_url) {
                if (PREVIEW_TYPES.indexOf(entry.preview) !== -1) {
                    result = {
                        type: entry.preview,
                        url:  decodeURI(entry.preview_url)
                    };
                    return false; // break from $.each()
                }
            }
        });
        return result;
    }

    /**
     * updateButton
     *
     * @param {Selector} control
     * @param {string}   bibkeys
     */
    function updateButton(control, bibkeys) {
        var $control = $(control || defaultSelector());
        var $button  = $control.children('a');
        $.ajax({
            url:      SCRIPT_PATH,
            type:     'GET',
            data:     { jscmd: 'viewapi', bibkeys: bibkeys },
            dataType: 'jsonp',
            success:  function(data) {
                var result = getBestPreviewUrl(data);
                if (result) {
                    var tooltip = (result.type === 'full')
                        ? 'The full text of this material'
                        : 'A selection of pages from this material';
                    tooltip += '\npresented by Google Books';
                    tooltip += '\nin a separate browser tab.';
                    $button.attr('href', result.url);
                    $button.attr('title', tooltip);
                    $button.addClass(result.type + '-preview');
                    $control.removeClass('hide');
                }
            }
        });
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
        return '.google-preview';
    }

    /**
     * updateControl
     *
     * @param {Selector} control      Default: {@link defaultSelector}()
     */
    function updateControl(control) {

        if (!enabled()) { return; }

        var $control = $(control || defaultSelector());
        var bibkeys  = '';

        ['isbn', 'oclc', 'lccn'].forEach(function(key) {
            var values = $control.attr('data-' + key);
            if (values) {
                if (bibkeys) { bibkeys += ',' }
                bibkeys += key.toUpperCase() + ':' + values;
            }
        });

        if (bibkeys) {
            updateButton($control, bibkeys);
        }
    }

    /**
     * updatePage
     *
     * @param {Selector} [root]       Default: {@link defaultRoot}()
     * @param {Selector} [selector]   Default: {@link defaultSelector}()
     */
    function updatePage(root, selector) {
        if (enabled()) {
            var $root     = root ? $(root) : defaultRoot();
            var $elements = $root.find(selector || defaultSelector());
            $elements.each(function() {
                updateControl(this);
            });
        }
    }

    // ========================================================================
    // Feature initialization
    // ========================================================================

    $(document).ready(function() {
        //console.log('GooglePreview ' + (enabled() ? 'enabled' : 'disabled'));
    });

    // ========================================================================
    // Exposed definitions
    // ========================================================================

    return {
        updatePage:      updatePage,
        updateControl:   updateControl,
        defaultRoot:     defaultRoot,
        defaultSelector: defaultSelector,
        suppress:        suppress,
        enabled:         enabled
    };

})();
