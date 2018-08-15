# config/routes.rb
#--
# rubocop:disable Metrics/LineLength
#++

Rails.application.routes.draw do

  # ===========================================================================
  # CatalogController
  #
  # @see Blacklight::Routes::RouteSets#catalog
  #
  # NOTE: Certain definitions have to come before Blacklight#add_routes and
  # `resources` so that they are not overridden by the :show route:
  #
  # 'catalog/home'        Catalog "portal" page.
  # 'catalog/index'       Catalog "null-search" results.
  # 'catalog/advanced'    Catalog advanced search.
  # ===========================================================================

  get 'catalog/home',     to: redirect('/catalog?q=*')
  get 'catalog/index',    to: redirect('/catalog?q=*'), as: 'catalog_all'
  get 'catalog/advanced', to: 'catalog#advanced'

  get 'catalog/ris',      to: 'catalog#ris',      as: 'ris_catalog',     defaults: { format: 'ris' }
  get 'catalog/endnote',  to: 'catalog#endnote',  as: 'endnote_catalog', defaults: { format: 'endnote' }
  get 'catalog/refworks', to: 'catalog#refworks', as: 'refworks_catalog'

  # Development-only direct Solr request page.
  unless Virgo.deployed_production?
    get 'catalog/direct', to: 'catalog#direct'
  end

  # Standard Blacklight routes (bookmarks, folders, search_history,
  # saved_searches, catalog and feedback) although only catalog is used here.
  Blacklight.add_routes(self, only: [:catalog])

  # Definition of the main page for the site has to follow the creation of the
  # index route above -- otherwise
  #   `url_for(controller: 'catalog', action: 'index', q: 'xxx')`
  # returns "/?q=xxx" instead of "/catalog?q=xxx".
  root to: 'catalog#index', as: 'root'

  resources :catalog, only: [] do
    member do
      get   :availability
      get   :brief_availability
      get   :children,           to: :hierarchy_children
      get   :firehose,           defaults: { format: 'xml' }
      get   :image
      get   :image_load
      get   :page_turner
      get   :tei
      get   :view,               to: :page_turner
    end
  end

  get 'catalog/:id/iiif/manifest.json',   to: 'catalog#iiif',            as: 'iiif_manifest'
  get 'fedora_metadata/:id/:pid.:format', to: 'catalog#fedora_metadata', as: 'fedora_metadata'

  # Hints for RubyMine (skipped during execution).
  unless ONLY_FOR_DOCUMENTATION
    get 'catalog/index', as: 'catalog_index'
    get 'catalog/show',  as: 'catalog'

    # Defined in Blacklight::Routes::RouteSets#catalog
    get 'catalog/citation',          as: 'citation_catalog'
    get 'catalog/email',             as: 'email_catalog'
    get 'catalog/sms',               as: 'sms_catalog'
    get 'catalog/endnote',           as: 'endnote_catalog'
    get 'catalog/send_email_record', as: 'send_email_record_catalog'
    get 'catalog/facet/:id',         as: 'catalog_facet', to: 'catalog#facet'
  end

  # ===========================================================================
  # FolderController - Starred Items
  #
  # @see Blacklight::Routes::RouteSets#folders
  #
  # NOTE: The :destroy, :article_destroy, :clear routes should be via :delete
  # only but this would require some degree of changes to the JavaScript in
  # order to support this.
  # ===========================================================================

  resources :folder, as: 'folders', only: [:index, :create, :update] do
    collection do
      get :citation
      get :csv,             defaults: { format: 'csv' }
      get :email
      get :endnote
      get :print
      get :refworks_texts
      get :ris,             defaults: { format: 'ris' }
      get :list,            defaults: { format: 'json' }
    end
  end

  match 'folder/clear',   as: 'clear_folders',   to: 'folder#clear',   via: [:get, :post]
  get   'folder/destroy', as: 'destroy_folders', to: 'folder#destroy'

  # Hints for RubyMine (skipped during execution).
  unless ONLY_FOR_DOCUMENTATION
    get  'folder/index', as: 'folders_index'
  end

  # ===========================================================================
  # FeedbackController
  #
  # @see Blacklight::Routes::RouteSets#feedback
  # ===========================================================================

  match 'feedback',          to: 'feedback#show',     via: [:get, :post]
  get   'feedback/complete', to: 'feedback#complete'

  # ===========================================================================
  # ReservesController - Course Reserves
  #
  # NOTE: `get 'reserves/send_email_record'` is needed to support redirection
  # back to the email form if the user unstars an item to remove it from the
  # list of items to place on course reserve.
  # ===========================================================================

  resources :reserves, only: [:index]

  get  'reserves/email',             to: 'reserves#email'
  post 'reserves/send_email_record', to: 'reserves#send_email_record'
  get  'reserves/send_email_record', to: 'reserves#email'
  get  'reserves/course/:id',        to: 'reserves#course', as: 'reserves_course'

  # Hints for RubyMine (skipped during execution).
  unless ONLY_FOR_DOCUMENTATION
    get 'reserves/index', as: 'reserves_index'
  end

  # ===========================================================================
  # UserSessionsController
  # ===========================================================================

  resource :user_sessions, only: []

  get  'login',           to: 'user_sessions#new',             as: 'login'
  get  'logout',          to: 'user_sessions#destroy',         as: 'logout'
  get  'logged_out',      to: 'user_sessions#logged_out',      as: 'logged_out'
  get  'patron_login',    to: 'user_sessions#patron_login',    as: 'patron_login'
  post 'do_patron_login', to: 'user_sessions#do_patron_login', as: 'do_patron_login'

  # ===========================================================================
  # MusicController - Music lens
  #
  # NOTE: Certain definitions have to come before `resources` so that they are
  # not overridden by the :show route.
  #
  # 'music/home'        Music lens "portal" page.
  # 'music/index'       Music lens "null-search" results.
  # 'music/advanced'    Music lens advanced search.
  # ===========================================================================

  get 'music/home',      to: redirect('/music')
  get 'music/index',     to: redirect('/music?q=*'), as: 'music_all'
  get 'music/advanced',  to: 'music#advanced'

  resources :music, only: [:index, :show, :update]

  get 'music/facet/:id', to: 'music#facet',          as: 'music_facet'

  # Hints for RubyMine (skipped during execution).
  unless ONLY_FOR_DOCUMENTATION
    get 'music/index', as: 'music_index'
    get 'music/show',  as: 'music'
  end

  # Finally, any other route are handled by the underlying CatalogController.
  # E.g.: '/music/XXX/children.json' => '/catalog/XXX/children.json'
  get 'music/:id/:other' => redirect('/catalog/%{id}/%{other}')
  get 'music/:other'     => redirect('/catalog/%{other}')

  # ===========================================================================
  # VideoController - Video lens
  #
  # NOTE: Certain definitions have to come before `resources` so that they are
  # not overridden by the :show route.
  #
  # 'video/home'        Video lens "portal" page.
  # 'video/index'       Video lens "null-search" results.
  # 'video/advanced'    Video lens advanced search.
  # ===========================================================================

  get 'video/home',      to: redirect('/video')
  get 'video/index',     to: redirect('/video?q=*'), as: 'video_all'
  get 'video/advanced',  to: 'video#advanced'

  resources :video, only: [:index, :show, :update]

  get 'video/facet/:id', to: 'video#facet',          as: 'video_facet'

  # Hints for RubyMine (skipped during execution).
  unless ONLY_FOR_DOCUMENTATION
    get 'video/index', as: 'video_index'
    get 'video/show',  as: 'video'
  end

  # Finally, any other route are handled by the underlying CatalogController.
  # E.g.: '/video/XXX/children.json' => '/catalog/XXX/children.json'
  get 'video/:id/:other' => redirect('/catalog/%{id}/%{other}')
  get 'video/:other'     => redirect('/catalog/%{other}')

  # ===========================================================================
  # ClassicController - "Virgo Classic" lens
  #
  # NOTE: Certain definitions have to come before `resources` so that they are
  # not overridden by the :show route.
  #
  # 'classic/home'        "Virgo Classic" "portal" page.
  # 'classic/index'       "Virgo Classic" "null-search" results.
  # 'classic/advanced'    "Virgo Classic" advanced search. [1]
  # 'classic/browse'      "Virgo Classic" "browse-by" results.
  #
  # [1] Future development; goes to 'catalog/advanced' for now.
  # ===========================================================================

  if UVA::Classic.feature_enabled?

    get 'classic/home',     to: 'classic#home'
    get 'classic/index',    to: redirect('/classic?q=*'), as: 'classic_all'
    get 'classic/advanced', to: 'catalog#advanced'
    get 'classic/browse',   to: 'classic#browse'

    resources :classic, only: [:index, :show]

    # Hints for RubyMine (skipped during execution).
    unless ONLY_FOR_DOCUMENTATION
      get 'classic/index', as: 'classic_index'
      get 'classic/show',  as: 'classic'
    end

  end

  # ===========================================================================
  # AccountController
  # ===========================================================================

  resources :account, as: 'accounts', only: [:index] do
    collection do
      get :checkouts
      get :holds
      get :not_found
      get :notices
      get :renew
      get :reserves
      get :review
      get :select
    end
  end

  # Hints for RubyMine (skipped during execution).
  unless ONLY_FOR_DOCUMENTATION
    get 'accounts/index', as: 'accounts_index'
  end

  # ===========================================================================
  # MapsController
  # ===========================================================================

  resources :maps

  # Hints for RubyMine (skipped during execution).
  unless ONLY_FOR_DOCUMENTATION
    get 'maps/index', as: 'maps_index'
  end

  # ===========================================================================
  # MapsUsersController
  # ===========================================================================

  resources :maps_users

  # Hints for RubyMine (skipped during execution).
  unless ONLY_FOR_DOCUMENTATION
    get 'maps_users/index', as: 'maps_users_index'
  end

  # ===========================================================================
  # CallNumberRangesController
  # ===========================================================================

  resources :call_number_ranges

  # Hints for RubyMine (skipped during execution).
  unless ONLY_FOR_DOCUMENTATION
    get 'call_number_ranges/index', as: 'call_number_ranges_index'
  end

  # ===========================================================================
  # SpecialCollectionsRequestsController
  # ===========================================================================

  resources :special_collections_requests, except: [:new] do
    member do
      get :non_uva
      get :show
      get :start
    end
  end

  get 'special_collections_requests/:id/new', to: 'special_collections_requests#new', as: 'new_special_collections_request'

  # Hints for RubyMine (skipped during execution).
  unless ONLY_FOR_DOCUMENTATION
    get 'special_collections_requests/index', as: 'special_collections_requests_index'
  end

  # ===========================================================================
  # ArticlesController - Article lens
  #
  # NOTE: Certain definitions have to come before `resources` so that they are
  # not overridden by the :show route.
  #
  # 'articles/home'        Article "portal" page.
  # 'articles/index'       Article "null-search" results.
  # 'articles/advanced'    Article advanced search.
  # ===========================================================================

  get 'articles/home',     to: redirect('/articles?q=*')
  get 'articles/index',    to: redirect('/articles?q=*'), as: 'articles_all'
  get 'articles/advanced', to: 'articles#advanced'

  get 'articles/ris',      to: 'articles#ris',      as: 'ris_articles',     defaults: { format: 'ris' }
  get 'articles/endnote',  to: 'articles#endnote',  as: 'endnote_articles', defaults: { format: 'endnote' }
  get 'articles/refworks', to: 'articles#refworks', as: 'refworks_articles'

  # Development-only direct EBSCO request page.
  unless Virgo.deployed_production?
    get 'articles/direct', to: 'articles#direct'
  end

  resources :articles, only: [:index] do
    collection do
      get :facet
    end
  end

  get 'articles/article',   to: 'articles#show'
  put 'articles/article',   to: 'articles#update'
  get 'articles/full_text', to: 'articles#full_text'
  get 'articles/citation',  to: 'articles#citation'
  get 'articles/endnote',   to: 'articles#endnote'
  get 'articles/ris',       to: 'articles#ris'

  # The following route is used to support testing different article search
  # providers and is not normally honored in production.
  post 'articles/change_engine', to: 'articles#change_engine'

  # Hints for RubyMine (skipped during execution).
  unless ONLY_FOR_DOCUMENTATION
    get 'articles/index', as: 'articles'
  end

  # ===========================================================================
  # AccountRequestsController
  # ===========================================================================

  resources :account_requests, only: [] do
    member do
      get  :start_hold
      post :create_hold
    end
  end

  get   'account_requests/:id/renew/:checkout_key', as: 'renew',        to: 'account_requests#renew'
  get   'account_requests/renew_all',               as: 'renew_all',    to: 'account_requests#renew_all'
  post  'account_requests/ill_main',                as: 'ill_main',     to: 'account_requests#ill_main'
  match 'account_requests/ill_requests',            as: 'ill_requests', to: 'account_requests#ill_requests', via: [:get, :post]
  get   'account_requests/ill_reset',               as: 'ill_reset',    to: 'account_requests#ill_reset'
  match 'account_requests/:id/ill_leo',             as: 'ill_leo',      to: 'account_requests#ill_leo',      via: [:get, :post]
  match 'account_requests/:id/ill_ivy',             as: 'ill_ivy',      to: 'account_requests#ill_ivy',      via: [:get, :post]

  # ===========================================================================
  # AboutController
  # ===========================================================================

  resources :about, only: [:index]

  get 'about/list/:topic', to: 'about#list', as: 'about_list'
  get 'about/:topic',      to: 'about#list'

  # Hints for RubyMine (skipped during execution).
  unless ONLY_FOR_DOCUMENTATION
    get 'about/index', as: 'about_index'
  end

  # ===========================================================================
  # PdaController
  # ===========================================================================

  resources :pda, only: [] do
    member do
      get  :confirm
      post :purchase
    end
  end

  # ===========================================================================
  # ShelfBrowseController
  # ===========================================================================

  if UVA::ShelfBrowse.feature_enabled?

    resources :shelf_browse, as: 'shelf_browse', only: [:index, :show] do
      collection do
        get :hierarchy, defaults: { format: 'json' }
      end
    end

    # Hints for RubyMine (skipped during execution).
    unless ONLY_FOR_DOCUMENTATION
      get 'shelf_browse/index', as: 'shelf_browse_index'
    end

  end

  # ===========================================================================
  # Blacklight Advanced Search
  #
  # NOTE: This exists for compatibility reasons.
  # /catalog/advanced is the preferred route for basic advanced search.
  # ===========================================================================

  match 'advanced', as: 'advanced', to: 'catalog#advanced'

  # ===========================================================================
  # Specialty routes for collection-level records notable digital collections.
  # ===========================================================================

  get '/daily_progress'   => redirect('/catalog/uva-lib:2137307')
  get '/wsls'             => redirect('/catalog/uva-lib:2214294')
  get '/corks_and_curls'  => redirect('/catalog/u126747')
  get '/yellow_fever'     => redirect('/catalog/uva-lib:2513789')

end
