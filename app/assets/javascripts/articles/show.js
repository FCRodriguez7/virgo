// app/assets/javascripts/articles/show.js

//= require shared/definitions

$(document).ready(function() {

    // Only perform these actions on the appropriate pages.
    if (!$('body').hasClass('articles-show-page')) { return; }

    // ========================================================================
    // Actions
    // ========================================================================

    // These full-text elements are of no use in a screen reader.
    $('.full-text-viewer anid').attr('aria-hidden', true);

});
