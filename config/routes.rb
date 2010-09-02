ActionController::Routing::Routes.draw do |map|

  # Web Application

  map.resources :harvest_events, :has_many => [:taxa]
  map.resources :resources, :as => 'content_partner/resources', :has_many => [:harvest_events]
  map.force_harvest_resource 'content_partner/resources/force_harvest/:id', :method => :post,
      :controller => 'resources', :action => 'force_harvest'

  map.resources :comments, :member => { :make_visible => :put, :remove => :put }
	map.resources :random_images
	map.resources :data_objects, :member => { :curate => :put, :curation => :get, :attribution => :get } do |data_objects|
    data_objects.resources :comments
    data_objects.resources :tags,  :collection => { :public => :get, :private => :get, :add_category => :post,
                                                    :autocomplete_for_tag_key => :get }, 
                                   :member => { :autocomplete_for_tag_value => :get }
  end
  map.resources :tags, :collection => { :search => :get }

  map.settings     'settings',     :controller => 'taxa',:action=>'settings'

  map.connect 'boom', :controller => 'content', :action => 'error' 

  map.reset_specific_users_password 'account/reset_specific_users_password',
                                    :controller => 'account',
                                    :action => 'reset_specific_users_password'

  # I don't like this.  Why don't we just use restful routes here?
  map.with_options(:controller => 'account') do |account|
    account.login     'login',     :action => 'login'
    account.logout    'logout',    :action => 'logout'
    account.register  'register',  :action => 'signup'
    account.profile   'profile',   :action => 'profile'
    account.user_info 'user_info', :action => 'info'
  end

  # TODO - we would like to make this all restfull.  Is that even possible, with images/videos vs data_objects?
  map.resources :taxon
  map.taxon 'taxa/:id',  :controller => 'taxa', :action => 'taxa', :requirements => { :id => /\d+/ }
  map.taxon 'pages/:id', :controller => 'taxa', :action => 'show'

  map.connect 'pages/:id',
              :controller => 'taxa', :action => 'show' 
  map.connect 'pages/:id.:format',
              :controller => 'taxa', :action => 'show' 
  map.classification_attribution 'pages/:id/classification_attribution',
              :controller => 'taxa', :action => 'classification_attribution' 
  map.connect 'pages/:taxon_concept_id/images/:page.:format',
              :controller => 'data_objects', :action => 'index',
              :requirements => { :taxon_concept_id => /\d+/, :page => /\d+/ }
  map.connect 'pages/:taxon_concept_id/videos/:page.:format',
              :controller => 'data_objects', :action => 'index',
              :requirements => { :taxon_concept_id => /\d+/, :page => /\d+/ }
  map.connect 'pages/:id/best_images.:format', :controller => 'content', :action => 'best_images'
  map.connect '/pages/:taxon_concept_id/update_common_names', :controller => 'taxa', :action => 'update_common_names'
  map.connect '/pages/:taxon_concept_id/add_common_name', :controller => 'taxa', :action => 'add_common_name'
  map.connect '/pages/:taxon_concept_id/delete_common_name', :controller => 'taxa', :action => 'delete_common_name'
  map.connect '/pages/:taxon_concept_id/publish_wikipedia_article', :controller => 'taxa', :action => 'publish_wikipedia_article'
  
  map.set_language      'set_language',      :controller => 'application', :action => 'set_language'

  map.contact_us    'contact_us',    :controller => 'content', :action => 'contact_us'
  map.media_contact 'media_contact', :controller => 'content', :action => 'media_contact'

  map.help         'help',         :controller => 'content', :action => 'page', :id => 'screencasts'
  map.screencasts  'screencasts',  :controller => 'content', :action => 'page', :id => 'screencasts'
  map.faq          'faq',          :controller => 'content', :action => 'page', :id => 'faqs'
  map.terms_of_use 'terms_of_use', :controller => 'content', :action => 'page', :id => 'terms_of_use'
  map.donate       'donate',       :controller => 'content', :action => 'donate'

  map.clear_caches 'clear_caches',      :controller => 'content', :action => 'clear_caches'
  map.expire_all   'expire_all',        :controller => 'content', :action => 'expire_all'
  map.expire       'expire/:id',        :controller => 'content', :action => 'expire_single',
                                        :requirements => { :id => /\w+/ }
  map.expire_taxon 'expire_taxon/:id',  :controller => 'content', :action => 'expire',
                                        :requirements => { :id => /\d+/ }
  map.expire_taxa  'expire_taxa',       :controller => 'content', :action => 'expire_multiple'
  map.exemplars    'exemplars.:format', :controller => 'content', :action => 'exemplars'

  map.external_link 'external_link', :controller => 'application', :action => 'external_link'

  map.search  'search',         :controller => 'taxa', :action => 'search'
  map.connect 'search/:id',     :controller => 'taxa', :action => 'search'
  map.connect 'search.:format', :controller => 'taxa', :action => 'search'
  map.found   'found/:id',      :controller => 'taxa', :action => 'found'
  
  map.connect 'content_partner/reports', :controller => 'content_partner/reports', :action => 'index' 
  map.connect 'content_partner/reports/login', :controller => 'content_partner', :action => 'login'
  map.connect 'content_partner/reports/:action', :controller => 'content_partner/reports'
  map.connect 'content_partner/content/:id', :controller => 'content_partner', :action => 'content', :requirements => { :id => /.*/}
  map.connect 'content_partner/stats/:id', :controller => 'content_partner', :action => 'stats', :requirements => { :id => /.*/}
  
  # map.connect 'content_partner/reports',         :controller => 'content_partner/reports', :action => 'index' 
  # map.connect 'content_partner/reports/:report', :controller => 'content_partner/reports', :action => 'catch_all',
  #                                                :requirements => { :report => /.*/ }
  map.connect 'administrator/reports',         :controller => 'administrator/reports', :action => 'index' 
  map.connect 'monthly_stats_email',         :controller => 'administrator/content_partner_report', :action => 'monthly_stats_email' 
  map.connect 'administrator/reports/:action', :controller => 'administrator/reports'
  
  map.request_publish_hierarchy 'content_partner/resources/request_publish/:id', :method => :post,
      :controller => 'content_partner', :action => 'request_publish_hierarchy'
  
  #map.connect 'administrator/user_data_object',    :controller => 'administrator/user_data_object', :action => 'index'

  
  # map.connect 'administrator/reports/:report', :controller => 'administrator/reports', :action => 'catch_all',
  #                                              :requirements => { :report => /.*/ }

  map.connect 'administrator/curator', :controller => 'administrator/curator', :action => 'index' 

  map.resources :public_tags, :controller => 'administrator/tag_suggestion'
  map.resources :search_logs, :controller => 'administrator/search_logs'

  map.connect '/taxon_concepts/:taxon_concept_id/comments/', :controller => 'comments', :action => 'index',
                                                             :conditions => {:method => :get}
  map.connect '/taxon_concepts/:taxon_concept_id/comments/', :controller => 'comments', :action => 'create',
                                                             :conditions => {:method => :post}
                                                             
  map.admin 'admin',           :controller => 'admin',           :action => 'index'
  map.content_partner 'content_partner', :controller => 'content_partner', :action => 'index'
  map.podcast 'podcast', :controller=>'content', :action=>'page', :id=>'podcast'
  
  # by default /api goes to the docs
  map.connect 'api', :controller => 'api/docs', :action => 'index'
  # not sure why this didn't work in some places - but this is for documentation
  map.connect 'api/docs/:action', :controller => 'api/docs'
  # ping is a bit of an exception - it doesn't get versioned and takes no ID
  map.connect 'api/ping', :controller => 'api', :action => 'ping'
  map.connect 'api/ping.:format', :controller => 'api', :action => 'ping'
  # if version is left out we'll default to the older 0.4
  map.connect 'api/:action/:id', :controller => 'api', :version => '0.4'
  map.connect 'api/:action/:id.:format', :controller => 'api', :version => '0.4'
  # looks for version, ID and format
  map.connect 'api/:action/:version/:id', :controller => 'api', :version => /[0-1]\.[0-9]/
  map.connect 'api/:action/:version/:id.:format', :controller => 'api', :version => /[0-1]\.[0-9]/
  
  map.connect 'curators', :controller => 'curators'
  
  ##### ALL ROUTES BELOW SHOULD PROBABLY ALWAYS BE AT THE BOTTOM SO THEY ARE RUN LAST ####
  # this represents a URL with just a random namestring -- send to search page (e.g. www.eol.org/animalia)
  # ...with the exception of "index", which historically pointed to home:
  map.connect '/index', :controller => 'content', :action => 'index'
  map.connect ':id', :id => /\d+/,  :controller => 'taxa', :action => 'show' # only a number passed in to the root of the web, then assume a specific taxon concept ID  
  map.connect ':id', :id => /[A-Za-z0-9% ]+/,  :controller => 'taxa', :action => 'search'  # if text, then go to the search page

  # Install the default routes as the lowest priority.
  map.connect ':controller/:action/:id'
  map.connect ':controller/:action/:id.:format'  
  
  map.root :controller => 'content', :action => 'index'
  
end
