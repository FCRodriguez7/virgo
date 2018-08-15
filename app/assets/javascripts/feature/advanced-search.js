// app/assets/javascripts/feature/advanced-search.js

//= require shared/definitions

$(document).ready(function() {

    /** @type {jQuery} */
    var $facet_categories = $('.facet-category-list > .facet-category');

    // Only perform these actions on the appropriate pages.
    if (isMissing($facet_categories)) { return; }

    // ========================================================================
    // Constants
    // ========================================================================

    /**
     * The CSS class indicating that a category is open.
     *
     * @constant
     * @type {string}
     */
    var OPEN_MARKER = 'facet-open';

    /**
     * Options for jQuery slideUp()/slideDown().
     *
     * @constant
     * @type {object}
     *
     * @property {string|number} duration
     * @property {boolean}       queue
     */
    var SLIDE_OPTIONS = {
        duration: 'fast',
        queue:    false
    };

    /**
     * The icon displayed on the label when a category list is open.
     *
     * @constant
     * @type {string}
     */
    var OPENED_ICON = 'fa-minus-square';

    /**
     * The icon displayed on the label when a category list is closed.
     *
     * @constant
     * @type {string}
     */
    var CLOSED_ICON = 'fa-plus-square';

    /**
     * The icon displayed on the label when a category list is transitioning.
     * (Originally tried 'fa-square' but it was a little jarring.)
     *
     * @constant
     * @type {string}
     */
    var TRANSITION_ICON = 'fa-minus-square';

    /**
     * All category list icons for removeClass().
     *
     * @constant
     * @type {string}
     */
    var ICONS = [OPENED_ICON, CLOSED_ICON, TRANSITION_ICON].join(' ');

    /**
     * @constant
     * @type {string}
     */
    var REPOSITION_PROPERTY = 'original_position';

    // ========================================================================
    // Actions
    // ========================================================================

    // Count the number of checked items in each category and finalize the
    // category lists.
    $facet_categories.each(function() {

        var $category = $(this);
        var $list     = getList($category);

        // Finish setting up the category list.
        finalizeList($list);

        // Update the category count if a checkbox is checked/unchecked.
        setCounter($category);
        $list.find('input:checkbox').change(function() {
            var delta = $(this).is(':checked') ? 1 : -1;
            updateCounter($category, delta);
        });

    });

    // ========================================================================
    // Event handlers
    // ========================================================================

    // Respond to click events on facet category titles to open/close the
    // associated list.
    getLabel($facet_categories).click(function() {
        if (isOpenCategory(this)) {
            closeCategory(this);
        } else {
            openCategory(this);
        }
    }).each(handleKeypressAsClick);

    // Set up facet category close buttons to close the associated list when
    // clicked.
    $facet_categories.find('.close-button').click(function() {
        window.scrollTo(0, 0);
        closeCategory(this);
    }).each(handleKeypressAsClick);

    // For floating facet category close buttons, halt the animation if the
    // button is hovered over.  To make the close button visible when tabbing,
    // when the button is focused when hidden then it will cause its container
    // to be repositioned for visibility; then when the button loses focus it
    // restores its container's position.
    $facet_categories.find('.close-button-anchor > .close-button')
        .hover(
            function() { stopFloatingCloseButton(this); },
            function() {}
        )
        .focus(function() {
            var $this = $(this);
            if (!$this.is(':active, :hover')) {
                var $container = $this.parent();
                var old_pos = {};
                var new_pos = {
                    position:  'absolute',
                    top:       '-0.33em',
                    right:     '7.33em',
                    'z-index': 1000
                };
                Object.keys(new_pos).forEach(function(key) {
                    var value = $container.css(key);
                    old_pos[key] = isDefined(value) ? value : '';
                });
                $container.prop(REPOSITION_PROPERTY, old_pos).css(new_pos);
            }
        })
        .blur(function() {
            var $container = $(this).parent();
            var old_pos = $container.prop(REPOSITION_PROPERTY);
            if (old_pos) {
                $container.removeProp(REPOSITION_PROPERTY).css(old_pos);
            }
        });

    // ========================================================================
    // Internal function definitions - Categories
    // ========================================================================

    /**
     * Find the category to which an element belongs.
     *
     * @param {Selector} element
     *
     * @return {jQuery}
     */
    function getCategory(element) {
        return $(element).closest('.facet-category');
    }

    /**
     * Open the list for the given category (closing any other open lists).
     *
     * @param {Selector} element
     */
    function openCategory(element) {
        var $category = getCategory(element);
        $facet_categories.not($category).each(function() {
            closeCategory(this);
        });
        openList($category);
    }

    /**
     * Close the list for the given category.
     *
     * @param {Selector} element
     */
    function closeCategory(element) {
        closeList(element);
    }

    /**
     * isOpenCategory
     *
     * @param {Selector} element
     *
     * @return {boolean}
     */
    function isOpenCategory(element) {
        return isOpenList(element);
    }

    // ========================================================================
    // Internal function definitions - Category Labels
    // ========================================================================

    /**
     * Get the category label.
     *
     * @param {Selector} element
     *
     * @return {jQuery}
     */
    function getLabel(element) {
        var $element = $(element);
        if ($element.hasClass('facet-category-label')) {
            return $element;
        } else {
            return getCategory($element).children('.facet-category-label');
        }
    }

    /**
     * Modify the category label.
     *
     * @param {Selector} element
     * @param {string}   icon_class
     *
     * @return {jQuery}
     */
    function setLabel(element, icon_class) {
        var sr_text;
        switch (icon_class) {
            case OPENED_ICON:     sr_text = 'Close selections for: '; break;
            case CLOSED_ICON:     sr_text = 'Open selections for: ';  break;
            case TRANSITION_ICON: sr_text = 'Changing menu for: ';    break;
        }
        var $label = getLabel(element);
        var $icon  = $label.children('.fa');
        $icon.removeClass(ICONS).addClass(icon_class).html(srOnly(sr_text));
        return $label;
    }

    /**
     * Modify the category label when the category list is in the open state.
     *
     * @param {Selector} element
     */
    function openLabel(element) {
        var $label  = setLabel(element, OPENED_ICON);
        var tooltip = $label.attr('data-opened-title');
        $label.attr({ title: tooltip, 'aria-expanded': true });
    }

    /**
     * Modify the category label when the category list is in the closed state.
     *
     * @param {Selector} element
     */
    function closeLabel(element) {
        var $label = setLabel(element, CLOSED_ICON);
        var tooltip = $label.attr('data-closed-title');
        $label.attr({ title: tooltip, 'aria-expanded': false });
    }

    /**
     * Modify the category label when the category list is transitioning.
     *
     * @param {Selector} element
     */
    function transitionLabel(element) {
        setLabel(element, TRANSITION_ICON);
    }

    // ========================================================================
    // Internal function definitions - Category Lists
    // ========================================================================

    /**
     * getList
     *
     * @param {Selector} element
     *
     * @return {jQuery}
     */
    function getList(element) {
        var $element = $(element);
        var $list;
        if ($element.hasClass('facet-choice-list')) {
            $list = $element;
        } else {
            $list = getCategory($element).children('.facet-choice-list');
        }
        return $list;
    }

    /**
     * The final entry is tentatively a close button to be shown if the browser
     * can't support the floating close button.  If this has been set to
     * "display: none" then the browser *does* support it and the close button
     * list entry can go away.  In either case, the final element of the list
     * should have the CSS class "last".
     *
     * @param {Selector} element
     */
    function finalizeList(element) {
        var $list  = getList(element);
        var $entry = $list.children('.close-button-entry');
        if (!$entry.is(':visible')) {
            $entry.remove();
        }
        $list.children('.facet-choice').last().addClass('last');
    }

    /**
     * isOpenList
     *
     * @param {Selector} element
     *
     * @return {boolean}
     */
    function isOpenList(element) {
        return getList(element).hasClass(OPEN_MARKER);
    }

    /**
     * openList
     *
     * @param {Selector} element
     *
     * @return {jQuery}
     */
    function openList(element) {
        var $list  = getList(element);
        var $label = getLabel($list);

        transitionLabel($label);

        var options =
            $.extend({}, SLIDE_OPTIONS, {
                complete: function() {
                    openLabel($label);
                    animateFloatingCloseButton($list);
                }
            });
        return $list.addClass(OPEN_MARKER).slideDown(options);
    }

    /**
     * closeList
     *
     * @param {Selector} element
     *
     * @return {jQuery}
     */
    function closeList(element) {
        var $list  = getList(element);
        var $label = getLabel($list);

        transitionLabel($label);
        stopFloatingCloseButton($list);

        var options =
            $.extend({}, SLIDE_OPTIONS, {
                complete: function() {
                    closeLabel($label);
                }
            });
        return $list.removeClass(OPEN_MARKER).slideUp(options);
    }

    // ========================================================================
    // Internal function definitions - Floating list close buttons
    // ========================================================================

    /**
     * getFloatingCloseButton
     *
     * @param {Selector} element
     *
     * @return {jQuery}
     */
    function getFloatingCloseButton(element) {
        var $element = $(element);
        var $button;
        if ($element.hasClass('close-button')) {
            $button = $element;
        } else {
            var $holder = getList($element).children('.close-button-anchor');
            $button = $holder.children('.close-button');
        }
        return $button;
    }

    /**
     * animateFloatingCloseButton
     *
     * @param {Selector} button
     */
    function animateFloatingCloseButton(button) {
        getFloatingCloseButton(button).addClass('animated');
    }

    /**
     * stopFloatingCloseButton
     *
     * @param {Selector} button
     */
    function stopFloatingCloseButton(button) {
        getFloatingCloseButton(button).removeClass('animated');
    }

    // ========================================================================
    // Internal function definitions - Category Counts
    // ========================================================================

    /**
     * Get the counter element for a category, creating it if necessary.
     *
     * @param {Selector} category
     *
     * @return {jQuery}
     */
    function getCounter(category) {
        var $category = getCategory(category);
        var $label    = getLabel($category);
        var $counter  = $label.children('.counter');
        if (isMissing($counter)) {
            var tooltip = 'Number of items checked;\n';
            tooltip += 'click here to uncheck all.';
            $counter = $('<span>').addClass('counter');
            $counter.attr({ role: 'button', title: tooltip, tabindex: 0 });
            $counter.click(function() {
                var has_focus = $counter.is(':focus');
                clearChecked($category);
                clearCounterValue($counter);
                if (has_focus) { $label.focus(); }
                return false;
            }).each(handleKeypressAsClick);
            $counter.appendTo($label);
        }
        return $counter;
    }

    /**
     * Set the counter element for a category.  If *value* is not provided then
     * the count is determined by counting the checked items in the category.
     *
     * @param {Selector}      category
     * @param {number|string} [value]
     */
    function setCounter(category, value) {
        var $category = getCategory(category);
        var $counter  = getCounter($category);
        var count = isDefined(value) ? value : getChecked($category).length;
        setCounterValue($counter, count);
    }

    /**
     * Modify the counter element for a category.
     *
     * @param {Selector}      category
     * @param {number|string} increment     Positive or negative integer.
     */
    function updateCounter(category, increment) {
        var $counter = getCounter(category);
        updateCounterValue($counter, increment);
    }

    /**
     * Get the checked checkboxes in a category.
     *
     * @param {Selector} category
     *
     * @return {jQuery}
     */
    function getChecked(category) {
        return getList(category).find('input:checked');
    }

    /**
     * Unchecks all of the checked items in a category.
     *
     * @param {Selector} category
     */
    function clearChecked(category) {
        getChecked(category).prop('checked', false);
    }

    /**
     * Retrieve the value assigned to a counter element.
     *
     * @param {Selector} counter
     *
     * @return {number}
     */
    function getCounterValue(counter) {
        var value = $(counter).attr('data-count');
        return ordinal(value);
    }

    /**
     * Assign a value to a counter element.
     *
     * @param {Selector}      counter
     * @param {number|string} [value]
     */
    function setCounterValue(counter, value) {
        var $counter  = $(counter);
        var new_count = ordinal(value);
        if (new_count) {
            $counter.text(new_count).show();
        } else {
            $counter.empty().hide();
        }
        $counter.attr('data-count', new_count);
    }

    /**
     * Reset the value of a counter element.
     *
     * @param {Selector} counter
     */
    function clearCounterValue(counter) {
        setCounterValue(counter);
    }

    /**
     * Modify the value of a counter element.
     *
     * @param {Selector}      counter
     * @param {number|string} increment     Positive or negative integer.
     */
    function updateCounterValue(counter, increment) {
        var delta = parseInt(increment);
        if (delta) {
            var $counter  = $(counter);
            var new_count = getCounterValue($counter) + delta;
            setCounterValue($counter, new_count);
        }
    }

});
