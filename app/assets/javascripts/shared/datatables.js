// app/assets/javascripts/shared/datatables.js
//
// Initializations for jquery.dataTables.

//= require jquery.dataTables.min
//= require shared/definitions

/**
 * Set up dataTables.
 */
var AppDatatables = (function() {

    $.fn.dataTableExt.sErrMode = 'throw';

    // Ignore "the" at beginning of sortable columns.
    // Based on: http://www.datatables.net/plug-ins/aaSorting

    $.fn.dataTableExt.oSort['anti-the-asc'] = function(a, b) {
        var x = stripArticle(a);
        var y = stripArticle(b);
        return (x < y) ? -1 : ((x > y) ? 1 : 0);
    };

    $.fn.dataTableExt.oSort['anti-the-desc'] = function(a, b) {
        var x = stripArticle(a);
        var y = stripArticle(b);
        return (x < y) ? 1 : ((x > y) ? -1 : 0);
    };

    /**
     * Remove "A", "An", or "The" from the beginning of a line and capitalize
     * the result.
     *
     * @param {string} line
     *
     * @return {string}
     */
    function stripArticle(line) {
        var result = $(line).text().replace(/^(a|an|the) +/i, '');
        return result.charAt(0).toUpperCase() + result.slice(1);
    }

    return 'shared/datatables @ ' + secondsSince(LOAD_TIME);

})();
