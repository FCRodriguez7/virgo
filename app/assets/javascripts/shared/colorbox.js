// app/assets/javascripts/shared/colorbox.js
//
// Initializations for jquery.colorbox.

//= require jquery.colorbox
//= require shared/definitions

/** @type {DebugEntry} */
var debugColorbox =
    ModuleDebug.add('shared/colorbox', 'COLORBOX', { all: DEVELOPMENT });

/**
 * Colorbox setup.
 *
 * @type {object}
 *
 * @property {function} updatePage
 * @property {function} settings
 * @property {function} defaultRoot
 * @property {function} defaultSelector
 * @property {function} suppress
 * @property {function} enabled
 * @property {function} onOpen
 * @property {function} onLoad
 * @property {function} onComplete
 * @property {function} onCleanup
 * @property {function} onClosed
 * @property {function} debugFocusIn
 */
var AppColorbox = (function(module_debug) {

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
     * @type {boolean}
     */
    var FEATURE_ENABLED = true;

    /**
     * Modal dialog operations.
     *
     * @readonly
     * @enum {number}
     */
    var ACTION = {
        Init:      0,
        ShowModal: 1,
        HideModal: 2
    };

    // ========================================================================
    // Variables
    // ========================================================================

    /** @type {boolean} */
    var suppressed = !FEATURE_ENABLED;

    /**
     * If true, setup of Colorbox has already occurred.
     *
     * @type {boolean}
     */
    var colorbox_initialized;

    /**
     * Elements on the page which are eligible to acquire keyboard focus.
     *
     * @type {jQuery}
     */
    var $focus_elements = $();

    // ========================================================================
    // Internal functions
    // ========================================================================

    /**
     * The current tree of elements within the modal dialog.
     *
     * This should typically not be cached because it will be different with
     * each invocation of Colorbox on the page.
     *
     * @return {jQuery}
     */
    function modalDialog() {
        return $('#cboxWrapper');
    }

    // ========================================================================
    // Internal functions - focus
    // ========================================================================

    /**
     * @constant
     * @type {string}
     */
    var TABINDEX_PROP = 'original-tabindex';

    /**
     * Remember the original 'tabindex' value for the item.
     *
     * @param {number|Selector} [index]
     * @param {Selector}        [element]
     *
     * @example Called from $.each() with both arguments filled.
     * @example Called directly a single selector argument.
     * @example Called with no arguments.
     *
     * @return {string|undefined}
     */
    function saveTabindex(index, element) {
        var $this    = $(element || index || this);
        var tabindex = $this.attr('tabindex');
        if (isDefined(tabindex)) {
            $this.prop(TABINDEX_PROP, tabindex);
        }
        return tabindex;
    }

    /**
     * Restore the original 'tabindex' value for the item.
     *
     * @param {number|Selector} [index]
     * @param {Selector}        [element]
     *
     * @example Called from $.each() with both arguments filled.
     * @example Called directly a single selector argument.
     * @example Called with no arguments.
     *
     * @return {string|undefined}
     */
    function restoreTabindex(index, element) {
        var $this    = $(element || index || this);
        var original = $this.prop(TABINDEX_PROP);
        if (isDefined(original)) {
            $this.attr('tabindex', original);
        } else {
            $this.removeAttr('tabindex');
        }
        return original;
    }

    /**
     * Ensure that tab events are only seen by the Colorbox popup.
     *
     * @param {ACTION}   action
     * @param {Selector} [root]       Default: {@link defaultRoot}()
     * @param {Selector} [selector]   Default: {@link defaultSelector}()
     */
    function captureFocus(action, root, selector) {
        _debug(arguments);
        switch (action) {
            case ACTION.Init:
                var $root = root ? $(root) : defaultRoot();
                $focus_elements = $root.find(selector || defaultSelector());
                $focus_elements.each(saveTabindex);
                break;
            case ACTION.ShowModal:
                if (isMissing($focus_elements)) {
                    captureFocus(ACTION.Init, root);
                }
                $focus_elements.filter(':visible').attr('tabindex', -1);
                modalDialog().focus();
                break;
            case ACTION.HideModal:
                $focus_elements.filter(':visible').each(restoreTabindex);
                modalDialog().blur();
                break;
            default:
                console.error('unexpected action: ' + action);
                break;
        }
    }

    // ========================================================================
    // Internal functions - user select
    // ========================================================================

    /**
     * @constant
     * @type {string[]}
     */
    var BROWSER_PREFIXES = ['', '-ms-', '-moz-', '-webkit-'];

    /**
     * @constant
     * @type {string}
     */
    var USER_SELECT_PROP = 'original-user-select';

    /** @type {string} */
    var attr_user_select;

    /**
     * Return the browser-specific attribute of 'user-select'.
     *
     * @return {string}
     */
    function attrUserSelect() {
        if (notDefined(attr_user_select)) {
            var $root = defaultRoot();
            $.each(BROWSER_PREFIXES, function(idx, prefix) {
                var value;
                var attr = prefix + 'user-select';
                try { value = $root.css(attr); }
                catch (e) { /* Ignore "not a valid attribute name". */ }
                if (isDefined(value)) {
                    if (value === 'auto') {
                        $root.css(attr, 'text');
                    }
                    attr_user_select = attr;
                    return false; // break from $.each()
                }
            });
        }
        return attr_user_select;
    }

    /**
     * Remember the original 'user-select' value for the item.
     *
     * @param {jQuery} $root
     *
     * @return {string}
     */
    function getUserSelect($root) {
        return $root.css(attrUserSelect()) || '';
    }

    /**
     * Update the 'user-select' value for the item.
     *
     * @param {jQuery}         $root
     * @param {string|boolean} [new_value]      Default: 'text'
     *
     * @return {string}
     */
    function setUserSelect($root, new_value) {
        var value;
        if (new_value === false) {
            value = 'none';
        } else if (new_value && (typeof new_value === 'string')) {
            value = new_value;
        }
        if (!value) {
            value = 'text';
        }
        $root.css(attrUserSelect(), value);
        return value;
    }

    /**
     * Remember the original 'user-select' value for the item.
     *
     * @param {jQuery} $root
     *
     * @return {string}
     */
    function saveUserSelect($root) {
        var value = getUserSelect($root);
        $root.prop(USER_SELECT_PROP, value);
        return value;
    }

    /**
     * Restore the original 'user-select' value for the item.
     *
     * @param {jQuery}         $root
     * @param {string|boolean} [fallback]  Fall-back value; default: 'text'
     *
     * @return {string}
     */
    function restoreUserSelect($root, fallback) {
        var value = $root.prop(USER_SELECT_PROP) || fallback;
        $root.removeProp(USER_SELECT_PROP);
        return setUserSelect($root, value);
    }

    /**
     * Ensure that selection events (e.g., Ctrl-A for "select all") are only
     * seen by the Colorbox popup.
     *
     * @param {ACTION}         action
     * @param {Selector}       [root]      Default: {@link defaultRoot}()
     * @param {string|boolean} [new_value] Default: ENABLE: 'none'; DISABLE: ''
     */
    function captureSelect(action, root, new_value) {
        _debug(arguments);
        var $root = root ? $(root) : defaultRoot();
        switch (action) {
            case ACTION.Init:
                // Currently a no-op.
                break;
            case ACTION.ShowModal:
                // Backup the current setting then turn off selection for the
                // elements within $root.
                saveUserSelect($root);
                var value = isDefined(new_value) ? new_value : 'none';
                setUserSelect($root, value);
                break;
            case ACTION.HideModal:
                restoreUserSelect($root, new_value);
                break;
            default:
                console.error('unexpected action: ' + action);
                break;
        }
    }

    // ========================================================================
    // Internal functions - scrolling
    // ========================================================================

    /**
     * @constant
     * @type {string}
     */
    var SCROLL_ROOT = 'html';

    /**
     * @constant
     * @type {string}
     */
    var NO_SCROLL_MARKER = 'no-scroll';

    /**
     * Ensure that mouse wheel events are only seen by the Colorbox popup.
     *
     * @param {ACTION}   action
     * @param {Selector} [scroll_root]  Default: {@link SCROLL_ROOT}
     * @param {string}   [marker]       Default: {@link NO_SCROLL_MARKER}
     */
    function captureScrolling(action, scroll_root, marker) {
        _debug(arguments);
        var $root     = $(scroll_root || SCROLL_ROOT);
        var no_scroll = marker || NO_SCROLL_MARKER;
        switch (action) {
            case ACTION.Init:      /* Currently a no-op. */         break;
            case ACTION.ShowModal: $root.addClass(no_scroll);       break;
            case ACTION.HideModal: $root.removeClass(no_scroll);    break;
            default: console.error('unexpected action: ' + action); break;
        }
    }

    // ========================================================================
    // Internal function definitions
    // ========================================================================

    /**
     * Setup global Colorbox defaults.
     *
     * @param {object} [colorbox]     Default: $.fn.colorbox
     * @param {object} [options]      Passed into Colorbox settings.
     *
     * @return {boolean}              Always *true*.
     *
     * @see vendor/assets/javascripts/jquery.colorbox.js:59
     */
    function initializeColorbox(colorbox, options) {
        _trace(arguments);

        var cbox = colorbox || $.fn.colorbox;

        // Global Colorbox defaults.
        $.extend(cbox.settings, settings(options));

        // Make an open Colorbox respond to window resizing.
        $(window).resize(function() {
            if ($('#cboxOverlay').is(':visible')) {
                cbox.load();
            }
        });

        return true;
    }

    /**
     * Prepare internal data.
     *
     * @param {Selector} [root]       Default: {@link defaultRoot}()
     */
    function initialize(root) {
        _trace(arguments);
        captureFocus(ACTION.Init, root);
        captureSelect(ACTION.Init, root);
        captureScrolling(ACTION.Init);
        if (_debugging) { debugFocusIn(root); }
    }

    // ========================================================================
    // Function definitions
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
     * The current tree of elements on the page.
     *
     * This should typically not be cached because it will be different with
     * each invocation of Colorbox on the page.
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
        return FOCUS_SELECTOR;
    }

    /**
     * Update the page.
     *
     * @param {Selector} [root]       Default: {@link defaultRoot}()
     */
    function updatePage(root) {
        _trace(arguments);
        if (enabled()) {
            if (!colorbox_initialized) {
                colorbox_initialized = initializeColorbox();
            }
            initialize(root);
        }
    }

    /**
     * settings
     *
     * @param {string} [caller]
     * @param {object} [options]
     *
     * @return {object}
     */
    function settings(caller, options) {
        _trace(arguments);
        var name = caller || debugColorbox.feature_name;
        var result = {
            opacity:    0.7,
            maxHeight:  '90%',
            maxWidth:   '95%',
            previous:   asButton('&laquo;&thinsp;Previous'),
            next:       asButton('Next&thinsp;&raquo;'),
            close:      asButton('Close'),
            onOpen:     function() { onOpen(name);     },
            onLoad:     function() { onLoad(name);     },
            onComplete: function() { onComplete(name); },
            onCleanup:  function() { onCleanup(name);  },
            onClosed:   function() { onClosed(name);   }
        };
        return isPresent(options) ? $.extend(result, options) : result;
    }

    /**
     * If a function invokes Colorbox and defines an onOpen handler, the
     * handler should run this function first.
     *
     * @param {string} [caller]       For debug messages.
     */
    function onOpen(caller) {
        _trace(arguments);
    }

    /**
     * If a function invokes Colorbox and defines an onLoad handler, the
     * handler needs to run this function to ensure that the window behind the
     * popup does not respond to events that the user would assume are limited
     * to the popup.
     *
     * @param {string} [caller]       For debug messages.
     */
    function onLoad(caller) {
        _trace(arguments);
        captureFocus(ACTION.ShowModal);
        captureSelect(ACTION.ShowModal);
        captureScrolling(ACTION.ShowModal);
    }

    /**
     * If a function invokes Colorbox and defines an onComplete handler, the
     * handler should run this function to ensure that copy/paste selections
     * can be made within the modal dialog.
     *
     * @param {string} [caller]       For debug messages.
     */
    function onComplete(caller) {
        _trace(arguments);
        var $dialog = modalDialog();
        captureSelect(ACTION.HideModal, $dialog);
        captureSelect(ACTION.ShowModal, $dialog.find('[role="button"]'));
        handleKeypressAsClick($dialog);
        $('#cboxIframe').attr('aria-label', 'Modal dialog box');
        if (_debugging) { debugFocusIn($dialog); }
    }

    /**
     * If a function invokes Colorbox and defines an onCleanup handler, the
     * handler should run this function first.
     *
     * @param {string} [caller]       For debug messages.
     */
    function onCleanup(caller) {
        _trace(arguments);
    }

    /**
     * If a function invokes Colorbox and defines an onClosed handler, it needs
     * to run this function to restore the page to its pre-onLoad() state.
     *
     * @param {string} [caller]       For debug messages.
     */
    function onClosed(caller) {
        _trace(arguments);
        captureFocus(ACTION.HideModal);
        captureSelect(ACTION.HideModal);
        captureScrolling(ACTION.HideModal);
    }

    /**
     * Wrap text in an <a> tag.
     *
     * @param {string} s              HTML content to wrap.
     * @param {string} [css_class]    Default: 'cbox-button'.
     *
     * @returns {string}
     */
    function asButton(s, css_class) {
        var css = css_class || 'cbox-button';
        return '<a href="#" class="' + css + '" role="button">' + s + '</a>';
    }

    /**
     * Attach console output handlers to the focusIn event on elements below
     * the given root element.
     *
     * @param {Selector} [root]       Default: {@link defaultRoot}()
     * @param {Selector} [selector]   Default: {@link defaultSelector}()
     */
    function debugFocusIn(root, selector) {
        var $root     = root ? $(root) : defaultRoot();
        var $elements = $root.find(selector || defaultSelector());
        _debug(arguments, ('[element count: ' + $elements.length + ']'));
        $elements.focusin(function(event) {
            var tgt  = event.target;
            var type = tgt.localName;
            var node = [];
            node.push('<' + type + '>');
            node.push(tgt.className);
            node.push('"' + (tgt.text || tgt.title) + '"');
            if (FOCUS_ELEMENTS.indexOf(type) < 0) {
                console.warn('FOCUS IN: ' + node.join(' '));
            } else {
                console.log('FOCUS IN: ' + node.join(' '));
            }
        });
    }

    // ========================================================================
    // Feature initialization
    // ========================================================================

    $(document).ready(function() {
        _trace(enabled() ? 'enabled' : 'disabled');
    });

    // ========================================================================
    // Exposed definitions
    // ========================================================================

    return {
        updatePage:      updatePage,
        settings:        settings,
        defaultRoot:     defaultRoot,
        defaultSelector: defaultSelector,
        suppress:        suppress,
        enabled:         enabled,
        onOpen:          onOpen,
        onLoad:          onLoad,
        onComplete:      onComplete,
        onCleanup:       onCleanup,
        onClosed:        onClosed,
        debugFocusIn:    debugFocusIn
    };

})(debugColorbox);
