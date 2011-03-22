class TaxaController < ApplicationController

  prepend_before_filter :redirect_back_to_http if $USE_SSL_FOR_LOGIN   # if we happen to be on an SSL page, go back to http
  before_filter :set_session_hierarchy_variable, :only => [:show, :classification_attribution, :content, :curators]
  after_filter :set_meta_description_and_keys

  # this is cheating because of mixing taxon and taxon concept use of the controller
  def index
    # you need to be a content partner OR ADMIN and logged in to get here
    if current_agent.nil? && !current_user.is_admin?
      return redirect_to(root_url)
    end

    if params[:harvest_event_id] && params[:harvest_event_id].to_i > 0
      page = params[:page] || 1
      @harvest_event = HarvestEvent.find(params[:harvest_event_id])
      @taxa_contributed = @harvest_event.taxa_contributed(params[:harvest_event_id]).all_hashes.uniq.paginate(:page => page)
      @page_title = $ADMIN_CONSOLE_TITLE if current_user.is_admin?
      @navigation_partial = '/admin/navigation'
      render :html => 'content_partner', :layout => current_user.is_admin? ? 'left_menu' : 'content_partner'
    else
      redirect_to(:action=>:show, :id => params[:id])
    end
  end

  def search
    # remove colon from query, because it reserved for fields separation
    @colon_warning_flag = 0
    if params[:q]  =~ /:/
      @querystring = params[:q].gsub(':', '')
      @colon_warning_flag = 1
    else
      @querystring = params[:q] || params[:id]
    end
    @search_type = params[:search_type] || 'text'
    @page_title  = "EOL Search: #{@querystring}"
    @parent_search_log_id = params[:search_log_id] || 0 # Keeps track of searches done immediately after other searches
    log_search(request)
    if @search_type == 'google'
      current_user.log_activity(:google_search_on, :value => params[:q])
      render :action => 'google_search'
    elsif @search_type == 'tag'
      search_tag
    else
      search_text
    end
  end

  def found
    # update the search log if we are coming from the search page, to indicate the user got here from a search
    update_logged_search :id => params[:search_id], :taxon_concept_id => params[:id] if params.key? :search_id
    current_user.log_activity(:clicked_on_search_result, :taxon_concept_id => params[:id])
    redirect_to taxon_concept_url(:id => params[:id])
  end

  # a permanent redirect to the new taxon_concept page
  def taxa
    headers["Status"] = "301 Moved Permanently"
    redirect_to(params.merge(:controller => 'taxa', :action => 'show', :id => HierarchyEntry.find(params[:id]).taxon_concept_id))
  end

  # Main taxon_concept view
  def show

    if this_request_is_really_a_search
      do_the_search
      return
    end

    taxon_concept = find_taxon_concept || return
    return if taxon_concept_invalid?(taxon_concept)
    return redirect_to(params.merge(:controller => 'taxa',
                                    :action => 'show',
                                    :id => taxon_concept.id,
                                    :status => :moved_permanently)) if taxon_concept.superceded_the_requested_id?

    inc = [
      { :top_concept_images => :data_object },
      { :last_curated_dates => :user },
      { :hierarchy_entries => [ :synonyms, :published_refs ]},
      { :data_objects => :published_refs }]
    sel = {
      :data_objects => [ :id, :data_type_id, :vetted_id, :visibility_id, :published, :guid, :data_rating ],
      :last_curated_dates => '*',
      :users => [ :given_name, :family_name ],
      :synonyms => :synonym_relation_id,
      :refs => :id }
    @taxon_concept = TaxonConcept.core_relationships(:add_include => inc, :add_select => sel).find_by_id(taxon_concept.id)


    # inc = [
    #   { :hierarchy_entries => [ :rank, { :name => :canonical_form }, :hierarchy, :hierarchies_content ] },
    #   { :all_data_objects => [ { :toc_items => :info_items }, :license, :published_refs ] },
    #   { :last_curated_dates => :user },
    #   { :hierarchy_entries => [ :synonyms, :published_refs ] } ]
    # sel = {
    #   :taxon_concepts => '*',
    #   :hierarchy_entries => [ :id, :identifier, :hierarchy_id, :parent_id, :published, :visibility_id, :lft, :rgt, :taxon_concept_id, :source_url ],
    #   :hierarchies => [ :agent_id, :browsable, :outlink_uri, :label ],
    #   :hierarchies_content => [ :content_level, :image, :text, :child_image, :map, :youtube, :flash ],
    #   :ranks => :label,
    #   :names => :string,
    #   :canonical_forms => :string,
    #   :data_objects => [ :id, :data_type_id, :vetted_id, :visibility_id, :published, :guid, :data_rating ],
    #   :licenses => :title,
    #   :table_of_contents => '*',
    #   :last_curated_dates => '*',
    #   :users => [ :given_name, :family_name ],
    #   :synonyms => :synonym_relation_id,
    #   :refs => :id }
    # @taxon_concept = TaxonConcept.core_relationships(:include => inc, :select => sel).find_by_id(taxon_concept.id)



    if params[:action_name] == "update_common_names"
      update_common_names
    end
    if params[:category_id]
      params[:category_id] = nil if !TocItem.find_by_id(params[:category_id].to_i)
      @languages = build_language_list if is_common_names?(params[:category_id].to_i)
    end

    @concept_browsable_hierarchies = Hierarchy.browsable_for_concept(@taxon_concept)
    @all_browsable_hierarchies = Hierarchy.browsable_by_label

    # there is where we can set it to ALL hierarchies, or only for this node
    @hierarchies_to_offer = @all_browsable_hierarchies.dup
    # add the user's hierarchy in case the current concept is it
    # we'll need to default the list to the user's hierarchy no matter what
    @hierarchies_to_offer << @session_hierarchy
    @hierarchies_to_offer = @hierarchies_to_offer.uniq.sort_by{|h| h.form_label}

    @feed_item = FeedItem.new(:feed_id => @taxon_concept.id, :feed_type => @taxon_concept.class.name)

    current_user.log_activity(:viewed_taxon_concept, :taxon_concept_id => @taxon_concept.id)

    respond_to do |format|
      format.html do
        show_taxa_html
      end
    end

  end

  def classification_attribution
    @taxon_concept = find_taxon_concept
    return if taxon_concept_invalid?(@taxon_concept)
    current_user.log_activity(:viewed_classification_attribution_on_taxon_concept, :taxon_concept_id => @taxon_concept.id)
    render :partial => 'classification_attribution', :locals => {:taxon_concept => @taxon_concept}
  end

  def search_tag
    @search = Search.new(params, request, current_user, current_agent)
    # The Search class (above) is using 'old' result sets, which we need to adapt to the Solr-style:
    results = EOL::SearchResultsCollection.adapt_old_tag_search_results_to_solr_style_results(@search.search_results[:tags])
    if current_user.expertise.to_s == 'expert'
      @scientific_results = results.paginate(:page => 1, :per_page => results.length + 1, :total_entries => results.length)
      @common_results = empty_paginated_set
    else
      @scientific_results = empty_paginated_set
      @common_results = results.sort_by {|tc| tc['common_name'] }.paginate(:page => 1, :per_page => results.length + 1, :total_entries => results.length)
    end
    @suggested_results = empty_paginated_set
    @all_results = results
    current_user.log_activity(:tag_search_on, :value => params[:q])
  end

  def search_text
    if @querystring.blank?
      @all_results = empty_paginated_set
    else
      @suggested_results  = get_suggested_search_results(@querystring)
      # Are we passing params here for pagination?
      @scientific_results = TaxonConcept.search_with_pagination(@querystring, params.merge(:type => :scientific))
      @common_results     = TaxonConcept.search_with_pagination(@querystring, params.merge(:type => :common))

      @all_results = (@suggested_results + @scientific_results + @common_results)
      current_user.log_activity(:text_search_on, :value => params[:q])
    end
    respond_to do |format|
      format.html do
        redirect_to_taxa_page(@all_results) if (@all_results.length == 1 and not params[:page].to_i > 1)
      end
    end
  end

  # page that will allows a non-logged in user to change content settings
  def settings

    store_location(params[:return_to]) if !params[:return_to].nil? # store the page we came from so we can return there if it's passed in the URL

    # grab logged in user
    @user = current_user

    # if the user is logged in, they should be at the profile page
    if logged_in?
      if params[:from_taxa_page].blank?
        return redirect_to(profile_url)
      else
        @user.update_attributes(params[:user])
        params[:from_taxa_page]
      end
    end

    unless request.post? # first time on page, get current settings
      # set expertise to a string so it will be picked up in web page controls
      @user.expertise = current_user.expertise.to_s
      return
    end
    @user.attributes = params[:user]
    set_current_user(@user)
    flash[:notice] = "Your preferences have been updated."[:your_preferences_have_been_updated] if params[:from_taxa_page].blank?
    store_location(EOLWebService.uri_remove_param(return_to_url, 'vetted')) if valid_return_to_url
    redirect_back_or_default
  end

  ################
  # AJAX CALLS
  ################

  def user_text_change_toc
    @taxon_concept = TaxonConcept.find(params[:taxon_concept_id])
    @taxon_concept.current_agent = current_agent unless current_agent.nil?
    @taxon_concept.current_user = current_user

    if (params[:data_objects_toc_category] && (toc_id = params[:data_objects_toc_category][:toc_id]))
      @toc_item = TocEntry.new(TocItem.find(toc_id), :has_content => false)
    else
      @toc_item = TocEntry.new(@taxon_concept.tocitem_for_new_text, :has_content => false)
    end

    @category_id = @toc_item.category_id
    get_content_variables(:ajax_update => true)
    current_user.log_activity(:viewed_toc_id, :value => toc_id, :taxon_concept_id => @taxon_concept.id)
  end

  # AJAX: Render the requested content page
  def content

    if !request.xhr?
      render :nothing => true
      return
    end

    @taxon_concept = TaxonConcept.core_relationships(:only => [{:data_objects => :toc_items}, { :users_data_objects => { :data_object => :toc_items } }]).find(params[:id])
    @category_id   = params[:category_id].to_i

    @taxon_concept.current_agent = current_agent unless current_agent.nil?
    @taxon_concept.current_user  = current_user
    @curator = @taxon_concept.current_user.can_curate?(@taxon_concept)

    get_content_variables(:ajax_update => true)
    if @content.nil?
      render :text => '[content missing]'
      return true
    else
      @new_text_tocitem_id = get_new_text_tocitem_id(@category_id)
      current_user.log_activity(:viewed_content_for_category_id, :value => @category_id, :taxon_concept_id => @taxon_concept.id)
    end
  end

  def images
    taxon_concept = find_taxon_concept
    return if taxon_concept_invalid?(taxon_concept)
    inc = { :top_concept_images => :data_object }
    sel = { :taxon_concepts => :supercedure_id,
      :data_objects => [ :id, :data_type_id, :vetted_id, :visibility_id, :published, :guid, :data_rating ] }
    @taxon_concept = TaxonConcept.core_relationships(:include => inc, :select => sel).find_by_id(taxon_concept.id)
    @taxon_concept.current_user = current_user
    @taxon_concept.current_agent = current_agent
    @image_page  = (params[:image_page] ||= 1).to_i
    start        = $MAX_IMAGES_PER_PAGE * (@image_page - 1)
    last         = start + $MAX_IMAGES_PER_PAGE - 1
    @images      = @taxon_concept.images(:image_page => @image_page)[start..last]
    @image_count = @taxon_concept.image_count
    set_image_data
    current_user.log_activity(:viewed_page_of_images, :value => @image_page, :taxon_concept_id => @taxon_concept.id)
    render :partial => "images"
  end

  def maps
    @taxon_concept = find_taxon_concept
    return if taxon_concept_invalid?(@taxon_concept)
    render :partial => "maps"
  end

  def videos
    @taxon_concept = find_taxon_concept
    return if taxon_concept_invalid?(@taxon_concept)
    @taxon_concept.current_user = current_user
    @taxon_concept.current_agent = current_agent
    @video_collection = videos_to_show
    render :layout => false
  end

  # AJAX: show the requested video
  def show_video

   if !request.xhr?
     render :nothing => true
     return
   end

    @data_object = DataObject.find(params[:data_object_id].to_i)
    current_user.log_activity(:viewed_video, :value => @data_object.object_cache_url)
    render :update do |page|
      page.replace_html 'video-player', :partial => 'shared/show_video'
    end
  end

  # AJAX: used to show a pop-up in a floating div, all views are in the "popups" subfolder
  def show_popup
    if !params[:name].blank? && request.xhr?
      template = params[:name]
      @taxon_name = params[:taxon_name] || "this taxon"
      render :layout => false, :template => 'popups/' + template
    else
      render :nothing => true
    end
  end

  # Ajax method to change the preferred name on a Taxon Concept:
  def update_common_names
    tc = find_taxon_concept
    return if taxon_concept_invalid?(tc)
    if tc.is_curatable_by?(current_user)
      if !params[:preferred_name_id].nil?
        name = Name.find(params[:preferred_name_id])
        language = Language.find(params[:language_id])
        tc.add_common_name_synonym(name.string, :agent => current_user.agent, :language => language, :preferred => 1,
                                   :vetted => Vetted.trusted)
        expire_taxa([tc.id])
      end

      if params[:trusted_name_clicked_on] != "false"
        if params[:trusted_name_checked] == "true"
          name = Name.find(params[:trusted_name_clicked_on])
          language = Language.find(params[:language_id])
          tc.add_common_name_synonym(name.string, :agent => current_user.agent, :language => language,
                                     :vetted => Vetted.trusted, :preferred => 0)
          expire_taxa([tc.id])
        elsif params[:trusted_synonym_clicked_on] != "false"
          tcn = TaxonConceptName.find_by_synonym_id_and_taxon_concept_id(params[:trusted_synonym_clicked_on], tc.id)
          tc.delete_common_name(tcn)
          expire_taxa([tc.id])
        end
      end
      current_user.log_activity(:updated_common_names, :taxon_concept_id => tc.id)
    end
    redirect_to "/pages/#{tc.id}?category_id=#{params[:category_id]}"
  end

  def add_common_name
    tc = TaxonConcept.find(params[:taxon_concept_id])
    if params[:name][:name_string] && params[:name][:name_string].strip != ""
      agent = current_user.agent
      language = Language.find(params[:name][:language])
      if tc.is_curatable_by?(current_user)
        name, synonym, taxon_concept_name =
          tc.add_common_name_synonym(params[:name][:name_string], :agent => agent, :language => language,
                                     :vetted => Vetted.trusted)
        current_user.log_activity(:added_common_name, :value => params[:name][:name_string], :taxon_concept_id => tc.id)
      else
        flash[:error] = "User #{current_user.full_name} does not have enough privileges to add a common name to the taxon"
      end
      expire_taxa([tc.id])
    end
    redirect_to "/pages/#{tc.id}?category_id=#{params[:name][:category_id]}"
  end

  def delete_common_name
    tc = TaxonConcept.find(params[:taxon_concept_id].to_i)
    synonym_ids = params[:synonym_ids].map {|s| s.to_i}.uniq
    category_id = params[:category_id].to_i
    synonym_ids.each do |synonym_id|
      tcn = TaxonConceptName.find_by_synonym_id_and_taxon_concept_id(synonym_id, tc.id)
      tc.delete_common_name(tcn)
      current_user.log_activity(:deleted_common_name, :taxon_concept_id => tc.id)
    end
    redirect_to "/pages/#{tc.id}?category_id=#{category_id}"
  end

  def vet_common_name
    @taxon_concept = TaxonConcept.find(params[:taxon_concept_id].to_i)
    language_id = params[:language_id].to_i
    name_id = params[:name_id].to_i
    vetted = Vetted.find(params[:vetted_id])
    @taxon_concept.current_user = current_user
    @taxon_concept.vet_common_name(:language_id => language_id, :name_id => name_id, :vetted => vetted)
    current_user.log_activity(:vetted_common_name, :taxon_concept_id => @taxon_concept.id, :value => name_id)
    render :partial => 'taxa/content/content_language_common_names_curator_vetting',
           :locals => {:language_id => language_id, :name_id => name_id, :unique_id => params[:unique_id],
             :vetted_id => vetted.id}
  end

  def publish_wikipedia_article
    tc = TaxonConcept.find(params[:taxon_concept_id].to_i)
    data_object = DataObject.find(params[:data_object_id].to_i)
    data_object.publish_wikipedia_article

    category_id = params[:category_id].to_i
    redirect_url = "/pages/#{tc.id}"
    redirect_url += "?category_id=#{category_id}" unless category_id.blank? || category_id == 0
    current_user.log_activity(:published_wikipedia_article, :taxon_concept_id => tc.id)
    redirect_to redirect_url
  end

  def lookup_reference
    ref = Ref.find(params[:ref_id].to_i)
    callback = params[:callback]

    if defined? $REFERENCE_PARSING_ENABLED
      raise 'Reference parsing disabled' if !$REFERENCE_PARSING_ENABLED
    else
      parameter = SiteConfigurationOption.reference_parsing_enabled
      raise 'Reference parsing disabled' unless parameter && parameter.value == 'true'
    end

    if defined? $REFERENCE_PARSER_ENDPOINT
      endpoint = $REFERENCE_PARSER_ENDPOINT
    else
      endpoint_param = SiteConfigurationOption.reference_parser_endpoint
      endpoint = endpoint_param.value
    end

    if defined? $REFERENCE_PARSER_PID
      pid = $REFERENCE_PARSER_PID
    else
      pid_param = SiteConfigurationOption.reference_parser_pid
      pid = pid_param.value
    end

    raise 'Invalid configuration' unless pid && endpoint

    url = endpoint + "?pid=#{pid}&output=json&q=#{URI.escape(ref.full_reference)}&callback=#{callback}"
    render :text => Net::HTTP.get(URI.parse(url))
  end

  def curators
    # if this is named taxon_concept then the RSS feeds will be added to the page
    # in Firefox those feeds are evaluated when the pages loads, so this should save some queries
    @concept = find_taxon_concept
    return if taxon_concept_invalid?(@concept)
    @page_title = "Curators of #{@concept.title(@session_hierarchy)}"
    @curators = @concept.curators(:add_names => true)
    @curators.sort! do |a, b|
      if a.family_name.strip.blank? && b.family_name.strip.blank? # last names blank, sort by first
        a.given_name.strip <=> b.given_name.strip
      elsif a.family_name.strip.blank?                            # A.last blank, sort A.first to B.last
        a.given_name.strip <=> b.family_name.strip
      elsif b.family_name.strip.blank?                            # B last name blank, sort B.first to A.last
        a.family_name.strip <=> b.given_name.strip
      elsif a.family_name.strip == b.family_name.strip            # sort last
        a.given_name.strip <=> b.given_name.strip
      else                                                        # then sort first
        a.family_name.strip <=> b.family_name.strip
      end
    end
  end

