// app/assets/javascripts/feature/copyright.js

//= require shared/colorbox

/**
 * Create popups for copyright/permissions.
 *
 * @type {object}
 *
 * @property {function} updatePage
 * @property {function} updateLinks
 * @property {function} updateInfo
 * @property {function} defaultRoot
 * @property {function} defaultSelector
 * @property {function} suppress
 * @property {function} enabled
 */
var Copyright = (function() {

    /**
     * @constant
     * @type {boolean}
     */
    var FEATURE_ENABLED = true;

    /**
     * @constant
     * @type {string}
     */
    var POPUP_HEIGHT = FRAME_POPUP_HEIGHT;

    /**
     * @constant
     * @type {string}
     */
    var POPUP_WIDTH = '640px';

    // ========================================================================
    // Variables
    // ========================================================================

    /**
     * Copyright popups are not displayed in print view.
     *
     * @type {boolean}
     */
    var suppressed = !FEATURE_ENABLED || inPrintView();

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
     * The default selector for copyright links.
     *
     * @return {string}
     */
    function defaultSelector() {
        return '.copyright-popup';
    }

    /**
     * Override the copyright links to be modal dialogs.
     *
     * @param {Selector} [root]       Default: {@link defaultRoot}()
     * @param {Selector} [selector]   Default: {@link defaultSelector}()
     */
    function updateLinks(root, selector) {
        if (!enabled()) { return; }
        var _func_ = arguments.callee.name;
        var $root  = root ? $(root) : defaultRoot();
        var $links = $root.find(selector || defaultSelector());
        var cbox_settings =
            AppColorbox.settings(_func_, {
                iframe:      true,
                innerHeight: POPUP_HEIGHT,
                innerWidth:  POPUP_WIDTH,
                rel:         'nofollow'
            });
        $links.removeAttr('target title aria-label').colorbox(cbox_settings);
    }

    /**
     * Reposition and setup click handlers for the info popup.  On subsequent
     * executions, only repositioning will be attempted.
     *
     * @param {Selector} [root]       Default: {@link defaultRoot}()
     * @param {Selector} [parent]     Default: '.item-content'.
     */
    function updateInfo(root, parent) {
        if (!enabled()) { return; }
        var $root  = root ? $(root) : defaultRoot();
        var $links = $root.find('.cc-info-link');
        $links.each(function() {
            var $link      = $(this);
            var $parent    = $link.closest(parent || '.item-content');
            var $container = $parent.children('.cc-info-container');

            // If the popup has not already been moved to the parent then this
            // is the initial execution of this function.
            if (isMissing($container)) {
                // Setup click handler for showing/hiding the info popup.
                $link.click(function() {

                    // It's important to perform the following repositioning
                    // operation when the item is first clicked to ensure that
                    // the element is visible and getBoundingClientRect() can
                    // provide useful values.
                    if (!$container.parent().is($parent)) {
                        // Reparent.
                        $container = $link.children('.cc-info-container');
                        $container.appendTo($parent);

                        // Adjust position of the popup relative to the parent
                        // element.
                        var icon_rect   = $link[0].getBoundingClientRect();
                        var parent_rect = $parent[0].getBoundingClientRect();
                        $container.css({
                            position: 'absolute',
                            top:      icon_rect.top  - parent_rect.top  + 12,
                            left:     icon_rect.left - parent_rect.left + 15
                        });

                        // Set up click handler for the close button.
                        $container.find('.cc-info-close').click(function() {
                            $container.hide();
                            return false;
                        }).each(handleKeypressAsClick);
                    }
                    $container.toggle({
                        duration: 0,
                        complete: function() {
                            var $this = $(this);
                            var displayed = $this.is(':visible');
                            $link.attr('aria-expanded', displayed);
                            if (displayed) {
                                $this.focus();
                            }
                        }
                    });
                    return false;
                }).each(handleKeypressAsClick);
            }
        });
    }

    /**
     * Update all request links on the page...
     *
     * @param {Selector} [root]       Default: {@link defaultRoot}()
     */
    function updatePage(root) {
        if (enabled()) {
            var $root = root ? $(root) : defaultRoot();
            updateLinks($root);
            updateInfo($root);
        }
    }

    // ========================================================================
    // Feature initialization
    // ========================================================================

    $(document).ready(function() {
        //console.log('Copyright ' + (enabled() ? 'enabled' : 'disabled'));
    });

    // ========================================================================
    // Exposed definitions
    // ========================================================================

    return {
        updatePage:      updatePage,
        updateLinks:     updateLinks,
        updateInfo:      updateInfo,
        defaultRoot:     defaultRoot,
        defaultSelector: defaultSelector,
        suppress:        suppress,
        enabled:         enabled
    };

})();
