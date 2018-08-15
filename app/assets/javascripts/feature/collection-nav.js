// app/assets/javascripts/feature/collection-nav.js

//= require shared/jstree

$(document).ready(function() {

    /** @type {jQuery} */
    var $tree_scroller = $('.tree-scroller');

    // Only perform these actions on the appropriate pages.
    if (isMissing($tree_scroller)) { return; }

    // ========================================================================
    // Create tree.
    // ========================================================================

    /** @type {string} */
    var focus_id = $tree_scroller.attr('data-id');

    /** @type {string} */
    var base_path = $tree_scroller.attr('data-base_path');

    /** @type {string} */
    var collection_path = $tree_scroller.attr('data-cid_path');

    /** @type {number} */
    var top_min = 25;

    $tree_scroller.children('.collection-tree')
        .jstree(AppJstree.settings('tree-scroller', {
            json_data: {
                ajax: {
                    url: function(node) {
                        var result;
                        if (node === -1) {
                            result = collection_path;
                            result += '/children.json';
                            result += '?expand_to_include=' + focus_id;
                        } else {
                            result = base_path;
                            result += '/' + node.attr('id');
                            result += '/children.json';
                        }
                        return result;
                    }
                }
            },
            ui: {
                selected_parent_close: false,
                initially_select:      [focus_id]
            }
        }))
        .bind('loaded.jstree', function() {
            // Prevent individual nodes from becoming part of the tab sequence.
            // Use arrow keys to navigate the hierarchy.
            $(this).find('a').attr('tabindex', -1);
        })
        .bind('open_node.jstree', function() {
            // Prevent individual nodes from becoming part of the tab sequence.
            // Use arrow keys to navigate the hierarchy.
            $(this).find('a').attr('tabindex', -1);
        })
        .bind('select_node.jstree', function(e, node) {
            var $node = node.rslt.obj;
            if ($node.attr('id') === focus_id) {
                var top = $node.position().top - top_min;
                if (top < 0) { top = 0; }
                $tree_scroller.scrollTop(top);
            } else {
                document.location = $node.children('a').attr('href');
            }
        });

});
