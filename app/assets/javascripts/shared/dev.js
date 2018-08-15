// app/assets/javascripts/shared/dev.js
//
// Utility methods for debugging.

//= require shared/definitions

/**
 * @typedef DebugEntry
 *
 * @type {object}
 *
 * @property {string}   feature_name
 * @property {number}   start_time
 * @property {boolean}  tracing
 * @property {boolean}  debugging
 * @property {function} error
 * @property {function} warn
 * @property {function} trace
 * @property {function} debug
 * @property {function} logMsg
 * @property {function} nullMsg
 */
var DebugEntry;

/**
 *  Global table of debug instances.
 *
 *  @type {object}
 *
 *  @property {function} add
 */
var ModuleDebug = (function() {

    /**
     * Module debug instances.
     * @type {{ string: DebugEntry }}
     */
    var instance = {};

    // ========================================================================
    // Function definitions
    // ========================================================================

    /**
     * Create a debug entry unless it already exists.
     *
     * @param {string}         file             Name of calling source file.
     * @param {string}         [feature]        Log message prefix.
     * @param {boolean|object} [set_tracing]    Default: *false*.
     * @param {boolean}        [set_debugging]  Default: value of set_tracing.
     *
     * @return {DebugEntry}
     */
    function add(file, feature, set_tracing, set_debugging) {
        var name  = feature || file.replace(/^([^\/]*\/)*/, '').toUpperCase();
        var entry = instance[name];
        if (isPresent(entry)) {
            console.warn('ModuleDebug: ' + name + ': already present');
        } else {
            entry = create(name, set_tracing, set_debugging);
            instance[name] = entry;
        }
        entry.trace('INCLUDING ' + file);
        return entry;
    }

    /**
     * Turn on/off console debugging messages for a given feature.
     *
     * If *set_tracing* and *set_debugging* are both missing or false then
     * there is no log output for that feature.  If *set_debugging* is true
     * then *set_tracing* will be set to true unconditionally.
     *
     * @param {string}         [feature]        Log message prefix.
     * @param {boolean|object} [set_tracing]    Default: *false*.
     * @param {boolean}        [set_debugging]  Default: value of set_tracing.
     *
     * @return {DebugEntry}
     */
    function create(feature, set_tracing, set_debugging) {

        /**
         * The name of the controlling feature.
         *
         * @type {string}
         */
        var feature_name = feature || '';

        /** @type {boolean} */
        var debugging;

        /** @type {boolean} */
        var tracing;

        if (typeof set_tracing === 'object') {
            var set = set_tracing;
            if (isDefined(set.all))   { debugging = tracing = set.all; }
            if (isDefined(set.debug)) { debugging = set.debug; }
            if (isDefined(set.trace)) { tracing   = set.trace; }
        } else {
            debugging = set_debugging;
            tracing   = set_tracing;
        }
        if (notDefined(debugging)) { debugging = false; }
        if (notDefined(tracing))   { tracing   = debugging; }

        /** @type {number} */
        var start_time = Date.now();

        // ====================================================================
        // Function definitions
        // ====================================================================

        /**
         * Produce a console log message.
         *
         * @param {string|IArguments} label
         * @param {...object}         [args]
         */
        function logMsg(label, args) {

            var message   = feature_name;
            var separator = ': ';
            if (message) { message += separator; }
            var is_arguments = (typeof label === 'object') && label.callee;

            // If the label uses printf format and there's only one additional
            // argument then assume that console.log() formatting will be used.
            // Otherwise, format additional arguments according to their type.
            if (isMissing(args)) {
                message += is_arguments ? callString(label) : label;
                console.log(message);
            } else {
                var values = (args instanceof Array) ? args : [args];
                var formatted =
                    !is_arguments &&
                    (values.length === 1) &&
                    (message.indexOf('%') >= 0);
                if (formatted) {
                    console.log(message, values[0]);
                } else {
                    if (is_arguments) {
                        var max;
                        switch (typeof values[0]) {
                            case 'number':
                            case 'boolean':
                                max = values.shift();
                                break;
                        }
                        message += callString(label, max);
                    } else {
                        message += label;
                    }
                    if (isPresent(values)) {
                        if (message.charAt(message.length - 1) !== "\n") {
                            message += separator;
                        }
                        message +=
                            values.map(function(v) {
                                switch (typeof v) {
                                    case 'function': return v();
                                    case 'object':   return JSON.stringify(v);
                                    default:         return v;
                                }
                            }).join(', ');
                    }
                    console.log(message);
                }
            }
        }

        /**
         * Empty function.
         *
         * @param {*} [_ignored]
         */
        function nullMsg(_ignored) { }

        // ====================================================================
        // Exposed definitions
        // ====================================================================

        return {
            feature_name: feature_name,
            start_time:   start_time,
            tracing:      tracing,
            debugging:    debugging,
            error:        console.error,
            warn:         console.warn,
            trace:        (tracing   ? logMsg : nullMsg),
            debug:        (debugging ? logMsg : nullMsg),
            logMsg:       logMsg,
            nullMsg:      nullMsg
        };
    }

    // ========================================================================
    // Exposed definitions
    // ========================================================================

    return {
        add: add
    };

})();
