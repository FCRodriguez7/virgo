// app/assets/javascripts/home.js
//
// Actions for the home page (root) of the web site.
//
// Each of the files "required" here are designed to "require" all of the
// script(s) on which they depend, but to only perform actions in the
// appropriate DOM tree context.  This eliminates the need for downloading
// multiple file assets depending on the Virgo page and allows all scripting to
// be run from a single JavaScript context.
//
// @see app/views/layouts/home.html.erb

//= require shared/session
//= require shared/skip-nav
//= require feature/analytics
//= require feature/articles
//= require feature/search-toggle

$(document).ready(function() {

    /**
     * @constant
     * @type {number}
     */
    var FLASH_FADE_TIME = 800 * MILLISECONDS;

    // ========================================================================
    // Event handlers
    // ========================================================================

    // Show and hide search help on user click.
    $('.which-search').click(function() {
        var $toggle = $(this);
        var $panel  = $('.which-search-help');
        $panel.slideToggle({
            complete: function() {
                $toggle.attr('aria-expanded', $panel.is(':visible'));
            }
        });
        return false;
    });

    // ========================================================================
    // Actions
    // ========================================================================

    // Bring up flash message (if present).
    $('.flash-message').fadeTo(FLASH_FADE_TIME, 1);

    // Respond to article switching (if present).
    Articles.addArticleEngineSwitch();

    // Update links for analytics as the final step in case earlier actions
    // create additional link targets on the page.
    Analytics.updatePage();

    // Initialize Colorbox now that the DOM tree is settled.
    AppColorbox.updatePage();

    // Begin with focus set appropriately.
    AppSession.setInitialFocus();

});
