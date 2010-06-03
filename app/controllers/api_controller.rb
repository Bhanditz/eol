class ApiController < ApplicationController
  
  include ApiHelper
  
  def pages
    taxon_concept_id = params[:id] || 0
    params[:images] ||= 1
    params[:text] ||= 1
    params[:vetted] ||= false
    params[:vetted] = false if params[:vetted] == '0'
    params[:common_names] ||= false
    params[:common_names] = false if params[:common_names] == '0'
    params[:images] = 75 if params[:images].to_i > 75
    params[:text] = 75 if params[:text].to_i > 75
    params[:details] = 1 if params[:format] == 'html'
    
    begin
      taxon_concept = TaxonConcept.find(taxon_concept_id)
      raise if taxon_concept.nil? || !taxon_concept.published?
    rescue
      render(:partial => 'error.xml.builder', :locals => {:error => "Unknown identifier #{taxon_concept_id}"})
      return
    end
    
    details_hash = taxon_concept.details_hash(:return_media_limit => params[:images].to_i, :subjects => params[:subjects], :return_text_limit => params[:text].to_i, :details => params[:details], :vetted => params[:vetted], :common_names => params[:common_names])
    
    if params[:format] == 'html'
      render(:partial => 'pages', :layout=>false, :locals => {:details_hash => details_hash, :data_object_details => true } )
    else
      respond_to do |format|
        format.xml { render(:partial => 'pages', :layout=>false, :locals => {:details_hash => details_hash, :data_object_details => params[:details] } ) }
        format.json {
          @return_hash = pages_json(details_hash, params[:details]!=nil)
          render :json => @return_hash, :callback => params[:callback] 
        }
      end
    end
  end
  
  def data_objects
    data_object_guid = params[:id] || 0
    params[:common_names] ||= false
    
    details_hash = DataObject.details_for_object(data_object_guid, :include_taxon => true, :common_names => params[:common_names])
    
    if details_hash.blank?
      render(:partial => 'error.xml.builder', :locals => {:error => "Unknown identifier #{data_object_guid}"})
      return
    end
    
    if params[:format] == 'html'
      render(:partial => 'pages', :layout => false, :locals => { :details_hash => details_hash, :data_object_details => true } )
    else
      respond_to do |format|
        format.xml { render(:partial => 'pages', :layout => false, :locals => { :details_hash => details_hash, :data_object_details => true } ) }
        format.json {
          @return_hash = pages_json(details_hash)
          render :json => @return_hash, :callback => params[:callback] 
        }
      end
    end
  end
  
  def search
    @search_term = params[:id]
    @page = params[:page].to_i || 1
    @page = 1 if @page < 1
    @per_page = 30
    @results = TaxonConcept.search_with_pagination(@search_term, :page => @page, :per_page => @per_page, :type => :all, :lookup_trees => false)
    @last_page = (@results.total_entries/@per_page.to_f).ceil
    
    
    respond_to do |format|
      format.xml { render :layout => false }
      format.json {
          @return_hash = search_result_hash({:search_term => @search_term, :page => @page, :per_page => @per_page, :results => @results, :format => params[:format]})
          render :json => @return_hash, :callback => params[:callback] 
        }
    end
  end
  
  def hierarchy_entries
    id = params[:id] || 0
    format = params[:format] || 'dwc'
    begin
      @hierarchy_entry = HierarchyEntry.find(id)
      @ancestors = @hierarchy_entry.ancestor_details
      @common_names = @hierarchy_entry.common_name_details
      @synonyms = @hierarchy_entry.synonym_details
      @children = @hierarchy_entry.children_details
      raise if @hierarchy_entry.nil? || !@hierarchy_entry.published?
    rescue
      render(:partial => 'error.xml.builder', :locals => {:error => "Unknown identifier #{id}"})
      return
    end
    
    if format == 'tcs'
      render :action =>'hierarchy_entries.xml.builder', :layout => false
    else
      respond_to do |format|
        format.xml { render :action =>'hierarchy_entries_dwc.xml.builder', :layout => false }
        format.json {
          @return_hash = hierarchy_entries_json
          render :json => @return_hash, :callback => params[:callback] 
        }
      end
    end
  end
  
  def synonyms
    id = params[:id] || 0
    begin
      @synonym = Synonym.find(id)
    rescue
      render(:partial => 'error.xml.builder', :locals => {:error => "Unknown identifier #{id}"})
      return
    end
    
    respond_to do |format|
       format.xml { render :layout => false }
    end
  end
  
  def ping
    respond_to do |format|
      format.xml { render :layout => false }
      format.json { render :json => { 'response' => { 'message' => 'Success' } } , :callback => params[:callback] }
    end
  end
end
