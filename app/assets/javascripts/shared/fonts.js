// app/assets/javascripts/shared/fonts.js

//= depends_on //use.typekit.com/dcu6kro.js

//= require shared/definitions

/**
 * The Typekit script is loaded via the <head> section of the page.
 *
 * @external Typekit
 * @requires https://use.typekit.com/dcu6kro.js
 */

/**
 * Set up fonts.
 */
var AppFonts = (function() {

    $(document).ready(function() {

        try {
            Typekit.load();
        }
        catch (err) {
            console.error('Typekit: ' + err);
        }

    });

    return 'shared/fonts @ ' + secondsSince(LOAD_TIME);

})();
