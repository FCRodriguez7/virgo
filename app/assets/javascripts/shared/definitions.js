// app/assets/javascripts/shared/definitions.js

//= require shared/rails

/** @type {number} */
var LOAD_TIME;

if (!LOAD_TIME) {

    LOAD_TIME = Date.now();

    // ========================================================================
    // Basic values and enumerations
    // ========================================================================

    /**
     * @constant
     * @type {number}
     */
    var MILLISECONDS = 1;

    /**
     * @constant
     * @type {number}
     */
    var MS_PER_SECOND = 1000;

    /**
     * @constant
     * @type {number}
     */
    var SECONDS = MS_PER_SECOND;

    /**
     * Key codes.
     *
     * @readonly
     * @enum {number}
     */
    var CHAR = {
        Backspace:  8,
        Tab:        9,
        Enter:      13,
        Shift:      16,
        Ctrl:       17,
        Alt:        18,
        CapsLock:   20,
        Escape:     27,
        Space:      32,
        PageUp:     33,
        PageDown:   34,
        End:        35,
        Home:       36,
        ArrowLeft:  37,
        ArrowUp:    38,
        ArrowRight: 39,
        ArrowDown:  40,
        Insert:     45,
        Delete:     46
    };

    // ========================================================================
    // General settings
    // ========================================================================

    /**
     * @constant
     * @type {string}
     */
    var RAILS_ENV = Rails.RAILS_ENV;

    /**
     * @constant
     * @type {boolean}
     */
    var DEPLOYED = Rails.DEPLOYED;

    /**
     * @constant
     * @type {boolean}
     */
    var DEVELOPMENT = Rails.DEVELOPMENT;

    /**
     * @constant
     * @type {number}
     */
    var GLOBAL_TIMEOUT = 20 * SECONDS;

    // ========================================================================
    // Dimensions
    // ========================================================================

    /**
     * @constant
     * @type {string}
     *
     * @see .popup-content in shared/styles
     */
    var FRAME_POPUP_HEIGHT = '460px';

    /**
     * @constant
     * @type {string}
     *
     * @see .popup-content in shared/styles
     */
    var FRAME_POPUP_WIDTH = '606px';

    /**
     * Small screen if window.innerHeight is at or below this number of pixels.
     *
     * @constant
     * @type {number}
     */
    var SMALL_HEIGHT = 500;

    /**
     * Small screen if window.innerWidth is at or below this number of pixels.
     *
     * @constant
     * @type {number}
     */
    var SMALL_WIDTH = 1000;

    // ========================================================================
    // Browser properties
    // ========================================================================

    /**
     * User agents.
     *
     * @readonly
     * @enum {string}
     */
    var UA = {
        Firefox: 'Firefox',
        Chrome:  'Chrome',
        Safari:  'Safari',
        Edge:    'Edge',
        IE:      'IE'
    };

    /**
     * Used in {@link browserProperties()} to find `navigator.user_agent`
     * substrings which indicate the browser family of the current web browser.
     *
     * @readonly
     * @enum {string}
     */
    var UA_MARKER = {
        Firefox: UA.Firefox,
        Chrome:  UA.Safari,
        Safari:  UA.Safari, // TODO: ???
        Edge:    UA.Edge,
        IE:      'NET'
    };

    // ========================================================================
    // JSDoc typedefs
    // ========================================================================

    /**
     * Indicates a function parameter that expects a {@link jQuery} object or
     * something that can be used to generate a {@link jQuery} object.
     *
     * @typedef Selector
     * @type {string|HTMLElement|jQuery}
     */
    var Selector;

    // ========================================================================
    // Function definitions - Time and date
    // ========================================================================

    /**
     * secondsSince
     *
     * @param {number} timestamp      Original `Date.now()` value.
     *
     * @return {number}
     */
    function secondsSince(timestamp) {
        return (Date.now() - timestamp) / MS_PER_SECOND;
    }

    /**
     * hhmmssSince
     *
     * @param {number} timestamp
     *
     * @return {string}
     */
    function hhmmssSince(timestamp) {
        var t  = secondsSince(timestamp);
        var hh = parseInt((t / 3600) % 24);
        var mm = parseInt((t / 60) % 60);
        var ss = parseInt(t % 60);
        if (hh) {
            hh = ((hh < 10) ? '0' : '') + hh + ':';
        } else {
            hh = '';
        }
        mm = ((mm < 10) ? '0' : '') + mm + ':';
        ss = ((ss < 10) ? '0' : '') + ss;
        return hh + mm + ss;
    }

    // ========================================================================
    // Function definitions - URL and parameters
    // ========================================================================

    /**
     * The URL which generated the current page (accommodates variations in
     * browser families).
     *
     * @return {string}
     */
    function currentUrl() {
        return window.location.href || document.documentURI || document.URL;
    }

    /**
     * getUrlParams
     *
     * @param {string} [url]          Default: `currentUrl()`.
     *
     * @return {object}
     */
    function getUrlParameters(url) {
        var result = {};
        var href   = url || currentUrl();
        var pairs  = href.slice(href.indexOf('?') + 1).split('&');
        pairs.forEach(function(key_value) {
            var kv = key_value.split('=');
            result[kv[0]] = kv[1];
        });
        return result;
    }

    /**
     * addParameter
     *
     * @param {string}         url
     * @param {string|object}  key
     * @param {string|boolean} [value]
     * @param {boolean}        [preserve_blanks]
     *
     * @return {string}
     */
    function addParameter(url, key, value, preserve_blanks) {

        // If key is an object it will hold multiple key-value pairs.
        var kv_pairs;
        var pre;
        if (typeof key === 'object') {
            kv_pairs = key;
            pre = isDefined(value) ? value : preserve_blanks;
        } else {
            kv_pairs = {};
            kv_pairs[key] = value;
            pre = preserve_blanks;
        }
        var add_params = {};
        $.each(kv_pairs, function(k, v) {
            add_params[k] = (!v && pre) ? '' : encodeURIComponent(v);
        });

        // Determine whether there is a URL fragment attached.
        var parts = url.toString().split('#');
        var base_url = parts[0];
        var fragment = parts[1];

        // Get the current URL options and update them with the argument(s).
        var params = getUrlParameters(base_url);
        $.extend(params, add_params);

        // Build the result from the base path, the parameters and the fragment
        // if there was one.
        var result = base_url.replace(/\?.*$/, '');
        var separator = '?';
        $.each(params, function(k, v) {
            result += separator + k + '=' + v;
            separator = '&';
        });
        if (fragment) {
            result += '#' + fragment;
        }
        return result;

    }

    /**
     * Indicate whether the session is in print view.
     *
     * @param {string} [url]          Default: `currentUrl()`.
     *
     * @return {boolean}
     */
    function inPrintView(url) {
        return getUrlParameters(url).view === 'print';
    }

    /**
     * Construct a URL from a path and parameters given as an object.
     *
     * @param {string} path
     * @param {object} [parameters]
     *
     * @return {string}
     */
    function makeUrl(path, parameters) {
        var result = path;
        if (isPresent(parameters)) { result += '?' + $.param(parameters); }
        return result;
    }

    // ========================================================================
    // Function definitions - AJAX
    // ========================================================================

    /**
     * @constant
     * @type {string[]}
     */
    var SAFE_METHODS = ['GET', 'HEAD', 'OPTIONS', 'TRACE'];

    /** @type {string} */
    var csrf_token;

    /** @type {string} */
    var csrf_param;

    /**
     * Get the CSRF token from the page.
     *
     * @returns {string}
     */
    function getCsrfToken() {
        if (!csrf_token) {
            csrf_token = $('meta[name="csrf-token"]').attr('content');
        }
        return csrf_token;
    }

    /**
     * Get the CSRF parameter from the page.
     *
     * @returns {string}
     */
    function getCsrfParam() {
        if (!csrf_param) {
            csrf_param = $('meta[name="csrf-param"]').attr('content');
        }
        return csrf_param;
    }

    /**
     * Indicate whether the given HTTP method does not require CSRF protection.
     *
     * @param {string} method
     *
     * @return {boolean}
     */
    function csrfSafeMethod(method) {
        return SAFE_METHODS.indexOf(method.toString().toUpperCase()) >= 0;
    }

    // ========================================================================
    // Function definitions - Element values
    // ========================================================================

    /**
     * Indicate whether the item is not undefined.
     *
     * @param {*} item
     *
     * @return {boolean}
     */
    function isDefined(item) {
        return typeof item !== 'undefined';
    }

    /**
     * Indicate whether the item is not defined.
     *
     * @param {*} item
     *
     * @return {boolean}
     */
    function notDefined(item) {
        return !isDefined(item);
    }

    /**
     * Indicate whether the item does not contain a value.
     *
     * @param {*} item
     *
     * @return {boolean}
     */
    function isEmpty(item) {
        if (!item) {
            return true;
        } else if (isDefined(item.length)) {
            return !item.length;
        } else if (typeof item === 'object') {
            for (var property in item) {
                if (item.hasOwnProperty(property)) {
                    return false;
                }
            }
            return true;
        }
        return false;
    }

    /**
     * Indicate whether the item contains a value.
     *
     * @param {*} item
     *
     * @return {boolean}
     */
    function notEmpty(item) {
        return !isEmpty(item);
    }

    /**
     * Indicate whether the item does not contain a value.
     *
     * @param {*} item
     *
     * @return {boolean}
     */
    function isMissing(item) {
        return isEmpty(item);
    }

    /**
     * Indicate whether the item contains a value.
     *
     * @param {*} item
     *
     * @return {boolean}
     */
    function isPresent(item) {
        return !isMissing(item);
    }

    /**
     * Translate the given value into a non-negative integer.
     *
     * @param {*} value
     *
     * @return {number}
     */
    function ordinal(value) {
        return Rails.to_number(value);
    }

    /**
     * Make a selector out of an array of attributes.
     *
     * @param {string[]} attributes
     *
     * @return {string}
     */
    function attributeSelector(attributes) {
        return '[' + attributes.join('], [') + ']';
    }

    // ========================================================================
    // Function definitions - console output support
    // ========================================================================

    /**
     * Return a string representation of *item*
     *
     * @param {*}              item
     * @param {boolean|number} [max]    If missing or *false* then output is
     *                                    limited to the first 3 elements; if
     *                                    *true* then output is (effectively)
     *                                    not truncated.
     *
     * @return {string}
     */
    function asString(item, max) {
        var max_count = 3;
        switch (typeof max) {
            case 'number':  max_count = max; break;
            case 'boolean': if (max) { max_count = 100; } break;
        }
        var s = '';
        var content, count, excess, value;
        if (item instanceof jQuery) {
            s += '$(' + item.selector + ')[' + item.length + ']';

        } else if (item instanceof Array) {
            content = [];
            excess = item.length - max_count;
            if (excess > 0) {
                for (var i = 0; i < max_count; i++) {
                    value = asString(item[i], max_count);
                    content.push(value);
                }
                content.push('(' + excess + ' more...)');
            } else {
                content =
                    item.map(function(v) { return asString(v, max_count); });
            }
            s += '[' + content.join(', ') + ']';

        } else if (item instanceof Object) {
            content = [];
            count   = 0;
            for (var property in item) {
                if (item.hasOwnProperty(property)) {
                    if (count < max_count) {
                        value = asString(item[property], max_count);
                        content.push(property + ': ' + value);
                    }
                    count += 1;
                }
            }
            excess = count - max_count;
            if (excess > 0) { content.push('(' + excess + ' more...)'); }
            s += '{' + content.join(', ') + '}';

        } else {
            switch (typeof item) {
                case 'function': s += 'function';       break;
                case 'string':   s += '"' + item + '"'; break;
                default:         s += item;             break;
            }
        }
        return s;
    }

    /**
     * Return a string presentation of an array of argument values.
     *
     * @param {IArguments|array|string} args
     * @param {boolean|number}          [max]   See {@link asString}.
     *
     * @return {string}
     */
    function argsString(args, max) {
        var array;
        if (args instanceof Array) {
            array = args;
        } else if (isDefined(Array.from)) {
            array = Array.from(args);
        }
        if (isDefined(array)) {
            return array.map(function(v) {
                return asString(v, max);
            }).join(', ');
        } else {
            return args.toString();
        }
    }

    /**
     * Return a string presentation of an array of argument values.
     *
     * @param {IArguments}     arg
     * @param {boolean|number} [max]  See {@link asString}.
     *
     * @return {string}
     */
    function callString(arg, max) {
        var is_arguments = (typeof arg === 'object') && isDefined(arg.callee);
        var prefix = is_arguments ? arg.callee.name : '';
        var args   = argsString(arg, max);
        return (prefix && args) ? (prefix + ': ' + args) : (prefix || args);
    }

    // ========================================================================
    // Function definitions - HTML
    // ========================================================================

    /**
     * Produce a link that opens a new browser tab.
     *
     * @param {string|jQuery} label   Text or HTML element.
     * @param {string}        url
     * @param {object}        [opt]   HTML element parameters.
     *
     * A tooltip (and aria-label) will be generated from the link text if not
     * otherwise provided via *opt*.
     *
     * If *opt.title* is **false** then no tooltip will be added.
     *
     * @return {jQuery}
     */
    function outlink(label, url, opt) {

        var options = {
            href:   url,
            target: '_blank'
        };
        if (isPresent(opt)) {
            $.extend(options, opt);
        }

        var $link = $('<a>');
        var text;
        if (typeof label === 'object') {
            $(label).appendTo($link);
        } else if (typeof label === 'string') {
            $link.text(label);
            text = label;
        }

        var tooltip;
        switch (options.title) {
            case false: delete options.title;              break;
            case true:  tooltip = text || 'External link'; break;
            default:    tooltip = options.title;           break;
        }
        if (tooltip) {
            options.title = tooltip + ' (opens in a new window)';
            options['aria-label'] = options['aria-label'] || tooltip;
        }

        return $link.attr(options);
    }

    /**
     * Screen-reader-only content element.  If *content* is blank then the
     * resulting element is returned with 'aria-hidden="true"'.
     *
     * @param {string|jQuery} content
     *
     * @return {jQuery}
     */
    function srOnly(content) {
        var $result = $('<span>').addClass('sr-only');
        if (isPresent(content)) {
            $result.html(content);
        } else {
            $result.attr('aria-hidden', true);
        }
        return $result;
    }

    // ========================================================================
    // Function definitions - Browser properties
    // ========================================================================

    /**
     * Get a displayable representation of a key press.
     *
     * @param {CHAR} key
     * @param {CHAR} [modifier]
     *
     * @return {string}
     */
    function keyName(key, modifier) {
        var result = '';
        switch (modifier) {
            case CHAR.Shift: result += 'SHIFT'; break;
            case CHAR.Ctrl:  result += 'CTRL';  break;
            case CHAR.Alt:   result += 'ALT';   break;
        }
        if (result) { result += '+'; }
        switch (key) {
            case CHAR.Backspace:  result += 'BS  '; break;
            case CHAR.Tab:        result += 'TAB '; break;
            case CHAR.Enter:      result += 'CR  '; break;
            case CHAR.CapsLock:   result += 'CAPS'; break;
            case CHAR.Escape:     result += 'ESC '; break;
            case CHAR.Space:      result += 'SP  '; break;
            case CHAR.PageUp:     result += 'PGUP'; break;
            case CHAR.PageDown:   result += 'PGDN'; break;
            case CHAR.End:        result += 'END '; break;
            case CHAR.Home:       result += 'HOME'; break;
            case CHAR.ArrowLeft:  result += '<LFT'; break;
            case CHAR.ArrowUp:    result += 'UP  '; break;
            case CHAR.ArrowDown:  result += 'DOWN'; break;
            case CHAR.ArrowRight: result += 'RGT>'; break;
            default:              result += '(' + key.toString() + ')'; break;
        }
        return result;
    }

    /**
     * The family name of the current web browser.
     *
     * @return {string}
     */
    function getUserAgent() {
        var ua = navigator.userAgent;
        if (ua.indexOf(UA_MARKER.Firefox) >= 0) {
            return UA.Firefox;
        } else if (ua.indexOf(UA_MARKER.Edge) >= 0) {
            return UA.Edge;
        } else if (ua.indexOf(UA_MARKER.Chrome) >= 0) {
            return UA.Chrome;
        } else if (ua.indexOf(UA_MARKER.Safari) >= 0) {
            return UA.Safari;
        } else if (ua.indexOf(UA_MARKER.IE) >= 0) {
            return UA.IE;
        }
        return ua;
    }

    /**
     * Get properties of the browser display.
     *
     * @return {object}
     *
     * @property {string} user_agent
     * @property {number} screen_width
     * @property {number} screen_height
     * @property {number} window_width
     * @property {number} window_height
     * @property {number} client_width
     * @property {number} client_height
     * @property {number} width
     * @property {number} height
     * @property {number} scroll_width
     * @property {number} scroll_height
     */
    function browserProperties() {
        var s  = screen;
        var w  = window;
        var d  = document.documentElement;
        var sw = s.width;
        var sh = s.height;
        var ww = w.innerWidth;
        var wh = w.innerHeight;
        var cw = d.scrollWidth;
        var ch = d.scrollHeight;
        return {
            user_agent:    getUserAgent(),
            screen_width:  sw,
            screen_height: sh,
            window_width:  ww,
            window_height: wh,
            client_width:  cw,
            client_height: ch,
            width:         Math.min(sw, ww, cw),
            height:        Math.min(sh, wh, ch),
            scroll_width:  (w.outerWidth  - ww),
            scroll_height: (w.outerHeight - wh)
        };
    }

    /**
     * Indicate whether the display has the given property value.
     *
     * @param {string} property
     * @param {string} value
     *
     * @returns {boolean}
     */
    function displayHas(property, value) {
        var media_query = '(' + property + ': ' + value + ')';
        return window.matchMedia(media_query).matches;
    }

    /**
     * Indicate whether the window is narrow (either because the window has
     * been manually resized or the display is on a mobile device).
     *
     * @returns {boolean}
     */
    function shortScreen() {
        return window.innerHeight < SMALL_HEIGHT;
    }

    /**
     * Indicate whether the window is narrow (either because the window has
     * been manually resized or the display is on a mobile device).
     *
     * @returns {boolean}
     */
    function narrowScreen() {
        return window.innerWidth < SMALL_WIDTH;
    }

    /**
     * Indicate whether the window is small (either because the window has been
     * manually resized or the display is on a mobile device).
     *
     * @returns {boolean}
     */
    function smallScreen() {
        return shortScreen() || narrowScreen();
    }

    // ========================================================================
    // Function definitions - Accessibility
    // ========================================================================

    /**
     * @constant
     * @type {string[]}
     */
    var FOCUS_ELEMENTS =
        ['a', 'area', 'button', 'input', 'select', 'textarea'];

    /**
     * @constant
     * @type {string}
     */
    var FOCUS_ELEMENTS_SELECTOR = FOCUS_ELEMENTS.join(', ');

    /**
     * @constant
     * @type {string[]}
     */
    var FOCUS_ATTRIBUTES =
        ['href', 'controls', 'data-path', 'draggable', 'tabindex'];

    /**
     * @constant
     * @type {string}
     */
    var FOCUS_ATTRIBUTES_SELECTOR = attributeSelector(FOCUS_ATTRIBUTES);

    /**
     * @constant
     * @type {string}
     */
    var FOCUS_SELECTOR =
        FOCUS_ELEMENTS_SELECTOR + ', ' + FOCUS_ATTRIBUTES_SELECTOR;

    /**
     * @constant
     * @type {string[]}
     */
    var NO_FOCUS_ATTRIBUTES = ['tabindex="-1"'];

    /**
     * @constant
     * @type {string}
     */
    var NO_FOCUS_SELECTOR = attributeSelector(NO_FOCUS_ATTRIBUTES);

    /**
     * @constant
     * @type {string}
     */
    var KEYPRESS_PROP = 'keypress-click';

    /**
     * @constant
     * @type {string}
     */
    var TABINDEX_PROP = 'original-tabindex';

    /**
     * Used internally by {@link handleKeypressAsClick}.
     *
     * @param {Event} event
     */
    function hkacKeyHandler(event) {
        var key = event.keyCode || event.which;
        if (key === CHAR.Enter) {
            var $target  = $(event.target || this);
            var href     = $target.attr('href');
            if (!href || (href === '#')) {
                $target.prop(KEYPRESS_PROP, key).click().focusin();
                return false;
            }
        }
    }

    /**
     * For "buttons" or "links" which are not <a> tags (or otherwise don't
     * respond by default to a carriage return as an equivalent to a click).
     *
     * @param {Selector}       selector  Specification of node(s) containing
     *                                     elements which must respond to a
     *                                     carriage return like a mouse click.
     *
     * @param {boolean}        [direct]  If *true* then the target is the nodes
     *                                     indicated by *selector* and not the
     *                                     descendents of those nodes.
     *
     * @param {string|boolean} [match]   If *false* then $(selector) specifies
     *                                     the target elements directly; if
     *                                     *true* or missing then all focusable
     *                                     elements at or below $(selector) are
     *                                     chosen; if a string then it is used
     *                                     instead of FOCUS_ATTRIBUTES_SELECTOR
     *
     * @param {string|boolean} [except]  If *false* then all matches are
     *                                     chosen; otherwise elements matching
     *                                     FOCUS_ELEMENTS_SELECTOR are
     *                                     eliminated.  In either case,
     *                                     elements with tabindex == -1 are
     *                                     skipped. Default: elements like <a>.
     *
     * @return {jQuery}
     *
     * @see {@link nodeHandleKeypressAsClick}
     * @see {@link treeHandleKeypressAsClick}
     */
    function handleKeypressAsClick(selector, direct, match, except) {

        // Determine the target(s) based on the *direct* argument.
        var $elements = (typeof selector === 'number') ? $(this) : $(selector);

        // Apply match criteria to select all elements that would be expected
        // to receive a keypress based on their attributes.
        var criteria = [];
        if (match && (typeof match === 'string')) {
            criteria.push(match);
        } else if (direct || (match === true) || notDefined(match)) {
            criteria.push(FOCUS_ATTRIBUTES_SELECTOR);
        }
        if (isPresent(criteria)) {
            var sel = criteria.join(', ');
            $elements = direct ? $elements.filter(sel) : $elements.find(sel);
        }

        // Ignore elements that won't be reached by tabbing to them.
        var exceptions = [NO_FOCUS_SELECTOR];
        if (except && (typeof except === 'string')) {
            exceptions.push(except);
        }
        if (isPresent(exceptions)) {
            $elements = $elements.not(exceptions.join(', '));
        }

        // Attach the handler to any remaining elements, ensuring that the
        // handler is not added twice.
        var evt = 'keydown';
        return $elements.off(evt, hkacKeyHandler).on(evt, hkacKeyHandler);
    }

    /**
     * Attach the keypress handler to the node(s) indicated by *selector*.
     *
     * As a convenience, if the argument is a number then this is interpreted
     * as meaning that the function is being run as the argument to the jQuery
     * .each() function.
     *
     * @param {Selector|number} selector
     *
     * @return {jQuery}
     *
     * @see {@link handleKeypressAsClick}
     */
    function nodeHandleKeypressAsClick(selector) {
        var $target = (typeof selector === 'number') ? $(this) : $(selector);
        return handleKeypressAsClick($target, true);
    }

    /**
     * Attach the keypress handler to the node(s) indicated by *selector* as
     * well as to any descendents.
     *
     * As a convenience, if the argument is a number then this is interpreted
     * as meaning that the function is being run as the argument to the jQuery
     * .each() function.
     *
     * @param {Selector|number} selector
     *
     * @return {jQuery}
     *
     * @see {@link handleKeypressAsClick}
     */
    function treeHandleKeypressAsClick(selector) {
        var $target = (typeof selector === 'number') ? $(this) : $(selector);
        handleKeypressAsClick($target, true);
        handleKeypressAsClick($target, false);
        return $target;
    }

    /**
     * Given the set of elements referenced by the selector, find the active
     * links within the elements and their descendents.
     *
     * @param {Selector} [selector]     Default: 'body'.
     *
     * @return {jQuery}
     */
    function focusableElements(selector) {
        var $root  = $(selector || 'body');
        var $self  = $root.filter(FOCUS_SELECTOR).not(NO_FOCUS_SELECTOR);
        var $child = $root.find(FOCUS_SELECTOR).not(NO_FOCUS_SELECTOR);
        return $($self.toArray().concat($child.toArray()));
    }

    /**
     * Given the set of elements referenced by the selector, find the active
     * links within the elements and their descendents.
     *
     * @param {Selector} [selector]     Default: 'body'.
     *
     * @return {jQuery}
     */
    function activeLinks(selector) {
        return focusableElements(selector).filter(':visible');
    }

    /**
     * Given the set of elements referenced by the selector, find the first
     * element or child with an active link.
     *
     * @param {Selector} [selector]     Default: 'body'.
     *
     * @return {jQuery|undefined}
     */
    function firstActiveLink(selector) {
        var $result;
        var $link = activeLinks(selector).first();
        if (isPresent($link)) { $result = $link; }
        return $result;
    }
}
