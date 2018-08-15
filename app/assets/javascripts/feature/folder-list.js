// app/assets/javascripts/feature/folder-list.js

//= require shared/datatables
//= require feature/availability

$(document).ready(function() {

    /** @type {jQuery} */
    var $listing = $('table.item-list');

    // Only perform these actions on the appropriate pages.
    if (isMissing($listing)) { return; }

    /** @type {jQuery} */
    var print_view = $('body').hasClass('print-view');

    // ========================================================================
    // Functions
    // ========================================================================

    /**
     * Return the sort order based on the CSS class associated with the table.
     *
     * Sort by item status if the column is present, otherwise sort by due date
     * (account) or title (starred items).
     *
     * @param {Selector} table
     *
     * @returns {*[][]}
     */
    function tableSortOrder(table) {
        var $table = $(table);
        var result;
        if ($table.hasClass('starred-items')) {
            result = [[2, 'asc']];
        } else if ($table.hasClass('checkouts')) {
            result = [[3, 'desc'], [4, 'asc']];
        } else {
            result = [[3, 'asc']];
        }
        return result;
    }

    // ========================================================================
    // Actions
    // ========================================================================

    // Initialize DataTable column sorting and callbacks.
    $listing.dataTable({
        aaSorting: tableSortOrder($listing),
        aoColumnDefs: [{
            bSortable: false,
            aTargets: [
                'account-number-heading',
                'account-renew-heading',
                'starred-star-heading',
                'starred-number-heading',
                'starred-availability-heading',
                'starred-reserve-library-heading',
                'starred-reserve-period-heading',
                'starred-reserve-notes-heading'
            ]
        }],
        bAutoWidth:     false,
        bInfo:          false,
        bLengthChange:  false,
        bPaginate:      false,
        bFilter:        false,

        /**
         * Give sorted column headers the appropriate ARIA label and make them
         * respond to carriage return.
         *
         * @param {*}      nHead
         * @param {*}      aData
         * @param {number} iStart
         * @param {number} iEnd
         * @param {*}      aiDisplay
         */
        fnHeaderCallback: function(nHead, aData, iStart, iEnd, aiDisplay)  {
            //console.log(callString(arguments));
            var $headers = $(this).find('th');
            if (!print_view) {
                $headers = $headers.not('.print-only');
            }
            $headers.each(function() {

                var $header = $(this);
                var sortable, sorted, descending, reversible;
                if ($header.hasClass('sorting_disabled')) {
                    sortable = false;
                } else if ($header.hasClass('sorting')) {
                    sortable = true;
                } else if ($header.hasClass('sorting_asc')) {
                    sortable = sorted = reversible = true;
                } else if ($header.hasClass('sorting_desc')) {
                    sortable = sorted = reversible = descending = true;
                } else {
                    return true; // next each() iteration
                }

                // Update the ARIA label for the header.
                var type = $header.text();
                var label;
                if (sorted) {
                    label = 'Table sorted by ' + type;
                } else if (sortable) {
                    label = 'Sort table by ' + type;
                } else {
                    label = type + ' column';
                }
                if (descending) { label += ' in descending order'; }
                if (reversible) { label += '; click to reverse'; }
                $header.attr('aria-label', label);

                // Make the header keyboard-addressable and set up a keypress
                // handler.
                if (sortable) {
                    if (notDefined($header.attr('tabindex'))) {
                        $header.attr('tabindex', 0);
                    }
                    if (!$header.prop('hkac_initialized')) {
                        nodeHandleKeypressAsClick($header);
                        $header.prop('hkac_initialized', true);
                    }
                }
            });
        },

        /**
         * Maintain numerical order even after table changes.
         * Need to redo the counters if filtered or sorted.
         *
         * @param {object} oSettings
         */
        fnDrawCallback: function(oSettings) {
            //console.log(callString(arguments));
            if (oSettings.bSorted || oSettings.bFiltered) {
                oSettings.aiDisplay.forEach(function(value, index) {
                    var $number = $('td:eq(0)', oSettings.aoData[value].nTr);
                    $number.html(index + 1 + '.');
                });
            }
        }
    });

    // For "Check availability" links.
    Availability.updatePopups();

});
