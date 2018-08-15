// app/assets/javascripts/feature/page-turner.js

//= require shared/definitions
//= require OpenLayers
//= require iscroll-lite-min
//= require page-turner-dependencies

/**
 * @external PageTurner
 * @see app/views/catalog/page_turner.html.erb
 */

$(document).ready(function () {

    var app = {};
    window.app = app;

    // Page model - unused currently but here for your hacking pleasure.
    app.Page = Backbone.Model.extend();

    // Book collection - representation of book data for our app.
    app.Book = Backbone.Collection.extend({

        // Get book data from the initial page source.
        // Only happens once - read only.
        sync: _.memoize(function(method, collection, options) {
            if (method === "read") {
                collection.add(
                    _.map($("li.page-thumb"), function(item) {
                        var obj = {
                            id:    item.id,
                            title: $(item).find('.page-title').first().text()
                        };
                        if (obj.id) {
                            return obj;
                        }
                    })
                );
            }
            else {
                options.error();
            }
        }),

        // Get the index number for a given pid.
        // Setup for caching given a books page length.
        pageIndex: function(pid) {
            var cacheable_func =
                _.bind(function(pageCount, pid) {
                    return this.indexOf(this.get(pid));
                }, this);
            return _.memoize(cacheable_func)(this.length, pid);
        },

        // Return the page model following the model with the given pid.
        nextPage: function(pid) {
            var index = this.pageIndex(pid);
            var nextIndex = 0;
            if ((index !== -1) && (index < (this.length - 1))) {
                nextIndex = ++index;
            }
            return this.at(nextIndex);
        },

        // Return the page model before the model with the given pid.
        prevPage: function(pid) {
            var index = this.pageIndex(pid);
            var prevIndex = 0;
            if (index !== -1) {
                prevIndex = (index > 0) ? --index : (this.length - 1);
            }
            return this.at(prevIndex);
        },

        // Return the book collection w/o the sides, top, and bottom in the
        // proper order (back last).
        // Only need to do this once if asked for multiple times.
        getProperBookOrder: _.once(function() {
            var newBook = this.clone();
            var back = newBook.findWhere({title:'Back Cover'});
            if (back) {
                newBook.remove(back);
            }
            var remove = newBook.filter(function(item) {
                var title = item.get('title');
                if ((title === 'Spine') || (title === 'Head') ||
                    (title === 'Back Cover') || (title === 'Tail') ||
                    (title === 'Fore-edge')) {
                    return true;
                }
            });
            if (remove) { newBook.remove(remove); }
            if (back)   { newBook.push(back); }
            return newBook;
        })
    });
    app.book = new app.Book();

    // State of our application.
    // Views should change state attributes and listen to those attributes for
    // changes.
    // Attributes watched:
    // viewer       - openLayer | twoPage
    // book         - the book model/collection used
    // selectedPage - the currently selected page
    // zoom         - zoom level
    // center       - center of viewable page image
    // showHeader   - show page header
    // showSidebar  - show page sidebar
    app.State = Backbone.Model.extend({

        initialize: function() {
            $(document).keydown(_.bind(function(e) {
                var previous = CHAR.ArrowLeft, next = CHAR.ArrowRight;
                switch (e.keyCode) {
                    case previous:
                        this.selectPrevPage();
                        e.preventDefault();
                        break;
                    case next:
                        this.selectNextPage();
                        e.preventDefault();
                        break;
                }
            }, this));
            this.listenTo(this, 'change:viewer', this.viewerChanged);
        },

        // Toggle the book based on the viewer used.
        viewerChanged: function() {
            var viewer = this.get('viewer');
            if (viewer === "openLayer") {
                this.set({ book: app.book });
            } else {
                this.set({ book: app.book.getProperBookOrder() });
            }
        },

        // Select the currently viewed page.
        selectPage: function(pageId) {
            this.set({ selectedPage: pageId });
        },

        // Select the next page in book order.
        selectNextPage: function() {
            this.selectPage(
                this.get('book').nextPage(this.get('selectedPage')).id
            );
        },

        // Select the previous page in book order.
        selectPrevPage: function() {
            this.selectPage(
                this.get('book').prevPage(this.get('selectedPage')).id
            );
        },

        // Set the state of the OpenLayers viewer given zoom, center
        // options arg allows for silent state change if needed (or other
        // backbone model set options).
        setOpenLayerState: function(zoom, center, options) {
            var ctr = center || { lat: 0, lon: 0 };
            this.set({
                zoom:   zoom || 0,
                center: { lat: ctr.lat, lon: ctr.lon }
            }, options);
        },

        // Get the currently selected Image number (count of page including
        // cover and other pages.
        selectedImageNumber: function() {
            return this.get('book').pageIndex(this.get('selectedPage'));
        }
    });
    app.state = new app.State({ book: app.book }); //, viewer:"openLayer"});

    // View that controls the page header bar (created on Virgo server-side).
    app.PageHeaderView = Backbone.View.extend({
        model: app.state,

        initialize: function() {
            // Replace the current permalink link and add a "Two Page" viewer
            // button.
            this.$('.page-permalink').remove();

            this.listenTo(this.model, 'change:viewer', this.changeMainView);
            this.listenTo(this.model, 'change:book',   this.bookChange);
            this.listenTo(this.model, 'change:showHeader',   this.hideShow);
            this.listenTo(this.model, 'change:selectedPage', this.changePage);
            this.model.set({showHeader: true});
            this.hideShow();
        },

        events: {
            "click .page-permalink":             "switchView",
            "change .page-turner-select select": "selectPage",
            "click .page-turner-next":           "nextPage",
            "click .page-turner-prev":           "prevPage",
            "click .hide-header":                "toggleHeader",
            "click .lock-zoom":                  "defaultZoom"
        },

        // Update our view whenever the selected page changes.
        changePage: function(event) {
            // Is this a single page?
            if (app.book.length === 1) {
                this.$('.page-turner-next').remove();
                this.$('.page-turner-select').remove();
                this.$('.page-turner-prev').remove();
            } else {
                var pid = this.model.get('selectedPage');
                this.$('.page-turner-select select').val(pid);
                this.setupNavBar();
            }
        },

        setupNavBar: _.once(function() {
            $('<button class="page-permalink">Two Page View</button>')
                .insertBefore('.lock-zoom');
        }),

        // Toggle the page viewer.
        switchView: function(event) {
            event.preventDefault();
            this.model.set({
                viewer: this.model.get('viewer')==="twoPage" ? "openLayer" : "twoPage"
            });
        },

        // Update the Page turner select pulldown whenever the book is changed.
        bookChange: function() {
            var selectedPage = this.model.get('selectedPage');
            this.collection = this.model.get('book');
            this.undelegateEvents();
            this.pageTurnerSelect =
                this.$('.page-turner-select select').empty();
            this.collection.each(_.bind(function(item) {
                if (item.id === selectedPage) {
                    this.pageTurnerSelect.append("<option selected='selected' value='" +
                        item.id + "'>" + item.get('title') + "</option>");
                } else {
                    this.pageTurnerSelect.append("<option value='" +
                        item.id + "'>" + item.get('title') + "</option>");
                }
            }, this));
            this.delegateEvents();
        },

        // The page selector pull down has change, update the app state.
        selectPage: function(event) {
            this.model.selectPage(event.target.value);
        },
        // The app state main viewer has changed, update the head to reflect
        // viewer.
        changeMainView: function() {
            if (this.model.get('viewer') === "openLayer") {
                this.$('.page-permalink').html('Two Page View');
                if (PageTurner.lock) {
                    this.$('.lock-zoom')
                        .removeClass('lock-inactive')
                        .addClass('lock-active')
                        .html('Unset Default Zoom');
                } else {
                    this.$('.lock-zoom')
                        .removeClass('lock-active')
                        .addClass('lock-inactive')
                        .html('Set Default Zoom');
                }
            } else {
                this.$('.page-permalink').html('Zoomable View');
                this.$('.lock-zoom')
                    .removeClass('lock-active')
                    .addClass('lock-inactive')
                    .html('Toggle Zoom');
            }
        },

        // The nextPage button has been clicked, update the app state.
        nextPage: function() {
            this.model.selectNextPage();
        },

        // The prevPage button has been clicked, update the app state.
        prevPage: function() {
            this.model.selectPrevPage();
        },

        // The show/hide header button has been clicked, toggle the state.
        toggleHeader: function(event) {
            this.model.set({ showHeader: !this.model.get('showHeader') });
        },

        // The showHeader app state has changed, show | hide this header now.
        hideShow: _.debounce(function() {
            var showHeader = this.model.get('showHeader');
            if (showHeader) {
                this.$('.page-turner-title').slideDown(_.bind(function() {
                    $('#container').removeClass('title-closed');
                    $('.hide-header').html('Hide');
                    _.delay(_.bind(function() {
                        this.model.trigger("change:showHeaderDone");
                    }, this), 500);
                }, this));
            } else {
                this.$('.page-turner-title').slideUp(_.bind(function() {
                    $('#container').addClass('title-closed');
                    $('.hide-header').html('Show');
                    _.delay(_.bind(function() {
                        this.model.trigger("change:showHeaderDone");
                    }, this), 500);
                }, this));
            }
            _.delay(function() { $(window).resize(); }, 300);
        }, 500),

        // The default zoom button has been clicked, update the app state.
        defaultZoom: _.throttle(function(event) {
            var el = $(event.target);
            if (this.model.get('viewer') === "openLayer") {
                if (el.hasClass('lock-active')) {
                    el.html("Set Default Zoom");
                    PageTurner.lock = "false";
                    PageTurner.z = null
                } else {
                    el.html("Unset Default Zoom");
                    PageTurner.lock = "true";
                    //PageTurner.z = map.getZoom() ? map.getZoom() : 0
                    PageTurner.z = this.model.has('zoom') ? this.model.get('zoom') : 0;
                }
                el.toggleClass("lock-active").toggleClass("lock-inactive");
            } else {
                this.model.set({
                    defaultZoom: !this.model.get('defaultZoom')
                });
            }
        }, 1000)
    });

    // OpenLayer Viewer
    // OpenLayer viewer attached to jpeg2000 server for tiles.
    app.OpenLayerPageViewer = Backbone.View.extend({
        model: app.state,

        initialize: function() {
            OpenLayers.ImgPath = "http://js.mapbox.com/theme/dark/";
            app.map = this.map = new OpenLayers.Map("page_viewer", {
                zoom: this.model.get('zoom') || 0,
                eventListeners: {
                    moveend: this.updateCenterState,
                    zoomend: this.updateZoomState
                }
            });

            $(window).resize(function () {
                this.$(".page-container").css({
                    height: $(window).height() - (this.$(".page-turner-head").outerHeight(true) + 1),
                    "min-height": "600 !important"
                });
            }).trigger("resize");

            if (navigator.userAgent.match(/iP(ad|od|hone)/i)) {
                var scroller = new iScroll("page_viewer");
            }
            this.startListening();
        },

        events: {},

        // Here we extend supers stopListening function to stop listening to
        // everything except changes to the viewer attribute.
        stopListening: _.throttle(function() {
            Backbone.View.prototype.stopListening.apply(this);
            // We need to continue listening to the viewer attribute so that we
            // can re-enable this view when needed.
            this.listenTo(this.model, 'change:viewer', this.changeView);
        }, 300),

        // Events that this view listens to.
        startListening: _.throttle(function() {
            this.listenTo(this.model, 'change:viewer', this.changeView);
            this.listenTo(this.model, 'change:selectedPage', this.changePage);
//          this.listenTo(this.model, 'change:defaultZoom', this.defaultZoom);
            this.listenTo(this.model, 'change:zoom', this.changeZoom);
            this.listenTo(this.model, 'change:center', this.changeCenter);
        }, 300),

        // Change the viewers loaded page.
        changePage: _.throttle(function() {
            var pid = this.model.get('selectedPage');
            this.loadViewer(pid);
        }, 300),

        // Enable or disable this view as needed.
        // Quit listening to events when view is disabled.
        changeView: _.throttle(function() {
            if (this.model.get('viewer') === "openLayer") {
                this.$('#page_viewer').show();
                this.startListening();
                if (this.setup) {
                    this.model.trigger('change:zoom');
                    this.model.trigger('change:center');
                    this.model.trigger('change:selectedPage');
                }
                this.setup = true;
            } else {
                this.$('#page_viewer').hide();
                this.stopListening();
            }
        }, 300),

        changeZoom: _.throttle(function() {
            this.map.zoomTo(this.model.get('zoom'));
        }, 300),

        updateZoomState: _.debounce(function() {
            app.state.set({ zoom: app.map.getZoom() });
        }, 300),

        changeCenter: _.throttle(function() {
            var center = this.model.get('center');
            this.map.setCenter(new OpenLayers.LonLat(center.lon, center.lat));
        }, 300),

        updateCenterState: _.debounce(function() {
            var center = app.map.getCenter();
            app.state.set({ center: { lat: center.lat, lon: center.lon } });
        }, 300),

        loadViewer: _.throttle(function(pid) {
            if (this.map.getLayersByName("JP2k").length && this.OUlayer) {
                this.map.removeLayer(this.OUlayer);
            }
            var metadataUrl =
                "/fedora_metadata/" + PageTurner.id + "/" + pid + ".json";
            var imageUrl =
                PageTurner.repo + "/get/" + pid + "/content";
            var djatokaUrl =
                PageTurner.repo + "/objects/" + pid + "/methods/djatoka:jp2SDef/getRegion?";
            var tileSize = new OpenLayers.Size(512, 512);
            this.OUlayer = new OpenLayers.Layer.OpenURL("JP2k", djatokaUrl, {
                layername:   "basic",
                format:      "image/jpeg",
                rft_id:      imageUrl,
                metadataUrl: metadataUrl,
                tileSize:    tileSize,
                buffer:      0
            });
            var metadata    = this.OUlayer.getImageMetadata();
            var resolutions = this.OUlayer.getResolutions();
            var maxExtent =
                new OpenLayers.Bounds(0, 0, metadata.width, metadata.height);
            var options = {
                resolutions: resolutions,
                maxExtent:   maxExtent
            };
            this.map.setOptions(options);
            this.map.addLayer(this.OUlayer);
            this.centerZoom(this.map, metadata)
        }, 300),

        centerZoom: function(map, meta) {
            var max = this.map.getMaxExtent();
            var lon = PageTurner.x ? PageTurner.x : (max.getWidth() / 2);
            var lat = PageTurner.y ? PageTurner.y : (max.getHeight() / 2);
            PageTurner.x = null;
            PageTurner.y = null;
            this.model.set({center:{lon:lon, lat:lat}});
            this.defaultZoom();
        },

        defaultZoom: function() {
            if (PageTurner.z) {
                this.map.zoomTo(PageTurner.z);
                if (PageTurner.lock !== "true") {
                    PageTurner.z = null;
                }
            } else {
                this.map.zoomToMaxExtent();
            }
//            this.map.zoomToMaxExtent();
//            this.model.set({defaultZoom: false},{silent:true});
        }
    });

    // TODO: change page-permalink to more descriptive id and update css.
    app.DoublePageViewer = Backbone.View.extend({
        model:      app.state,
        collection: app.state.get('book'), //app.book,

        initialize: function() {
            yepnope({
                test:     Modernizr.csstransforms,
                yep:      ['/assets/turn.min.js'],
                nope:     ['/assets/turn.html4.min.js'],
                both:     ['/assets/zoom.min.js'],
                complete: _.bind(this.ready, this)
            });
        },

        events: {
            //"click #page_permalink":                  "switchView",
            "missing .magazine":                        "missingPage",
            "turning .magazine":                        "turningPage",
            "turned .magazine":                         "turnedPage",
            "zoomtap .magazine-viewport":               "zoomPage",
            "zoomresize .magazine-viewport":            "zoomResize",
            "zoomzoomOut .magazine-viewport":           "postZoomOut",
            "zoomswipeLeft .magazine-viewport":         "prevPage",
            "zoomswipeRight .magazine-viewport":        "nextPage",
            "hover .next-button, .previous-button":     "paginationHover",
            "mousedown .next-button, .previous-button": "paginationDownUp",
            "mouseup .next-button, .previous-button":   "paginationDownUp",
            "click .next-button, .previous-button":     "paginationClick"
        },

        ready: function() {
            this.listenTo(this.model, 'change:viewer', this.changeView);
            this.listenTo(this.model, 'change:book',   this.render);
//          this.listenTo(this.model, 'change:showHeader', this.resizeViewport);
            this.listenTo(this.model, 'change:showHeaderDone', this.resizeViewport);
            this.listenTo(this.model, 'change:showSidebar',  this.resizeViewport);
            this.listenTo(this.model, 'change:defaultZoom',  this.zoomToggle);
            this.listenTo(this.model, 'change:selectedPage', this.changePage);
            this.render();
            this.changeView();
            this.changePage();
        },

        render: function() {
            this.collection = this.model.get('book');
            this.$('#twoPage_viewer').remove();
            this.viewerArea = $('<div id="twoPage_viewer"></div>').hide();
            // View switch button.
            this.$('.page-container').prepend(this.viewerArea);
            // The viewer itself.
            this.viewport =
                $('<div class="magazine-viewport"><div class="container"></div></div>');
            this.magazine =
                $('<div class="magazine"></div>');
            this.nextButton =
                $('<div ignore="1" class="next-button"></div>')
                    .appendTo(this.magazine);
            this.prevButton =
                $('<div ignore="1" class="previous-button"></div>')
                    .appendTo(this.magazine);
            this.viewport.find('.container').append(this.magazine);
            this.viewerArea.append(this.viewport);

            // Start the Page turner.
            var selectedImageNumber = this.model.selectedImageNumber();
            this.magazine.turn({
                page:   (selectedImageNumber===-1) ? 1 : selectedImageNumber+1,
                width:  1382,
                height: 900,
                // Elevation will move the peeling corner this number of pixels
                // by default.
                elevation: 50,
                // Hardware acceleration.
                acceleration: !(navigator.userAgent.toLowerCase().indexOf('chrome') > -1), //isChrome(),
                // Enable gradients.
                gradients: true,
                // Auto center this flipbook.
                autoCenter: true,
                // The number of pages.
                pages: this.collection.length //getProperBookLength()
            });

            // Start the Zoom.js module.
            this.viewport.zoom({
                flipbook: this.magazine,
                max: _.bind(function() {
                        return this.largeWidth() / this.magazine.width();
                    },this)
            });

            // ESC key to get out of zoom.
            $(document).keydown(_.bind(function(e) {
                if (e.keyCode === CHAR.Escape) {
                    this.viewport.zoom('zoomOut');
                    e.preventDefault();
                }
            }, this));

            this.resizeViewport();
            this.magazine.addClass('animated');

            // Make image thumbnails "clickable" by pressing carriage return.
            nodeHandleKeypressAsClick('.page-thumb img');

            // Make "Previous" and "Next" respond to carriage return.
            nodeHandleKeypressAsClick('.page-turner-prev, .page-turner-next');

            return this;
        },

        changePage: function() {
            this.magazine.turn('page', this.model.selectedImageNumber()+1);
        },

        changeView: function() {
            if (this.model.get('viewer') === "openLayer") {
                this.viewerArea.hide();
            } else {
                this.viewerArea.show();
                this.resizeViewport();
            }
        },

        resizeViewport: function() {
            var width   = this.viewerArea.width(), //$(window).width(),
                height  = this.viewerArea.height(), //$(window).height(),
                options = this.magazine.turn('options');
            this.magazine.removeClass('animated');
            this.viewport.css({
                width:  width,
                height: height
            }).zoom('resize');
            if (this.magazine.turn('zoom') === 1) {
                var bound = this.calculateBound({
                    width:       options.width,
                    height:      options.height,
                    boundWidth:  Math.min(options.width,  width),
                    boundHeight: Math.min(options.height, height)
                });
                if (bound.width % 2 !== 0) {
                    bound.width -= 1;
                }
                if (bound.width !== this.magazine.width() || bound.height !== this.magazine.height()) {
                    this.magazine.turn('size', bound.width, bound.height);
                    if (this.magazine.turn('page') === 1) {
                        this.magazine.turn('peel', 'br');
                    }
                    this.$('.next-button').css({
                        height: bound.height,
                        backgroundPosition: '5px '+(bound.height/2-32/2)+'px'
                    });
                    this.$('.previous-button').css({
                        height: bound.height,
                        backgroundPosition: '5px '+(bound.height/2-32/2)+'px'
                    });
                }
                this.magazine.css({
                    top:  -bound.height / 2,
                    left: -bound.width / 2
                });
            }

            var magazineOffset = this.magazine.offset(),
                boundH = height - magazineOffset.top - this.magazine.height(),
                marginTop = boundH / 2;
            if (magazineOffset.top < $('.made').height()) {
                this.$('.made').hide();
            } else {
                this.$('.made').show();
            }

            this.magazine.addClass('animated');
        },

        missingPage: function(event, pages) {
            // Add pages that aren't in the magazine.
            for (var i = 0; i < pages.length; i++) {
                this.addPage(
                    pages[i],
                    $(event.target),
                    this.collection.at(pages[i] - 1).id
                );   //getIdAtIndex(pages[i]-1) );
            }
        },

        loadLargePage: function(page, pageElement, pid) {
            var src =
                'http://xxx.virginia.edu/xxx/' +
                pid + '/methods/djatoka:jp2SDef/getRegion?level=4';
            $('<img>')
                .load(function() {
                    var $previous_img = pageElement.find('img');
                    $(this)
                        .css({ width: '100%', height: '100%' })
                        .appendTo(pageElement);
                    $previous_img.remove();
                })
                .attr('src', src); // Load new page
        },

        loadSmallPage: function(page, pageElement, pid) {
            var src =
                'http://xxx.virginia.edu/xxx/' +
                pid + '/methods/djatoka:jp2SDef/getRegion?level=3';
            pageElement.find('img')
                .css({ width: '100%', height: '100%' })
                .unbind('load')
                .attr('src', src) // Load new page
        },

        zoomToggle: function() {
            if (this.viewport.zoom('value') === 1) {
                this.magazine
                    .removeClass('animated')
                    .addClass('zoom-in');
                this.viewport.zoom('zoomIn');
            } else {
                this.viewport.zoom('zoomOut');
            }
        },

        zoomPage: function(event) {
            if (this.viewport.zoom('value') === 1) {
                this.magazine
                    .removeClass('animated')
                    .addClass('zoom-in');
                if (event) {
                    this.viewport.zoom('zoomIn', event);
                } else {
                    this.viewport.zoom('zoomIn');
                }
            } else {
                this.viewport.zoom('zoomOut');
            }
        },

        zoomResize: function(event, scale, page, pageElement) {
            var pid = this.collection.at(page-1).id;
            if (scale === 1) {
                this.loadSmallPage(page, pageElement, pid);
            } else {
                this.loadLargePage(page, pageElement, pid);
            }
        },

        postZoomOut: function() {
            setTimeout(_.bind(function() {
                this.magazine.addClass('animated').removeClass('zoom-in');
//                this.resizeViewport();
            }, this), 0);
        },

        nextPage: function() { model.selectNextPage(); },
        prevPage: function() { model.selectPrevPage(); },

        turningPage: function(event, page, view) {
            var book = $(this),
            currentPage = book.turn('page'),
            pages = book.turn('pages');
            // Show and hide navigation buttons.
            this.disableControls(page);
        },

        turnedPage: function(event, page, view) {
            this.disableControls(page);
            $(event.target).turn('center');
            if (page === 1) {
                $(event.target).turn('peel', 'br');
            }
            this.model.selectPage(this.collection.at(page-1).id); //getIdAtProperIndex(page) );
        },

        paginationHover: function(event) {
            $(event.target).toggleClass('button-hover');
        },

        paginationDownUp: function(event) {
            $(event.target).toggleClass('button-down');
        },

        paginationClick: function(event) {
            var button = $(event.target);
            if (button.hasClass('next-button')) {
                this.model.selectNextPage();
            } else {
                this.model.selectPrevPage();
            }
        },

        addPage: function(page, book, pid) {
            var id,
                pages = book.turn('pages');

            // Create a new element for this page.
            var element = $('<div>');

            // Add the page to the flipbook
            if (book.turn('addPage', element, page)) {
                // Add the initial HTML.
                // It will contain a loader indicator and a gradient.
                var hard = ''; //= (page == 1 || book.pages == page) ' hard':''
                $('<div>').addClass('gradient' + hard).appendTo(element);
                $('<div>').addClass('loader').appendTo(element);
                // Load the page.
                this.loadPage(page, element, pid);
            }
        },

        loadPage: function(page, pageElement, pid) {
            if (pid) {
                this.$('#all').fadeIn(1000);
                // Create an image element.
                var src =
                    'http://xxx.virginia.edu/xxx/' +
                    pid + '/methods/djatoka:jp2SDef/getRegion?level=2';
                $('<img>')
                    .mousedown(function(e) {
                        e.preventDefault();
                    })
                    .load(function() {
                        // Add the image to the page after loaded.
                        $(this)
                            .css({width: '100%', height: '100%'})
                            .appendTo(pageElement);
                        // Remove the loader indicator.
                        pageElement.find('.loader').remove();
                    })
                    .attr('src', src); // Load the page
            }
        },

        disableControls: function(page) {
            if (page === 1) {
                this.$('.previous-button').hide();
            } else {
                this.$('.previous-button').show();
            }

            if (page === $('.magazine').turn('pages')) {
                this.$('.next-button').hide();
            } else {
                this.$('.next-button').show();
            }
        },

        largeWidth: function() { return 2214; },

        // Calculate the width and height of a square within another square.
        calculateBound: function(d) {
            var bound = { width: d.width, height: d.height };
            if (bound.width > d.boundWidth || bound.height > d.boundHeight) {
                var rel = bound.width / bound.height;
                if (d.boundWidth/rel > d.boundHeight && d.boundHeight*rel <= d.boundWidth) {
                    bound.width  = Math.round(d.boundHeight*rel);
                    bound.height = d.boundHeight;
                } else {
                    bound.width  = d.boundWidth;
                    bound.height = Math.round(d.boundWidth/rel);
                }
            }
            return bound;
        }
    });

    app.PageThumbViewer = Backbone.View.extend({
        model: app.state,

        initialize: function() {
            this.listenTo(this.model, 'change:selectedPage', this.changePage);
            this.scrollTimer;
            this.thumbs = this.$(".page-thumbs");
            this.thumbsList = this.thumbs.find(".page-thumbs-list");
            this.thumbsListItems = this.thumbsList.find("li.page-thumb");
            this.showViewableThumbs();
            this.thumbsList.scroll(_.bind(function() {
                if (this.scrollTimer) {
                    clearTimeout(this.scrollTimer);
                    this.scrollTimer = null
                }
                this.scrollTimer = setTimeout(_.bind(function() {
                    this.showViewableThumbs();
                }, this), 500);
            }, this));
            this.listenTo(this.model, 'change:book', this.bookChange);
        },

        showViewableThumbs: function() {
            var listHeight = this.thumbs.height();
            this.thumbsListItems.each(_.bind(function(index) {
                var el = this.thumbsListItems.eq(index);
                if (el.find(".jp2k-preview .page-default").length > 0) {
                    var pos = el.position();
                    if (pos.top > -700 && pos.top < listHeight+700) {
                        this.loadThumb(el);
                    }
                }
            }, this));
        },

        events: {
            "click .page-thumb":  "selectPage",
            "click .hide-thumbs": "hideThumbs"
        },

        selectPage: function(event) {
            this.model.selectPage(
                $(event.target).closest('.page-thumb').attr('id')
            );
        },

        bookChange: function() {
            this.collection = this.model.get('book');
            var $new = $();
            this.collection.each(_.bind(function(item) {
                $new = $new.add($('.page-thumb[id="'+item.id+'"]')
                                     .detach()
                                     .show());
            }, this));
            var list = this.$('.page-thumb').hide().detach();
            $('.page-thumbs-list').append($new).append(list);
            this.changePage();
        },

        changePage: function() {
            var pid = this.model.get('selectedPage');
            var selectedThumb =
                this.$(".page-thumb")
                    .removeClass("thumb-select")
                    .filter("[id='"+pid+"']")
                    .addClass("thumb-select");
            this.$(".page-thumbs-list")
                .scrollTop(
                    $(".page-thumbs-list").scrollTop() +
                    selectedThumb.position().top - 200
                );
            this.$(".thumbs-current-num")
                .html(this.model.selectedImageNumber()+1);
        },

        hideThumbs: function(event) {
            this.$(".page-thumbs").slideToggle("fast", _.bind(function() {
                $("#container").toggleClass("thumbs-closed");
                if ($("#container.thumbs-closed").length) {
                    $(event.target).html('Show').attr('aria-expanded', false);
                    _.delay(_.bind(function() {
                        this.model.set({showSidebar:true})
                    }, this), 500);
                } else {
                    $(event.target).html('Hide').attr('aria-expanded', true);
                    _.delay(_.bind(function() {
                        this.model.set({showSidebar:false})
                    }, this), 500);
                }
                $(window).resize();
            }, this));
            return false;
        },

        loadThumb: function(el) {
            var pid = el.attr('id');
            var url = PageTurner.repo +
                '/get/' + pid + '/djatoka:jp2SDef/getRegion?scale=125';
            var caption   = el.children('.page-title').text();
            var new_image = $('<img>').attr({ alt: caption, src: url });
            new_image.attr('tabindex', 0);
            el.find('.jp2k-preview img').replaceWith(new_image);
        }
    });

    app.Router = Backbone.Router.extend({

        initialize: function() {
            app.book.fetch();
            this.listenTo(app.state, 'change', this.updatePageURL);
        },

        routes: {
            "twoPage/:page/:header/:sidebar": "twoPagePermalink",
            "openLayer/:page/:lat/:lon/:zoom/:header/:sidebar": "openLayerPermalink",
            "*path": "defaultRoute"
        },

        twoPagePermalink: function(page, header, sidebar) {
            app.state.selectPage(page);
            app.state.set({
                viewer:      "twoPage",
                showHeader:  !!header,
                showSidebar: !!sidebar
            });
        },

        openLayerPermalink: function(page, lat, lon, zoom, header, sidebar) {
            app.state.selectPage(page);
            app.state.setOpenLayerState(
                parseInt(zoom),
                { lat: parseInt(lat), lon: parseInt(lon) }
            );
            app.state.set({
                viewer:      "openLayer",
                showHeader:  !!header,
                showSidebar: !!sidebar
            });
        },

        defaultRoute: function() {
            app.params = this.decodeParams();
            if (app.params.page) {
                window.location =
                    window.location.href.split('?')[0] +
                    "#openLayer/" + app.params.page + "/" + app.params.y +
                    "/" + app.params.x + "/" + app.params.z + "/1/1";
            } else {
                app.state.selectPage(PageTurner.pid);
                app.state.set({ viewer: "openLayer" });
            }
        },

        updatePageURL: function() {
            var center      = app.state.get('center');
            var historic    = !app.state.changedAttributes().selectedPage;
            var showHeader  = app.state.get('showHeader')  ? 1 : 0;
            var showSidebar = app.state.get('showSidebar') ? 1 : 0;
            if (app.state.get('viewer') === 'openLayer') {
                this.navigate(
                    "openLayer/" + app.state.get('selectedPage') + "/" +
                    center.lat + "/" + center.lon + "/" +
                    app.state.get('zoom') + "/" + showHeader + "/" +
                    showSidebar,
                    { trigger: false, replace: historic }
                );
            } else {
                this.navigate(
                    "twoPage/" + app.state.get('selectedPage') + "/" +
                    showHeader + "/" + showSidebar,
                    { trigger: false, replace: historic }
                );
            }
        },

        // Decode URL parameters.
        decodeParams: function() {
            var data  = window.location.search.replace( "?", "" );
            var parts = data.split('&'), d, obj = {};
            for (var i = 0; i < parts.length; i++) {
                d = parts[i].split('=');
                obj[decodeURIComponent(d[0])] = decodeURIComponent(d[1]);
            }
            return obj;
        }
    });

    var container = document.getElementById("container");

    app.doublePageViewer    = new app.DoublePageViewer({ el: container });
    app.openLayerPageViewer = new app.OpenLayerPageViewer({ el: container });
    app.pageThumbViewer     = new app.PageThumbViewer({ el: container });
    app.pageHeaderView      = new app.PageHeaderView({ el: container });
    app.router              = new app.Router();

    Backbone.history.start({ pushState: false });

});
