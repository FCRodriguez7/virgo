// app/assets/javascripts/feature/cover-image.js

//= require shared/definitions

/** @type {DebugEntry} */
var debugCoverImage =
    ModuleDebug.add('feature/cover-image', 'COVERS', { trace: DEVELOPMENT });

/**
 * Cover Images feature.
 *
 * @type {object}
 *
 * @property {function} coverImageUrl
 * @property {function} coverImageElements
 * @property {function} loadCoverImage
 * @property {function} loadCoverImageElements
 * @property {function} suppress
 * @property {function} enabled
 */
var CoverImage = (function(module_debug) {

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
    var FEATURE_ENABLED = Rails.CoverImage.ENABLED;

    /**
     * @constant
     * @type {number}
     * NOTE: Set this to *null* for no retry.
     */
    var COVER_IMAGE_RETRY = Rails.CoverImage.RETRY;

    /**
     * @constant
     * @type {string}
     */
    var COVER_IMAGE_URL = Rails.CoverImage.COVER_IMAGE_URL;

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
     * Get the URL for the cover image of a given document ID.
     *
     * @param {string} doc_id
     *
     * @return {string}
     */
    function coverImageUrl(doc_id) {
        var id = encodeURIComponent(doc_id).replace(/\./g, '%2E');
        return COVER_IMAGE_URL + '/cover_images/' + id + '.json';
    }

    /**
     * Get the page element cover image targets.
     *
     * @param {string} [selector]
     *
     * @return {jQuery}
     */
    function coverImageElements(selector) {
        var elements = 'span.cover-image';
        if (selector) {
            if (selector.charAt(0) !== ' ') {
                elements += ' ';
            }
            elements += selector;
        }
        return $(elements);
    }

    /**
     * Load a cover image.
     *
     * @param {Selector} element
     *
     * === Usage Notes
     * In HTML, create a <span> with class "cover-image".  (The contents of the
     * span will be replaced by the cover image; the content is not used
     * however there has to be something (for example, a comment):
     *
     *    <span class="cover-image"><!-- * --></span>
     *
     * The span cannot be empty (i.e. '<span class="cover-image" />').
     */
    function loadCoverImage(element) {

        var _func_ = arguments.callee.name;
        if (!enabled()) {
            _debug(_func_, 'suppressed');
            return;
        }
        if (!element) {
            console.error(_func_ + ': no element');
            return;
        }
        if ((typeof element === 'object') && (element.length > 1)) {
            console.error(_func_ + ': multiple elements');
            return;
        }

        var $element = $(element);
        var doc_id = $element.attr('data-doc-id') || $element.attr('title');
        var url = coverImageUrl(doc_id);
        if (!url) {
            console.error(_func_ + ': no url');
            return;
        }
        _trace(_func_, url);

        var query = {};
        var data_attribute = {
            doc_type:    'doc-type',
            title:       'title',
            album_name:  'title',
            author:      'artist',
            artist_name: 'artist',
            issn:        'issn',
            isbn:        'isbn',
            oclc:        'oclc',
            lccn:        'lccn',
            upc:         'upc',
            ht_id:       'ht-id'
        };
        $.each(data_attribute, function(key, value) {
            var data = $element.attr('data-' + value);
            if (data) { query[key] = data; }
        });

        $.get(url, query, function(data) {
            _debug(_func_, "received:\n", data);
            var $image = $('<img>').attr({
                src: data.image_base64,
                alt: 'Cover image for ' + doc_id
            });
            $element.html($image).removeAttr('title');
        }).fail(function() {
            $element.attr('title', 'Cover image service failure.');
            $element.find('.ajax-loader').addClass('failure');
        });
    }

    /**
     * Load all cover image elements matching the selector.
     *
     * @param {Selector|boolean|null}           [elements]
     * @param {boolean|number|{retry: boolean}} [retry]
     */
    function loadCoverImageElements(elements, retry) {

        if (!enabled()) { return; }

        var timeout;
        var $elements;
        if (typeof elements === 'boolean') {
            timeout   = elements;
            $elements = coverImageElements();
        } else {
            timeout   = (typeof retry === 'object') ? retry['retry'] : retry;
            $elements = elements ? $(elements) : coverImageElements();
        }

        // Load cover images.
        $elements.each(function() {
            loadCoverImage(this);
        });

        // Schedule a retry unless explicitly avoided.
        if (notDefined(timeout) || (timeout === true)) {
            timeout = COVER_IMAGE_RETRY;
        } else if (typeof timeout === 'string') {
            timeout = parseInt(timeout);
        } else if (typeof timeout !== 'number') {
            timeout = false;
        }
        if (timeout) {
            setTimeout(
                function() { loadCoverImageElements($elements, false); },
                timeout
            );
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
        coverImageUrl:          coverImageUrl,
        coverImageElements:     coverImageElements,
        loadCoverImage:         loadCoverImage,
        loadCoverImageElements: loadCoverImageElements,
        suppress:               suppress,
        enabled:                enabled
    };

})(debugCoverImage);
