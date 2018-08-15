// app/assets/javascripts/popup.js
//
// Actions for the popup layout.
//
// Each of the files "required" here are designed to "require" all of the
// script(s) on which they depend, but to only perform actions in the
// appropriate DOM tree context.  This eliminates the need for downloading
// multiple file assets depending on the Virgo page and allows all scripting to
// be run from a single JavaScript context.
//
// @see app/views/layouts/popup.html.erb

//= require shared/session

$(document).ready(function() {

    // ========================================================================
    // Event handlers
    // ========================================================================

    // This ensures that the Escape key will close the Colorbox in which this
    // popup even in cases where focus is on an element (like <a>) that would
    // otherwise "consume" the keypress event.
    $('body').keyup(function(event) {
        var key = event.keyCode || event.which;
        if (key === CHAR.Escape) {
            parent.$.fn.colorbox.close();
            return false;
        }
    });

    // ========================================================================
    // Actions
    // ========================================================================

    var $form = $('.request-container form');
    var url   = $form.attr('action');
    if (url) {
        url = addParameter(url, 'popup', 'true');
        $form.attr('action', url);
    }

});
