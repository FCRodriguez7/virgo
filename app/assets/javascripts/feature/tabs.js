// app/assets/javascripts/feature/tabs.js

//= require jquery.ui.widget
//= require jquery.ui.tabs
//= require jquery.ui.core
//= require shared/definitions

$(document).ready(function() {

    /** @type {jQuery} */
    var $tabs = $('#tabs');

    // Only perform these actions on the appropriate pages.
    if (isMissing($tabs)) { return; }

    // ========================================================================
    // Actions
    // ========================================================================

    $tabs.tabs({
        show: function(event, ui) {
            var $iframe = $('#' + ui.panel.id).find('iframe');
            if (!$iframe.attr('src')) {
                $iframe.attr('src', $iframe.attr('lazy-src'));
            }
        }
    });

});