private

  def get_content_variables(options = {})
    @content = @taxon_concept.content_by_category(@category_id, :current_user => current_user)
    @whats_this = WhatsThis.get_url_for_name(@content[:category_name])
    @ajax_update = options[:ajax_update]
    @languages = build_language_list if is_common_names?(@category_id)
  end

  def update_user_content_level
    current_user.content_level = params[:content_level] if ['1','2','3','4'].include?(params[:content_level])
  end

  def add_page_view_log_entry
    PageViewLog.create(:user => current_user, :agent => current_agent, :taxon_concept => @taxon_concept)
  end

  def get_new_text_tocitem_id(category_id)
    if category_id && toc = TocItem.find_by_id(category_id)
      return category_id if toc.allow_user_text?
    end
    return 'none'
  end

  def videos_to_show
    @default_videos = @taxon_concept.video_data_objects
    @videos = show_unvetted_videos

    if params[:vet_flag] == "false"
      @video_collection = @videos
    else
      @video_collection = @default_videos unless @default_videos.blank?
    end
  end

  # collect all videos (unvetted as well)
  def show_unvetted_videos
    videos = @taxon_concept.video_data_objects(:unvetted => true) unless @default_videos.blank?
    return videos
  end

  # If you want this to redirect to search, call (do_the_search && return if this_request_is_really_a_search) before this.
  def find_taxon_concept
    tc_id = params[:id].to_i
    tc_id = params[:taxon_concept_id].to_i if tc_id == 0
    redirect_to_missing_page_on_error do
      TaxonConcept.find(tc_id)
    end
  end

  def taxon_concept_invalid?(tc)
    redirect_to_missing_page_on_error do
      raise "TaxonConcept not found" if tc.nil?
      raise "Page not accessible" unless accessible_page?(tc)
    end
  end

  def redirect_to_missing_page_on_error(&block)
    begin
      yield
    rescue => e
      @message = e.message
      render(:layout => 'main', :template => "content/missing", :status => 404)
      return false
    end
  end

  # wich TOC item choose to show
  def show_category_id
    if params[:category_id] && !params[:category_id].blank?
      params[:category_id]
    elsif !(first_content_item = @taxon_concept.table_of_contents(:vetted_only => current_user.vetted, :agent_logged_in => agent_logged_in?).detect {|item| item.has_content? }).nil?
      first_content_item.category_id
    else
      nil
    end
  end

  def first_content_item
    # find first valid content area to use
    @taxon_concept.table_of_contents(:vetted_only => current_user.vetted, :agent_logged_in => agent_logged_in?).detect { |item| item.has_content? }
  end

  def handle_whats_this
  end

  def this_request_is_really_a_search
    params[:id].to_i == 0
  end

  def do_the_search
    redirect_to search_path(:id => params[:id])
  end

  def show_taxa_html

    update_user_content_level
    add_page_view_log_entry

    @taxon_concept.current_user = current_user
    @image_id = params[:image_id]

    unless show_taxa_html_can_be_cached? &&
        fragment_exist?(:controller => 'taxa', :part => taxa_page_html_fragment_name)
      failure = set_taxa_page_instance_vars
      return false if failure
    end # end get full page since we couldn't read from cache

    render :template => '/taxa/show_cached' if allow_page_to_be_cached? and not params[:category_id] # if caching is allowed, see if fragment exists using this template
  end

  def taxa_page_html_fragment_name
    current_user = @taxon_concept.current_user
    return "page_#{params[:id]}_#{current_user.taxa_page_cache_str}_#{@taxon_concept.show_curator_controls?}"
  end
  helper_method(:taxa_page_html_fragment_name)

  def show_taxa_html_can_be_cached?
    return(allow_page_to_be_cached? and
           params[:category_id].blank? and
           params[:image_id].blank?)
  end

  def find_selected_image_index(images,image_id)
    images.each_with_index do |image,i|
      # We're "normalizing" the ids, here, since we've already run this method on the input id:
      lpvo = image.id
      if obj = DataObject.latest_published_version_of(lpvo)
        lpvo = obj.id
      end
      if lpvo == image_id
        return i
      end
    end
    return nil
  end

  # Image ID could have been superceded (by, say, a newer version of the same image), so we need to normalize it.
  def set_image_data
    if(params[:image_id])
      latest_published_image = DataObject.latest_published_version_of(params[:image_id].to_i)
      unless latest_published_image
        flash[:warning] = "Image not found"
        return
      end
      image_id = latest_published_image.id

      selected_image_index = find_selected_image_index(@images,image_id)
      if selected_image_index.nil?
        current_user.vetted = false
        current_user.save if logged_in?

        @taxon_concept.current_user = current_user
        selected_image_index = find_selected_image_index(@images,image_id)
      end
      unless selected_image_index
        flash[:warning] = "Image is no longer available"
        return
      end
      params[:image_page] = @image_page = ((selected_image_index+1) / $MAX_IMAGES_PER_PAGE.to_f).ceil
      start        = $MAX_IMAGES_PER_PAGE * (@image_page - 1)
      last         = start + $MAX_IMAGES_PER_PAGE - 1
      @images      = @taxon_concept.images(:image_page=>@image_page)[start..last]
      adjusted_selected_image_index = selected_image_index % $MAX_IMAGES_PER_PAGE
      @selected_image_id = @images[adjusted_selected_image_index].id
    else
      @selected_image_id = @images[0].id unless @images.blank?
    end
  end

  def set_text_data
    if(params[:text_id])
      text_id = params[:text_id].to_i

      @selected_text = DataObject.find_by_id(text_id)

      if @selected_text && @selected_text.get_taxon_concepts.include?(@taxon_concept) && (@selected_text.visible? || (@selected_text.invisible? && current_user.can_curate?(@selected_text)) || (@selected_text.inappropriate? && current_user.is_admin?))
        selected_toc = @selected_text.toc_items[0]

        params[:category_id] = selected_toc.id

        @category_id = show_category_id

        if current_user.vetted && (@selected_text.untrusted? || @selected_text.unknown?)
          current_user.vetted = false
          current_user.save if logged_in?
        end
      else
        flash[:warning] = "Text is no longer available"
      end
    end
  end

  # TODO - this smells like bad architecture.  The name of the method alone implies that we're doing something
  # wrong.  We really need some classes or helpers to take care of these details.
  def set_taxa_page_instance_vars
    @taxon_concept.current_agent = current_agent
    @images = @taxon_concept.images
    @image_count = @taxon_concept.image_count

    set_image_data
    set_text_data

    @category_id = show_category_id # need to be an instant var as we use it in several views and they use
                                    # variables with that name from different methods in different cases

    @new_text_tocitem_id = get_new_text_tocitem_id(@category_id)

    get_content_variables unless
      @category_id.nil? || @taxon_concept.table_of_contents(:vetted_only=>@taxon_concept.current_user.vetted).blank?
    @random_taxa = RandomHierarchyImage.random_set(5, @session_hierarchy, {:language => current_user.language, :size => :small})
  end

  # For regular users, a page is accessible only if the taxon_concept is published.
  # If an agent is logged in, then it's only accessible if the taxon_concept is
  # referenced by the Agent's most recent harvest events
  def accessible_page?(taxon_concept)
    return false if taxon_concept.nil?      # TC wasn't found.
    return true if taxon_concept.published? # Anyone can see published TCs
    return true if agent_logged_in? and current_agent.latest_unpublished_harvest_contains?(taxon_concept.id)
    return false # current agent can't see this unpublished page, or agent isn't logged in.
  end

  def allow_text_search_to_be_cached?
    text_search? and allow_page_to_be_cached?
  end

  def text_search?
    params[:search_type].downcase == 'text'
  end

  def search_fragment_name(lang, query, page)
    page ||= 1
    {:controller => 'taxa',
     :part => "search_#{lang}_#{query}_#{page}_#{current_user.vetted}_#{@last_harvest_event_id}"}
  end
  helper_method(:search_fragment_name)

  def redirect_to_taxa_page(result_set)
    redirect_to :controller => 'taxa', :action => 'show', :id => result_set.first['id']
  end

  def get_suggested_search_results(querystring)
    pluralized = querystring.pluralize
    singular   = querystring.singularize
    suggested_results_original = SearchSuggestion.find_all_by_term_and_active(singular, true, :order => 'sort_order') +
                                 SearchSuggestion.find_all_by_term_and_active(pluralized, true, :order => 'sort_order')

    # bacteria has a singular bacterium and a plural bacterias so we need to search on the original term too
    if querystring != pluralized && querystring != singular
      suggested_results_original += SearchSuggestion.find_all_by_term_and_active(querystring, true, :order => 'sort_order')
    end

    return [] if suggested_results_original.blank?
    suggested_results_query = suggested_results_original.select {|i| i.taxon_id.to_i > 0}.map {|i| 'taxon_concept_id:' + i.taxon_id}.join(' OR ')
    suggested_results_query = suggested_results_query.blank? ? "taxon_concept_id:0" : "(#{suggested_results_query})"
    suggested_results  = TaxonConcept.search_with_pagination(suggested_results_query, params)
    suggested_results_original = suggested_results_original.inject({}) {|res, sugg_search| res[sugg_search.taxon_id] = sugg_search; res}
    suggested_results.each do |res|
      common_name = suggested_results_original[res['taxon_concept_id'][0].to_s].common_name
      res['common_name'] = [common_name]
      res['preferred_common_name'] = common_name
    end
    suggested_results
  end

  def empty_paginated_set
    [].paginate(:page => 1, :per_page => 10, :total_entries => 0)
  end

  # Add an entry to the database desrcibing the fruitfullness of this search.
  def log_search(req)
    logged_search = SearchLog.log(
      {:search_term                       => @querystring,
       :search_type                       => @search_type,
       :parent_search_log_id              => @parent_search_log_id,
       :total_number_of_results           => get_num_results(@all_results),
       :number_of_common_name_results     => get_num_results(@common_results),
       :number_of_scientific_name_results => get_num_results(@scientific_results),
       :number_of_suggested_results       => get_num_results(@suggested_results) },
      req,
      current_user)
    @logged_search_id = logged_search.nil? ? '' : logged_search.id
  end

  def get_num_results(set)
    return 0 if set.nil?
    set.respond_to?(:total_entries) ?
      set.total_entries :
      set.length
  end

  def is_common_names?(category_id)
    TocItem.common_names.id == category_id
  end

  def build_language_list
    @languages = Language.with_iso_639_1.map  do |lang|
      {
        :label    => lang.label,
        :id       => lang.id,
        :selected => lang.id == (current_user && current_user.language_id) ? "selected" : nil
      }
    end
  end

  def set_meta_description_and_keys
    if @taxon_concept
      @meta_description = "#{@taxon_concept.title} (#{@taxon_concept.subtitle}) in Encyclopedia of Life"
      @meta_keywords = @taxon_concept.title + " " + @taxon_concept.subtitle
    end
  end

end
