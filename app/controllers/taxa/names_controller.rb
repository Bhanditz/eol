class Taxa::NamesController < TaxaController

  before_filter :instantiate_taxon_concept
  before_filter :authentication_for_names, :only => [ :create, :update ]
  before_filter :preload_core_relationships_for_names, :only => [ :index, :common_names, :synonyms ]

  # GET /pages/:taxon_id/names
  # related names default tab
  def index
    if @selected_hierarchy_entry
      @related_names = TaxonConcept.related_names(:hierarchy_entry_id => @selected_hierarchy_entry_id)
    else
      @related_names = TaxonConcept.related_names(:taxon_concept_id => @taxon_concept.id)
    end
    @assistive_section_header = I18n.t(:assistive_names_related_header)
    current_user.log_activity(:viewed_taxon_concept_names_related_names, :taxon_concept_id => @taxon_concept.id)

    # for common names count
    @common_names_count = get_common_names.count
  end

  # POST /pages/:taxon_id/names currently only used to add common_names
  def create
    if params[:commit_add_common_name]
      agent = current_user.agent
      language = Language.find(params[:name][:synonym][:language_id])
      synonym = @taxon_concept.add_common_name_synonym(params[:name][:string],
                  :agent => agent, :language => language, :vetted => Vetted.trusted)
      log_action(@taxon_concept, synonym, :add_common_name)
      expire_taxa([@taxon_concept.id])
    end
    store_location params[:return_to] unless params[:return_to].blank?
    redirect_back_or_default common_names_taxon_names_path(@taxon_concept)
  end

  # PUT /pages/:taxon_id/names currently only used to update common_names
  def update
    # TODO:
  end


  # GET for collection synonyms /pages/:taxon_id/synonyms
  def synonyms
    associations = { :published_hierarchy_entries => [ :name, { :scientific_synonyms => [ :synonym_relation, :name ] } ] }
    options = { :select => { :hierarchy_entries => [ :id, :name_id, :hierarchy_id, :taxon_concept_id ],
                           :names => [ :id, :string ],
                           :synonym_relations => [ :id ] } }
    TaxonConcept.preload_associations(@taxon_concept, associations, options )
    @assistive_section_header = I18n.t(:assistive_names_synonyms_header)
    current_user.log_activity(:viewed_taxon_concept_names_synonyms, :taxon_concept_id => @taxon_concept.id)
    
    # for common names count
    @common_names_count = get_common_names.count
  end

  # GET for collection common_names /pages/:taxon_id/names/common_names
  def common_names
    @common_names = get_common_names
    @common_names_count = @common_names.count
    @assistive_section_header = I18n.t(:assistive_names_common_header)
    current_user.log_activity(:viewed_taxon_concept_names_common_names, :taxon_concept_id => @taxon_concept.id)
  end

private

  def get_common_names
    unknown = Language.unknown.label # Just don't want to look it up every time.
    if @selected_hierarchy_entry
      names = EOL::CommonNameDisplay.find_by_hierarchy_entry_id(@selected_hierarchy_entry.id)
    else
      names = EOL::CommonNameDisplay.find_by_taxon_concept_id(@taxon_concept.id)
    end
    common_names = names.select {|n| n.language_label != unknown}
  end

  def preload_core_relationships_for_names
    includes = [
      { :published_hierarchy_entries => [ :name, { :hierarchy => :agent }, :hierarchies_content, :vetted ] }]
    selects = {
      :taxon_concepts => '*',
      :hierarchy_entries => [ :id, :rank_id, :identifier, :hierarchy_id, :parent_id, :published, :visibility_id, :lft, :rgt, :taxon_concept_id, :source_url ],
      :names => [ :string, :italicized, :canonical_form_id, :ranked_canonical_form_id ],
      :hierarchies => [ :agent_id, :browsable, :outlink_uri, :label ],
      :hierarchies_content => [ :content_level, :image, :text, :child_image, :map, :youtube, :flash ],
      :vetted => :view_order,
      :agents => '*' }
    @taxon_concept = TaxonConcept.core_relationships(:include => includes, :select => selects).find_by_id(@taxon_concept.id)
    @hierarchies = @taxon_concept.published_hierarchy_entries.collect{|he| he.hierarchy if he.hierarchy.browsable? }.uniq
    # TODO: Eager load hierarchy entry agents?
  end

  def authentication_for_names
    if ! current_user.is_curator?
      flash[:error] = I18n.t(:insufficient_privileges_to_curate_names)
      store_location params[:return_to] unless params[:return_to].blank?
      redirect_back_or_default common_names_taxon_names_path(@taxon_concept)
    end
  end

end
