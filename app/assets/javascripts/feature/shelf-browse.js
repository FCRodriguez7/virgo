// app/assets/javascripts/feature/shelf-browse.js
//
// ============================================================================
// Virtual shelf browse
//
// These definitions work for both the Colorbox popup (invoked from links on
// search results and item details pages) and for web pages accessed via direct
// routes to the ShelfBrowseController via "/shelf_browse/ID" and
// "/shelf_browse/?start=CALL_NUMBER".
// ============================================================================

//= require jquery-resizable
//= require jquery.cookie
//= require shared/colorbox
//= require shared/jstree
//= require feature/analytics
//= require feature/availability
//= require feature/bookplate
//= require feature/copyright
//= require feature/cover-image
//= require feature/google-preview
//= require feature/starred-items

/** @type {DebugEntry} */
var debugShelfBrowse =
    ModuleDebug.add('feature/shelf-browse', 'SHELF_BROWSE', { all: DEVELOPMENT });

/**
 * Virtual Shelf Browse feature.
 *
 * @type {object}
 *
 * @property {function} featureProperties
 * @property {function} featureStatus
 * @property {function} makeLccTree
 * @property {function} setupLinks
 * @property {function} updatePage
 * @property {function} suppress
 * @property {function} enabled
 */
var ShelfBrowse = (function(module_debug) {

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
    var FEATURE_ENABLED = Rails.ShelfBrowse.ENABLED;

    /**
     * @constant
     * @type {number}
     */
    var COVER_RETRY = 4 * SECONDS;

    /**
     * Default values.
     *
     * @constant
     * @type {object}
     *
     * @property {string}  orientation
     * @property {string}  feature_path
     * @property {string}  lcc_tree_path
     * @property {string}  root_id
     * @property {string}  shelfkey_attr
     * @property {string}  details_scroll    - Default metadata scroll location
     * @property {number}  cover_image_retry - Cover image retry time (ms).
     * @property {boolean} show_motion
     * @property {boolean} show_tile_scroller
     * @property {boolean} show_progress_bar
     * @property {boolean} show_progress_bar_text
     * @property {boolean} show_more_scroll
     *
     * @see UVA::Helper::ShelfBrowse::CONFIG
     */
    var CONFIG =
        $.extend({}, Rails.ShelfBrowse.CONFIG, {
            details_scroll:         'top',
            cover_image_retry:      COVER_RETRY,
            show_motion:            true,
            show_tile_scroller:     false,
            show_progress_bar:      true,
            show_progress_bar_text: false,
            show_more_scroll:       false
        });

    /**
     * Alias for {@link CONFIG}.root_id.
     *
     * @constant
     * @type {string}
     */
    var ROOT_ID = CONFIG.root_id;

    /**
     * Label values.
     *
     * @constant
     * @type {object}
     *
     * @property {?string} link
     * @property {?string} lcc_open
     * @property {?string} lcc_close
     * @property {?string} lcc_root
     *
     * @see UVA::Helper::ShelfBrowse::LABEL
     */
    var LABEL = Rails.ShelfBrowse.LABEL;

    /**
     * Tooltip text values.
     *
     * @constant
     * @type {object}
     *
     * @property {?string} help
     * @property {?string} origin
     * @property {?string} return
     * @property {?string} close
     * @property {?string} item
     * @property {?string} cover
     * @property {?string} status
     * @property {?string} no_item
     * @property {?string} splitter
     * @property {?string} close_dropdown
     * @property {?string} lcc
     * @property {?string} lcc_root
     * @property {?string} lcc_root_icon
     * @property {?string} range
     *
     * @see UVA::Helper::ShelfBrowse::TOOLTIP
     */
    var TOOLTIP = Rails.ShelfBrowse.TOOLTIP;

    /**
     * Message text values.
     *
     * @constant
     * @type {object}
     *
     * @property {string} lcc_loading
     *
     * @see UVA::Helper::ShelfBrowse::MESSAGE
     */
    var MESSAGE = Rails.ShelfBrowse.MESSAGE;

    /**
     * Actions for navigation() and keyHandler().
     *
     * @readonly
     * @enum {number}
     */
    var ACTION = {
        Ignored:    0,
        FocusFirst: 1,
        FocusLast:  2,
        FocusFwd:   3,
        FocusRev:   4,
        PageHome:   5,
        PageFwd:    6,
        PageRev:    7
    };

    // ========================================================================
    // Constants - Properties
    // ========================================================================

    /**
     * Dimension values.
     *
     * @constant
     * @type {object}
     *
     * Distance value numbers have an implied unit of "pixel"; distances may be
     * given as CSS distance values like "10px", "10em", "10%", etc.
     *
     * @property {number} cbox_border_width  - Colorbox left/right borders
     * @property {number} cbox_border_height - Colorbox top/bottom borders
     *
     * @property {number} item_width         - Item tile width
     * @property {number} item_margin_width  - Item tile left/right margins
     * @property {number} item_height        - Item tile height
     * @property {number} item_margin_height - Item tile top/bottom margins
     * @property {number} pg_width           - Page control width
     * @property {number} pg_margin_width    - Page control left/right margins
     * @property {number} pg_height          - Page control height
     * @property {number} pg_margin_height   - Page control top/bottom margins
     *
     * @property {number} small_screen_height
     *
     * @property {number|string} def_popup_width
     * @property {number|string} def_popup_height
     *
     * @property {number|string} def_item_ranges_width
     * @property {number|string} def_page_scroller_height
     *
     * @property {Object.<string,number>} scale
     * @property {Object.<string,number>} scale_factor
     */
    var PROP = {
        // ==== Colorbox properties ====
        cbox_border_width:    30,     // Colorbox left/right borders (px)
        cbox_border_height:   30,     // Colorbox top/bottom borders (px)

        // ==== Shelf browse properties ====
        item_width:           107.2,  // Item tile width (px)
        item_margin_width:    6,      // Item tile left/right margins (px)
        item_height:          194.2,  // Item tile height (px)
        item_margin_height:   0.4,    // Item tile top/bottom margins (px)
        pg_width:             32,     // Page control width (px)
        pg_margin_width:      13,     // Page control left/right margins (px)
        pg_height:            32,     // Page control height (px)
        pg_margin_height:     13,     // Page control top/bottom margins (px)

        // ==== Scale for small form-factor displays ====
        small_screen_height:  640,    // (px)

        // ==== Derived properties ====
        def_popup_width:  '99%',
        def_popup_height: '99%',

        // ==== Resizable panels ====
        def_item_ranges_width:    '48.4%',
        def_page_scroller_height: '48.4%',

        // ==== Item info scaling ====
        scale:        { small: 500, medium: 750, large: 1000 },
        scale_factor: { small: 0.4, medium: 0.5, large: 0.6 }
    };

    // ========================================================================
    // Variables
    // ========================================================================

    /**
     * Links in print view should not be adjusted for search context.
     *
     * @type {boolean}
     */
    var suppressed = !FEATURE_ENABLED || inPrintView();

    /**
     * CONFIG properties potentially overridden by URL query parameters.
     *
     * @type {object}
     *
     * @see {@link CONFIG}
     */
    var config = $.extend({}, CONFIG);

    /**
     * For debugging.
     *
     * @type {object}
     */
    var _browser_properties = {};

    /**
     * Current shelf-browse values.
     *
     * @type {object}
     *
     * @property {string} base_url - The original URL (with query parameters).
     *    <b>base_url</b>
     *    For the shelf browse popup, this is the URL from the link that
     *    invoked the popup; otherwise this is the URL of the web page where
     *    updatePage() was run.
     *
     * @property {string} full_url - URL with updated query parameters.
     *    <b>full_url</b>
     *    The {@link base_url} with query parameters modified/augmented to with
     *    additional values (in particular the width, i.e. the number of items
     *    shown in the .page-scroller).
     *
     * @property {string} orientation - Shelf browse display orientation.
     *    <b>orientation</b>
     *    Possible values are "horizontal" or "vertical"; if not present, the
     *    default value is implicitly "horizontal".  NOTE: There is no current
     *    support for a "vertical" orientation.
     *
     * @property {boolean}  popup   - Shelf browse invoked as a popup.
     * @property {string|string[]} skip - Comma-delimited list of parts to omit
     * @property {boolean}  active  - Shelf browse in operation.
     * @property {boolean}  loading - Shelf browse currently loading.
     * @property {boolean}  browser_resizing - Currently handling resize event.
     * @property {boolean}  resize_pending   - Will be handling a resize event.
     * @property {boolean}  splitter_dragging - Panels are being resized.
     * @property {string[]} dropdowns_open - Dropdown panel(s) being displayed.
     * @property {function} keyHandler     - Key press event handler.
     * @property {function} resizeHandler  - Resize event handler.
     * @property {number}   item_ranges_width
     * @property {number}   item_ranges_width_init
     * @property {number}   page_scroller_height
     * @property {number}   page_scroller_height_init
     * @property {number}   page_scroller_height_min
     */
    var feature_status = {
        dropdowns_open: []
    };

    /**
     * Settings used in makeLccTree() when first creating the tree.  At that
     * time this object is modified to cache the received data in
     * json_data.data and remove json_data.ajax.
     *
     * @type {object}
     *
     * @see app/assets/javascripts/shared/jstree
     *
     * @todo NOTE:
     * Because click handlers need to be set up for <a> anchor
     * elements within the tree, that makes json_data.progress_render
     * problematic. Maybe there's a better way to handle this...
     */
    var lcc_tree_options =
        AppJstree.settings(debugShelfBrowse.feature_name, {
            core: {
                html_titles:    true,
                initially_open: [ROOT_ID],
                open_parents:   false,
                strings:        { loading: MESSAGE.lcc_loading }
            },
            json_data: {
                ajax: {
                    url: function(node) {
                        var path = config.lcc_tree_path;
                        if (node !== -1) {
                            var id    = node.attr('id');
                            var range = treeIdToCallNumberRange(id);
                            if (range) { path += '?range=' + range; }
                        }
                        return path;
                    }
                }
            },
            themes: {
                icons: false
            },
            hotkeys: {
                up:   function() { return lccMotion(CHAR.ArrowUp,   this); },
                down: function() { return lccMotion(CHAR.ArrowDown, this); },
                esc:  function() { hideLccTree(); return false; } // TODO
            },
            cookies: {
                save_loaded:    'shelf_browse_loaded',
                save_opened:    'shelf_browse_opened',
                save_selected:  'shelf_browse_selected',
                cookie_options: { path: '/' }
            }
      });

    // ========================================================================
    // LCC tree data cache
    // ========================================================================

    /**
     * LCC tree data cache.
     *
     * @type {object}
     *
     * @property {function} get
     * @property {function} set
     */
    var lcc_cache = (function() {

        /**
         * Storage for LCC data between shelf browse invocations.
         *
         * @type {object.<string,object>}
         */
        var lcc_data;

        // ====================================================================
        // Function definitions
        // ====================================================================

        /**
         * Retrieve saved LCC data for the LCC tree browser.
         *
         * @return {object|undefined} Data in JSON format, or *undefined* if
         *                              the data has not been saved (yet).
         */
        function get() {
            return lcc_data;
        }

        /**
         * Save LCC data for the LCC tree browser to be used across
         * invocations.
         *
         * @param {object} data       Data in JSON format.
         *
         * @return {object}           Data in JSON format.
         */
        function set(data) {
            lcc_data = data;
            return lcc_data;
        }

        // ====================================================================
        // Exposed definitions
        // ====================================================================

        return {
            get: get,
            set: set
        };

    })();

    // ========================================================================
    // Function definitions - Utility
    // ========================================================================

    /**
     * Disable this feature temporarily.
     *
     * @param {boolean} [setting]     Default: *true*.
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
     * Extract options from URL query parameters.
     *
     * @param {string} [url]          The current URL by default.
     *
     * @return {object}               Transformed URL query parameters.
     */
    function getUrlOptions(url) {
        var result = {};
        var path   = url || feature_status.full_url || currentUrl();
        var start  = (typeof path === 'string') ? path.indexOf('?') : -1;
        if (start >= 0) {
            path.substr(start + 1).split('&').forEach(function(key_value) {
                var pair  = key_value.split('=');
                var key   = pair[0];
                var value = pair[1];
                switch (value) {
                    case 'true':
                        result[key] = true;
                        break;
                    case 'false':
                        result[key] = false;
                        break;
                    default:
                        if (value) { result[key] = value; }
                }
            });
        }
        return result;
    }

    /**
     * Make a URL query parameter string.
     *
     * @param {object} options
     *
     * @return {string}
     */
    function makeUrlParameters(options) {
        var result = [];
        if (options) {
            $.each(options, function(key, value) {
                if ((typeof value === 'object') && notDefined(value.length)) {
                    $.each(value, function(k, v) {
                        result.push(key + '[' + k + ']=' + v);
                    });
                } else {
                    result.push(key + '=' + value);
                }
            });
        }
        return result.join('&');
    }

    // ========================================================================
    // Function definitions - smart_resize
    //
    // Using "smart_resize" prevents multiple resize events (which happens when
    // you resize manually) from invoking its function multiple times.  The
    // function will only be invoked after a pause.
    // ========================================================================

    /**
     * Default de-bounce delay threshold, in milliseconds.
     *
     * @constant
     * @type {number}
     */
    var MIN_DEBOUNCE_DELAY = 500;

    (function(sr) {
        /**
         * De-bouncing function from John Hann.
         *
         * @param {function} func         Function to run.
         * @param {number}   [threshold]  Default: {@link MIN_DEBOUNCE_DELAY}.
         * @param {boolean}  [exec_now]   If *true*, run *func* immediately.
         *
         * @return {function}
         *
         * @see http://unscriptable.com/index.php/2009/03/20/debouncing-javascript-methods/
         */
        function debounce(func, threshold, exec_now) {

            var timeout;
            var delay_time = threshold || MIN_DEBOUNCE_DELAY;

            return function debounced() {

                var obj  = this;
                var args = arguments;

                function delayed() {
                    if (!exec_now) {
                        func.apply(obj, args);
                    }
                    timeout = null;
                }

                if (timeout) {
                    clearTimeout(timeout);
                } else if (exec_now) {
                    func.apply(obj, args);
                }

                timeout = setTimeout(delayed, delay_time);
            };
        }

        // smart_resize
        $.fn[sr] = function(fn) {
            return fn ? this.bind('resize', debounce(fn)) : this.trigger(sr);
        };

    })('smart_resize');

    // ========================================================================
    // Function definitions - Debugging
    //
    // NOTE: These are functional in all environments (including production) so
    // the caller is responsible for deciding appropriateness.
    // ========================================================================

    /**
     * Create lines for {@link logObject}, handling object values recursively.
     *
     * @param {object} target
     * @param {number} [indent]       Number of spaces to prepend to each line.
     *
     * @return {string}
     */
    function objectLines(target, indent) {

        // Generate the prefix string then increment the indent.
        var TAB_SIZE = 2;
        var prefix   = '';
        var left_col = indent || 0;
        if (left_col) {
            var max = left_col * TAB_SIZE;
            for (var x = 0; x < max; x++) { prefix += ' '; }
        }
        left_col += TAB_SIZE;

        // Generate newline-delimited lines.
        var target_is_object = false;
        var keys;
        if (target instanceof Array) {
            keys = target;
        } else if (target instanceof Object) {
            target_is_object = true;
            keys = Object.keys(target);
        } else {
            keys = [target];
        }

        // Generate newline-delimited lines.
        var lines = [];
        $.each(keys, function(key, value) {
            var line = target_is_object ? (key + ' = ') : '';
            switch (typeof value) {
                case 'function':
                    if (value.name) {
                        line += value.name + '()';
                    } else if (isDefined(value.name)) {
                        line += 'null';
                    } else {
                        line += '*function*';
                    }
                    break;
                case 'object':
                    var bracket = (value instanceof Array) ? '[]' : '{}';
                    var open  = bracket[0] + "\n";
                    var close = prefix + bracket[1];
                    line += open + objectLines(value, left_col) + close;
                    break;
                default:
                    line += value;
                    break;
            }
            lines.push(prefix + line);
        });
        return lines.join("\n");
    }

    /**
     * Emit an Object to console.log().
     */
    function logObject(label, object) {
        var bar = "----------------------------------------------------\n";
        var target, lines;
        if (isDefined(object)) {
            target = object;
            lines  = label + ':';
        } else {
            target = label;
            lines  = '';
        }
        lines += "\n" + bar + objectLines(target) + bar;
        console.log(lines);
    }

    /**
     * Emit default values to console.log().
     */
    function logDefaults() {
        var values = {
            started:              debugShelfBrowse.start_time,
            jquery_version:       $.fn.jquery,
            jquery_ajax_settings: $.ajaxSettings,
            lcc_cache:            typeof lcc_cache.get()
        };
        $.extend(values, config);
        logObject('defaults', values);
    }

    /**
     * Emit feature properties to console.log().
     */
    function logProperties() {
        logObject('properties', featureProperties());
    }

    /**
     * Emit feature status to console.log().
     */
    function logStatus() {
        var status = {
            lcc_cache: typeof lcc_cache.get()
        };
        $.extend(status, feature_status);
        logObject('feature_status', status);
    }

    // ========================================================================
    // Function definitions - Properties
    // ========================================================================

    /**
     * Get properties from the URL.
     *
     * @param {object} [options]      Optional overrides.
     *
     * @return {object}
     *
     * @property {boolean}  horizontal
     * @property {string[]} skip
     *
     * @see {@link config}
     * @see {@link feature_status}
     * @see {@link getUrlOptions}
     */
    function getUrlProperties(options) {
        var result =
            $.extend({}, config, feature_status, getUrlOptions(), options);
        if (result.orientation) {
            result.horizontal = (result.orientation === 'horizontal');
        }
        if (result.skip && !(result.skip instanceof Array)) {
            result.skip = result.skip.toString().split(',');
        }
        return result;
    }

    /**
     * Get properties of shelf browse components.
     *
     * @param {object} [options]      See {@link getUrlProperties}
     *
     * @return {object}
     *
     * @property {string}  user_agent
     * @property {number}  browser_width
     * @property {number}  browser_height
     * @property {number}  scroll_width
     * @property {number}  scroll_height
     * @property {number}  item_width
     * @property {number}  item_height
     * @property {number}  controls_width
     * @property {number}  controls_height
     * @property {number}  reserved_width
     * @property {number}  reserved_height
     * @property {number}  item_page_width
     * @property {number}  item_page_height
     * @property {string}  popup_width
     * @property {string}  popup_height
     * @property {number}  items_across
     * @property {number}  items_down
     */
    function featureProperties(options) {

        // ==== URL properties ====
        var url_option = getUrlProperties(options);

        // ==== Browser window properties ====
        var browser        = browserProperties();
        var user_agent     = browser.user_agent;
        var browser_width  = browser.width;
        var browser_height = browser.height;
        var scroll_width   = browser.scroll_width;
        var scroll_height  = browser.scroll_height;

        // ==== Colorbox properties ====
        var border_width    = 2 * PROP.cbox_border_width;
        var border_height   = 2 * PROP.cbox_border_height;

        // ==== Shelf browse properties ====
        var item_width      = PROP.item_width  + (2 * PROP.item_margin_width);
        var item_height     = PROP.item_height + (2 * PROP.item_margin_height);
        var controls_width  = 2 * (PROP.pg_width + (2 * PROP.pg_margin_width));
        var controls_height = item_height;

        // ==== Scale for small form-factor displays ====
        // (There is no requirement at this time for handling small displays
        // so this is just a quick-and-dirty attempt.  Real responsive design
        // will probably have to wait for a later version of Virgo.)
        if (browser.screen_height <= PROP.small_screen_height) {
            //border_width    /= 2;
            //border_height   /= 2;
            item_width      /= 2;
            item_height     /= 2;
            controls_width  /= 2;
            controls_height /= 2;
        }

        // ==== Areas outside the item tile container ====
        var reserved_width  = 0;
        var reserved_height = 0;
        if (url_option.popup) {
            reserved_width  += border_width;
            reserved_height += border_height;
        }
        if (url_option.horizontal) {
            reserved_width  += controls_width;
        } else {
            reserved_height += controls_height;
        }

        // ==== Area of the item tile container ====
        var item_page_width  = browser_width  - reserved_width;
        var item_page_height = browser_height - reserved_height;
        if (user_agent !== UA.Firefox) {
            item_page_width  -= scroll_width;
            item_page_height -= scroll_height;
        }

        // ==== Derived properties ====
        var items_across = 1;
        var items_down   = 1;
        var popup_width  = PROP.def_popup_width;
        var popup_height = PROP.def_popup_height;
        if (url_option.horizontal) {
            items_across = Math.floor(item_page_width / item_width);
            popup_width  = (item_width * items_across) + reserved_width;
            popup_width  = '' + popup_width + 'px';
        } else {
            items_down   = Math.floor(item_page_height / item_height);
            popup_height = (item_height * items_down) + reserved_height;
            popup_height = '' + popup_height + 'px';
        }

        // Return the full set of results.
        return $.extend({}, url_option, {
            user_agent:       user_agent,
            browser_width:    browser_width,
            browser_height:   browser_height,
            scroll_width:     scroll_width,
            scroll_height:    scroll_height,
            item_width:       item_width,
            item_height:      item_height,
            controls_width:   controls_width,
            controls_height:  controls_height,
            reserved_width:   reserved_width,
            reserved_height:  reserved_height,
            item_page_width:  item_page_width,
            item_page_height: item_page_height,
            popup_width:      popup_width,
            popup_height:     popup_height,
            items_across:     items_across,
            items_down:       items_down
        });
    }

    /**
     * Set the size of the shelf browse display to the width of the browser.
     */
    function setDisplaySize() {

        var $display = $('.shelf-browse.display');
        var old_width = $display.css('width');
        var ml = $display.css('margin-left');
        var mr = $display.css('margin-right');
        var bl = $display.css('border-left-width');
        var br = $display.css('border-right-width');
        var reserved_width =
            parseFloat(ml) + parseFloat(mr) + parseFloat(bl) + parseFloat(br);

        // Determine width based on the browser.
        var property  = featureProperties();
        var new_width = property.browser_width - reserved_width;
        if (property.user_agent !== UA.Firefox) {
            new_width -= property.scroll_width;
        }
        $display.css('width', (new_width + 'px'));

        // The .item-info area drives the overall height of the display.
        var $item_info = $display.find('.item-info');
        var old_height = $item_info.css('height');
        var new_height = property.browser_height;
        if (new_height < PROP.scale.small) {
            new_height *= PROP.scale_factor.small;
        } else if (new_height > PROP.scale.large) {
            new_height *= PROP.scale_factor.large;
        } else {
            new_height *= PROP.scale_factor.medium;
        }
        $item_info.css('height', (new_height + 'px'));

        // Debugging console output.
        if (_debugging) {
            var w = $display.css('width');
            var h = $item_info.css('height');
            _debug(arguments,
                'old_width='  + old_width + '; ' +
                'new_width='  + w + ' (' + new_width + '); ' +
                'old_height=' + old_height + '; ' +
                'new_height=' + h + ' (' + new_height + '); ' +
                'ml=' + ml + '; mr=' + mr + '; bl=' + bl + '; br=' + br
            );
        }
    }

    /**
     * Emit a console warning if any configuration values are in conflict.
     *
     * @param {object} [configuration]  Default: {@link config}.
     *
     * @return {object}                 Configuration object.
     */
    function validateConfigProperties(configuration) {
        var cfg = configuration || config;
        var dependencies = {
            show_motion:       ['show_progress_bar', 'show_title_scroller'],
            show_progress_bar: ['show_progress_bar_text']
        };
        $.each(dependencies, function(required, dependents) {
            if (notDefined(cfg[required])) {
                console.warn(
                    'CONFIG.' + required + ' is not defined' +
                    '; it will be treated as false'
                );
            }
            if (!cfg[required]) {
                dependents.forEach(function(dependent) {
                    if (cfg[dependent]) {
                        console.warn(
                            'CONFIG.' + required + ' is false' +
                            '; ' + dependent + ' ignored'
                        );
                    }
                });
            }
        });
        return cfg;
    }

    /**
     * Merge CONFIG properties with URL query parameter overrides (if any).
     *
     * @param {object} [options]      See {@link getUrlProperties}
     *
     * @return {object}               CONFIG overridden by getUrlProperties().
     */
    function setConfigProperties(options) {
        var url_option = getUrlProperties(options);
        $.each(config, function(property) {
            var url_property = url_option[property];
            if (isDefined(url_property)) {
                config[property] = url_property;
                _debug('CONFIG.' + property + ' set to ' + url_property);
            }
        });
        return validateConfigProperties();
    }

    /**
     * Current Virtual Shelf Browse status information.
     *
     * @returns {object}
     *
     * @see feature_status
     */
    function featureStatus() {
        return feature_status;
    }

    // ========================================================================
    // Function definitions - Elements
    // ========================================================================

    /**
     * Return a jQuery object with a single instance or return null.
     *
     * @param {Selector} selector
     * @param {string}   [label]      Name of item for error messages.
     * @param {string}   [called_by]  Name of the caller for error messages.
     *
     * @return {jQuery|undefined}
     */
    function single(selector, label, called_by) {
        var _func_ = called_by || label || arguments.callee.name;
        var _item_ = called_by ? label : selector;
        var $element = $(selector);
        if (isMissing($element)) {
            console.error(_func_ + ': missing ' + _item_);
            return;
        }
        if ($element.length > 1) {
            console.error(_func_ + ': multiple ' + _item_);
            $element = $element.first();
        }
        return $element;
    }

    /**
     * Extract a dataset item from an element.
     *
     * @param {Selector} element
     * @param {string}   data_item
     * @param {string}   [label]      Name of item for error messages.
     *
     * @return {string|undefined}
     */
    function valueFor(element, data_item, label) {
        var _func_ = arguments.callee.name;
        var value;
        var $element = single(element, label, _func_);
        if ($element) {
            var attr = data_item;
            if (attr.indexOf('data-') !== 0) { attr = 'data-' + attr; }
            value = $element.attr(attr);
            if (isEmpty(value)) {
                var _item_ = label || attr;
                _debug('*** no ' + _item_ + ' ***');
            }
        }
        return value;
    }

    /**
     * The shelfkey of the first displayed item.
     *
     * @return {string|undefined}
     */
    function startCurrentRange() {
        var selector = '.shelf-browse.display .current-range-first';
        return valueFor(selector, CONFIG.shelfkey_attr);
    }

    /**
     * The shelfkey of the last displayed item.
     *
     * @return {string|undefined}
     */
    function endCurrentRange() {
        var selector = '.shelf-browse.display .current-range-last';
        return valueFor(selector, CONFIG.shelfkey_attr);
    }

    /**
     * Extract the number of the given tile.
     *
     * @param {Selector} item_tile
     *
     * @return {number}               This will be -1 if the tile contains a
     *                                  non-document item.
     */
    function focusId(item_tile) {
        var id = valueFor(item_tile, 'data-focus-id');
        return (id && (id >= 0)) ? id : -1;
    }

    /**
     * Extract the identifier of the given tile.
     *
     * @param {Selector} item_tile
     *
     * @return {string}               This should always be a non-empty value
     *                                  (otherwise, the tile element is being
     *                                  created improperly).
     */
    function tileId(item_tile) {
        return valueFor(item_tile, 'data-tile');
    }

    /**
     * The .item-details element.
     *
     * @param {string}   [called_by]  Name of the caller for error messages.
     *
     * @return {jQuery|undefined}
     */
    function getItemDetails(called_by) {
        var _func_ = called_by || arguments.callee.name;
        return single('.shelf-browse.display .item-details', _func_);
    }

    /**
     * Get an item tile by tile identifier.
     *
     * @param {string} tile_id
     * @param {string} [called_by]    Name of the caller for error messages.
     *
     * @return {jQuery|undefined}
     */
    function getItemTile(tile_id, called_by) {
        var _func_ = called_by || arguments.callee.name;
        var $result;
        if (tile_id) {
            var selector = '.shelf-browse.display .item-tile';
            var tile_selector = selector + '[data-tile="' + tile_id + '"]';
            $result = single(tile_selector, _func_);
        } else {
            console.error(_func_ + ': no tile_id');
        }
        return $result;
    }

    /**
     * The .item-tile.focus element.
     *
     * @param {string}   [called_by]  Name of the caller for error messages.
     *
     * @return {jQuery|undefined}
     */
    function getFocusItemTile(called_by) {
        var _func_ = called_by || arguments.callee.name;
        var selector = '.shelf-browse.display .item-tile';
        var $tiles = $(selector);
        var $focus;
        $tiles.each(function() {
            var $this = $(this);
            if ($this.hasClass('focus')) {
                $focus = $this;
                return false; // break from each()
            }
        });
        if (!$focus) {
            $focus = single($tiles, _func_);
            if ($focus) {
                console.warn(_func_ + ': setting focus item');
                $focus.addClass('focus');
            }
        }
        return $focus;
    }

    /**
     * Get the .item-metadata from within the indicated element.
     *
     * @param {Selector} container
     * @param {string}   [called_by]  Name of the caller for error messages.
     *
     * @return {jQuery|undefined}
     */
    function getItemMetadata(container, called_by) {
        var _func_ = called_by || arguments.callee.name;
        var $result;
        var $container = single(container, _func_);
        if ($container) {
            var $metadata = $container.find('.item-metadata');
            $result = single($metadata, 'item metadata', _func_);
        }
        return $result;
    }

    // ========================================================================
    // Function definitions - Web access
    // ========================================================================

    /**
     * Adjust the shelf browse path with the appropriate query options.
     *
     * @param {string|Selector} [target]
     * @param {object}          [options]   See {@link featureProperties}
     *
     * @return {string}
     */
    function setCurrentUrl(target, options) {

        var _func_ = arguments.callee.name;

        // Get the base URL.
        var url;
        if (target) {
            switch (typeof target) {
                case 'string':
                    url = target;
                    break;
                case 'object':
                    var $target = $(target);
                    url = $target.attr('data-path') || $target.attr('href');
                    break;
                default:
                    console.warn(_func_ + ': unexpected: ' + target);
                    break;
            }
        }
        if (!url) {
            url = currentUrl();
            if (_debugging) {
                console.warn(_func_ + ': setting default: ' + url);
            }
        }
        feature_status.base_url = url;

        // Get and/or override properties.
        var property = featureProperties(options);
        var items_across = property.items_across || 0;

        // Adjust the result with current window and shelf browse properties;
        // determine the number of items to request in the URL.
        var args = {};
        if (property.skip)             { args.skip  = property.skip; }
        if (isDefined(property.popup)) { args.popup = property.popup; }
        if (items_across > 0)          { args.width = items_across; }
        if (isDefined(property.extra_metadata)) {
            args.extra_metadata = property.extra_metadata;
        }
        var url_parameters = makeUrlParameters(args);
        if (url_parameters) {
            url += (url.indexOf('?') >= 0) ? '&' : '?';
            url += url_parameters;
        }
        feature_status.full_url = url;

        if (_debugging) { logObject('properties', property); }

        return url;
    }

    /**
     * Set the virtual shelf display from a URL.
     *
     * The data returned from GET is massaged so that it works whether the URL
     * had the "popup=true" parameter or not.
     *
     * @param {string} url
     */
    function updateFrom(url) {
        var _func_ = arguments.callee.name;
        if (!url) {
            console.error(_func_ + ': no url');
            return;
        }
        var path = setCurrentUrl(url);
        _trace(_func_, path);
        var $display = $('.shelf-browse.display');
        $display.attr('aria-busy', 'true');
        var start = Date.now();
        $.get(path, function(result) {

            _debug(_func_, 'GET return sec.', secondsSince(start));

            // Replace the current display with DOM elements from the HTML that
            // was just acquired.
            var $new_display =
                $('<div>' + result + '</div>').find('.shelf-browse.display');
            $display.html($new_display.html());

            // If a range was selected from the dropdown menu, the flag will
            // need to be cleared right away.
            feature_status.dropdowns_open = [];

            // Attach handlers to the new DOM elements.
            _trace('*** updated shelf browse display ***');
            attachHandlers();

            // For direct web pages (not colorbox popups), if this update
            // occurred due to a browser window resize then this is the point
            // at which the resizing is complete.
            feature_status.browser_resizing = false;
            $display.attr('aria-busy', 'false');
        });
    }

    /**
     * Replace the display with the indicated page, giving feedback through the
     * progress bar if the operation does not complete quickly.
     *
     * @param {string|Selector} target
     * @param {string}          [motion]  See {@link showMotion}
     */
    function gotoShelfPage(target, motion) {
        var _func_ = arguments.callee.name;
        if (motion) { _func_ += ' ' + motion; }
        var url;
        if (typeof target === 'string') {
            url = target;
        } else {
            url = $(target).attr('data-path');
        }
        _trace(_func_, url);
        if (url) {
            showMotion(motion);
            updateFrom(url);
        }
    }

    /**
     * Place the display with the page implied by the given target item.
     *
     * @param {Selector} target
     */
    function gotoTargetPage(target) {
        var $target     = $(target);
        var destination = $target.attr(CONFIG.shelfkey_attr);
        var motion;
        if (destination <= startCurrentRange()) {
            motion = 'left';
        } else if (destination >= endCurrentRange()) {
            motion = 'right';
        }
        gotoShelfPage($target, motion);
    }

    // ========================================================================
    // Function definitions - Browser events
    // ========================================================================

    /**
     * If the window is resized while the shelf browse popup is open, reset it
     * by re-running createPopup to resize the virtual shelf.
     *
     * This is installed through "smart_resize" (defined above) to prevent
     * multiple resize events (which happen when you resize manually) from
     * invoking the function multiple times.
     */
    function resizePopup() {

        // Do not respond to resize events during certain conditions.
        if (!feature_status.active) {
            _debug('*** IGNORING RESIZE - SHELF BROWSE INACTIVE ***');
            return;
        }
        if (!feature_status.base_url) {
            _debug('*** IGNORING RESIZE - NO BASE_URL ***');
            return;
        }
        if (feature_status.loading) {
            _debug('*** IGNORING RESIZE - COLORBOX LOADING ***');
            return;
        }

        // Currently, the feature is not set up to handle a resize of the LCC
        // browser while it's open, so resizing must be dealt with after it is
        // closed (or after updateFrom() happens).
        if (feature_status.dropdowns_open.length) {
            _debug('*** DEFERRING RESIZE - DROPDOWN(S) OPEN ***');
            feature_status.resize_pending = true;
            return;
        }

        // Refresh the colorbox popup.
        _trace('*** BROWSER WINDOW RESIZED ***');
        createPopup(feature_status.base_url);
    }

    /**
     * If the window is resized, reset the virtual shelf web page.
     *
     * This is installed through "smart_resize" (defined above) to prevent
     * multiple resize events (which happen when you resize manually) from
     * invoking the function multiple times.
     */
    function resizeDisplay() {

        // Do not respond to resize events during certain conditions.
        if (!feature_status.active) {
            _debug('*** IGNORING RESIZE - SHELF BROWSE INACTIVE ***');
            return;
        }
        if (!feature_status.base_url) {
            _debug('*** IGNORING RESIZE - NO BASE_URL ***');
            return;
        }
        if (feature_status.browser_resizing) {
            _debug('*** IGNORING RESIZE - ALREADY RESIZING ***');
            return;
        }

        // Currently, the feature is not set up to handle a resize of the LCC
        // browser while it's open, so resizing must be dealt with after it is
        // closed (or after updateFrom() happens).
        if (feature_status.dropdowns_open.length) {
            _debug('*** DEFERRING RESIZE - DROPDOWN(S) OPEN ***');
            feature_status.resize_pending = true;
            return;
        }

        // If the resize did not change the width available for item tiles then
        // there is nothing additional to do (since re-flows will have already
        // been handled by the browser itself).
        setDisplaySize();
        var old_items = $('.shelf-browse.display .item-tile').length;
        var new_items = featureProperties().items_across;
        if (old_items === new_items) {
            _debug('*** IGNORING RESIZE - NO CHANGE TO ITEMS ***');
            return;
        }

        // Refresh the web page with the new set of items.
        _trace('*** BROWSER PAGE RESIZED ***');
        _debug('old items: ' + old_items + '; new items: ' + new_items);
        feature_status.browser_resizing = true;
        gotoShelfPage(feature_status.base_url);
    }

    /**
     * Use keys to navigate the virtual shelf.
     *
     * @param {Event} event
     *
     * @return {boolean|undefined}    *false* if the event was handled.
     */
    function keyHandler(event) {

        // Do not respond to key press events during certain conditions.
        if (!feature_status.active) {
            _debug('*** IGNORING KEY EVENT - SHELF BROWSE INACTIVE ***');
            return;
        }
        if (feature_status.loading) {
            _debug('*** IGNORING KEY EVENT - COLORBOX LOADING ***');
            return;
        }
        if (feature_status.browser_resizing) {
            _debug('*** IGNORING KEY EVENT - RESIZING ***');
            return;
        }
        if (feature_status.dropdowns_open.length) {
            _debug('*** IGNORING KEY EVENT - DROPDOWN(S) OPEN ***');
            return;
        }

        var key     = event.keyCode;
        var shifted = event.shiftKey;
        var action  = ACTION.Ignored;
        var count   = 1;
        _debug('KEY', key);

        // Determine action to perform based on the key combination pressed.
        switch (key) {
            case CHAR.PageUp:
                action = ACTION.PageFwd;
                if (shifted) { count = 10; }
                break;
            case CHAR.PageDown:
                action = ACTION.PageRev;
                if (shifted) { count = 10; }
                break;
            case CHAR.End:
                action = ACTION.FocusLast;
                break;
            case CHAR.Home:
                action = shifted ? ACTION.PageHome : ACTION.FocusFirst;
                break;
            case CHAR.ArrowLeft:
                action = shifted ? ACTION.PageRev : ACTION.FocusRev;
                break;
            case CHAR.ArrowRight:
                action = shifted ? ACTION.PageFwd : ACTION.FocusFwd;
                break;
            default:
                return;
        }

        // Respond to the event and return *false* to indicate that it has been
        // handled.
        event.preventDefault();
        event.stopPropagation();
        navigation(action, count);
        return false;
    }

    // ========================================================================
    // Function definitions - Overlays
    // ========================================================================

    /**
     * Add an instance of the named class to .shelf-browse.display.
     *
     * @param {string} class_name
     */
    function addOverlay(class_name) {
        _debug(arguments);
        if (class_name) {

            // Add the overlay to the display.
            $('<div>')
                .addClass(class_name)
                .appendTo('.shelf-browse.display');

            // Add to the set of open dropdowns.
            if (feature_status.dropdowns_open.indexOf(class_name) < 0) {
                feature_status.dropdowns_open.push(class_name);
            }
        }
    }

    /**
     * Remove instance(s) of the named class from .shelf-browse.display.
     *
     * @param {string} class_name
     */
    function removeOverlay(class_name) {
        _debug(arguments);
        if (class_name) {

            // Remove overlay from the display.
            $('.shelf-browse.display .' + class_name).remove();

            // Remove from the set of open dropdowns.
            var index = feature_status.dropdowns_open.indexOf(class_name);
            if (index >= 0) {
                feature_status.dropdowns_open.splice(index, 1);
            }
        }
    }

    /**
     * Update the tray of control buttons.
     *
     * @param {Selector} control
     * @param {Selector} container
     * @param {function} [close_function]
     */
    function finalizeButtonTray(control, container, close_function) {
        var $container = $(container);
        var $tray = $container.children('.button-tray').first();
        if (!$tray.hasClass('complete')) {
            $tray.addClass('complete');
            $tray.children('.help-button').click(function() {
                _debug('CLICK .help-button');
                toggleHelp(this);
            });
            if (close_function) {
                $tray.children('.close-button').click(function() {
                    close_function(control, $container);
                });
            }
        }
    }

    /**
     * Display a marker indicating there is more to see by scrolling.  But, if
     * there is no scrollbar then hide the marker if it is already present.
     *
     * @param {Selector} container
     * @param {string}   direction    "right"/"left" (or "up"/"down")
     */
    function updateMoreScroll(container, direction) {

        var _func_ = arguments.callee.name;
        var $container = $(container);
        if (isEmpty($container)) { return; }

        var marker_class = 'more-scroll';
        var modifier     = direction || 'down';
        var horizontal   = (modifier === 'right');
        var has_scroll_bar = horizontal ?
            ($container[0].scrollWidth  > $container[0].clientWidth) :
            ($container[0].scrollHeight > $container[0].clientHeight);
        var not_scrolled =
            horizontal ? !$container.scrollLeft() : !$container.scrollTop();
        var show_marker = has_scroll_bar && not_scrolled;

        var selector = '.' + marker_class + '.' + modifier;
        var $marker  = $container.children(selector).first();
        if (notEmpty($marker)) {
            // Show or hide an existing marker.
            if (show_marker) {
                $marker.removeClass('hidden');
            } else {
                $marker.addClass('hidden');
            }
        } else if (show_marker) {
            // Show a new marker.
            _debug(_func_, 'creating ' + selector);
            $('<div>')
                .html('More' + (horizontal ? '&rtrif;' : '&dtrif;'))
                .addClass(marker_class)
                .addClass(modifier)
                .appendTo($container);
        }
    }

    // ========================================================================
    // Function definitions - Help
    // ========================================================================

    /**
     * @constant
     * @type {object}
     */
    var HELP = {
        close_marker:     'close',
        overlay_class:    'help-overlay',
        container:        '.shelf-browse.display .help-container',
        scroll_direction: 'right'
    };

    /**
     * Display the currently-hidden help panel.
     *
     * @param {Selector} [control]
     * @param {Selector} [container]
     */
    function showHelp(control, container) {

        _debug(arguments);

        // Show overlay to dim the display.
        addOverlay(HELP.overlay_class);

        // Change the control into a button for re-hiding the panel.
        $(control).addClass(HELP.close_marker).attr('aria-expanded', true);

        // Show the panel.
        var $container = $(container || HELP.container);
        finalizeButtonTray(control, $container, hideHelp);
        scrollHelp($container);
        handleKeypressAsClick($container);
        $container.css('display', 'block').focus();
    }

    /**
     * Close the currently-displayed help panel.
     *
     * @param {Selector} [control]
     * @param {Selector} [container]
     */
    function hideHelp(control, container) {

        _debug(arguments);

        // Make the control a button for re-showing the help panel.
        $(control).removeClass(HELP.close_marker).attr('aria-expanded', false);

        // Hide the help panel.
        $(container || HELP.container).css('display', 'none');

        // Remove the overlay.
        removeOverlay(HELP.overlay_class);

        // If a page resize was deferred, complete it now.
        if (feature_status.resize_pending) {
            feature_status.resize_pending = false;
            feature_status.resizeHandler();
        }
    }

    /**
     * Toggle the state of the help panel: Close it if it is currently
     * displayed; open it if it is currently hidden.
     *
     * @param {Selector} control
     */
    function toggleHelp(control) {
        var $control = $(control);
        if ($control.hasClass(HELP.close_marker)) {
            hideHelp($control);
        } else {
            showHelp($control);
        }
    }

    /**
     * scrollHelp
     *
     * @param {Selector} container
     * @param {number}   [position]
     */
    function scrollHelp(container, position) {
        var pos = position || 0;
        var $container = $(container).scrollTop(pos).scrollLeft(pos);
        if (config.show_more_scroll) {
            updateMoreScroll($container, HELP.scroll_direction);
        }
    }

    /**
     * changeHelpTopics
     *
     * @param {string} topic          Either "default", "lcc" or "unused".
     *
     * === Implementation Notes
     * Note that if a topic has neither "visible" nor "hidden" CSS classes then
     * it will never be shown.
     *
     * @see app/views/shelf_browse/shared/_help_content.html.erb
     * @see topic_combo in _help_content
     * @see topic_css   in _help_content
     */
    function changeHelpTopics(topic) {
        var to_lcc = (topic === 'lcc');
        $('.shelf-browse.display .help-content').children().each(function() {
            var $topic = $(this);
            var node   = $topic[0];
            var prefix = 'help_lcc_';
            var names  = (' ' + node.className).replace(/[\t\r\n\f]/g, ' ');
            var lcc_topic = (names.indexOf(' ' + prefix) >= 0);
            var make_visible = to_lcc ? lcc_topic : !lcc_topic;
            if (make_visible && $topic.hasClass('hidden')) {
                $topic.removeClass('hidden').addClass('visible');
            } else if (!make_visible && $topic.hasClass('visible')) {
                $topic.removeClass('visible').addClass('hidden');
            }
        });
    }

    // ========================================================================
    // Function definitions - Navigation
    // ========================================================================

    /**
     * Make the first/last item the focus item.
     *
     * @param {string} location       Either "first" or "last".
     */
    function focusOn(location) {

        var first   = (location === 'first');
        var $tiles  = $('.shelf-browse.display .item-tile');
        var $target = first ? $tiles.first() : $tiles.last();

        // If the first/last item is empty - go forward/backward until the
        // first/last good item is encountered.
        if (focusId($target) < 0) {
            do {
                $target = first ? $target.next() : $target.prev();
            } while (notEmpty($target) && (focusId($target) < 0));
            if (isEmpty($target)) {
                _debug('*** no change; no good tiles ***');
                return;
            }
        }

        // Change focus to the requested item unless it is already the focus
        // item.
        if ($target.hasClass('focus')) {
            _debug('*** no change ***');
        } else {
            _debug('*** focus ' + location + ' ***');
            setFocusItem($target);
        }
    }

    /**
     * Move the focus *count* tiles forward or backward.
     *
     * @param {string} direction      Either "forward" or "reverse".
     * @param {number} [count]        Default: 1.
     */
    function step(direction, count) {
        var steps   = count || 1;
        var fwd     = (direction === 'forward');
        var edge    = fwd ? 'last' : 'first';
        var $focus  = $('.shelf-browse.display .item-tile.focus');
        var $target = fwd ? $focus.next() : $focus.prev();
        if (isMissing($target)) {
            _debug('*** at ' + edge + ' tile ***');
            return;
        }
        var fid = focusId($target);
        if ((fid < 0) && isMissing(fwd ? $target.next() : $target.prev())) {
            _debug('*** at ' + edge + ' good tile ***');
            return;
        }
        _debug('*** focus ' + direction + ' ' + steps + ' ***');
        setFocusItem($target);
    }

    /**
     * Move *count* pages forward or backward.
     *
     * @param {string} direction      Either "forward" or "reverse".
     * @param {number} [count]        Default: 1.
     */
    function page(direction, count) {
        var pages = count || 1;
        _debug('*** page ' + direction + ' ' + pages + ' ***');
        var selector = '.shelf-browse.display .page-' + direction;
        selector += '[data-step="' + pages + '"]';
        $(selector).click();
    }

    /**
     * Perform a navigation action.
     *
     * @param {ACTION} action
     * @param {number} [count]
     */
    function navigation(action, count) {
        switch (action) {
            case ACTION.FocusFirst:
                focusOn('first');
                break;

            case ACTION.FocusLast:
                focusOn('last');
                break;

            case ACTION.FocusFwd:
                step('forward', count);
                break;

            case ACTION.FocusRev:
                step('reverse', count);
                break;

            case ACTION.PageHome:
                _debug('*** page 0 ***');
                gotoTargetPage('.shelf-browse.display .origin');
                break;

            case ACTION.PageFwd:
                page('forward', count);
                break;

            case ACTION.PageRev:
                page('reverse', count);
                break;

            default:
                //_debug('ignored action ' + action);
                break;
        }
    }

    // ========================================================================
    // Function definitions - Item details
    // ========================================================================

    /**
     * Scroll according to *feature_status*.
     *
     * @param {Selector} container
     * @param {string}   scroll_override  One of "top", "bottom" or "toggle".
     * @param {string}   [called_by]  Name of the caller for error messages.
     */
    function updateItemDetails(container, scroll_override, called_by) {

        var _func_ = called_by || arguments.callee.name;
        var $container = container ? $(container) : getItemDetails(_func_);

        // If a scroll mode has been specified, the radio buttons do not need
        // to be consulted (or updated).  If not then see whether a scroll mode
        // has already been selected.
        var $radio_buttons;
        var scroll;
        if (notEmpty(scroll_override)) {
            scroll = scroll_override;
        } else {
            $radio_buttons = $container.find('.scroll-options input');
            $radio_buttons.each(function() {
                var $this = $(this);
                var checkbox = $this[0];
                if (checkbox.checked) {
                    scroll = $this.attr('value');
                    return false; // break from each()
                }
            });
        }

        // See if a scroll mode has defined internally.
        if (notDefined(scroll)) {
            scroll = feature_status.details_scroll || config.details_scroll;
        }

        // If a scroll mode has been supplied or pre-defined, honor it now.
        if (isDefined(scroll)) {

            // Update scroll position.
            var c = $container[0];
            var pos_top    = 0;
            var pos_bottom = c.scrollHeight - c.offsetHeight;
            var pos;
            switch (scroll) {
                case 'top':
                    pos = pos_top;
                    break;
                case 'bottom':
                    pos = pos_bottom;
                    break;
                case 'toggle':
                    var pos_middle = pos_bottom / 2;
                    pos = (c.scrollTop > pos_middle) ? pos_top : pos_bottom;
                    break;
                default:
                    console.warn(_func_ + ': unexpected: ' + scroll);
                    break;
            }
            if (isDefined(pos)) {
                $container.scrollTop(pos);
            }

            // Update radio button selection.
            if ($radio_buttons) {
                feature_status.details_scroll = scroll;
                $radio_buttons.each(function() {
                    var $this = $(this);
                    var checkbox = $this[0];
                    checkbox.checked = ($this.attr('value') === scroll);
                });
            }
        }

        // Reposition copyright info popup.
        Copyright.updateInfo($container, '.item-metadata');
    }

    /**
     * Show metadata for the focus item.
     */
    function showFocusDetails() {

        _debug(arguments);
        var _func_ = arguments.callee.name;

        // Get the .item-details element.
        var $container = getItemDetails(_func_);
        if (!$container) { return; }

        // Get the metadata currently displayed in .item-details (if any).
        var $old_metadata = getItemMetadata($container, _func_);
        var old_tile_id = tileId($old_metadata);

        // Get the current focus item.
        var $focus = getFocusItemTile(_func_);
        var new_tile_id = tileId($focus);

        // If the id of the focus item matches the currently-displayed metadata
        // then the focus item is already showing.
        if (old_tile_id && (old_tile_id === new_tile_id)) {
            _debug(_func_, 'already displaying tile', old_tile_id);
            return;
        }

        // Get the focus item metadata.
        var $new_metadata = getItemMetadata($focus, _func_);
        if (!$new_metadata) { return; }

        // Find the owner of the currently-displayed metadata.
        var $old_item = old_tile_id && getItemTile(old_tile_id, _func_);

        // Move the focus item metadata into .item-details.
        if ($new_metadata) {
            $new_metadata.detach().prependTo($container).addClass('visible');
            updateItemDetails($container, '', _func_);
        }

        // Move the previous metadata out of .item-details and back to its
        // owner.
        if ($old_metadata) {
            $old_metadata.removeClass('visible');
            if ($old_item) {
                $old_metadata.detach().appendTo($old_item);
            } else {
                $old_metadata.remove();
            }
        }
    }

    /**
     * Temporarily display metadata for an item without removing the focus item
     * metadata.
     *
     * @param {Selector} item
     * @param {string}   [scroll_override]  One of "top", "bottom" or "toggle".
     */
    function addTempDetails(item, scroll_override) {

        _debug(arguments);
        var _func_ = arguments.callee.name;

        // Get the .item-details element.
        var $container = getItemDetails(_func_);
        if (!$container) { return; }

        // Get the metadata currently displayed in .item-details (if any).
        var $old_metadata = getItemMetadata($container, _func_);
        var old_tile_id = tileId($old_metadata);

        // Get the temporary item.
        var $new_item = single(item, 'item', _func_);
        if (!$new_item) { return; }
        var new_tile_id = tileId($new_item);

        // If the id of the temporary item matches the currently-displayed
        // metadata then there's nothing else to do.
        if (old_tile_id && (old_tile_id === new_tile_id)) {
            _debug(_func_, 'already displaying tile', old_tile_id);
            return;
        }

        // If the temporary item has no metadata then take no action.
        var $new_metadata = getItemMetadata($new_item, _func_);
        if (!$new_metadata) {
            console.error(_func_ + ': item has no metadata');
            return;
        }

        // Move the metadata into .item-display (which masks the current
        // item metadata but does not replace it).
        $new_metadata.detach().prependTo($container);
        $new_metadata.addClass('temporary').addClass('visible');
        updateItemDetails($container, scroll_override, _func_);

        // Hide the previous metadata.
        if ($old_metadata) {
            $old_metadata.removeClass('visible');
        }
    }

    /**
     * Remove temporary item metadata inserted by addTempDetails() and restore
     * the focus item metadata.
     */
    function removeTempDetails() {

        _debug(arguments);
        var _func_ = arguments.callee.name;

        // Determine if .item-details contains any temporary item metadata.
        var selector   = '.shelf-browse.display .item-details .item-metadata';
        var $temporary = $(selector + '.temporary');
        if (isMissing($temporary)) { return; }

        // Remove temporary item metadata.
        $temporary.each(function() {
            var $metadata = $(this);
            var tile_id   = tileId($metadata);
            var $owner    = getItemTile(tile_id, _func_);
            if ($owner) {
                $metadata.removeClass('temporary').removeClass('visible');
                $metadata.detach().appendTo($owner);
            }
        });

        // Restore visibility of the focus item metadata which was hidden by
        // addTempDetails().
        $(selector).each(function() {
            var $metadata = $(this);
            $metadata.addClass('visible');
        });

        // Apply final updates to the displayed metadata item.
        updateItemDetails(null, '', _func_);
    }

    /**
     * Change the item of focus by moving the item's metadata from the new
     * focus item tile into .item-display and moving the previous focus item's
     * metadata back into its item tile.
     *
     * @param {Selector} new_item           New donor of metadata.
     * @param {string}   [scroll_override]  One of "top", "bottom" or "toggle".
     */
    function setFocusItem(new_item, scroll_override) {

        _debug(arguments);
        var _func_ = arguments.callee.name;

        // Get the .item-details element and return any temporary metadata
        // elements to their respective tiles.
        var $container = getItemDetails(_func_);
        if (!$container) { return; }
        removeTempDetails();

        // Get the new item.
        var $new_item = single(new_item, 'new item', _func_);
        if (!$new_item) { return; }
        if (_debugging) {
            var fid = focusId($new_item);
            if (fid < 0) {
                _debug(_func_, '*** bad tile; focus-id ' + fid + ' ***');
            }
        }

        // If this is already the focus item then we can be done, although if
        // a scroll has been specified, the currently-displayed metadata may
        // need to be updated.
        if ($new_item.hasClass('focus')) {
            _debug(_func_, 'item already has focus');
            if (notEmpty(scroll_override)) {
                updateItemDetails($container, scroll_override, _func_);
            }
            return;
        }

        // If the new item has no metadata then take no action.
        var $new_metadata = getItemMetadata($new_item, _func_);
        if (!$new_metadata) { return; }

        // Get the current focus item.
        var $old_item = getFocusItemTile(_func_);

        // Get the metadata currently displayed in .item-details (which should
        // belong to the current focus item).
        var $old_metadata = getItemMetadata($container, _func_);
        if (_debugging && $old_metadata) {
            var itm_id = tileId($old_item);
            var dat_id = tileId($old_metadata);
            if (itm_id !== dat_id) {
                console.error(
                    _func_ + ': item_id=' + itm_id + ', data_id=' + dat_id
                );
            }
        }

        // Move the focus item metadata into .item-details.
        if ($new_metadata) {
            $new_metadata.detach().prependTo($container).addClass('visible');
            updateItemDetails($container, scroll_override, _func_);
        }

        // Move the previous metadata out of .item-details and back to its
        // owner.
        if ($old_metadata) {
            $old_metadata.removeClass('visible');
            if ($old_item) {
                $old_metadata.detach().appendTo($old_item);
            } else {
                $old_metadata.remove();
            }
        }

        // Change item of focus.
        if ($old_item) { $old_item.removeClass('focus'); }
        if ($new_item) { $new_item.addClass('focus'); }
    }

    // ========================================================================
    // Function definitions - Progress bar
    // ========================================================================

    /**
     * Replace the call number range display with the progress bar overlay.
     *
     * @param {string} motion         Either "right" or "left"; if *null*, this
     *                                  is determined by the presence of the
     *                                  element with class
     *                                  ".page-display.behind".
     * @param {string} [text]         Optional text to show in the bar.
     *
     * @see UVA::Helper::ShelfBrowse#page_display
     */
    function showProgressBar(motion, text) {

        _debug(arguments);

        var $display = $('.shelf-browse.display');
        var $target = $display.find('.current-range-area').first();
        if (isMissing($target)) {
            var _func_ = arguments.callee.name;
            console.error(_func_ + ': missing .current-range-area');
            return;
        }

        var behind;
        var dir;
        if (motion) {
            behind = (motion === 'left');
            dir    = motion;
        } else {
            behind = !!$display.find('.page-display.behind')[0];
            dir    = behind ? 'right' : 'left';
        }

        var content;
        if (text) {
            content = text;
        } else if (config.show_progress_bar_text) {
            var arrow = behind ? '<<<<<<<<<<' : '>>>>>>>>>>';
            content = arrow + ' retrieving items ' + arrow;
        } else {
            content = '&nbsp;';
        }

        var $bar =
            $('<div>')
              .addClass('progress-bar ' + dir)
              .attr('role', 'progressbar')
              .html(content);
        $target.html($('<div>').addClass('progress-overlay').append($bar));
    }

    /**
     * Scroll the entire .tile-container element.
     *
     * @param {string} motion         Either "right" or "left"; if *null*, this
     *                                  is determined by the presence of the
     *                                  element with class
     *                                  ".page-display.behind".
     *
     * @see UVA::Helper::ShelfBrowse#page_display
     */
    function showTileScroller(motion) {

        _debug(arguments);

        var $display = $('.shelf-browse.display');
        var $target  = $display.find('.tile-container').first();
        if (isMissing($target)) {
            var _func_ = arguments.callee.name;
            console.error(_func_ + ': missing .tile-container');
            return;
        }

        var behind;
        var dir;
        if (motion) {
            behind = (motion === 'left');
            dir    = motion;
        } else {
            behind = !!$display.find('.page-display.behind')[0];
            dir    = behind ? 'right' : 'left';
        }

        // Moving to the right (to higher call numbers) causes a scroll to the
        // left.  Moving to the left (to lower call numbers) causes a scroll to
        // the right.
        var opposite = (dir === 'right') ? 'left' : 'right';
        $target.addClass('scroll-' + opposite);
    }

    /**
     * Illustrate movement across the virtual shelf.
     *
     * @param {string} motion         Either "right" or "left".
     * @param {string} [text]         Optional text to show (where applicable).
     *
     * @see UVA::Helper::ShelfBrowse#page_display
     */
    function showMotion(motion, text) {
        if (config.show_motion) {
            if (config.show_progress_bar)  { showProgressBar(motion, text); }
            if (config.show_tile_scroller) { showTileScroller(motion); }
        } else {
            _debug(arguments, 'disabled');
        }
    }

    // ========================================================================
    // Function definitions - Cover images
    // ========================================================================

    /**
     * Request cover images for all .cover-image elements in the display.
     */
    function loadCoverImages() {
        _debug(arguments);
        var $elements = $('.shelf-browse.display span.cover-image');
        CoverImage.loadCoverImageElements($elements);
    }

    // ========================================================================
    // Function definitions - LCC browser
    // ========================================================================

    /**
     * @constant
     * @type {object}
     */
    var LCC = {
        close_marker:  'close',
        overlay_class: 'lcc-overlay',
        container:     '.shelf-browse.display .lcc-tree-display'
    };

    /**
     * Get the call number range from the LCC tree element id.
     *
     * Classes have ids of the form "CLASS_X"; subclasses have ids of the form
     * "SUBCLASS_XX"; all other have ids which are the call number range for
     * the element.
     *
     * @param {string} tree_id
     *
     * @return {string}               Empty if *id* was ROOT_ID.
     */
    function treeIdToCallNumberRange(tree_id) {
        var id = tree_id.toString().toUpperCase();
        return (id === ROOT_ID) ? '' : id.replace(/^[^_]*_/, '');
    }

    /**
     * Indicate whether the LCC browser is filled with tree data.
     *
     * @return {boolean}
     */
    function hasTreeData() {
        return !!lcc_tree_options.json_data.data;
    }

    /**
     * LCC browser tree data, taken from the cache if present.
     *
     * @return {object|undefined}     Data in JSON format or *undefined* if
     *                                  data has not been saved (yet).
     */
    function getTreeData() {
        return lcc_tree_options.json_data.data || setTreeData();
    }

    /**
     * Store LCC browser tree data.
     *
     * @param {object} [tree_data]    Data in JSON format; if missing, the
     *                                  cache will be used.
     *
     * @return {object|undefined}     Data in JSON format or *undefined* if
     *                                  data was missing.
     */
    function setTreeData(tree_data) {
        var cache;
        var data = tree_data || (cache = lcc_cache.get());
        if (data) {
            lcc_tree_options.json_data.data = data;
            lcc_tree_options.json_data.ajax = false;
            if (!cache) {
                lcc_cache.set(data);
            }
        }
        return data;
    }

    /**
     * Save data from the jstree instance.
     *
     * @param {object} [tree_instance]
     */
    function cacheTreeData(tree_instance) {
        feature_status.lcc_downloading = true;
        var tree = tree_instance || $.jstree._focused();
        var data = tree.get_json();
        setTreeData(data);
        feature_status.lcc_downloading = false;
    }

    /**
     * Set up LCC tree scroller.
     *
     * @param {Selector} [element]
     *
     * @todo This would benefit from some speed-up tuning:
     *    - Saving the received data with get_json() takes several seconds.
     *        Is there a faster way to accomplish this?
     *    - Even with cached data, creating the tree with each invocation of
     *        new_page() is fairly slow (~1.5 seconds).  Is there a way to
     *        reuse the same jstree instance instead?
     */
    function makeLccTree(element) {

        _debug(arguments);

        var _func_ = arguments.callee.name;
        var $element = $(element || '.shelf-browse.display #lcc-tree');
        if (hasTreeData()) {
            _debug(_func_, 'REUSING LCC TREE');
        } else if (getTreeData()) {
            _debug(_func_, 'USING CACHED DATA');
        }
        var start = Date.now();

        // Documentation for jstree recommends binding the "loaded" event
        // before actually creating the tree control.
        $element.bind('loaded.jstree', function() {

            // Report on the time it takes for the jstree to be built.
            _debug(_func_, 'JSTREE LOADED sec.', secondsSince(start));
            var $tree = $(this);

            // Set up click handlers for tree nodes but defer tab focus to the
            // interior div.class, div.subclass, or div.range.
            $tree.find('a')
                .attr('tabindex', -1)
                .focus(function(event) { lccFocusOn(event.target, 'FOCUS'); })
                .blur(function(event)  { lccFocusOff(event.target, 'FOCUS'); })
                .hover(
                    function(event) { lccFocusOn(event.target, 'HOVER'); },
                    function(event) { /*lccFocusOff(event.target, 'HOVER');*/ }
                )
                .click(function(event) {
                    var $button = $(event.target);
                    if ($button.attr('data-path')) {
                        _debug('TREE ITEM CLICKED - inside range button');
                        event.preventDefault();
                        gotoShelfPage($button);
                    } else {
                        _debug('TREE ITEM CLICKED - outside range button');
                    }
                });

            // Make return act as a click for items reached by keyboard tabbing
            handleKeypressAsClick($tree);

            // Setup analytics click handlers.
            Analytics.updatePage($tree, '[data-path]');

            // Handle the icon on the root node specially -- clicking does not
            // toggle the whole tree open/closed but instead recursively closes
            // all nodes.  This is, in part, to make sure that the tree window
            // does not shrink when the tree is closed because the button tray
            // (now pinned) would remain behind on the display.
            var $root_node = $tree.find('li#' + ROOT_ID);
            var $root_icon = $root_node.children('ins');
            $root_icon.attr('title', TOOLTIP.lcc_root_icon);
            $root_icon.click(function(event) {
                _debug('TREE ROOT ICON CLICKED');
                event.preventDefault();
                event.stopPropagation();
                $.jstree._focused().close_all($root_node, false);
                $.jstree._focused().open_node($root_node, null, true);
            });

            // Save the JSON tree data if it has not already been cached.
            // (This won't be executed if fetchLccData() had already filled the
            // cache.)
            if (!hasTreeData()) {
                cacheTreeData();
                _debug(_func_, 'CACHED sec.', secondsSince(start));
            }
        });

        // Create the tree control.
        $element.jstree(lcc_tree_options);
    }

    /**
     * Download the JSON data for the LCC tree.
     */
    function fetchLccData() {

        if (hasTreeData()) {
            return;
        }
        var _func_ = arguments.callee.name;
        if (feature_status.lcc_downloading) {
            _debug(_func_, 'already downloading');
            return;
        }
        var start = Date.now();
        feature_status.lcc_downloading = true;

        $.ajax({
            url:      config.lcc_tree_path,
            type:     'GET',
            dataType: 'json',

            // Store the received data.
            success: function(result) {
                _debug(_func_, 'GET return sec.', secondsSince(start));
                setTreeData(result);
            },

            // Note the failure.
            error: function(xhr, status, error) {
                console.warn(_func_ + ': ' + status + ': ' + error);
            },

            // Reset the downloading flag when done.
            complete: function() {
                feature_status.lcc_downloading = false;
            }
        });
    }

    /**
     * Display the currently-hidden LCC tree.
     *
     * @param {Selector} [control]
     * @param {Selector} [container]
     */
    function showLccTree(control, container) {

        _debug(arguments);

        // Show overlay to dim the display.
        addOverlay(LCC.overlay_class);

        // Change the control into a button for re-hiding the panel.
        if (control) {
            $(control).text(LABEL.lcc_close).addClass(LCC.close_marker);
        }

        // If the tree display does not yet exist, fill the container with a
        // placeholder.
        var $container   = $(container || LCC.container);
        var $carrier     = $container.children('.lcc-tree').first();
        var tree_missing = isMissing($carrier.children('#lcc-tree'));
        if (tree_missing) {
            var label = lcc_tree_options.core.strings.loading;
            $('<div id="lcc-tree">').html(label).prependTo($carrier);
        }

        // Modify help topics; hide main help; show LCC help.
        finalizeButtonTray(control, $container, hideLccTree);
        changeHelpTopics('lcc');
        $container.css('display', 'block').focus();

        // Create the tree display if needed.
        if (tree_missing) {
            makeLccTree();
        }
    }

    /**
     * Close the currently-displayed LCC tree.
     *
     * @param {Selector} [control]
     * @param {Selector} [container]
     */
    function hideLccTree(control, container) {

        _debug(arguments);

        // Make the control a button for re-showing the tree.
        if (control) {
            $(control).text(LABEL.lcc_open).removeClass(LCC.close_marker);
        }

        // Hide the tree display.
        $(container || LCC.container).css('display', 'none');

        // Remove the overlay.
        removeOverlay(LCC.overlay_class);

        // Restore help topics; restore main help; hide LCC help.
        changeHelpTopics('default');

        // If a page resize was deferred, complete it now.
        if (feature_status.resize_pending) {
            feature_status.resize_pending = false;
            feature_status.resizeHandler();
        }
    }

    /**
     * Toggle the state of the LCC tree: Close it if it is currently displayed;
     * open it if it is currently hidden.
     *
     * @param {Selector} control
     */
    function toggleLccTree(control) {
        var $control = $(control);
        if ($control.hasClass(LCC.close_marker)) {
            hideLccTree($control);
        } else {
            showLccTree($control);
        }
    }

    // ========================================================================
    // Function definitions - LCC browser keyboard navigation
    // ========================================================================

    /**
     * Move the element currently selected in the LCC tree based on the given
     * key press.
     *
     * Used by jstree hotkeys plugin key handlers defined above.
     *
     * @param {CHAR}   key
     * @param {object} [tree_instance]
     *
     * @return {boolean}              Always *false*.
     */
    function lccMotion(key, tree_instance) {
        var tree = tree_instance || $.jstree._focused();
        var $cur = tree.data.ui.hovered || tree.data.ui.last_selected;
        var _dir;
        switch (key) {
            case CHAR.ArrowUp:   _dir = 'UP  '; break;
            case CHAR.ArrowDown: _dir = 'DOWN'; break;
        }
        var node;
        switch (key) {
            case CHAR.ArrowUp:   node = tree._get_prev($cur || -1); break;
            case CHAR.ArrowDown: node = tree._get_next($cur || -1); break;
        }
        if (isPresent(node)) {
            tree.hover_node(node);
            var $new = tree.data.ui.hovered;
            if (isPresent($new)) {
                if ($cur && !$new.is($cur)) { $cur.children('a').blur(); }
                $new.children('a').focus();
            }
        }
        return false;
    }

    /**
     * Given a element within the LCC tree, return the <a> element if it is
     * is in the hovered state.
     *
     * @param {Selector} target
     * @param {string}   [_name]      Action label for debug messages.
     * @param {string}   [_dir]       Direction label for debug messages.
     *
     * @return {jQuery|boolean|undefined}
     */
    function lccFocusTarget(target, _name, _dir) {
        var $target = $(target);
        var $a;
        if ($target.is('li')) {
            $a = $target.children('a');
        } else if ($target.is('a')) {
            $a = $target;
        } else if ($target.not('[data-path]')) {
            $a = $target.closest('a');
        } else {
            return;
        }
        _debug(arguments);
        return $a.hasClass('jstree-hovered') && $a;
    }

    /**
     * Give an LCC tree entry focus.
     *
     * @param {Selector} target
     * @param {string}   [name]
     */
    function lccFocusOn(target, name) {
        var $a = lccFocusTarget(target, name, 'IN');
        if (isPresent($a)) {
            $a.children('div').focus().children('[data-path]').focus();
        }
    }

    /**
     * Remove focus from an LCC tree entry.
     *
     * @param {Selector} target
     * @param {string}   [name]
     */
    function lccFocusOff(target, name) {
        var $a = lccFocusTarget(target, name, 'OUT');
        if (isPresent($a)) {
            $a.children('div').blur().children('[data-path]').blur();
        }
    }

    // ========================================================================
    // Function definitions - Requests
    // ========================================================================

    /**
     * @constant
     * @type {object}
     */
    var DIALOG = {
        overlay_class: 'dialog-overlay',
        container:     '.shelf-browse.display .dialog-container',
        cancel_labels: ['Cancel', 'Close', 'Done']
    };

    /**
     * Display a request dialog panel.
     *
     * @param {Selector} control
     * @param {Selector} [container]
     */
    function showRequestDialog(control, container) {

        _debug(arguments);

        // Display overlay to dim the display.
        addOverlay(DIALOG.overlay_class);

        // Get the link destination from the control.
        var $control = $(control);
        var url = $control.attr('data-path') || $control.attr('href');

        // Display the initially-empty panel.
        var $container = $(container || DIALOG.container);
        var $dialog    = $container.children('.dialog-contents').first();
        finalizeButtonTray(control, $container, hideRequestDialog);
        clearDialog($dialog);
        $container.css('display', 'block').focus();

        // Load content from the destination.
        $.get(url, function(result) {
            updateDialog($dialog, result);
        });
    }

    /**
     * Close the currently-displayed request dialog panel.
     *
     * @param {Selector} [control]
     * @param {Selector} [container]
     */
    function hideRequestDialog(control, container) {

        _debug(arguments);

        // Hide the dialog display.
        $(container || DIALOG.container).css('display', 'none');

        // Remove the overlay.
        removeOverlay(DIALOG.overlay_class);

        // If a page resize was deferred, complete it now.
        if (feature_status.resize_pending) {
            feature_status.resize_pending = false;
            feature_status.resizeHandler();
        }
    }

    /**
     * Restore the dialog element to its unloaded state.
     *
     * @param {Selector} dialog
     */
    function clearDialog(dialog) {
        $(dialog).empty().addClass('loading');
    }

    /**
     * Extract content from an AJAX reply and append the results to the dialog
     * element.
     *
     * @param {Selector} dialog
     * @param {string}   html
     */
    function updateDialog(dialog, html) {

        _debug(arguments);

        var _func_ = arguments.callee.name;
        var $dialog = $(dialog);

        // Extract the element that has the content and normalize so that
        // "dialog-wrapper" is the root element.
        var $received = $('<div class="dialog-wrapper">' + html + '</div>');
        var $wrapper =
            dialogContent($received, '.popup-content') ||
            dialogContent($received, '.page-content') ||
            dialogContent($received);

        // If the result was empty, add some content here just to indicate the
        // updated state of the dialog.
        if (isMissing($wrapper)) {
            $('<div>')
                .addClass('dialog-inserted-text')
                .text('Request complete.')
                .appendTo($wrapper);
        }

        // Fix "Cancel" links so that they operate like close buttons.
        var $buttons = $wrapper.find('.btn,.button,[role="button"]');
        $buttons.each(function() {
            dialogCancel(this);
        });

        // Override "Submit" button so that the results are captured.
        var $form = $wrapper.find('form');
        if (notEmpty($form)) {

            // Add hidden form parameters to control the generation of the
            // destination page content.
            var hidden_parameters = {
                popup:    true,
                redirect: false
            };
            $.each(hidden_parameters, function(name, value) {
                var parameters = 'name="' + name + '" value="' + value + '"';
                $form.append('<input type="hidden" ' + parameters + ' >');
            });

            // Override click handler.
            var url    = $form.attr('action');
            var method = $form.attr('method') || 'POST';
            $form.find('input[type="submit"]').click(function(event) {
                event.preventDefault();
                event.stopPropagation();
                $dialog.addClass('loading').children().hide();
                $.ajax({
                    url:  url,
                    type: method,
                    data: $form.serialize(),
                    success: function(result) {
                        updateDialog($dialog, result);
                    },
                    error: function(xhr, status, error) {
                        console.warn(_func_ + ': ' + status + ': ' + error);
                        updateDialog($dialog, error);
                    }
                });
            });
        }

        // Display the updated dialog.
        $dialog.empty().removeClass('loading').append($wrapper);

        // If there were no control buttons add a "Done" button for consistency
        // (although it does the same thing as the close button).
        //
        // NOTE: This has to happen after $result is appended to $dialog
        // because the jQuery ":visible" selector will have no meaning until
        // the buttons are part of the DOM display.
        //
        if (isEmpty($buttons.filter(':visible'))) {
            var $done =
                $('<div>')
                  .addClass('dialog-inserted-done btn primary')
                  .attr('role', 'button')
                  .text('Done')
                  .appendTo($wrapper);
            dialogCancel($done);
        }

        // Make return act as a click for items reached by keyboard tabbing.
        handleKeypressAsClick($wrapper);
    }

    /**
     * dialogContent
     *
     * @param {jQuery} $received
     * @param {string} [root_selector]
     *
     * @return {jQuery|undefined}
     */
    function dialogContent($received, root_selector) {
        var $result;
        if (root_selector) {
            var $root = $received.find(root_selector).first();
            if (notEmpty($root)) { $result = $root; }
        } else {
            $result = $received;
        }
        if ($result && !$result.hasClass('dialog-wrapper')) {
            var $wrapper = $('<div>').addClass('dialog-wrapper');
            $result = $wrapper.append($result.children());
        }
        return $result;
    }

    /**
     * If the link is intended to cancel the operation, turn it into a dialog
     * cancel button (which does the same thing as the dialog close button in
     * the button tray).
     *
     * @param {Selector} link
     */
    function dialogCancel(link) {
        var $link = $(link);
        var label = $link.text();
        if (DIALOG.cancel_labels.indexOf(label) >= 0) {
            $link.removeAttr('href');
            $link.click(function() {
                hideRequestDialog($link);
            });
        }
    }

    // ========================================================================
    // Function definitions - Resizable panels
    // ========================================================================

    /**
     * Highlight the splitter unless it is currently being dragged.
     *
     * @param {Selector} element
     */
    function highlightSplitter(element) {
        if (!feature_status.splitter_dragging) {
            $(element)
              .css('background-color', 'orange')
              .attr('title', TOOLTIP.splitter);
        }
    }

    /**
     * Un-highlight the splitter unless it is currently being dragged.
     *
     * @param {Selector} element
     */
    function unhighlightSplitter(element) {
        if (!feature_status.splitter_dragging) {
            $(element).css('background-color', 'transparent');
        }
    }

    // ========================================================================
    // Function definitions - Setup
    // ========================================================================

    /**
     * Install shelf browse event handlers on the appropriate DOM elements.
     *
     * @param {object} [options]      Optional.
     *
     * === Usage Note
     * This is required for both colorbox popups and web pages when starting up
     * and every time a new /shelf_browse page is acquired.
     */
    function attachHandlers(options) {

        _debug(arguments);

        var _func_ = arguments.callee.name;

        var popup = true;
        if (options && isDefined(options.popup)) {
            popup = options.popup;
        } else if (isDefined(feature_status.popup)) {
            popup = feature_status.popup;
        }

        // Determine which types of information to update.
        var update = {
            analytics:      true,
            availability:   true,
            bookplates:     true,
            copyright:      true,
            covers:         true,
            google_preview: true,
            starred_items:  false
        };
        var skip   = false;
        if (options && isDefined(options.skip)) {
            skip = options.skip;
        } else if (isDefined(feature_status.skip)) {
            skip = feature_status.skip;
        }
        if (typeof skip === 'string') {
            skip = skip.split(',');
        }
        if (skip) {
            skip.forEach(function(info) {
                if (notDefined(update[info])) {
                    console.warn(_func_ + ': unexpected: ' + info);
                }
                update[info] = false;
            });
        }

        // ====================================================================
        // Check for resize needed (web pages only; not for colorbox popup).
        // ====================================================================

        // If the browser makes a direct URL request for a virtual shelf browse
        // web page then there is no way for the server to determine the right
        // number of items to fill the page with.  The size of the display must
        // be evaluated to determine the number of items the display can
        // currently handle.
        //
        // If this is different than the number of items delivered by the
        // server then a new page is requested.
        //
        if (!popup && !skip) {
            if (_debugging) { logProperties(); }
            resizeDisplay();
        }

        // ====================================================================
        // Event handlers - Browser events
        // ====================================================================

        var $window = $(window);

        // Honor arrow keys to move the focus item.
        if (!feature_status.keyHandler) {
            feature_status.keyHandler = keyHandler;
            $window.bind('keyup', feature_status.keyHandler);
        }

        // Adjust number of items displayed with the window resizes.
        if (!feature_status.resizeHandler) {
            feature_status.resizeHandler = popup ? resizePopup : resizeDisplay;
            $window.smart_resize(feature_status.resizeHandler);
        }

        // ====================================================================
        // Event handlers - Header row
        // ====================================================================

        var $display     = $('.shelf-browse.display');
        var $header_area = $display.children('.header-area').children();

        // If $header_area is empty then something's very wrong so quit now.
        if (isEmpty($header_area)) {
            console.error(_func_ + ': NO .header-area; ABORTING');
            return;
        }

        var $help_button   = $header_area.filter('.help-button');
        var $lcc_button    = $header_area.filter('.lcc-button');
        var $title_text    = $header_area.filter('.title-text');
        var $origin_button = $header_area.filter('.origin');
        var $close_button  = $header_area.filter('.close-button');

        // Click on the main title to send information to the browser console.
        // (This is active in all deployments, including production.)
        $title_text.click(function() {
            logDefaults();
            logProperties();
            logStatus();
        });

        // Return to origin: Replace the display with the contents of virtual
        // shelf window 0.
        //
        // @see UVA::Helper::ShelfBrowse#origin_button
        //
        $origin_button.click(function() {
            _debug('CLICK .origin');
            gotoTargetPage(this);
        });

        // Click to close the popup.
        //
        // Since both .origin and .close-button have "float: right", ensure
        // that .close-button comes before .origin so that.close-button becomes
        // the rightmost element of .header-area.
        //
        if (isPresent($close_button)) {
            if ($origin_button) {
                $close_button.insertBefore($origin_button);
            }
            if (popup) {
                $close_button.click(function() {
                    $.fn.colorbox.close();
                });
            } else {
                $close_button.attr('title', 'Not enabled for web page.');
                $close_button[0].disabled = true;
            }
        }

        // ====================================================================
        // Event handlers - Help
        // ====================================================================

        // Click on a help button to show/hide the help panel.
        $help_button.click(function() {
            _debug('CLICK .help-button');
            toggleHelp(this);
        });

        // Display the "more" marker only when at the beginning of the scroll.
        if (config.show_more_scroll) {
            $display.find('.help-container').scroll(function() {
                //_debug('SCROLL .help-container');
                updateMoreScroll(this, HELP.scroll_direction);
            });
        }

        // ====================================================================
        // Event handlers - LCC browser
        // ====================================================================

        // Open/close the LCC tree display window.
        $lcc_button.click(function() {
            _debug('CLICK .lcc-button');
            toggleLccTree(this);
        });

        // ====================================================================
        // Event handlers - Navigation
        // ====================================================================

        var $page_controls = $display.find('.page-controls').children();

        // Page forward: Replace the display with the contents of the next
        // virtual shelf window.
        //
        // @see UVA::Helper::ShelfBrowse#page_forward_button
        //
        $page_controls.filter('.page-forward').click(function() {
            _debug('CLICK .page-forward');
            gotoShelfPage(this, 'right');
        });

        // Page backward: Replace the display with the contents of the previous
        // virtual shelf window.
        //
        // @see UVA::Helper::ShelfBrowse#page_reverse_button
        //
        $page_controls.filter('.page-reverse').click(function() {
            _debug('CLICK .page-reverse');
            gotoShelfPage(this, 'left');
        });

        // Replace the display with the contents of the link.
        //
        // @see UVA::Helper::ShelfBrowse#range_frame
        //
        $display.find('.range-frame [data-path]').click(function() {
            _debug('CLICK range link');
            gotoTargetPage(this);
        });

        // ====================================================================
        // Event handlers - Item details
        // ====================================================================

        var $metadata_areas = $display.find('.item-details, .item-tile');
        var $item_tiles     = $metadata_areas.filter('.item-tile');
        var $items          = $item_tiles.find('.item');

        // Change focus when the item is clicked.
        $item_tiles.click(function() {
            _debug('CLICK .item-tile');
            setFocusItem(this);
        });

        // Toggle scroll-to-top/scroll-to-bottom.
        $item_tiles.dblclick(function() {
            _debug('DOUBLE CLICK .item-tile');
            setFocusItem(this, 'toggle');
        });

        // Display item metadata when hovering over an item.
        $item_tiles.hover(
            function() {
                //_debug('MOUSE ENTER >>> .item-tile');
                addTempDetails(this);
            },
            function() {
                //_debug('MOUSE LEAVE <<< .item-tile');
                removeTempDetails();
            }
        );

        // Since $('.item-tile .item') are the elements with 'tabindex', the
        // focus events on those elements must be used to set the "focus" item
        // tile.
        $items.focus(function() {
            _debug('TABBED TO .item');
            var $tile = $(this).closest('.item-tile');
            setFocusItem($tile);
        });

        // ====================================================================
        // Event handlers - Resizable panels
        // ====================================================================

        var $item_ranges   = $display.find('.item-ranges');
        var $page_scroller = $display.find('.page-scroller');

        var $item_info_splitter     = $display.find('.item-info-separator');
        var $page_scroller_splitter = $display.find('.page-scroller-separator');

        var splitter = [$item_info_splitter, $page_scroller_splitter];

        // Highlight a splitter when hovered.
        splitter.forEach(function($target) {
            $target.hover(
                function() {
                    //_debug('SPLITTER ENTER >>>');
                    highlightSplitter(this);
                },
                function() {
                    //_debug('SPLITTER LEAVE <<<');
                    unhighlightSplitter(this);
                }
            );
        });

        // Double-clicking on the splitter restores the original split.
        $item_info_splitter.dblclick(function() {
            _debug('DOUBLE-CLICK .item-info-separator');
            var value =
                    feature_status.item_ranges_width_init ||
                    PROP.def_item_ranges_width;
            $(this).parent().children('.item-ranges').css('width', value);
            feature_status.item_ranges_width = 0;
            updateItemDetails(null, '', _func_);
        });

        // Double-clicking on the splitter restores the original split.
        $page_scroller_splitter.dblclick(function() {
            _debug('DOUBLE-CLICK .page-scroller-separator');
            var value =
                    feature_status.page_scroller_height_init ||
                    PROP.def_page_scroller_height;
            $(this).parent().children('.page-scroller').css('height', value);
            feature_status.page_scroller_height = 0;
        });

        // Allow manual resize of .item-ranges width.
        $item_ranges.resizable({

            handleSelector: '.item-info-separator',
            resizeHeight:   false,

            // Without this, the drag event seems to get picked up by text
            // boxes anywhere within the resize container.
            onDragStart: function(event, $element) {
                //_debug('.item-ranges onDragStart', event);
                event.preventDefault();
                unhighlightSplitter(event.currentTarget);
                feature_status.splitter_dragging = true;
                if (_debugging) {
                    var value = $element.css('width');
                    _debug('feature_status.item_ranges_width start', value);
                }
            },

            // Save the manually-set value to be re-applied with each
            // gotoShelfPage().
            onDragEnd: function(event, $element) {
                //_debug('.item-ranges onDragEnd', event);
                var value                        = $element.css('width');
                feature_status.item_ranges_width = value;
                feature_status.splitter_dragging = false;
                _debug('feature_status.item_ranges_width assigned', value);
                updateItemDetails(null, '', _func_);
            }
        });

        // Allow manual resize of .page-scroller height.
        $page_scroller.resizable({

            handleSelector: '.page-scroller-separator',
            resizeWidth:    false,

            // Without this, the drag event seems to get picked up by text
            // boxes anywhere within the resize container.
            onDragStart: function(event, $element) {
                //_debug('.page-scroller onDragStart', event);
                event.preventDefault();
                unhighlightSplitter(event.currentTarget);
                feature_status.splitter_dragging = true;
                if (_debugging) {
                    var value = $element.css('height');
                    _debug('feature_status.page_scroller_height start', value);
                }
            },

            // Save the manually-set value to be re-applied with each
            // gotoShelfPage().
            onDragEnd: function(event, $element) {
                //_debug('.page-scroller onDragEnd', event);
                var h = $element.css('height');
                if (parseFloat(h) < feature_status.page_scroller_height_min) {
                    h = feature_status.page_scroller_height_min + 'px';
                    $element.css('height', h);
                }
                _debug('feature_status.page_scroller_height assigned', h);
                feature_status.page_scroller_height = h;
                feature_status.splitter_dragging    = false;
            }
        });

        // ====================================================================
        // Actions - Resizable panels
        // ====================================================================

        var value;

        // Adjust the splitter between .item-ranges and .item-details if it was
        // manually changed.
        if (!feature_status.item_ranges_width_init) {
            value = $item_ranges.css('width');
            feature_status.item_ranges_width_init = value;
            _debug('item-ranges width initial', value);
        } else if (value = feature_status.item_ranges_width) {
            $item_ranges.css('width', value);
            _debug('item-ranges width restored', value);
        }

        // Adjust the splitter between .page-scroller and .item-info if it was
        // manually changed.
        if (!feature_status.page_scroller_height_init) {
            value = $page_scroller.css('height');
            feature_status.page_scroller_height_init = value;
            feature_status.page_scroller_height_min  = parseFloat(value);
            _debug('page-scroller height initial', value);
        } else if (value = feature_status.page_scroller_height) {
            $page_scroller.css('height', value);
            _debug('page-scroller height restored', value);
        }

        // ====================================================================
        // Actions - Item details
        // ====================================================================

        // Prepare request links in item metadata.
        var RECALL_LINK = 'a.initiate-request.no-popup';
        var SC_REQ_LINK = 'a.initiate-sc-request';
        $metadata_areas.find(RECALL_LINK + ',' + SC_REQ_LINK).each(function() {
            var $link = $(this);
            var href  = $link.attr('href');
            if (href) {
                if (!$link.attr('data-path')) {
                    $link.attr('data-path', href);
                }
                $link.removeAttr('href');
            }
            var url = $link.attr('data-path');
            if (url && !url.match('popup=true')) {
                url = addParameter(url, 'popup', 'true');
                $link.attr('data-path', url);
            }
            $link.attr('aria-haspopup', 'dialog');
            $link.click(function() {
                showRequestDialog(this);
            });
        });

        // Start out with metadata displayed for the focus item.
        //
        // The size of the .item-details will have already been settled by the
        // previous action; if the focus item has .physical-availability then
        // that will be dealt with in the next section.
        //
        showFocusDetails();

        // ====================================================================
        // Actions - Availability
        // ====================================================================

        // Get availability information for the focus item and then for the
        // rest of the items.  This way, the other items are likely to have
        // completed by the time the user switches to them.
        //
        if (update.availability) {
            Availability.getAvailability($metadata_areas);
        }

        // ====================================================================
        // Actions - Cover images
        // ====================================================================

        if (update.covers) {
            // Load cover images in the popup; on the shelf browse page, cover
            // images will be loaded from application.js.
            if (popup) {
                loadCoverImages();
            }
            // In either case, retry cover images in a few seconds in case
            // missing ones have been harvested.
            setTimeout(loadCoverImages, config.cover_image_retry);
        }

        // ====================================================================
        // Actions - Copyright & Permissions
        // ====================================================================

        if (update.copyright) {
          $metadata_areas.each(function() {
              Copyright.updateInfo(this, '.item-metadata');
          });
        }

        // ====================================================================
        // Actions - Starred Items
        // ====================================================================

        // NOTE: Currently not supported.
        if (update.starred_items) {
            StarredItems.updatePage($metadata_areas);
        }

        // ====================================================================
        // Actions - Bookplates
        // ====================================================================

        if (update.bookplates) {
            Bookplate.updatePage($metadata_areas);
        }

        // ====================================================================
        // Actions - Google Preview
        // ====================================================================

        if (update.google_preview) {
            GooglePreview.updatePage($metadata_areas);
        }

        // ====================================================================
        // Actions - Analytics
        // ====================================================================

        if (update.analytics) {
            Analytics.updatePage($display);
        }

        // ====================================================================
        // Event handlers - Accessibility
        // ====================================================================

        // Make return act as a click for items reached by keyboard tabbing.
        handleKeypressAsClick($display);

        // ====================================================================
        // Actions - Pre-load JSON data for the LCC tree
        // ====================================================================

        // This should only have to occur once per browser session.  Even in
        // that case, since the load takes around 5 seconds, it's very likely
        // that the data will already be downloaded by the time the user opens
        // the LCC tree viewer.
        fetchLccData();
    }

    /**
     * Uninstall event handlers.
     *
     * === Usage Note
     * This is required for the colorbox popup so that traces of the feature
     * are removed when the popup is closed.
     */
    function detachHandlers() {
        _debug(arguments);
        var $window = $(window);
        if (feature_status.keyHandler) {
            $window.unbind('keyup');
            feature_status.keyHandler = null;
        }
        if (feature_status.resizeHandler) {
            $window.unbind('resize');
            feature_status.resizeHandler = null;
        }
    }

    // ========================================================================
    // Function definitions - Links
    // ========================================================================

    /**
     * Create a virtual shelf browse popup for the given shelf browse URL.
     *
     * @param {string} url
     * @param {object} [opt]
     */
    function createPopup(url, opt) {
        var _func_ = arguments.callee.name;
        if (!url) {
            console.error(_func_ + ': no url');
            return;
        }

        // Add parameters to the URL.
        var options = { popup: true };
        if (opt) { $.extend(options, opt); }
        var path = setCurrentUrl(url, options);
        var prop = featureProperties(options);
        _trace(_func_, path);

        // Create the colorbox with the required size.
        $.fn.colorbox(AppColorbox.settings(_func_, {
            href:      path,
            scrolling: false,
            width:     prop.popup_width,
            height:    prop.popup_height,
            rel:       'nofollow',

            // Begin by marking shelf browse as active.
            onOpen: function() {
                AppColorbox.onOpen();
                _debug('colorbox onOpen');
                feature_status.active = true;
            },

            // This will be called after opening and after resize events.
            // (Active status is set a second time to cover the case where
            // virtual shelf browse is started from the availability popup
            // because onOpen() has already been called.)
            onLoad: function() {
                AppColorbox.onLoad();
                _debug('colorbox onLoad');
                feature_status.active  = true;
                feature_status.loading = true;
                var current = featureProperties(options);
                var w = current.popup_width;
                var h = current.popup_height;
                if ((w !== prop.popup_width) || (h !== prop.popup_height)) {
                    prop = current;
                    $(this).colorbox.resize({ innerWidth: w, innerHeight: h });
                }
            },

            // When ready, finalize the size of the colorbox and hook up event
            // handlers.
            onComplete: function() {
                AppColorbox.onComplete();
                _debug('colorbox onComplete', this);
                attachHandlers();
                feature_status.loading = false;
            },

            onCleanup: function() {
                AppColorbox.onCleanup();
                _debug('colorbox onCleanup');
                detachHandlers();
                feature_status.dropdowns_open = [];
            },

            // When this colorbox is closed then shelf browse is inactive.
            onClosed: function() {
                AppColorbox.onClosed();
                _debug('colorbox onClosed');
                feature_status.active = false;
            }
        }));
    }

    /**
     * Prepare the current content page (search results or show page) by
     * setting up handlers for each shelf browse link.
     *
     * @param {Selector} [selector]   Default: '.shelf-browse.links'.
     */
    function setupLinks(selector) {

        if (feature_status.active) {
            _debug(arguments, 'skipping for active ShelfBrowse');
            return;
        }
        _debug(arguments);
        var _func_ = arguments.callee.name;

        var links_class = '.shelf-browse.links';
        var display;
        switch (typeof selector) {
            case 'undefined':
                display = links_class;
                break;
            case 'string':
                display = selector + ' ' + links_class;
                break;
            case 'object':
                display = $(selector).find(links_class);
                break;
            default:
                console.warn(_func_ + ': unexpected: ' + selector);
                return;
        }
        var $display = $(display);
        var $buttons = $display.find('.browse-button');
        var $links   = $display.find('.call-number.browse > a');

        // Set accessibility attributes.
        var attributes = {
            role:            'button',
            'aria-haspopup': 'dialog'
        };
        [$buttons, $links].forEach(function($set) {
            $.each(attributes, function(key, value) {
                $set.attr(key, value);
            });
        });

        // Create colorbox when a shelf-browse button is activated.
        //
        // Creation of the colorbox is deferred so that determination of the
        // initial colorbox size can be made based on the current window
        // properties rather than the properties that were true when the page
        // was created.
        //
        $buttons.click(function() {
            _debug('CLICK browse button');
            try {
                createPopup(this);
            } catch(err) {
                // Generally this should only be triggered on IE 11 with the
                // current version of jQuery (2.1.4).  (It's hard to say why
                // the second invocation works.)
                console.warn(err.message + '  Retrying popup...');
                createPopup(this);
            }
        }).each(handleKeypressAsClick);

        // Sets colorbox for shelf-browse links.
        //
        // NOTE: This is not currently used.  However, if call numbers should
        // be displayed as links to shelf browse, this should probably be
        // refactored as a click handler just like .browse-button so that the
        // colorbox is created just-in-time.
        //
        $links.click(function() {
            _debug('BROWSE LINK', this);
            createPopup(this);
        }).each(handleKeypressAsClick);
    }

    // ========================================================================
    // Function definitions - Initialization
    // ========================================================================

    /**
     * Called when the web page is ready to initialize the virtual shelf browse
     * feature.
     */
    function updatePage() {

        // Currently there is no shelf browse support in print preview.
        if (inPrintView()) {
            return;
        }

        setCurrentUrl();
        setConfigProperties();

        var _func_ = arguments.callee.name;
        _trace(_func_, feature_status.full_url);

        // ====================================================================
        // Event handlers
        // ====================================================================

        var highlight_class = 'debug-highlight';

        // Highlight the enclosing element when hovering over a "debug-note".
        $('.debug-note').hover(
            function() { $(this).parent().addClass(highlight_class); },
            function() { $(this).parent().removeClass(highlight_class); }
        );

        // ====================================================================
        // Actions
        // ====================================================================

        var url = feature_status.full_url || feature_status.base_url;

        // Act based on the request URL.
        //
        // NOTE: Microsoft IE and Microsoft Edge don't seem to understand
        // String.include().
        //
        if (url.indexOf(config.feature_path) < 0) {

            _debug(_func_, 'not a virtual shelf browse page');
            setupLinks();

        } else {

            var option = getUrlProperties(url);
            if (isDefined(option.popup)) {
                feature_status.popup = option.popup;
            }
            if (isDefined(option.skip)) {
                var skip = option.skip;
                if (!(skip instanceof Array)) {
                    skip = skip.toString().split(',');
                }
                feature_status.skip = skip;
                skip.forEach(function(value) {
                    switch (value) {
                        case 'availability':
                            Availability.suppress();
                            break;
                        case 'covers':
                            CoverImage.suppress();
                            break;
                        default:
                            console.warn(_func_ + ': unexpected: ' + value);
                            break;
                    }
                });
            }

            if (feature_status.popup) {
                _trace(_func_, 'virtual shelf browse popup');
            } else {
                _trace(_func_, 'virtual shelf browse web page');
                feature_status.active = true;
                attachHandlers({popup: false});
            }

        }
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
        featureProperties:  featureProperties,
        featureStatus:      featureStatus,
        makeLccTree:        makeLccTree,
        setupLinks:         setupLinks,
        updatePage:         updatePage,
        suppress:           suppress,
        enabled:            enabled
    };

})(debugShelfBrowse);
