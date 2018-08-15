// app/assets/javascripts/feature/bookplate.js

//= require shared/definitions

/** @type {DebugEntry} */
var debugBookplate =
    ModuleDebug.add('feature/bookplate', 'BOOKPLATES', { trace: DEVELOPMENT });

/**
 * Manage bookplates.
 *
 * @type {object}
 *
 * @property {function} updatePage
 * @property {function} defaultRoot
 * @property {function} defaultSelector
 * @property {function} suppress
 * @property {function} enabled
 */
var Bookplate = (function(module_debug) {

    /** @type {function} */
    var _trace = module_debug.trace;

    /** @type {function} */
    var _debug = module_debug.debug;

    _trace('INITIALIZING');

    // ========================================================================
    // Constants
    // ========================================================================

    /**
     * @constant
     * @type {boolean}
     */
    var FEATURE_ENABLED = Rails.Bookplate.ENABLED;

    /**
     * @constant
     * @type {string}
     */
    var BOOKPLATE_URL = Rails.Bookplate.BASE_PATH;

    /**
     * Max number of characters per line for the text displayed in the popup
     * tooltip.  (80 was the desired value but 50 seems compatible with all
     * browser families.)
     *
     * @constant
     * @type {number}
     */
    var TOOLTIP_WIDTH = 50;

    // ========================================================================
    // Variables
    // ========================================================================

    /** @type {boolean} */
    var suppressed = !FEATURE_ENABLED;

    // ========================================================================
    // Function definitions.
    // ========================================================================

    /**
     * Suppress web requests.
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
     * The default selector for bookplate links.
     *
     * @return {string}
     */
    function defaultSelector() {
        return '.bookplate a';
    }

    /**
     * Update all bookplate links on the page...
     *
     * @param {Selector} [root]       Default: {@link defaultRoot}()
     * @param {Selector} [selector]   Default: {@link defaultSelector}()
     */
    function updatePage(root, selector) {
        if (enabled()) {
            _trace(arguments);
            var $root  = root ? $(root) : defaultRoot();
            var $links = $root.find(selector || defaultSelector());
            $links.each(function() {
                getBookplate(this);
            });
        }
    }

    // ========================================================================
    // Internal functions
    // ========================================================================

    /**
     * getBookplateUrl
     *
     * @param {string} fund_code
     *
     * @return {string|undefined}
     *
     * === Implementation Notes
     * The current version (v1) of the bookplates API seems to *require* that
     * the fund code be in quotes and that the quotes be URL-encoded.
     */
    function getBookplateUrl(fund_code) {
        var url;
        if (isPresent(fund_code)) {
            url = BOOKPLATE_URL + '?';
            url += $.param({fundID: '"' + fund_code + '"'});
        }
        return url;
    }

    /**
     * Update the bookplate tag element with the URL of the bookplate entry,
     * the name of the fund and descriptive text in a tooltip.
     *
     * @param {jQuery} $tag
     * @param {object} data
     *
     * @returns {jQuery}
     */
    function updateBookplateTag($tag, data) {
        var attributes = { href: data.url };
        var label = data.title   || ('Fund code ' + $tag.data('fund-id'));
        var text  = data.summary || '';
        if (text) {
            var words = '';
            var chars = 0;
            text.split(/\s+/).forEach(function(word) {
                if (notEmpty(word)) {
                    var space = ' ';
                    chars += space.length + word.length;
                    if (chars > TOOLTIP_WIDTH) {
                        space = "\n";
                        chars = word.length;
                    }
                    if (words) { words += space; }
                    words += word;
                }
            });
            attributes.title = words;
        }
        // If a fund doesn't have a description then that is currently an
        // indicator that it doesn't really have a bookplate, so there is no
        // point in displaying a badge for it.
        if (text) {
            $tag.attr(attributes).html(label).parent().css('display', 'block');
        }
        return $tag;
    }

    /**
     * processBookplateData
     *
     * @param {jQuery}       $tag       The tag to modify.
     * @param {string}       fund_code
     * @param {object|Array} data
     *
     * @returns {jQuery|undefined}      The modified $tag.
     */
    function processBookplateData($tag, fund_code, data) {
        var result;
        if (data instanceof Array) {
            // Data in this form in unexpected but we can attempt to treat each
            // array entry as holding bookplate data.
            $.each(data, function(_index, entry) {
                result = processBookplateData($tag, fund_code, entry);
                if (result) { return false; } // break from $.each()
            });

        } else if (typeof data !== 'object') {
            // Not expecting string or other types of arguments.
            var _func_ = arguments.callee.name;
            console.error(_func_ + ': invalid data type ' + typeof(data));

        } else if (data.fundID === fund_code) {
            // See if the bookplate data is directly in the data.
            result = updateBookplateTag($tag, data);

        } else {
            // Otherwise, look for bookplate data in key-value pairs.
            $.each(data, function(_key, value) {
                var entry = (typeof value === 'object') ? value : {};
                if (entry.fundID === fund_code) {
                    result = updateBookplateTag($tag, entry);
                    return false; // break from $.each()
                }
            });
        }
        return result;
    }

    /**
     * getBookplate
     *
     * @param {Selector} tag
     */
    function getBookplate(tag) {
        var $bookplate_tag = $(tag);
        var fund_code = $bookplate_tag.data('fund-id');
        var url = getBookplateUrl(fund_code);
        if (fund_code && url) {
            $.get(url, function(data) {
                processBookplateData($bookplate_tag, fund_code, data);
            });
        }
    }

    // ========================================================================
    // Feature initialization
    // ========================================================================

    $(document).ready(function() {
        _trace(enabled() ? 'enabled' : 'disabled');
    });

    // ========================================================================
    // Exposed definitions.
    // ========================================================================

    return {
        updatePage:      updatePage,
        defaultRoot:     defaultRoot,
        defaultSelector: defaultSelector,
        suppress:        suppress,
        enabled:         enabled
    };

})(debugBookplate);
