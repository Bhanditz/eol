class NavigationController < ApplicationController

  # caches_page :flash_tree_view

  def show_tree_view
    # set the users default hierarchy if they haven't done so already
    current_user.default_hierarchy_id = Hierarchy.default.id if current_user.default_hierarchy_id.nil? || !Hierarchy.exists?(current_user.default_hierarchy_id)
    @session_hierarchy = Hierarchy.find(current_user.default_hierarchy_id)
    @session_secondary_hierarchy = current_user.secondary_hierarchy_id.nil? ? nil : Hierarchy.find(current_user.secondary_hierarchy_id)
    
    
    load_taxon_for_tree_view
    render :layout => false, :partial => 'browse_page', :locals => { :current_user => current_user }
  end
  
  def show_tree_view_for_selection
    load_taxon_for_tree_view
    render :layout => false, :partial => 'tree_view_for_selection', :locals => { :current_user => current_user }
  end
  
  # AJAX call to set default taxonomic browser in session and save to profile
  def set_default_taxonomic_browser
    
        browser=params[:browser] || $DEFAULT_TAXONOMIC_BROWSER
        current_user.default_taxonomic_browser=browser
        current_user.save if logged_in?
        render :nothing=>true
        
  end
  
  def browse
    @hierarchy_entry = HierarchyEntry.find_by_id(params[:id])
    @expand = params[:expand] == "1"
    if @hierarchy_entry.blank?
      return
    end
    @hierarchy = @hierarchy_entry.hierarchy
    current_user.log_activity(:browsing_for_hierarchy_entry_id, :value => params[:id])
    render :layout => false, :partial => 'browse'
  end
  
  def browse_stats
    @hierarchy_entry = HierarchyEntry.find_by_id(params[:id])
    @expand = params[:expand] == "1"
    if @hierarchy_entry.blank?
      return
    end
    @hierarchy = @hierarchy_entry.hierarchy
    render :partial => 'browse_stats', :layout => false
  end
  
  
  protected
  
  def load_taxon_for_tree_view
    @hierarchy_entry = HierarchyEntry.find(params[:id].to_i)
    current_user.log_activity(:showing_tree_view_for_hierarchy_entry_id, :value => params[:id])
    #@taxon_concept = TaxonConcept.find(params[:id].to_i, :include => [:names])
    #@taxon_concept.current_user = current_user
  end
  
end
