// app/assets/javascripts/feature/image-collection.js

//= require shared/colorbox

$(document).ready(function() {

    /** @type {jQuery} */
    var $image_links = $('.image-collection a');

    // Only perform these actions on the appropriate pages.
    if (isMissing($image_links)) { return; }

    // ========================================================================
    // Event handlers
    // ========================================================================

    // Re-create Colorbox popups if window dimensions change.
    $(window).resize(function() {
        updateLinks($image_links);
    });

    // ========================================================================
    // Actions
    // ========================================================================

    // For pages with content from the old repository server:
    // Initialize popups for image content, using data-group for HTML5
    // validation.
    updateLinks($image_links);

    // ========================================================================
    // Internal function definitions
    // ========================================================================

    /**
     * Initialize popups for image content, using data-group for HTML5
     * validation.
     *
     * @param {jQuery} $links
     */
    function updateLinks($links) {
        var _func_ = arguments.callee.name;
        $links.each(function() {
            var $this = $(this);
            $this.colorbox(AppColorbox.settings(_func_, {
                current:     '{current} of {total}',
                photo:       true,
                scalePhotos: true,
                rel:         $this.attr('data-group')
            }));
        });
    }

});
