// app/assets/javascripts/feature/availability.js

//= require shared/colorbox
//= require shared/datatables
//= require feature/requests

//= depends_on feature/shelf-browse

/** @type {DebugEntry} */
var debugAvailability =
    ModuleDebug.add('feature/availability', 'AVAIL', { trace: DEVELOPMENT });

/**
 * Availability feature: Display availability of catalog holdings via Firehose.
 *
 * @type {object}
 *
 * @property {function} getAvailability
 * @property {function} updateIndicators
 * @property {function} updatePopups
 * @property {function} updatePage
 * @property {function} defaultRoot
 * @property {function} defaultSelector
 * @property {function} suppress
 * @property {function} enabled
 */
var Availability = (function(module_debug) {

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
    var FEATURE_ENABLED  = true;

    /**
     * @constant
     * @type {number}
     */
    var FIREHOSE_TIMEOUT = 120 * SECONDS;

    /**
     * @constant
     * @type {number}
     */
    var FILTER_MINIMUM   = 4;

    // ========================================================================
    // Variables
    // ========================================================================

    /** @type {boolean} */
    var suppressed = !FEATURE_ENABLED;

    /**
     * Table of currently active event handlers where the key is a string of
     * the form "event ['/' selector]" and the value is a function.  This is
     * used to avoid re-assigning handlers which are already bound.
     *
     * @type {{string : function}}
     */
    var handler_table = {};

    // ========================================================================
    // Internal function definitions
    // ========================================================================

    /**
     * Add an event handler if not already added.
     *
     * @param {string}     name         Event name.
     * @param {jQuery}     [$elements]
     * @param {function|*} func         Function to bind or a placeholder to
     *                                    prevent future binding.
     */
    function addHandler(name, $elements, func) {
        var key, fn;
        if (typeof $elements === 'function') {
            key = name;
            fn  = $elements;
        } else {
            key = '' + name + '/' + $elements.selector;
            fn  = func;
        }
        if (key && !handler_table[key]) {
            handler_table[key] = fn;
            if (typeof fn === 'function') { $(window).bind(name, fn); }
        }
    }

    /**
     * Add a window resize event handler if not already added.
     *
     * @param {jQuery}   $elements
     * @param {function} fn           Function to bind.
     */
    function onWindowResize($elements, fn) {
        addHandler('resize', $elements, fn);
    }

    /**
     * Include a filter if there are many entries in the table.
     *
     * @param {Selector} selector
     */
    function addFilter(selector) {

        var _func_  = arguments.callee.name;
        var $target = $(selector);

        // Do not show a filter if there are only a few entries in the table.
        var rows = $target.find('tr.holding').length;
        if (rows < FILTER_MINIMUM) {
            _debug(arguments, (' -- ' + rows + ' rows [skipping]'));
            return;
        }
        _debug(arguments);

        var field = 'filter_input_field';
        var label = 'Filter Availability';

        $target.find('table.holdings').dataTable({
            bAutoWidth:    false,
            bInfo:         false,
            bLengthChange: false,
            bPaginate:     false,
            bSort:         false,
            oLanguage: {
                sSearch: '<label for="' + field + '">' + label + '</label>'
            }
        });

        var default_text   = 'Filter availability by dates, keywords, etc.';
        var default_marker = 'default_filter';
        var input_selector = '.dataTables_filter input[type="text"]';
        var $filter_input  = $target.find(input_selector);

        if (isMissing($filter_input)) {
            console.error(_func_ + ': no input element');
            return;
        }

        $filter_input.attr({ 'id': field, 'aria-label': default_text });
        $filter_input.val('');

        $filter_input.focus(function() {
            var $this = $(this);
            if ($this.val() === default_text) {
                $this.removeClass(default_marker);
                $this.val('');
            }
        });

        $filter_input.blur(function() {
            var $this = $(this);
            if ($this.val() === '') {
                $this.addClass(default_marker);
                $this.val(default_text);
            }
        });

        $filter_input.blur();
    }

    /**
     * Update availability information.
     *
     * @param {Selector} selector
     */
    function updateElement(selector) {
        _trace(arguments);
        addFilter(selector);
        itemNoteButtons(selector);
    }

    /**
     * Fill the target element with availability information.
     *
     * @param {Selector} selector
     * @param {string}   data
     */
    function loadElement(selector, data) {

        _debug(arguments);

        // Load received data and update the availability table.
        var $target = $(selector);
        $target.addClass('hidden').html(data);
        updateElement($target);
        $target.addClass('complete').removeClass('hidden');

        // Move request links into place.
        var $request_buttons = $target.find('.request-buttons');
        $request_buttons.css('position', 'absolute');

        // Popups on request links.
        Requests.updatePage($request_buttons);

        // Add virtual shelf browse links.  (These will be hidden when viewing
        // the availability information from within the virtual shelf browser.)
        ShelfBrowse.setupLinks($target);
    }

    /**
     * Partial path to availability data from the server.
     *
     * @param {string} id
     * @param {object} [parameters]
     *
     * @return {string}
     */
    function availabilityPath(id, parameters) {
        return makeUrl(('/catalog/' + id + '/availability'), parameters);
    }

    /**
     * Acquire availability information via an AJAX call.
     *
     * @param {Selector} selector
     */
    function fetchAvailability(selector) {

        _trace(arguments);

        var $target = $(selector);
        var id      = $target.attr('title');
        var path    = availabilityPath(id);
        var _func_  = arguments.callee.name;
        var start;

        $.ajax({
            url:      path,
            type:     'GET',
            dataType: 'html',
            cache:    false,
            timeout:  FIREHOSE_TIMEOUT,

            beforeSend: function() {
                _debug(_func_, 'actionStarted');
                start = Date.now();
            },

            success: function(data) {
                _debug(_func_, 'GET sec.', secondsSince(start));
                loadElement($target, data);
            },

            error: function() {
                _debug(_func_, 'FAIL sec.', secondsSince(start));
                $target.html('Item status is temporarily unavailable.');
            }
        });
    }

    /**
     * Attach a Colorbox popup to view item availability.
     *
     * @param {Selector} element
     * @param {string}   id
     *
     * @note Colorbox.resize() will not recognize changes to innerWidth.
     * Use of that function here is only to adjust the height of the Colorbox.
     */
    function availabilityPopup(element, id) {
        var _func_ = arguments.callee.name;
        var href   = availabilityPath(id, { popup: true });
        var width  = narrowScreen() ? '90%' : '50%';
        var cbox_settings =
            AppColorbox.settings(_func_, {
                href:       href,
                scrolling:  false,
                innerWidth: width,
                rel:        'nofollow',
                onComplete: function() {
                    AppColorbox.onComplete(_func_);
                    var $root = $('#colorbox');
                    updateElement($root);
                    Requests.updatePage($root);
                    ShelfBrowse.setupLinks($root.find('.call-number'));
                    $(this).colorbox.resize();
                }
            });
        $(element).each(handleKeypressAsClick).colorbox(cbox_settings);
    }

    /**
     * Make the availability text a button if indicated by the presence of
     * CSS class "active".
     *
     * @param {Selector} element
     * @param {string}   id
     */
    function availabilityButton(element, id) {
        var $button = $(element).find('.availability-indicator.active');
        availabilityPopup($button, id);
    }

    /**
     * Show additional information about an individual item.
     *
     * @param {Selector} [root]       Default: '.physical-availability'.
     * @param {Selector} [selector]   Default: '.holdings'.
     */
    function itemNoteButtons(root, selector) {
        var $root     = $(root || '.physical-availability');
        var $holdings = $root.find(selector || '.holdings');
        $holdings.find('.disbound-help-link').click(function() {
            var $note = $(this).children('.disbound-help-container');
            if ($note.is(':visible')) {
                $note.hide();
            } else {
                $note.show();
            }
        }).each(nodeHandleKeypressAsClick);
    }

    /**
     * Attach Colorbox popups to "View Locations and Availability" links.
     *
     * @param {jQuery} $links
     */
    function createPopups($links) {
        $links.each(function() {
            var $lnk = $(this);
            var id = $lnk.closest('.document').attr('id').replace(/^doc-/, '');
            availabilityPopup($lnk, id);
        });
    }

    /**
     * Fill in all single-line availability indicators.
     *
     * @param {jQuery} $links
     */
    function createIndicators($links) {
        $links.each(function() {
            var $indicator = $(this);
            var id = $indicator.parent().attr('id').split('availability_')[1];
            if ($indicator.hasClass('complete')) {
                availabilityButton($indicator, id);
            } else {
                var path = '/catalog/' + id + '/brief_availability';
                $indicator.load(path, function() {
                    availabilityButton($indicator, id);
                    $indicator.addClass('complete');
                });
            }
        });
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
        _trace(arguments);
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
        return '.availability a';
    }

    /**
     * Acquire new availability information or update existing availability
     * information.
     *
     * Any elements with CSS classes 'complete' or 'suppressed' will not result
     * in an AJAX call to Firehose.
     *
     * @param {Selector} [root]       Default: {@link defaultRoot}()
     * @param {Selector} [selector]   Default: '.physical-availability'
     */
    function getAvailability(root, selector) {

        if (!enabled()) {
            _debug(arguments, 'not enabled');
            return;
        }

        var $root     = root ? $(root) : defaultRoot();
        var $elements = $root.find(selector || '.physical-availability');
        if (isMissing($elements)) {
            _debug(arguments, 'no elements');
            return;
        }

        _trace(arguments);
        var _func_ = arguments.callee.name;

        // Handle each target individually.
        $elements.each(function() {
            var $this = $(this);
            if ($this.hasClass('complete')) {
                updateElement($this);
            } else if ($this.hasClass('suppressed')) {
                _debug(_func_, 'suppressed');
            } else {
                fetchAvailability($this);
            }
        });
    }

    /**
     * Attach Colorbox popups to "View Locations and Availability" links.
     *
     * @param {Selector} [root]       Default: {@link defaultRoot}()
     * @param {Selector} [selector]   Default: '.multiple-copies'
     */
    function updatePopups(root, selector) {
        if (enabled()) {
            var $root  = root ? $(root) : defaultRoot();
            var $links = $root.find(selector || '.multiple-copies');
            if (isPresent($links)) {
                var action = function() { createPopups($links); };
                onWindowResize($links, action);
                action();
            }
        }
    }

    /**
     * Fill in all single-line availability indicators.
     *
     * @param {Selector} [root]       Default: {@link defaultRoot}()
     * @param {Selector} [selector]   Default: '.single-copy'
     */
    function updateIndicators(root, selector) {
        if (enabled()) {
            var $root  = root ? $(root) : defaultRoot();
            var $links = $root.find(selector || '.single-copy');
            if (isPresent($links)) {
                var action = function() { createIndicators($links); };
                onWindowResize($links, action);
                action();
            }
        }
    }

    /**
     * Fill in all single-line availability indicators and attach popups.
     *
     * Indicator elements
     *
     * @param {Selector} [root]       Default: {@link defaultRoot}()
     * @param {Selector} [selector]   Default: {@link defaultSelector}()
     */
    function updatePage(root, selector) {
        if (!enabled()) {
            _debug(arguments, 'skipped - not enabled');
        } else if (inPrintView()) {
            _debug(arguments, 'skipped - in print view');
        } else {
            _debug(arguments);
            var $root = root ? $(root) : defaultRoot();
            updateIndicators($root, selector);
            updatePopups($root, selector);
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
        getAvailability:  getAvailability,
        updateIndicators: updateIndicators,
        updatePopups:     updatePopups,
        updatePage:       updatePage,
        defaultRoot:      defaultRoot,
        defaultSelector:  defaultSelector,
        suppress:         suppress,
        enabled:          enabled
    };

})(debugAvailability);
