// app/assets/javascripts/catalog/show.js

//= require feature/availability
//= require feature/bookplate
//= require feature/collection-nav
//= require feature/copyright
//= require feature/cover-image
//= require feature/google-preview
//= require feature/iiif-viewer
//= require feature/image-collection
//= require feature/marc-view
//= require feature/requests
//= require feature/search-context
//= require feature/see-more
//= require feature/shelf-browse
//= require feature/starred-items
//= require feature/sticky-sidebar

$(document).ready(function() {

    // Only perform these actions on the appropriate pages.
    if (!$('body').hasClass('show-page')) { return; }

    // ========================================================================
    // Actions
    // ========================================================================

    // Update common page elements, handling "See More" first since the
    // metadata listing is in the center of the user's view.
    SeeMore.updatePage();
    StarredItems.updatePage();
    SearchContext.updatePage();
    Bookplate.updatePage();
    Copyright.updatePage();
    Requests.updatePage();
    ShelfBrowse.updatePage();

    // Get the cover image.  (This is likely to be quick since it should have
    // already been acquired on the index page.)
    CoverImage.loadCoverImageElements();

    // Fetch availability information.
    Availability.getAvailability();

    // Finally, attempt to set up "Google Preview" for this item.
    GooglePreview.updatePage();

});
