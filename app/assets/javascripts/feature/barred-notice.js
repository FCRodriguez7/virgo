// app/assets/javascripts/feature/barred-notice.js

//= require shared/colorbox

$(document).ready(function() {

    /** @type {jQuery} */
    var $barred_notice = $('.barred-notice');

    // Only perform these actions on the appropriate pages.
    if (isMissing($barred_notice)) { return; }

    // ========================================================================
    // Actions
    // ========================================================================

    $barred_notice.hide();

    var whats_this = '.whats-this';
    $(whats_this)
        .show()
        .colorbox(AppColorbox.settings(whats_this, {
            href:     '#barred_notice',
            inline:   true,
            maxWidth: narrowScreen() ? '75%' : '40%',

            onOpen: function() {
                AppColorbox.onOpen(whats_this);
                $barred_notice.show();
            },

            onCleanup: function() {
                AppColorbox.onCleanup(whats_this);
                $barred_notice.hide();
            }
        }));

});
