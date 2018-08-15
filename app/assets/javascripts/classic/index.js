// app/assets/javascripts/classic/index.js

//= require feature/classic

$(document).ready(function() {

    // Only perform these actions on the appropriate pages.
    if (!$('body').hasClass('classic-page')) { return; }

    // ========================================================================
    // Actions
    // ========================================================================

    ClassicLens.updatePage();

});
