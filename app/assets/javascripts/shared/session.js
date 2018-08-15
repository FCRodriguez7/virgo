// app/assets/javascripts/shared/session.js
//
// Set session properties.

//= require shared/definitions
//= require shared/fonts
//= require shared/dev

/** @type {DebugEntry} */
var debugSession =
    ModuleDebug.add('shared/session', 'SESSION', { all: DEVELOPMENT });

/**
 * Application session.
 *
 * @type {object}
 *
 * @property {function} initialFocus
 * @property {function} rememberFocus
 * @property {function} setInitialFocus
 * @property {function} defaultRoot
 */
var AppSession = (function(module_debug) {

    /** @type {boolean} */
    var _debugging = module_debug.debugging;

    /** @type {function} */
    var _trace = module_debug.trace;

    /** @type {function} */
    var _debug = module_debug.debug;

    _trace('INITIALIZING');
    _debug('jQuery version', $.fn.jquery);

    // ========================================================================
    // Constants
    // ========================================================================

    /**
     * @constant
     * @type {string}
     */
    var LAST_FOCUS_MARKER = 'last-focus';

    // ========================================================================
    // Variables
    // ========================================================================

    /**
     * The element that should receive focus when the page is completely ready.
     *
     * @type {jQuery}
     */
    var $initial_focus;

    // ========================================================================
    // Internal function definitions
    // ========================================================================

    /**
     * Toggle a hidden input value on the page to force it to reload itself
     * when redisplayed from cache.
     *
     * The pages or layouts requiring this functionality must include the
     * element:
     *
     *  <input type="hidden" id="needs-refresh" value="no">
     *
     * When loading the page, data sources have this precedence:
     *
     *  - URL parameters
     *  - History data
     *  - Hidden element data
     *
     *  @return {boolean}             If reloading *true* else *false*.
     */
    function pageRefresh() {

        // Index pages should not be saving counter/search; to ensure that they
        // don't, the values are eliminated.
        var params     = {};
        var hist_state = history.state || {};
        var elements   = { counter: null, search: null };
        if (!$('body').hasClass('index-page')) {
            params     = getUrlParameters();
            elements.counter = $('.item-properties').attr('data-counter');
            elements.search  = $('.search-properties').attr('data-search');
        }

        var href       = currentUrl();
        var refresh    = document.getElementById('needs-refresh');
        var page_state = refresh && refresh.value;
        var reloading  = '';
        var names      = Object.keys(elements);

        var log = '*** pageRefresh';
        log += '(' + (page_state ? ('"' + page_state + '"') : '') + ') - ';

        // Process based on the state of the hidden element.
        switch (page_state) {
            case 'no':
                // The initial load of a page with <input id="needs-refresh">
                // or any page where there are special URL parameters that are
                // not already in the history entry for this page.
                var new_data = {};
                names.forEach(function(name) {
                    var new_value = params[name] || elements[name];
                    if (new_value && (new_value !== hist_state[name])) {
                        new_data[name] = new_value;
                    }
                });

                // If any values were accumulated, use them for the history
                // entry.
                if ($.isEmptyObject(new_data)) {
                    refresh.value = 'yes';
                    _debug(log + 'no change to ' + href);
                } else {
                    refresh.value = 'first';
                    new_data = $.extend({}, hist_state, new_data);
                    history.replaceState(new_data, '', href);
                    _debug(log + 'updated history for ' + href);
                }
                break;

            case 'first':
                // The first re-load of a page with <input id="needs-refresh">
                // or any page where there are special URL parameters that are
                // not already in the history entry for this page.
                var href_orig = href;
                names.forEach(function(name) {
                    var new_value = hist_state[name] || elements[name];
                    if (new_value && (new_value !== params[name])) {
                        href = addParameter(href, name, new_value);
                    }
                });

                // Since this is the second time this page has been loaded
                // (this time due to `history.back()` or `history.forward()`)
                // it needs to be reloaded.
                reloading = (href === href_orig) ? 'RELOAD' : 'UPDATE to';
                break;

            case 'yes':
                // Second and subsequent page visits through `history.back()`
                // or `history.forward`.  At this point, the history data has
                // been settled, so this is just a simple reload.
                reloading = 'RELOAD';
                break;

            default:
                // There was no <input id="needs_refresh"> and no data in the
                // history so no action is taken.
                _debug(log + 'SKIPPED ' + href);
                break;
        }

        // Reload with the given URL.
        if (reloading) {
            _trace(reloading + ' ' + href);
            refresh.value = 'no';
            window.location = href;
        }
        return !!reloading;
    }

    /**
     * findLastFocus
     *
     * @param {Selector} [root]       Default: {@link defaultRoot}()
     *
     * @return {jQuery}
     */
    function findLastFocus(root) {
        _trace(arguments);
        var selector = history.state && history.state.initial_focus;
        if (!selector) {
            selector = '#' + LAST_FOCUS_MARKER + ', .' + LAST_FOCUS_MARKER;
        }
        var $root   = root ? $(root) : defaultRoot();
        var $result = $root.find(selector);
        if (isPresent($result)) {
            _debug('Last focus: "' + $result.selector + '"');
        }
        return $result;
    }

    // ========================================================================
    // Function definitions
    // ========================================================================

    /**
     * defaultRoot
     *
     * @return {jQuery}
     */
    function defaultRoot() {
        return $('body');
    }

    /**
     * Store the last of the specified element(s) as the initial focus to use
     * if no LAST_FOCUS_MARKER has been set.
     *
     * @param {Selector} element
     * @param {boolean}  [force]
     *
     * @return {boolean}
     */
    function initialFocus(element, force) {
        _trace(arguments);
        var $element;
        var already_set = isDefined($initial_focus);
        var set_here    = false;
        if (!force && already_set) {
            console.warn('$initial_focus already set');
        } else if (isPresent($element = $(element))) {
            if (already_set) {
                console.warn('$initial_focus forced replacement');
            }
            $initial_focus = $element;
            set_here = true;
        } else {
            _debug('no focus for "' + $element.selector + '"');
        }
        return set_here;
    }

    /**
     * Process all focusable elements under *root*.
     *
     * @param {Selector} [root]       Default: {@link defaultRoot}()
     */
    function rememberFocus(root) {
        _trace(arguments);
        var $root = root ? $(root) : defaultRoot();
        focusableElements($root).not('[target="_blank"]').click(function() {
            _debug('Setting #' + LAST_FOCUS_MARKER + ' on ' + this);
            var $this = $(this);
            var id = $this[0].id;
            if (!id) {
                id = $this[0].id = LAST_FOCUS_MARKER;
            }
            var state = $.extend({}, (history.state || {}));
            state.initial_focus = '#' + id;
            history.replaceState(state, '');
            history.scrollRestoration = 'manual';
        });
        history.scrollRestoration = 'auto';
    }

    /**
     * The function should be run as the last statement of the
     * $(document).ready() handler for a top-level script associated with a
     * layout.
     *
     * @param {Selector} [root]       Default: {@link defaultRoot}()
     */
    function setInitialFocus(root) {
        _trace(arguments);
        if (isPresent($initial_focus)) {
            $initial_focus.focus();
        }
        rememberFocus(root);
    }

    // ========================================================================
    // Feature initialization
    // ========================================================================

    $(document).ready(function() {

        _trace('STARTING');

        // ====================================================================
        // Page refresh.
        // ====================================================================

        // This should be performed as soon as possible, so
        // '@include "shared/session" must be the first statement of any
        // app/assets/javascripts/*.js script that is associated with a layout.
        if (pageRefresh()) {
            _trace('ENDING');
            return;
        }

        // ====================================================================
        // AJAX setup.
        // ====================================================================

        // Allow for communication lags during desktop development.
        if (!DEPLOYED) {
            console.log('Rails.env == "' + RAILS_ENV + '"');
            console.log(currentUrl());
            GLOBAL_TIMEOUT *= 3;
        }

        // Define default AJAX settings.
        // @see https://api.jquery.com/jQuery.ajax
        $.ajaxSetup({
            timeout: GLOBAL_TIMEOUT
        });

        // Called before each AJAX request to ensure that HTTP requests include
        // the CSRF token when needed.
        $.ajaxPrefilter(function(options, original_options, jq_xhr) {
            if (!csrfSafeMethod(options['type'])) {
                jq_xhr.setRequestHeader('X-CSRF-Token', getCsrfToken());
            }
        });

        // ====================================================================
        // Flash control
        // ====================================================================

        // To ensure that flash messages do not persist even when actions don't
        // result in a new page (e.g. starring/unstarring items, some menu
        // selections), hide after a completed mouse action.
        $(document).mouseup(function() {
            _debug(arguments);
            $('.flash-message:not(.static)').hide();
        });

        // ====================================================================
        // Restore focus
        // ====================================================================

        var last_focus = findLastFocus();
        if (initialFocus(last_focus, true)) {
            _trace('Restoring focus to "' + last_focus + '"');
            $initial_focus.focus();
        } else if (last_focus) {
            _trace('Cannot restore focus to "' + last_focus + '"');
        } else {
            _debug('No focus to restore');
        }

    });

    // ========================================================================
    // Exposed definitions
    // ========================================================================

    return {
        initialFocus:    initialFocus,
        rememberFocus:   rememberFocus,
        setInitialFocus: setInitialFocus,
        defaultRoot:     defaultRoot
    };

})(debugSession);
