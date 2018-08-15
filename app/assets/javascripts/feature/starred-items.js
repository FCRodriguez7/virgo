// app/assets/javascripts/feature/starred-items.js
//
// Definitions to support "starred item" folder operations.

//= require jquery.form.min
//= require shared/colorbox

//= depends_on feature/shelf-browse

/** @type {DebugEntry} */
var debugStarredItems =
    ModuleDebug.add('feature/starred-items', 'STARRED', { all: DEVELOPMENT });

/**
 * Starred Items
 *
 * @type {object}
 *
 * @property {function} updatePage
 * @property {function} defaultRoot
 * @property {function} defaultSelector
 * @property {function} suppress
 * @property {function} enabled
 */
var StarredItems = (function(module_debug) {

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
    var FEATURE_ENABLED     = Rails.StarredItems.ENABLED;

    /**
     * @constant
     * @type {string}
     */
    var INDEX_PATH          = Rails.StarredItems.INDEX_PATH;

    /**
     * @constant
     * @type {string}
     */
    var CLEAR_PATH          = Rails.StarredItems.CLEAR_PATH;

    /**
     * @constant
     * @type {string}
     */
    var LIST_PATH           = Rails.StarredItems.LIST_PATH;

    /**
     * @constant
     * @type {string}
     */
    var STAR_LIT_LABEL      = Rails.StarredItems.STAR_LIT_LABEL;

    /**
     * @constant
     * @type {string}
     */
    var STAR_LIT_TOOLTIP    = Rails.StarredItems.STAR_LIT_TOOLTIP;

    /**
     * @constant
     * @type {string}
     */
    var STAR_LIT_CLASS      = Rails.StarredItems.STAR_LIT_CLASS;

    /**
     * @constant
     * @type {string}
     */
    var STAR_UNLIT_LABEL    = Rails.StarredItems.STAR_UNLIT_LABEL;

    /**
     * @constant
     * @type {string}
     */
    var STAR_UNLIT_TOOLTIP  = Rails.StarredItems.STAR_UNLIT_TOOLTIP;

    /**
     * @constant
     * @type {string}
     */
    var STAR_UNLIT_CLASS    = Rails.StarredItems.STAR_UNLIT_CLASS;

    /**
     * @constant
     * @type {string}
     */
    var STAR_SAVING_CLASS   = Rails.StarredItems.STAR_SAVING_CLASS;

    /**
     * @constant
     * @type {number}
     */
    var DEF_MAX_COUNT       = Rails.StarredItems.MAX_STARS;

    /**
     * @constant
     * @type {string}
     */
    var DISABLED_TOOLTIP    = 'No starred items.';

    /**
     * Selector for the menu item elements that should go to the current tab
     * if there are no stars (since the only action is a flash message) or to
     * a new tab if there are stars.
     *
     * @constant
     * @type {string}
     */
    var NEW_TAB_IF_STARS = [
        'a.cite-starred',
        'a.email-starred',
        'a.print-starred',
        'a.refworks-starred'
    ].join(', ');

    /**
     * Selector for the menu items that should be hidden if there are no stars
     * and visible if there are stars.
     *
     * @constant
     * @type {string}
     */
    var VISIBLE_IF_STARS = [
        '.course-reserve-starred'
    ].join(', ');

    /**
     * Selector for the menu item elements that should be disabled unless there
     * are starred items.
     *
     * @constant
     * @type {string}
     */
    var ENABLED_IF_STARS = [
        'a.view-starred',
        'a.clear-starred',
        'a.cite-starred',
        'a.email-starred',
        'a.print-starred',
        'a.refworks-starred',
        'a.endnote-starred',
        'a.zotero-starred',
        'a.csv-starred'
    ].join(', ');

    /**
     * Pages containing these selectors will be refreshed if the star count
     * is changed (rather than simply updating starred item related elements).
     *
     * @constant
     * @type {string}
     *
     * @see updateStarredItems()
     */
    var REFRESH_IF_COUNT_CHANGED = [
        'body.folder-index-page'
    ].join(', ');

    /**
     * Star operations.
     *
     * @readonly
     * @enum {number}
     */
    var ACTION = {
        None:   0,
        Add:    1,
        Remove: 2
    };

    /**
     * @constant
     * @type {string}
     */
    var STAR_TABINDEX_PROP = 'star-original-tabindex';

    // ========================================================================
    // Variables
    // ========================================================================

    /**
     * Starred items are not currently managed in print view.
     *
     * @type {boolean}
     */
    var suppressed = !FEATURE_ENABLED;

    /** @type {boolean|number} */
    var updating_page = false;

    /** @type {boolean|number} */
    var updating_starred_items = false;

    // ========================================================================
    // Internal function definitions - starred item count
    // ========================================================================

    /**
     * The current count of starred items.
     *
     * This number is initialized in updatePage() with the count at the time
     * that the page was rendered, then modified by setStar() and unsetStar()
     * if the user activates those functions.
     *
     * This allows implementation of behaviors which change based on the
     * presence or absence of starred items (for example, the "target" property
     * of some Starred Item menu entries).
     *
     * @type {number}
     */
    var star_count;

    /**
     * Set (or reset) the *star_count*.
     *
     * (Initialization is not counted as "changed".)
     *
     * @param {number|string} [new_count]
     *
     * @return {boolean}              True if the count was changed; false if
     *                                  the value stayed the same or if this
     *                                  was the initialization of *star_count*.
     */
    function updateStarCount(new_count) {
        _debug(arguments);
        var report   = arguments.callee.name + ': ';
        var changed  = isDefined(star_count);
        var original = star_count;
        if (isMissing(new_count)) {
            star_count = 0;
            report += (changed ? 'reset' : 'initialize') + ' to';
        } else {
            var count = parseInt(new_count);
            star_count = (count && (count > 0)) ? count : 0;
            changed = changed && (star_count !== original);
            report += (changed ? 'new' : 'same') + ' star count:';
        }
        _debug(report + ' ' + star_count + ' (was: ' + original + ')');
        return changed;
    }

    // ========================================================================
    // Internal function definitions - starred items
    // ========================================================================

    /**
     * The star items meeting the given condition.
     *
     * @param {Selector} [stars]      Default: all stars on the page.
     * @param {string}   [condition]  Default: blank.
     *
     * @return {jQuery}               Elements with .star-container class.
     */
    function getStar(stars, condition) {
        //_debug(arguments);
        var star_class = defaultSelector();
        var $stars = stars ? $(stars).closest(star_class) : $(star_class);
        if (condition) {
            $stars = $stars.filter(function() {
                return isPresent($(this).find('.submit-form' + condition));
            });
        }
        return $stars;
    }

    /**
     * Return the starred items.
     *
     * @param {Selector} [stars]
     *
     * @return {jQuery}               Elements with .star-container class.
     */
    function getMarkedStars(stars) {
        _debug(arguments);
        var selector = '.' + STAR_LIT_CLASS;
        return getStar(stars, selector);
    }

    /**
     * Return the un-starred stars.
     *
     * @param {Selector} [stars]
     *
     * @return {jQuery}               Elements with .star-container class.
     */
    function getUnmarkedStars(stars) {
        _debug(arguments);
        var selector = ':not(.' + STAR_LIT_CLASS + ')';
        return getStar(stars, selector);
    }

    // ========================================================================
    // Internal function definitions - starred item IDs
    // ========================================================================

    /**
     * Fill array with IDs of items (starred or unstarred).
     *
     * @param {Selector} stars
     *
     * @return {string[]}
     */
    function getIds(stars) {
        _debug(arguments);
        var $stars = getStar(stars);
        var result = [];
        var index  = 0;
        getStarSubmit($stars).each(function() {
            var $elements = $(this).siblings('input');
            var $id = $elements.filter('[name="id"]');
            if (isEmpty($id)) {
                $id = $elements.filter('[name="article_id"]');
            }
            if (isPresent($id)) {
                result[index] = $id.val();
                index += 1;
            }
        });
        return result;
    }

    /**
     * Fill array with IDs of starred items, which have the .remove-star class.
     *
     * @param {Selector} [stars]
     *
     * @return {string[]}
     */
    function getMarkedIds(stars) {
        _debug(arguments);
        var $stars = getMarkedStars(stars);
        return getIds($stars);
    }

    /**
     * Fill array with IDs of un-starred items.
     *
     * @param {Selector} [stars]
     *
     * @return {string[]}
     */
    function getUnmarkedIds(stars) {
        _debug(arguments);
        var $stars = getUnmarkedStars(stars);
        return getIds($stars);
    }

    // ========================================================================
    // Internal function definitions - star/unstar
    // ========================================================================

    /**
     * Indicate whether the star is set.
     *
     * @param {jQuery} $star_submit   Elements with .submit-form class.
     *
     * @return {boolean}
     */
    function isSet($star_submit) {
        //_debug(arguments);
        return $star_submit.hasClass(STAR_LIT_CLASS);
    }

    /**
     * Indicate whether the star is not set.
     *
     * @param {jQuery} $star_submit   Elements with .submit-form class.
     *
     * @return {boolean}
     */
    function isUnset($star_submit) {
        //_debug(arguments);
        return !isSet($star_submit);
    }

    /**
     * Indicate whether a star's label should be included as text on the
     * display (i.e., the text value of the <a> element).
     *
     * @param {Selector} star
     *
     * @return {boolean}              If false, the link label should be blank.
     */
    function getShowLabel(star) {
        //_debug(arguments);
        return getStar(star).find('input[name="show_label"]').val() === 'true';
    }

    /**
     * Update a starred item.
     *
     * @param {ACTION}  action        Star operation.
     * @param {jQuery}  $star_submit  Elements with .submit-form class.
     * @param {boolean} [show_label]  Extracted from *star* if not provided.
     *
     * @return {boolean}              True if modified; false otherwise.
     *
     */
    function updateStarSubmit(action, $star_submit, show_label) {
        _debug(arguments);
        var star_lit, label, tooltip, aria_label;
        switch (action) {
            case ACTION.Add:
                star_lit = true;
                label    = STAR_LIT_LABEL;
                tooltip  = STAR_LIT_TOOLTIP;
                break;
            case ACTION.Remove:
                star_lit = false;
                label    = STAR_UNLIT_LABEL;
                tooltip  = STAR_UNLIT_TOOLTIP;
                break;
            default:
                return false;
        }
        var value = label;

        // Clear the label if it is not supposed to be shown.
        var show =
            isDefined(show_label) ? show_label : getShowLabel($star_submit);
        if (!show) {
            aria_label = tooltip;
            tooltip = label;
            label = '';
        }

        // Update the element appearance and the form submit value.
        var options = { 'aria-checked': star_lit };
        if (tooltip)    { options['title']      = tooltip; }
        if (aria_label) { options['aria-label'] = aria_label; }
        $star_submit.html(label).attr(options);
        if (star_lit) {
            $star_submit.addClass(STAR_LIT_CLASS);
        } else {
            $star_submit.removeClass(STAR_LIT_CLASS);
        }
        $star_submit.siblings('input[name="commit"]').attr('value', value);
        return true;
    }

    /**
     * Return with the '.submit-form' element of the indicated item.
     *
     * @param {Selector} star
     *
     * @return {jQuery}               Elements with .submit-form class.
     */
    function getStarSubmit(star) {
        _debug(arguments);
        var $submit = $(star);
        if (!$submit.hasClass('submit-form')) {
            $submit = getStar($submit).find('.submit-form');
        }
        return $submit;
    }

    /**
     * Turn on a starred item.
     *
     * @param {Selector} star
     * @param {boolean}  [show_label] Extracted from *star* if not provided.
     *
     * @return {boolean}              True if modified; false if already set.
     */
    function setStarSubmit(star, show_label) {
        var $submit = getStarSubmit(star);
        var add     = isUnset($submit) && ACTION.Add;
        return updateStarSubmit(add, $submit, show_label);
    }

    /**
     * Turn off a starred item.
     *
     * @param {Selector} star
     * @param {boolean}  [show_label] Extracted from *star* if not provided.
     *
     * @return {boolean}              True if modified; false if already unset.
     */
    function unsetStarSubmit(star, show_label) {
        var $submit = getStarSubmit(star);
        var remove  = isSet($submit) && ACTION.Remove;
        return updateStarSubmit(remove, $submit, show_label);
    }

    // ========================================================================
    // Internal function definitions - page updating
    // ========================================================================

    /**
     * Do not display an element.
     *
     * @param {Selector} selector
     */
    function hide(selector) {
        _debug(arguments);
        $(selector).addClass('hidden');
    }

    /**
     * Display an element.
     *
     * @param {Selector} selector
     */
    function show(selector) {
        _debug(arguments);
        $(selector).removeClass('hidden');
    }

    /**
     * Display an element as disabled.
     *
     * @param {Selector} selector
     * @param {boolean} [update_title]  Default: *true*.
     */
    function disable(selector, update_title) {
        _debug(arguments);
        var update = notDefined(update_title) || update_title;
        $(selector).each(function() {
            var $element = $(this);
            var tabindex = $element.attr('tabindex') || 'none';
            if ((tabindex === -1) || (tabindex === '-1')) {
                return true; // next each() iteration
            } else {
                $element.prop(STAR_TABINDEX_PROP, tabindex);
                var attr = { tabindex: -1 };
                if (update) {
                    var new_title = DISABLED_TOOLTIP;
                    var old_title = $element.attr('title') || '';
                    if (old_title === new_title) { old_title = ''; }
                    attr.original_title = old_title;
                    attr.title = new_title;
                }
                $element.addClass('link-disabled').attr(attr);
            }
        });
    }

    /**
     * Restore a disabled element.
     *
     * @param {Selector} selector
     * @param {boolean} [update_title]  Default: *true*.
     */
    function enable(selector, update_title) {
        _debug(arguments);
        var update = notDefined(update_title) || update_title;
        $(selector).each(function() {
            var $element = $(this);
            var old_tabindex = $element.prop(STAR_TABINDEX_PROP);
            $element.removeProp(STAR_TABINDEX_PROP);
            if (isDefined(old_tabindex)) {
                var attr = {};
                switch (old_tabindex) {
                    case '':
                    case 'none':
                        $element.removeAttr('tabindex');
                        break;
                    default:
                        attr.tabindex = old_tabindex;
                        break;
                }
                if (update) {
                    var old_title = DISABLED_TOOLTIP;
                    var new_title = $element.attr('original_title') || '';
                    if (new_title === old_title) { new_title = ''; }
                    attr.title = new_title;
                }
                $element.removeClass('link-disabled').attr(attr);
            }
        });
    }

    /**
     * Perform updates based on the current count of starred items.
     *
     * @param {Selector} [counter]
     * @param {boolean}  [plain]      If *true* don't display parens.
     */
    function updateStarCounter(counter, plain) {
        _debug(arguments);
        var display = plain ? star_count.toString() : ('(' + star_count + ')');
        $(counter || '.star-counter').each(function() {
            var $counter = $(this);
            $counter.text(display);
            if (star_count) {
                show($counter);
            } else if (!$counter.hasClass('no-hide')) {
                hide($counter);
            }
        });
    }

    /**
     * Perform updates based on the current count of starred items.
     */
    function updateActionMenu() {
        _debug(arguments);

        var $menu             = $('.action-list');
        var $menu_list        = $menu.children('.list-body');
        var $visible_if_stars = $menu_list.find(VISIBLE_IF_STARS);
        var $enabled_if_stars = $menu_list.find(ENABLED_IF_STARS);
        var $new_tab_if_stars = $menu_list.find(NEW_TAB_IF_STARS);

        if (star_count) {
            show($visible_if_stars);
            enable($enabled_if_stars);
            $new_tab_if_stars.attr('target', '_blank');
        } else {
            hide($visible_if_stars);
            disable($enabled_if_stars);
            $new_tab_if_stars.attr('target', '');
        }
        updateStarCounter();
    }

    /**
     * Update the star; if on the item details show page, adjust the course
     * reserve menu entries.
     *
     * @param {jQuery}   $submit
     * @param {string[]} starred_ids
     * @param {number}   [max_count]
     */
    function toggleStar($submit, starred_ids, max_count) {
        _debug(arguments);
        var $resv_this = $('.action-list .course-reserve-this');
        if (isPresent(starred_ids)) {
            var max = max_count || DEF_MAX_COUNT;
            if ((star_count < max) && setStarSubmit($submit)) {
                updateStarCount(star_count + 1);
                hide($resv_this);
            }
        } else {
            if (unsetStarSubmit($submit)) {
                updateStarCount(star_count - 1);
                show($resv_this);
            }
        }
        updateActionMenu();
    }

    /**
     * clearStars
     *
     * @param {Selector} [stars]
     */
    function clearStars(stars) {
        _debug(arguments);
        getStarSubmit(stars).each(function() {
            if (unsetStarSubmit(this)) {
                updateStarCount(star_count - 1);
            }
        });
        updateActionMenu();
    }

    /**
     * Star all items on the page.
     *
     * @param {string[]} starred_ids
     * @param {number}   [max_count]
     */
    function setStarList(starred_ids, max_count) {
        _debug(arguments);
        if (isPresent(starred_ids)) {
            var max = max_count || DEF_MAX_COUNT;
            $.each(starred_ids, function(idx, docId) {
                if (star_count >= max) {
                    return false; // break from $.each()
                }
                var divId = 'div[id="doc-' + docId + '"]';
                var $star = $(divId + ' ' + defaultSelector());
                if (setStarSubmit($star)) {
                    updateStarCount(star_count + 1);
                }
            });
        }
        updateActionMenu();
    }

    // ========================================================================
    // Internal function definitions - user messages
    // ========================================================================

    /**
     * popupDialog
     *
     * @param {string} content
     * @param {string} [title]
     */
    function popupDialog(content, title) {
        _trace(arguments);
        var _func_ = callString(arguments);
        var height = shortScreen()  ? '75%' : '40%';
        var width  = narrowScreen() ? '75%' : '40%';
        var $display = $('<div>')
            .addClass('folder-notice ui-state-highlight ui-corner-all notice')
            .html(content || 'ERROR');
        $.fn.colorbox(AppColorbox.settings(_func_, {
            open:   true,
            html:   $display,
            height: height,
            width:  width,
            title:  title || '',
            onComplete: function() {
                AppColorbox.onComplete(_func_);
                $(this).delegate('.close-notice', 'click', function() {
                    clearAllStarredItems(this);
                    $.fn.colorbox.close();
                    return false;
                });
            }
        }));
    }

    /**
     * Show a notice if the starred item list is full.
     *
     * @param {string} [status]
     *
     * @return {boolean}              True if the maximum was reached.
     */
    function warnStarCount(status) {

        if (status === 'OK') {
            return false;
        }

        var max_count =
            status || DEF_MAX_COUNT;
        var view_and_export =
            '<a href="' + INDEX_PATH + '">view and export</a>';
        var clear_the_list =
            '<a href="#" class="clear-all close-notice">clear the list</a>';
        var notice =
            'You may only save up to ' + max_count + ' items in your ' +
            'starred item list.  ' +
            'Please ' + view_and_export + ' any items you wish to ' +
            'preserve then ' + clear_the_list + ' to add more items.';

        popupDialog(notice, 'Starred Item List Full');
        return true;
    }

    /**
     * Show a notice if there was an error.
     *
     * @param {XMLHttpRequest} xhr
     * @param {string}         [dialog_title]
     */
    function warnServerError(xhr, dialog_title) {
        var title;
        var notice;
        if (xhr.responseText.match(/CookieOverflow/)) {
            title  = dialog_title || 'Session cookie error';
            notice =
                'Sorry - not enough room to add the all of the identifiers ' +
                'for those starred items.  ' +
                'Try adding fewer items and/or removing some ' +
                'currently-starred items to make room.';
        }
        title  = title  || dialog_title || 'Unknown server error';
        notice = notice ||
            'Something went wrong on the Virgo server and it could not add ' +
            'those starred items at this time.';
        popupDialog(notice, title);
    }

    // ========================================================================
    // Internal function definitions - data acquisition
    // ========================================================================

    /**
     * updateStarredItems
     *
     * @param {{documents: Array, articles: Array}} data
     *
     * @return {boolean}              If *true* a page reload is needed.
     */
    function updateStarredItems(data) {

        _trace(arguments);

        var documents = data.documents || [];
        var articles  = data.articles  || [];
        var new_count = documents.length + articles.length;
        var initial   = notDefined(star_count);
        var changed   = updateStarCount(new_count);
        var $stars    = getStar();
        var reload    = false;
        var _func_    = arguments.callee.name;

        // Update page elements based on the nature of the page.
        if (isPresent($(REFRESH_IF_COUNT_CHANGED))) {

            // If the count has changed then a reload is definitely
            // required; if not, it's still possible that the composition
            // of the starred item list is different than the last time
            // this browser tab was visited.  In that case, the stars on
            // the page have to be checked individually against the current
            // set of starred items.

            if (!initial) {
                if (!changed) {
                    _debug(_func_, 'looking for changes');
                    var visited = 0;
                    $stars.each(function() {
                        var $star  = $(this).children('a');
                        var href   = $star.attr('href') || '';
                        var pair   = href.replace(/^.*\?/, '').split('=');
                        var type   = pair[0];
                        var doc_id = decodeURIComponent(pair[1]);
                        var list   = (type === 'id') ? documents : articles;
                        changed = (list.indexOf(doc_id) < 0);
                        if (changed) {
                            _debug(_func_,
                                (asString(doc_id) + ' not in [' + list + ']'));
                            return false; // break from each()
                        }
                        visited += 1;
                    });
                    changed = changed || (visited !== new_count);
                    _debug(_func_,
                        ('new_count = ' + new_count),
                        ('visited = ' + visited),
                        ('changed = ' + changed));
                }
                reload = changed;
            }
            updateActionMenu();

        } else if (isMissing($stars)) {

            // On account pages, only the star counter needs to be updated.
            updateStarCounter();

        } else {

            // On index and show pages, the stars that are displayed may
            // or may not correlate to the stars items so each of the stars
            // needs to be considered against the current set of starred
            // items.

            var $resv_this = $('.action-list .course-reserve-this');

            $stars.each(function() {
                var $star  = $(this);
                var $input = $star.find('input');
                var types  = { id: documents, article_id: articles };
                $.each(types, function(doc_type, doc_list) {
                    var $id = $input.filter('[name="' + doc_type + '"]');
                    if (notEmpty($id)) {
                        var doc_id = $id.val();
                        if (doc_list.indexOf(doc_id) >= 0) {
                            setStarSubmit($star);
                            hide($resv_this);
                        } else {
                            unsetStarSubmit($star);
                            show($resv_this);
                        }
                    }
                });
            });
            updateActionMenu();
        }
        return reload;
    }

    /**
     * Acquire the current list of starred items from the server.
     */
    function getStarredItems() {

        _trace(arguments);

        if (updating_starred_items) {
            _debug(arguments, 'skipping - update in progress');
            return;
        }

        var path        = LIST_PATH;
        var reload_page = false;
        var reload_url  = currentUrl();
        var _func_      = arguments.callee.name;
        var start;

        $.ajax({
            url:        path,
            type:       'GET',
            dataType:   'json',
            timeout:    GLOBAL_TIMEOUT,
            cache:      false,

            /**
             * Actions before the request is sent.
             *
             * @param {XMLHttpRequest} xhr
             * @param {object}         settings
             */
            beforeSend: function(xhr, settings) {
                _debug(_func_, 'beforeSend');
                start = Date.now();
                updating_starred_items = start;
            },

            /**
             * Update starred item count and any starred items on the page.
             *
             * @param {object}         data
             * @param {string}         status
             * @param {XMLHttpRequest} xhr
             */
            success: function(data, status, xhr) {
                _debug(_func_, 'success');
                if (isMissing(data)) {
                    console.warn(_func_ + ': no data from ' + path);
                } else if (typeof(data) !== 'object') {
                    console.warn(_func_ + ': ' + typeof(data) + ' unexpected');
                } else {
                    reload_page = updateStarredItems(data);
                }
            },

            /**
             * Note failures on the console.
             *
             * @param {XMLHttpRequest} xhr
             * @param {string}         status
             * @param {string}         error
             */
            error: function(xhr, status, error) {
                _debug(_func_, 'error');
                console.warn(_func_ + ': ' + status + ': ' + error);
            },

            /**
             * Actions after the request is completed.
             *
             * @param {XMLHttpRequest} xhr
             * @param {string}         status
             */
            complete: function(xhr, status) {
                _debug(_func_, ('complete ' + secondsSince(start) + ' sec.'));
                updating_starred_items = updating_page = false;
                if (reload_page) {
                    reload_url = reload_url || currentUrl();
                    _trace(_func_, 'RELOADING', reload_url);
                    reload_page = false;
                    if (isPresent($('#colorbox:visible'))) {
                        $(document).bind('cbox_closed', function() {
                            window.location = reload_url;
                        });
                    } else {
                        window.location = reload_url;
                    }
                }
            }
        });
    }

    /**
     * Set the starred items represented by the $stars elements.
     *
     * @param {Selector} control
     * @param {Selector} [stars]      The stars holding the IDs to add; if
     *                                  missing then all (unmarked) stars on
     *                                  the page will be added.
     */
    function setStarredItems(control, stars) {

        _trace(arguments);

        var _func_ = arguments.callee.name;
        var $stars = getUnmarkedStars(stars);
        var ids    = getIds($stars);

        if (isMissing(ids)) {
            _debug(_func_, 'skipping - no starred items');
            return;
        }
        _debug(_func_, ('ids: [' + ids + ']'));

        var $star_all_control = $(control);
        var $submit = getStarSubmit($stars);
        var start;

        var articles = $('body').hasClass('articles-page');
        var key   = articles ? 'article_id[]' : 'id[]';
        var data  = { add_only: true };
        data[key] = ids;

        $.ajax({
            url:      INDEX_PATH,
            type:     'POST',
            dataType: 'json',
            data:     data,

            /**
             * Pre-submit actions.
             *
             * @param {XMLHttpRequest} xhr
             * @param {object}         settings
             */
            beforeSend: function(xhr, settings) {
                _debug(_func_, 'beforeSend');
                start = Date.now();
                $submit.addClass(STAR_SAVING_CLASS);
                disable($star_all_control, false);
            },

            /**
             * Star all items on the page.
             *
             * @param {object}         data
             * @param {string}         status
             * @param {XMLHttpRequest} xhr
             */
            success: function(data, status, xhr) {
                _debug(_func_, 'success');
                if (isMissing(data)) {
                    console.warn(_func_ + ': no data from ' + INDEX_PATH);
                } else if (typeof(data) !== 'object') {
                    console.warn(_func_ + ': ' + typeof(data) + ' unexpected');
                } else {
                    var starred_status = data[0];
                    var starred_ids    = data[1];
                    var max_count      = parseInt(starred_status);
                    setStarList(starred_ids, max_count);
                    warnStarCount(starred_status);
                }
            },

            /**
             * Note failures on the console.
             *
             * @param {XMLHttpRequest} xhr
             * @param {string}         status
             * @param {string}         error
             */
            error: function(xhr, status, error) {
                _debug(_func_, 'error');
                console.warn(_func_ + ': ' + status + ': ' + error);
                warnServerError(xhr);
            },

            /**
             * Post-submit actions.
             *
             * @param {XMLHttpRequest} xhr
             * @param {string}         status
             */
            complete: function(xhr, status) {
                _debug(_func_, ('complete ' + secondsSince(start) + ' sec.'));
                $submit.removeClass(STAR_SAVING_CLASS);
                enable($star_all_control, false);
            }
        });
    }

    /**
     * Clear all starred items.
     *
     * @param {Selector} control
     * @param {Selector} [stars]      The visible stars which will need to be
     *                                  updated after all starred items are
     *                                  removed.  If missing then all stars on
     *                                  the page will be updated.
     */
    function clearAllStarredItems(control, stars) {

        _trace(arguments);

        var $stars  = getMarkedStars();
        var $submit = getStarSubmit($stars);
        var path    = CLEAR_PATH;
        var $clear_all_control = $(control);

        var _func_ = arguments.callee.name;
        var start;

        $.ajax({
            url:      path,
            type:     'POST',
            dataType: 'json',
            data:     {},

            /**
             * Disable the link before the request is submitted.
             *
             * @param {XMLHttpRequest} xhr
             * @param {object}         settings
             */
            beforeSend: function(xhr, settings) {
                _debug(_func_, 'beforeSend');
                start = Date.now();
                $submit.addClass(STAR_SAVING_CLASS);
                disable($clear_all_control);
            },

            /**
             * In response to the removal of all starred items, update the
             * state of the stars that were passed in to the function.
             *
             * @param {object}         data
             * @param {string}         status
             * @param {XMLHttpRequest} xhr
             */
            success: function(data, status, xhr) {
                _debug(_func_, 'success');
                clearStars($submit);
            },

            /**
             * Note failures on the console.
             *
             * @param {XMLHttpRequest} xhr
             * @param {string}         status
             * @param {string}         error
             */
            error: function(xhr, status, error) {
                _debug(_func_, 'error');
                console.warn(_func_ + ': ' + status + ': ' + error);
                warnServerError(xhr);
            },

            /**
             * Clean up after the request is complete by re-enabling the link
             * and forcing the collapse of the starred items drop down menu.
             *
             * @param {XMLHttpRequest} xhr
             * @param {string}         status
             */
            complete: function(xhr, status) {
                _debug(_func_, ('complete ' + secondsSince(start) + ' sec.'));
                $submit.removeClass(STAR_SAVING_CLASS);
                enable($clear_all_control);
            }
        });
    }

    /**
     * Submit a single star.
     *
     * @param {Selector} star
     */
    function toggleStarredItem(star) {

        _trace(arguments);

        var $star   = getStar(star);
        var $submit = getStarSubmit($star);

        var _func_ = arguments.callee.name;
        var start;

        $star.find('.add-star-form').ajaxSubmit({
            dataType:     'json',
            beforeSubmit: actionStarted,
            success:      processData,
            error:        reportFailure,
            complete:     actionCompleted
        });

        // ====================================================================
        // AJAX event handlers
        // ====================================================================

        /**
         * Actions before the request is sent.
         *
         * @param {object} form_data
         * @param {jQuery} jq_form
         * @param {object} options
         */
        function actionStarted(form_data, jq_form, options) {
            _debug(_func_, arguments.callee.name);
            start = Date.now();
            $submit.addClass(STAR_SAVING_CLASS);
        }

        /**
         * Update the star based on the received data.
         *
         * @param {object}         data
         * @param {string}         status
         * @param {XMLHttpRequest} xhr
         * @param {jQuery}         jq_form
         */
        function processData(data, status, xhr, jq_form) {
            _debug(_func_, arguments.callee.name);
            if (isMissing(data)) {
                console.warn(_func_ + ': no data from server');
            } else if (typeof(data) !== 'object') {
                console.warn(_func_ + ': ' + typeof(data) + ' unexpected');
            } else {
                var starred_status = data[0];
                var starred_ids    = data[1];
                var max_count      = parseInt(starred_status);
                $submit.removeClass(STAR_SAVING_CLASS);
                toggleStar($submit, starred_ids, max_count);
                warnStarCount(starred_status);
            }
        }

        /**
         * Note failures on the console and to the user.
         *
         * @param {XMLHttpRequest} xhr
         * @param {string}         status
         * @param {string}         error
         */
        function reportFailure(xhr, status, error) {
            _debug(_func_, arguments.callee.name);
            console.warn(_func_ + ': ' + status + ': ' + error);
            warnServerError(xhr);
        }

        /**
         * Actions after the request is completed.
         *
         * @param {XMLHttpRequest} xhr
         * @param {string}         status
         */
        function actionCompleted(xhr, status) {
            _debug(_func_, ('completed ' + secondsSince(start) + ' sec.'));
            $submit.removeClass(STAR_SAVING_CLASS);
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
     * @return {jQuery}
     */
    function defaultRoot() {
        return $('body');
    }

    /**
     * Selector for starred item controls.
     *
     * @return {string}
     */
    function defaultSelector() {
        return '.star-container';
    }

    /**
     * Update the page.
     *
     * @param {Selector} [root]       Default: {@link defaultRoot}()
     * @param {Selector} [selector]   Default: {@link defaultSelector}()
     */
    function updatePage(root, selector) {

        if (!enabled()) { return; }

        _trace(arguments);

        if (updating_page) {
            _debug(arguments, 'skipping - update in progress');
            return;
        }
        updating_page = true;

        var $root      = root ? $(root) : defaultRoot();
        var $stars     = $root.find(selector || defaultSelector());
        var $menu      = $('.action-list');
        var $menu_list = $menu.children('.list-body');
        var $dropdown  = $menu_list.not('.folder-tools');
        var $resv_this = $menu_list.find('.course-reserve-this');

        _debug(arguments,
            ('counts: $menu = ' + $menu.length),
            ('$dropdown = ' + $dropdown.length),
            ('$resv_this = ' + $resv_this.length));

        // ====================================================================
        // Event handlers - Star/Unstar
        // ====================================================================

        if ($root.hasClass('folder-page')) {
            // The "stars" on the folder page are not controls like those on
            // other pages.  This gives feedback when clicking on a star to
            // remove the item from starred items.
            $stars.find('.' + STAR_LIT_CLASS).click(function() {
                $(this)
                    .removeClass(STAR_LIT_CLASS)
                    .addClass(STAR_SAVING_CLASS);
            });
        } else {
            // Submit form to star/unstar an item on link click.
            $stars.delegate('.submit-form', 'click', function() {
                toggleStarredItem(this);
                return false;
            });
        }

        // Currently the only time that a root element is specified is for the
        // asynchronous article results on the combined results page.  In this
        // case the menu will have already been updated so the rest of this
        // function can be skipped.
        if (root) {
            updating_page = false;
            return;
        }

        // ====================================================================
        // Event handlers - Starred Items menu
        // ====================================================================

        function showMenu() {
            _trace(arguments);
            show($dropdown);
            $menu.attr('aria-expanded', true);
        }

        function hideMenu() {
            _trace(arguments);
            hide($dropdown);
            $menu.attr('aria-expanded', false);
        }

        // Show the action menu when the mouse hovers over it (unless the menu
        // list is in the side bar).
        $menu.hover(showMenu, hideMenu);

        // Also support mouse click and carriage return as a way to toggle the
        // action menu.
        $menu.click(function() {
            if ($dropdown.hasClass('hidden')) {
                showMenu();
            } else {
                hideMenu();
            }
        }).each(treeHandleKeypressAsClick);

        // Keep menu from sticking open waiting for a request to resolve when
        // the user clicks on a menu selection.
        $dropdown.click(function() {
            hideMenu();
            return true;
        });

        // Only for the item details show page:  Respond to a click of the
        // 'Place This Item on Course Reserve' menu entry as if the user
        // clicked on the star.
        $resv_this.click(function() {
            $stars.find('.submit-form').click();
            return false;
        });

        // ====================================================================
        // Event handlers - Starred Items tools
        // ====================================================================

        // Select all starred items by adding all items on the page to the
        // marked list (if they're not already there).
        $('a.select-all').click(function() {
            setStarredItems(this);
            return false;
        });

        // Clear all starred items and update the stars on the page.
        $(document).delegate('a.clear-all', 'click', function() {
            clearAllStarredItems(this, $stars);
            return false;
        });

        // ====================================================================
        // Event handlers - Browser tab
        // ====================================================================

        /**
         * Refresh if focus returns to the current browser tab; starred items
         * may have changed due to activity in a different browser tab (e.g.
         * removed through the Starred Items [folder index] page, added from a
         * separate Virgo tab, etc.).
         *
         * @param {Event} event
         */
        function windowFocus(event) {
            _debug('FOCUS - browser tab gains focus');
            if (!$('#colorbox').is(':visible')) {
                getStarredItems();
            }
        }

        /**
         * Report loss of browser tab focus (for debugging only).
         *
         * @param {Event} event
         */
        function windowBlur(event) {
            _debug('BLUR - browser tab loses focus');
        }

        // ====================================================================
        // Initial actions
        // ====================================================================

        var $window = $(window);
        $window.off('focus', windowFocus).on('focus', windowFocus);
        if (_debugging) {
            $window.off('blur', windowBlur).on('blur', windowBlur);
        }

        // Initialize.
        getStarredItems();
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
        defaultRoot:     defaultRoot,
        defaultSelector: defaultSelector,
        suppress:        suppress,
        enabled:         enabled
    };

})(debugStarredItems);
