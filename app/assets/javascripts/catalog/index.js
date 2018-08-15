// app/assets/javascripts/catalog/index.js

//= require feature/availability
//= require feature/cover-image
//= require feature/facets-popup
//= require feature/requests
//= require feature/search-context
//= require feature/shelf-browse
//= require feature/starred-items

$(document).ready(function() {

    // Only perform these actions on the appropriate pages.
    if (!$('body').hasClass('index-page')) { return; }

    // ========================================================================
    // Actions
    // ========================================================================

    // Setup page elements including modifying item links so that the resulting
    // item details show page contains "Previous", "Next" and other links
    // related to search result context.
    StarredItems.updatePage();
    SearchContext.updatePage();
    Requests.updatePage();
    ShelfBrowse.updatePage();

    // Get cover images then retry in a few seconds in case missing ones
    // have been harvested since the first attempt.
    CoverImage.loadCoverImageElements();

    // Fetch inline availability information and attach availability popups.
    // This is performed last since the cover image server will probably be
    // able to handle its requests (and relinquish browser network pipelines)
    // faster than Firehose would.
    Availability.updatePage();

});
