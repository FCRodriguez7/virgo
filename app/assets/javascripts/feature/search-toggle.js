// app/assets/javascripts/feature/search-toggle.js

//= require shared/definitions

$(document).ready(function() {

    /** @type {jQuery} */
    var $toggle = $('input[name="catalog_select"]');

    // Only perform these actions on the appropriate pages.
    if (isMissing($toggle)) { return; }

    /**
     * @constant
     * @type {string}
     */
    var ALL_SEARCH = Rails.Portal.ALL_PLACEHOLDER;

    /**
     * @constant
     * @type {string}
     */
    var CATALOG_SEARCH = Rails.Portal.CATALOG_PLACEHOLDER;

    /**
     * @constant
     * @type {string}
     */
    var ARTICLES_SEARCH = Rails.Portal.ARTICLES_PLACEHOLDER;

    // ========================================================================
    // Actions
    // ========================================================================

    // Change search box placeholder text based on user radio input selection.
    $toggle.change(function() {
        var radio_label = $(this).val();
        var tag;
        switch (radio_label) {
            case 'catalog':  tag = CATALOG_SEARCH;  break;
            case 'articles': tag = ARTICLES_SEARCH; break;
            default:         tag = ALL_SEARCH;      break;
        }
        $('#SI').attr('placeholder', tag).attr('aria-label', tag);
    });

});
