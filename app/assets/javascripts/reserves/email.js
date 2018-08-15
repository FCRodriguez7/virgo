// app/assets/javascripts/reserves/email.js

//= require feature/folder-list

$(document).ready(function() {

    // Only perform these actions on the appropriate pages.
    if (!$('body').hasClass('reserves-email-page')) { return; }

    // ========================================================================
    // Event handlers
    // ========================================================================

    $('#is_instructor').change(function() {
        $('#instructor-info').toggleClass('hidden');
    });

    $('#reserve_library_all').change(function() {
        var selected = $(this).val();
        $('.reserve-library-select').val(selected);
    });

    $('#reserve_period_all').change(function() {
        var selected = $(this).val();
        $('.reserve-period-select').val(selected);
    });

});
