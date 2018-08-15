// app/assets/javascripts/combined.js
//
// Actions for the combined results layout.
//
// Each of the files "required" here are designed to "require" all of the
// script(s) on which they depend, but to only perform actions in the
// appropriate DOM tree context.  This eliminates the need for downloading
// multiple file assets depending on the Virgo page and allows all scripting to
// be run from a single JavaScript context.
//
// @see app/views/layouts/combined.html.erb

//= require shared/session
//= require shared/skip-nav
//= require feature/analytics
//= require feature/articles
//= require feature/availability
//= require feature/search-context
//= require feature/shelf-browse
//= require feature/starred-items

$(document).ready(function() {

    StarredItems.updatePage();
    SearchContext.updatePage();
    ShelfBrowse.updatePage();

    // Perform article search asynchronously.  This comes before updating
    // availability to avoid waiting for a browser network pipeline in the case
    // where multiple availability requests are started in parallel (which is
    // likely to tie up all of the pipelines for some time initially).
    Articles.loadArticles();

    // Fetch inline availability information and attach availability popups.
    Availability.updatePage();

    // Update links for analytics as the final step in case earlier actions
    // create additional link targets on the page.
    Analytics.updatePage();

    // Initialize Colorbox now that the DOM tree is settled.
    AppColorbox.updatePage();

    // Begin with focus set appropriately.
    AppSession.setInitialFocus();

});
