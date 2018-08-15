// app/assets/javascripts/feature/classic.js
//
// Definitions for the "Virgo Classic" lens.

//= require feature/availability
//= require feature/see-more

/**
 * "Virgo Classic" lens functions.
 *
 * @type {object}
 *
 * @property {function} updatePage
 * @property {function} searchUrl
 * @property {function} defaultRoot
 * @property {function} defaultSelector
 * @property {function} suppress
 * @property {function} enabled
 */
var ClassicLens = (function() {

    /**
     * @constant
     * @type {boolean}
     */
    var FEATURE_ENABLED = Rails.Classic.ENABLED;

    /**
     * Controls whether "See more" appears in "Virgo Classic" lens item
     * details.
     *
     * If *false* then all metadata fields are shown initially.
     *
     * If *true* then the behavior is like the catalog item details show page:
     * A subset of metadata fields are show initially and the user must click
     * on the "see more" link to make the rest of them appear.
     *
     * @constant
     * @type {boolean}
     */
    var SHOW_SEE_MORE = Rails.Classic.SHOW_SEE_MORE;

    /**
     * The number of fields that are displayed before "See more"
     * (if SHOW_SEE_MORE is *true*).
     *
     * @constant
     * @type {number}
     */
    var SHOW_FIRST_FIELDS = Rails.Classic.SHOW_FIRST_FIELDS;

    /**
     * Timeout for fetching inset item details show pages.
     *
     * @constant
     * @type {number}
     */
    var TIMEOUT = GLOBAL_TIMEOUT;

    // ========================================================================
    // Variables
    // ========================================================================

    /** @type {boolean} */
    var suppressed = !FEATURE_ENABLED;

    // ========================================================================
    // Internal function definitions
    // ========================================================================

    /**
     * inProgressClass
     *
     * @param {string} [css_class]    Default 'in-progress'.
     *
     * @return {string}
     */
    function inProgressClass(css_class) {
        return css_class || 'in-progress';
    }

    /**
     * Create an in-progress element.
     *
     * @param {string} [css_class]    Default 'in-progress'.
     *
     * @return {jQuery}
     */
    function inProgressCreate(css_class) {
        var marker  = inProgressClass(css_class);
        var options = { src: '/assets/loading-balls.gif', alt: 'Loading...' };
        return $('<img>').addClass(marker).attr(options);
    }

    /**
     * Get the in-progress element(s) within a parent element.
     *
     * @param {Selector} parent
     * @param {string} [css_class]    Default 'in-progress'.
     *
     * @return {jQuery}
     */
    function inProgressElements(parent, css_class) {
        return $(parent).children('.' + inProgressClass(css_class));
    }

    /**
     * Indicate whether acquisition of the show page contents is already in
     * progress.
     *
     * @param {Selector} parent
     * @param {string} [css_class]    Default 'in-progress'.
     *
     * @return {boolean}
     */
    function alreadyInProgress(parent, css_class) {
        return notEmpty(inProgressElements(parent, css_class));
    }

    /**
     * Add an in-progress element to indicate that the show page contents are
     * being acquired.
     *
     * @param {Selector} parent
     * @param {string}   [css_class]  Default 'in-progress'.
     */
    function addInProgress(parent, css_class) {
        var $parent = $(parent);
        if (!alreadyInProgress($parent, css_class)) {
            inProgressCreate(css_class).appendTo($parent);
            $parent.css('height', 'auto');
        }
    }

    /**
     * Remove all in-progress element(s).
     *
     * @param {Selector} parent
     * @param {string} [css_class]    Default 'in-progress'.
     */
    function removeInProgress(parent, css_class) {
        inProgressElements(parent, css_class).remove();
    }

    /**
     * Get the vertical position of an element which can be compared against
     * `window.pageYOffset`.
     *
     * @param {HTMLElement} element
     *
     * @return {number}
     */
    function pageYOffset(element) {
        var offset = 0;
        var parent = element;
        while (parent) {
            offset += parent.offsetTop;
            parent = parent.offsetParent;
        }
        return offset;
    }

    /**
     * scrollDisplay
     *
     * @param {jQuery} $document
     * @param {jQuery} $display
     */
    function scrollDisplay($document, $display) {

        // If the details display is open, scroll if the bottom is not in view.
        if ($display.is(':visible')) {
            var display    = $display[0];
            var top        = pageYOffset(display);
            var bottom     = top + display.offsetHeight;
            var win_top    = window.pageYOffset;
            var win_bottom = win_top + window.innerHeight;
            if ((top < win_top) || (bottom > win_bottom)) {
                display.scrollIntoView(false);
            }
        }

        // If the document entry has been pushed off the screen then scroll so
        // that it is at the top of the window (even if the details display is
        // open and this causes its bottom to go below the bottom of the
        // window).
        var document = $document[0];
        if (pageYOffset(document) < window.pageYOffset) {
            document.scrollIntoView();
        }
    }

    /**
     * updateDisplay
     *
     * @param {jQuery} $toggle
     * @param {jQuery} $document
     * @param {jQuery} $display
     */
    function updateDisplay($toggle, $document, $display) {
        $display.slideToggle({
            duration: 'fast',
            complete: function() {
                $toggle.attr('aria-expanded', $display.is(':visible'));
                scrollDisplay($document, $display);
            }
        });
    }

    /**
     * Clear all markers and fill the display element with new content.
     *
     * @param {jQuery} $document
     * @param {jQuery} $display
     * @param {jQuery} $new_display
     */
    function fillDisplay($document, $display, $new_display) {
        removeInProgress($display);
        $new_display.appendTo($display);
        scrollDisplay($document, $display);
    }

    /**
     * Fill the display element with new item details content.
     *
     * @param {jQuery} $document
     * @param {jQuery} $display
     * @param {jQuery} $new_display
     */
    function fillDetailsDisplay($document, $display, $new_display) {
        if (SHOW_SEE_MORE) {
            SeeMore.setupShowDetails($new_display, '', SHOW_FIRST_FIELDS);
        } else {
            SeeMore.hideShowDetails($new_display);
        }
        Availability.getAvailability($new_display);
        Copyright.updatePage($new_display);
        //ShelfBrowse.updatePage($new_display);
        fillDisplay($document, $display, $new_display);
    }

    /**
     * Fill the display element with new search results content.
     *
     * @param {jQuery} $document
     * @param {jQuery} $display
     * @param {jQuery} $new_display
     */
    function fillResultsDisplay($document, $display, $new_display) {
        // TODO: ???
        fillDisplay($document, $display, $new_display);
    }

    /**
     * openItem
     *
     * @param {Selector} item
     * @param {string}   mode
     */
    function openItem(item, mode) {

        var $item     = $(item);
        var $document = $item.closest(defaultSelector());
        var id_value  = $document.attr('id');
        var id        = 'data-id="' + id_value + '"';
        var $display  = $document.siblings('.item-display[' + id + ']');

        // Skip if already in progress.
        if (alreadyInProgress($display)) {
            return;
        }

        // If the item display was previously just an error message, remove it
        // now so that the item is in the initial state.
        $display.children('.error-message').remove();

        if ($display.children().length) {

            // Just toggle the state of the item display if it has already been
            // filled.
            updateDisplay($item, $document, $display);

        } else {

            // Insert an in-progress marker and slide open the display; the
            // display expands to fit the content when it is acquired.
            addInProgress($display);
            $display.slideToggle({
                duration: 'fast',
                complete: function() {
                    $item.attr('aria-expanded', $display.is(':visible'));
                }
            });

            // Determine url to fetch.  If href is present and not '#' then it
            // is interpreted as the item details page; otherwise, a search URL
            // is generated.
            var url, displayFillFunction;
            if (mode === 'details') {
                url = $item.attr('href');
                displayFillFunction = fillDetailsDisplay;
            } else {
                url = searchUrl($document.attr('data-browse'), id_value);
                displayFillFunction = fillResultsDisplay;
            }

            // Otherwise, fetch the contents and then slide open the display.
            $.ajax({
                url:      url,
                type:     'GET',
                dataType: 'html',
                data:     'view=inset&popup=true',
                timeout:  TIMEOUT,

                success: function(result) {
                    var page = result.replace(/ id="doc-/g, ' id="item-doc-');
                    var $new_display =
                        $('<div>').html(page).find('.item-content');
                    displayFillFunction($document, $display, $new_display);

                    // Add event handlers.
                    $display.find('.item-toggle').click(function() {
                        updateDisplay($item, $document, $display);
                        return false;
                    });
                },

                error: function() {
                    var message = 'Item '+ mode + ' temporarily unavailable.';
                    var $new_display =
                        $('<div>').addClass('error-message').html(message);
                    fillDisplay($document, $display, $new_display);
                }
            });
        }
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
     * @return {string}
     */
    function defaultRoot() {
        return '.classic-page';
    }

    /**
     * defaultSelector
     *
     * @return {string}
     */
    function defaultSelector() {
        return '.document';
    }

    /**
     * searchUrl
     *
     * @param {string} type
     * @param {string} terms
     *
     * @return {string}
     */
    function searchUrl(type, terms) {
        var params = {
          //[type],       terms,
          //op:           'AND',
          //search_field: 'advanced'
            q:            terms,
            search_field: type
        };
        return addParameter('/classic', params);
    }

    /**
     * Add handlers to the page.
     *
     * @param {Selector} [root]       Default: {@link defaultRoot}()
     * @param {Selector} [selector]   Default: {@link defaultSelector}()
     */
    function updatePage(root, selector) {

        if (!enabled()) { return; }

        Availability.updatePage();

        var $root    = root ? $(root) : defaultRoot();
        var $entries = $root.find(selector || defaultSelector());

        // Set up links which open item details.
        $entries.find('dd.title-field a')
            .attr('aria-expanded', false)
            .click(function() {
                openItem(this, 'details');
                return false;
            });

        /*
        // Set up links which open item results.
        $entries.find('.browse-entry a')
            .attr('aria-expanded', false)
            .click(function() {
                openItem(this, 'results');
                return false;
            });
        */

        // When "Library" is selected, replace the results listing while the
        // new page is being fetched.
        $root.find('select#f_inclusive_library_facet_').change(function() {

            // Replace the current browse results with a marker to indicate
            // that the search is in progress.  Keep the height of the area the
            // same to avoid a jarring change to the overall display.
            var $browse_area = $('.classic-results.browse');
            if ($browse_area.length) {
                var current_height = $browse_area.css('height');
                $browse_area.empty();
                addInProgress($browse_area);
                $browse_area.css('height', current_height);
            }

            // Submit form.
            this.form.submit();

        });
    }

    // ========================================================================
    // Feature initialization
    // ========================================================================

    $(document).ready(function() {
        //console.log('ClassicLens ' + (enabled() ? 'enabled' : 'disabled'));
    });

    // ========================================================================
    // Exposed definitions
    // ========================================================================

    return {
        updatePage:      updatePage,
        searchUrl:       searchUrl,
        defaultRoot:     defaultRoot,
        defaultSelector: defaultSelector,
        suppress:        suppress,
        enabled:         enabled
    };

})();
