// app/assets/javascripts/application.js
//
// Definitions for the application layout.
//
// This file is intended to include all of the functionality normally needed by
// Virgo web pages so that only a single file asset needs to be downloaded by
// the web client.
//
// Each of the files "required" here are designed to "require" all of the
// script(s) on which they depend, but to only perform actions in the
// appropriate DOM tree context.  This eliminates the need for downloading
// multiple file assets depending on the Virgo page and allows all scripting to
// be run from a single JavaScript context.
//
// @see app/views/layouts/application.html.erb

//= require shared/session
//= require shared/skip-nav
//= require feature/analytics

//= require_tree ./account
//= require_tree ./advanced
//= require_tree ./articles
//= require_tree ./catalog
//= require_tree ./classic
//= require_tree ./folder
//= require_tree ./maps
//= require_tree ./reserves
//= require_tree ./video

$(document).ready(function() {

    // Update links for analytics as the final step in case earlier actions
    // create additional link targets on the page.
    Analytics.updatePage();

    // Initialize Colorbox now that the DOM tree is settled.
    AppColorbox.updatePage();

    // Begin with focus set appropriately.
    AppSession.setInitialFocus();

});
