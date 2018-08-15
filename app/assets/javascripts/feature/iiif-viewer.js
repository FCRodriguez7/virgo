// app/assets/javascripts/feature/iiif-viewer.js

//= depends_on ../../../../public/uv-2.0.2/lib/embed.js

//= require shared/definitions

$(document).ready(function() {

    if (!Rails.Iiif.ENABLED) { return; }

    /** @type {jQuery} */
    var $iiif_data = $('#iiif-data');

    // Only perform these actions on the appropriate pages.
    if (isMissing($iiif_data)) { return; }

    /**
     * @constant
     * @type {number}
     */
    var PDF_TIMEOUT = 5000 * MILLISECONDS;

    // ========================================================================
    // Actions
    // ========================================================================

    /** @type {object[]} */
    var info_array = JSON.parse($iiif_data.attr('data-info') || '{}');

    uvSwitcher(info_array);

    // ========================================================================
    // Functions
    // ========================================================================

    /**
     * uvSwitcher
     *
     * @param {object[]} info_array
     */
    function uvSwitcher(info_array) {

        /** @type {number} */
        var current_manifest = getCurrentManifestIndexFromUrl();

        // set the current manifestURL in the #uv div
        // (this executes before universal viewer creates an iframe within that
        // div)

        var $uv_wrapper  = $('#uv_wrapper').empty();
        var current_info = info_array[current_manifest];
        $('<div id="uv">')
            .addClass('uv')
            .css({ width: '700px', height: '600px' })
            .attr({
                'data-locale':        'en-GB:English (GB)', // NOTE: required
                'data-config':        '',
                'data-uri':           current_info.manifest_uri,
                'data-canvasindex':   current_info.first_canvas_index,
                'data-thumbnail':     current_info.thumbnail,
                'data-rightswrapper': current_info.rights_wrapper_url
            })
            .appendTo($uv_wrapper);

        // Activate the thumbnail of the item currently in the viewer.
        highlightSelectedManifest();

        // Enable PDF download links.
        $('.pdf-container').find('.request, .error').click(downloadPdf);

        // ====================================================================
        // Internal function definitions
        // ====================================================================

        /**
         * pidElementId
         *
         * @param {string} pid
         *
         * @return {string}
         */
        function pidElementId(pid) {
            return pid.toString().replace(/([:\-])/g, '\\$1');
        }

        /**
         * highlightSelectedManifest
         *
         * @param {number} [manifest]
         */
        function highlightSelectedManifest(manifest) {
            var pid = info_array[manifest || current_manifest].pid;
            $('.iiif-selected')
                .removeClass('iiif-selected')
                .find('.open-iiif-link').attr('tabindex', 0);
            $('#' + pidElementId(pid))
                .addClass('iiif-selected')
                .find('.open-iiif-link').attr('tabindex', -1);
        }

        /**
         * getPidFromUrl
         *
         * @param {string} [url]
         *
         * @return {string}
         */
        function getPidFromUrl(url) {
            var path = url || currentUrl() || '';
            var pid =
                path.replace(/^.*\/catalog\/([^\/?&#]+)[\/?&#]?.*$/, '$1');
            if (isEmpty(pid)) {
                console.warn('Error parsing "' + path + '"');
                pid = '';
            }
            return pid;
        }

        /**
         * getCurrentManifestIndexFromUrl
         *
         * @param {string} [url]
         *
         * @return {number}
         */
        function getCurrentManifestIndexFromUrl(url) {
            var index;
            var pid = getPidFromUrl(url);
            if (pid) {
                $.each(info_array, function(idx, info) {
                    if (info.pid === pid) {
                        index = idx;
                        return false; // break from $.each()
                    }
                });
                if (notDefined(index)) {
                    console.log('Manifest for ' + pid + ' not found.');
                }
            }
            if (notDefined(index)) {
                console.log('Defaulting to first manifest');
                index = 0;
            }
            return index;
        }

        /**
         * Checks for manifest parameter in URL and highlights correct
         * thumbnail.
         *
         * Does not currently use the manifest to change the UV.
         * There may not be an elegant way to do that from here.
         *
         * @param {string} [url]
         */
        function checkManifest(url) {
            var index;
            var pid = getPidFromUrl(url);
            if (pid) {
                $.each(info_array, function(idx, info) {
                    var uri = info.manifest_uri || '';
                    if (uri.indexOf('/' + pid + '/') !== -1) {
                        index = idx;
                        return false; // break from $.each()
                    }
                });
                if (notDefined(index)) {
                    console.log('URI for ' + pid + ' not present.');
                }
            }
            if (notDefined(index)) {
                console.log('Defaulting to first manifest');
                index = 0;
            }
            var thumbnail = $('.streaming-thumbnail')[index];
            if (thumbnail) {
                thumbnail.classList.add('iiif-selected');
            } else {
                console.warn(
                    "$('.streaming-thumbnail')[" + index + "] not found"
                );
            }
        }

        /**
         * downloadPdf
         *
         * @param {Event} event
         *
         * @return {boolean}          Return *false* to facilitate use as a
         *                              click handler.
         */
        function downloadPdf(event) {

            var $link     = $(event.target);
            var $all      = $link.parent().children();
            var $control  = $all.filter('.request');
            var $prep     = $all.filter('.prep');
            var $error    = $all.filter('.error');
            var $retrieve = $all.filter('.retrieve');

            var url          = $control.attr('href');
            var status_url   = url + '/status';
            var download_url = $retrieve.attr('href');

            // Setup $retrieve to restore $control after being clicked.
            function restoreControl() {
                $all.not($control).hide().off('click', restoreControl);
                var new_tooltip = $control.attr('data-msg');
                if (new_tooltip) { $control.attr('title', new_tooltip); }
                $control.addClass('visited').show();
            }
            $retrieve.on('click', restoreControl);

            // Display in-progress message.
            $all.hide();
            $prep.show();

            // Initiate the request and wait for a status response.
            var start = Date.now();
            $.get(url + '?embed=1').done(function(data) {
                var ival = setInterval(function() {
                    $.ajax({
                        url:      status_url,
                        dataType: 'text',
                        complete: function(jqXHR, textStatus) {
                            var response = jqXHR.responseText;
                            console.log(
                                'PDF download: ' +
                                'response "' + response + '", ' +
                                'status "' + textStatus + '"'
                            );
                            var $new_link;
                            if (response === 'READY') {
                                console.log('PDF: ' + download_url);
                                $new_link = $retrieve;
                            } else if (response === 'FAILED') {
                                $new_link = $error;
                            }
                            if ($new_link) {
                                // Processing is done.
                                clearInterval(ival);
                                $prep.hide();
                            } else {
                                // Processing continues; add a time count to
                                // the tooltip and attempt to refresh it.
                                var tip = $prep.attr('data-msg');
                                if (!tip) {
                                    tip = $prep.attr('title');
                                    $prep.attr('data-msg', tip);
                                }
                                tip += ' [' + hhmmssSince(start) + ']';
                                $prep.removeAttr('title').hide().show();
                                $new_link = $prep.attr('title', tip).hide();
                            }
                            $new_link.show().focus();
                        }
                    });
                }, PDF_TIMEOUT);
            });
            return false;
        }
    }

});
