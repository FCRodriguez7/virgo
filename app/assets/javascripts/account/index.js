// app/assets/javascripts/account/index.js

//= require feature/barred-notice
//= require feature/starred-items

$(document).ready(function() {

    // Only perform these actions on the appropriate pages.
    if (!$('body').hasClass('account-page')) { return; }

    // ========================================================================
    // Actions
    // ========================================================================

    // For the starred item count in the sidebar.
    StarredItems.updatePage();

});
