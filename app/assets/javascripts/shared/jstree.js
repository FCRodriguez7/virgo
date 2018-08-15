// app/assets/javascripts/shared/jstree.js
//
// Initializations for jquery.jstree.

//= require jquery.jstree
//= require jquery.hotkeys
//= require shared/definitions

/** @type {DebugEntry} */
var debugJstree =
    ModuleDebug.add('shared/jstree', 'JSTREE', { trace: DEVELOPMENT });

/**
 * Set up jstree.
 *
 * @type {object}
 *
 * @property {function} settings
 * @property {function} keyPress
 * @property {function} motion
 * @property {function} suppress
 * @property {function} enabled
 */
var AppJstree = (function(module_debug) {

    /** @type {boolean} */
    var _debugging = module_debug.debugging;

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
    var FEATURE_ENABLED = true;

    /**
     * Actions for navigation() and keyHandler().
     *
     * @readonly
     * @enum {number}
     */
    var ACTION = {
        Ignored:    0,
        Next:       1,
        Prev:       2,
        Open:       3,
        Close:      4
    };

    /**
     * Shared jstree initial settings.
     *
     * @constant
     * @type {object}
     */
    var jstree_options = {
        core: {
            // TBD
        },
        json_data: {
            // TBD
        },
        themes: {
            // TBD
        },
        ui: {
            select_limit:             1,
            select_multiple_modifier: 'alt'
        },
        hotkeys: {
            // These override the defaults for the plugin (except for 'space',
            // 'ctrl+space' and 'shift+space') plus some key combinations that
            // are provided by the jQuery plugin but do not have defaults
            // ('backspace', 'tab', 'shift+tab').
            //
            // @see vendor/assets/javascripts/jquery.hotkeys.js
            //
            // @note Find a way to honor 'tab' only if the tree has focus.
            //
            //'backspace':   function() { return motion(ACTION.Prev,  this) },
            //'tab':         function() { return motion(ACTION.Next,  this) },
            //'shift+tab':   function() { return motion(ACTION.Prev,  this) },
            'up':          function() { return motion(ACTION.Prev,  this) },
            'ctrl+up':     function() { return motion(ACTION.Prev,  this) },
            'shift+up':    function() { return motion(ACTION.Prev,  this) },
            'down':        function() { return motion(ACTION.Next,  this) },
            'ctrl+down':   function() { return motion(ACTION.Next,  this) },
            'shift+down':  function() { return motion(ACTION.Next,  this) },
            'left':        function() { return motion(ACTION.Close, this) },
            'ctrl+left':   function() { return motion(ACTION.Close, this) },
            'shift+left':  function() { return motion(ACTION.Close, this) },
            'right':       function() { return motion(ACTION.Open,  this) },
            'ctrl+right':  function() { return motion(ACTION.Open,  this) },
            'shift+right': function() { return motion(ACTION.Open,  this) },
            f2:            false,
            del:           false
        },
        cookies: {
            // TBD
        },
        dnd: {
            drag_target: false,
            drop_target: false
        },
        plugins: ['json_data', 'themes', 'ui', 'hotkeys']
    };

    // ========================================================================
    // Variables
    // ========================================================================

    /** @type {boolean} */
    var suppressed = !FEATURE_ENABLED;

    // ========================================================================
    // Function definitions
    // ========================================================================

    /**
     * Suppress this feature.
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
     * The settings for all jstree plugins are merged recursively.  The caller
     * does not need to provide a "plugins" element; additional plugins will be
     * inferred from the keys that are present in *options*.
     *
     * @param {string} [caller]
     * @param {object} [options]
     *
     * @return {object}
     */
    function settings(caller, options) {
        _trace(arguments);
        var result = $.extend(true, {}, jstree_options);
        if (isPresent(options)) {
            var plugins = $.merge([], result.plugins);
            var opt_plugins = options.plugins || Object.keys(options) || [];
            opt_plugins.forEach(function(key) {
                if ((key !== 'plugins') && (plugins.indexOf(key) === -1)) {
                    plugins.push(key);
                }
            });
            $.extend(true, result, options);
            result.plugins = plugins;
        }
        return result;
    }

    /**
     * Move tree focus based on the given key combination.
     *
     * @param {CHAR}   key
     * @param {object} [tree_instance]
     *
     * @return {boolean}              Always *false*.
     */
    function keyPress(key, tree_instance) {
        _debug(arguments, ('[keyName ' + keyName(key) + ']'));
        var action;
        switch (key) {
            case CHAR.Backspace:  action = ACTION.Prev;  break;
            case CHAR.Tab:        action = ACTION.Next;  break;
            case CHAR.ArrowDown:  action = ACTION.Next;  break;
            case CHAR.ArrowRight: action = ACTION.Open;  break;
            case CHAR.ArrowUp:    action = ACTION.Prev;  break;
            case CHAR.ArrowLeft:  action = ACTION.Close; break;
        }
        if (action) {
            motion(action, tree_instance);
        }
        return false;
    }

    /**
     * Move tree focus based on the given action.
     *
     * @param {ACTION} action
     * @param {object} [tree_instance]
     *
     * @return {boolean}              Always *false*.
     */
    function motion(action, tree_instance) {
        _debug(arguments);
        var tree = tree_instance || $.jstree._focused();
        var $cur = tree.data.ui.hovered || tree.data.ui.last_selected;
        var node;
        switch (action) {
            case ACTION.Open:
                if ($cur && $cur.hasClass('jstree-closed')) {
                    tree.open_node($cur);
                    break;
                }
                // Fall through
            case ACTION.Next:
                node = tree._get_next($cur || -1);
                break;
            case ACTION.Close:
                if ($cur && $cur.hasClass('jstree-open')) {
                    tree.close_node($cur);
                    break;
                }
                // Fall through
            case ACTION.Prev:
                node = tree._get_prev($cur || -1);
                break;
        }
        if (isPresent(node)) {
            tree.hover_node(node);
            var $new = tree.data.ui.hovered;
            if (isPresent($new)) {
                if (!$new.is($cur)) { $cur.children('a').blur(); }
                $new.children('a').focus();
            }
        }
        return false;
    }

    // ========================================================================
    // Feature initialization
    // ========================================================================

    $(document).ready(function() {
        _trace(enabled() ? 'enabled' : 'disabled');
    });

    if (enabled()) {
        // Giving a value for _themes first prevents jstree from uselessly
        // requesting "/themes/default/style.css" as it runs through the set of
        // possible locations for the file.
        $.jstree._themes = '/assets/themes/';

        // This is the default for later versions of jstree.
        $.jstree.defaults.core.animation = 200 * MILLISECONDS;
    }

    // ========================================================================
    // Exposed definitions
    // ========================================================================

    return {
        settings:   settings,
        keyPress:   keyPress,
        motion:     motion,
        suppress:   suppress,
        enabled:    enabled
    };

})(debugJstree);
