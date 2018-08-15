// app/assets/javascripts/shared/skip-nav.js

//= require shared/definitions

//= depends_on shared/session

$(document).ready(function() {

    /** @type {jQuery} */
    var $nav = $('.skip-nav');

    // Only perform these actions on the appropriate pages.
    if (isMissing($nav)) { return; }

    // ========================================================================
    // Event handlers
    // ========================================================================

    // Make the hidden navigation menu visible when one of its links receives
    // focus.
    $nav.find('a')
        .focus(function() {
            $(this).parents('.skip-nav').addClass('visible');
        })
        .blur(function() {
            $(this).parents('.skip-nav').removeClass('visible');
        });

    // ========================================================================
    // Actions
    // ========================================================================

    // The main skip nav menu has to be generated after all templates have been
    // given an opportunity to contribute to it, which means that it will be
    // inserted near the end of the DOM tree.
    //
    // To make it immediately available to screen readers, it needs to be moved
    // so that it is the first element that is encountered when tabbing.
    //
    // Initialize focus on the page to the title line of the skip navigation
    // menu.  This will not make the menu visible initially, but it will cause
    // the first tab press on the page to land on the first link of the menu.
    //
    var $main_skip_nav = $nav.filter('.main');
    if (isPresent($main_skip_nav)) {
        $main_skip_nav.prependTo('body');
        AppSession.initialFocus($main_skip_nav.children(':first'));
    }

    // Inject a hidden target for the "#top" anchor.  (This is needed because
    // "target: '_top'" alone will not move the focus -- without an anchor tag,
    // after clicking on the "Skip to top" link the view would scroll to the
    // top but tabbing would resume with the link following "Skip to top".)
    if (isMissing($('#top'))) {
        $('<div id="top">').addClass('visuallyhidden').prependTo('body');
    }

});
