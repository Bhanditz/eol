# Represents an entry in the Tree of Life (see Hierarchy).  This is one of the major models of the EOL codebase, and most
# data links to these instances.
class HierarchyEntry < SpeciesSchemaModel

  acts_as_tree :order => 'lft'

  belongs_to :hierarchy 
  belongs_to :name
  belongs_to :rank 
  belongs_to :taxon_concept
  belongs_to :vetted
  belongs_to :visibility
  
  has_many :agents_hierarchy_entries
  has_many :agents, :finder_sql => 'SELECT * FROM agents JOIN agents_hierarchy_entries ahe ON (agents.id = ahe.agent_id)
                                      WHERE ahe.hierarchy_entry_id = #{id} ORDER BY ahe.view_order'
  has_many :top_images, :foreign_key => :hierarchy_entry_id
  has_many :synonyms
  has_many :scientific_synonyms, :class_name => Synonym.to_s,
      :conditions => "synonyms.synonym_relation_id NOT IN (#{SynonymRelation.common_name_ids.join(',')})"
  has_many :common_names, :class_name => Synonym.to_s,
      :conditions => "synonyms.synonym_relation_id IN (#{SynonymRelation.common_name_ids.join(',')})"
  has_many :flattened_ancestors, :class_name => HierarchyEntriesFlattened.to_s
  
  has_and_belongs_to_many :data_objects
  has_and_belongs_to_many :refs

  has_one :hierarchies_content
  has_one :hierarchy_entry_stat
  
  define_core_relationships :select => {
      :hierarchy_entries => [ :id, :identifier, :hierarchy_id, :parent_id, :lft, :rgt, :taxon_concept_id ],
      :names => [ :string, :italicized ],
      :canonical_forms => :string,
      :ranks => :label,
      :hierarchies_content => [ :content_level, :image, :text, :child_image ]},
    :include => [{ :name => :canonical_form }, :rank, :hierarchies_content ]
  
  def self.sort_by_lft(hierarchy_entries)
    hierarchy_entries.sort_by{ |he| he.lft }
  end
  
  def self.sort_by_name(hierarchy_entries)
    hierarchy_entries.sort_by{ |he| he.name.string.downcase }
  end
  
  def self.sort_by_common_name(hierarchy_entries, language)
    hierarchy_entries.sort_by{ |he| he.common_name_in_language(language).downcase }
  end
  
  def self.sort_by_vetted(hierarchy_entries)
    hierarchy_entries.sort_by do |he|
      [he.taxon_concept_id,
        Invert(he.published),
       he.vetted.view_order,
       he.id]
    end
  end
  

  # this is meant to be filtered by a taxon concept so it will find all hierarchy entries AND their ancestors/parents for a given TaxonConcept
  def self.with_parents taxon_concept_or_hierarchy_entry = nil
    if taxon_concept_or_hierarchy_entry.is_a?TaxonConcept
      HierarchyEntry.find_all_by_taxon_concept_id(taxon_concept_or_hierarchy_entry.id).inject([]) do |all, he|
        all << he
        all += he.ancestors
        all
      end
    elsif taxon_concept_or_hierarchy_entry.is_a?HierarchyEntry
      [taxon_concept_or_hierarchy_entry] + taxon_concept_or_hierarchy_entry.ancestors
    else
      raise "Don't know how to return with_parents for #{ taxon_concept_or_hierarchy_entry.inspect }"
    end
  end
  
  def get_ancestry(ancestry_array = [])
    ancestry_array.unshift self
    return ancestry_array unless parent_id.to_i > 0
    parent_hierarchy_entry = HierarchyEntry.find(parent_id, :select => 'id, parent_id, name_id, published, taxon_concept_id')
    parent_hierarchy_entry.get_ancestry(ancestry_array)
  end
  
  def italicized_name
    species_or_below? ? name.italicized : name.string
  end
  
  def canonical_form
    return name.canonical_form
  end

  def media
    {:images => hierarchies_content.image != 0 || hierarchies_content.child_image  != 0,
     :video  => hierarchies_content.flash != 0 || hierarchies_content.youtube != 0,
     :map    => hierarchies_content.map != 0}
  end

  def rank_label
    rank.nil? ? "taxon" : rank.label
  end

  # Returns true if the specified user has access to the TaxonConcept that this HierarchyEntry belongs to
  # (because curators have access to pages, not really specific HierarchyEntry instances.  This is confusing
  # because users have a HierarchyEntry that their 
  def is_curatable_by? user
    return taxon_concept.is_curatable_by?(user)
  end

  def species_or_below?
    return false if rank_id == 0  # this was causing a lookup for rank id=0, so I'm trying to save queries here
    return Rank.italicized_ids.include?(rank_id)
  end

  def images
    @images ||= DataObject.images_for_hierarchy_entry(id)
  end

  def videos
    @videos ||= DataObject.videos_for_hierarchy_entry(id)
  end

  def map
    @map ||= DataObject.map_for_hierarchy_entry(id)
  end

  def valid
    return false if hierarchies_content.nil? # This really only happens in test environ, but...
    hierarchies_content.content_level >= $VALID_CONTENT_LEVEL
  end

  def enable
    return false if hierarchies_content.nil?
    return species_or_below? ? (hierarchies_content.text == 1 or hierarchies_content.image == 1) : valid
  end

  def ancestors(params = {}, cross_reference_hierarchy = nil)
    # return @ancestors unless @ancestors.nil?
    
    # # TODO: reimplement completing a partial hierarchy with another curated hierarchy
    
    add_include = []
    add_select = {}
    if params[:include_stats]
      add_include << :hierarchy_entry_stat
      add_select[:hierarchy_entry_stats] = '*'
    end
    if params[:include_common_names]
      add_include << {:taxon_concept => {:preferred_common_names => :name}}
      add_select[:taxon_concept_names] = :language_id
    end
    
    ancestor_ids = flattened_ancestors.collect{ |f| f.ancestor_id }
    ancestor_ids << self.id
    ancestors = HierarchyEntry.core_relationships(:add_include => add_include, :add_select => add_select).find_all_by_id(ancestor_ids)
    @ancestors = HierarchyEntry.sort_by_lft(ancestors)
  end
  
  def children(params = {})
    add_include = []
    add_select = {}
    if params[:include_stats]
      add_include << :hierarchy_entry_stat
      add_select[:hierarchy_entry_stats] = '*'
    end
    if params[:include_common_names]
      add_include << {:taxon_concept => {:preferred_common_names => :name}}
      add_select[:taxon_concept_names] = :language_id
    end
    
    vis = [Visibility.visible.id, Visibility.preview.id]
    c = HierarchyEntry.core_relationships(:add_include => add_include, :add_select => add_select).find_all_by_hierarchy_id_and_parent_id_and_visibility_id(hierarchy_id, id, vis)
    if params[:include_common_names]
      return HierarchyEntry.sort_by_common_name(c, params[:common_name_language])
    else
      return HierarchyEntry.sort_by_name(c)
    end
  end

  def kingdom(hierarchy = nil)
    return ancestors(hierarchy).first rescue nil
  end

  def smart_thumb
    return images.blank? ? nil : images.first.smart_thumb
  end

  def smart_medium_thumb
    return images.blank? ? nil : images.first.smart_medium_thumb
  end

  def smart_image
    return images.blank? ? nil : images.first.smart_image
  end

  def classification_attribution(params={})
    attribution = []

    # its possible that the hierarchy is not associated with an agent
    if hierarchy.agent
      attribution = [hierarchy.agent]
      attribution.first.full_name = attribution.first.display_name = hierarchy.label # To change the name from just "Catalogue of Life"
    end
    attribution += agents
  end

  def agents_roles
    agents_roles = []

    # its possible that the hierarchy is not associated with an agent
    if h_agent = hierarchy.agent
      h_agent.full_name = h_agent.display_name = hierarchy.label # To change the name from just "Catalogue of Life"
      role = AgentRole.find_or_create_by_label('Source')
      agents_roles << AgentsHierarchyEntry.new(:hierarchy_entry => self, :agent => h_agent, :agent_role => role, :view_order => 0)
    end
    agents_roles += agents_hierarchy_entries
  end

  def has_gbif_identifier?
    return false unless hierarchies_content
    return false unless hierarchies_content.map
    return false if hierarchies_content.map == 0
    return false if identifier.blank?
    return true
  end

  # Walk up the list of ancestors until you find a node that we can map to the specified hierarchy.
  def find_ancestor_in_hierarchy(hierarchy)
    he = self
    until he.nil? || he.taxon_concept.nil? || he.taxon_concept.in_hierarchy?(hierarchy)
      return nil if he.parent_id == 0
      he = he.parent
    end
    return nil if he.nil? || he.taxon_concept.nil?
    he.taxon_concept.entry(hierarchy)
  end

  def vet_synonyms(options = {})
    raise "Missing :name_id"     unless options[:name_id]
    raise "Missing :language_id" unless options[:language_id]
    raise "Missing :vetted"      unless options[:vetted]
    Synonym.update_all(
      "vetted_id = #{options[:vetted].id}",
      "language_id = #{options[:language_id]} AND name_id = #{options[:name_id]} AND hierarchy_entry_id = #{id}"
    )
  end

  def outlink
    return nil if published != 1 && visibility_id != Visibility.visible.id
    this_hierarchy = hierarchy
    if !source_url.blank?
      return {:hierarchy_entry => self, :hierarchy => this_hierarchy, :outlink_url => source_url }
    elsif !this_hierarchy.outlink_uri.blank?
      # if the hierarchy outlink_uri expects an ID
      if matches = this_hierarchy.outlink_uri.match(/%%ID%%/)
        # .. and the ID exists
        unless identifier.blank?
          return {:hierarchy_entry => self, :hierarchy => this_hierarchy, :outlink_url => this_hierarchy.outlink_uri.gsub(/%%ID%%/, identifier) }
        end
      else
        # there was no %%ID%% pattern in the outlink_uri, but its not blank so its a generic URL for all entries
        return {:hierarchy_entry => self, :hierarchy => this_hierarchy, :outlink_url => this_hierarchy.outlink_uri }
      end
    end
  end
  
  def split_from_concept
    result = connection.execute("SELECT he2.id, he2.taxon_concept_id FROM hierarchy_entries he JOIN hierarchy_entries he2 USING (taxon_concept_id) WHERE he.id=#{self.id}").all_hashes
    unless result.empty?
      entries_in_concept = result.length
      # if there is only one member in the entry's concept there is no need to split it
      if entries_in_concept > 1
        # create a new empty concept
        new_taxon_concept = TaxonConcept.create(:published => self.published, :vetted_id => self.vetted_id, :supercedure_id => 0, :split_from => 0)
        
        # set the concept of this entry to the new concept
        self.taxon_concept_id = new_taxon_concept.id
        self.save!
        
        # update references to this entry to use new concept id
        connection.execute("UPDATE IGNORE taxon_concept_names SET taxon_concept_id=#{new_taxon_concept.id} WHERE source_hierarchy_entry_id=#{self.id}");
        connection.execute("UPDATE IGNORE hierarchy_entries he JOIN random_hierarchy_images rhi ON (he.id=rhi.hierarchy_entry_id) SET rhi.taxon_concept_id=he.taxon_concept_id WHERE he.taxon_concept_id=#{self.id}")
        return new_taxon_concept
      end
    end
    return false
  end
  
  def number_of_descendants
    rgt - lft - 1
  end
  
  def has_content?
    return false unless hierarchies_content  # this should really only happen during testing, and even that'
    hierarchies_content.content_level > 1
  end
  
  def is_leaf?
    return (rgt-lft == 1)
  end
  
  def common_name_in_language(language)
    preferred_in_language = taxon_concept.preferred_common_names.select{|tcn| tcn.language_id == language.id}
    return name.string if preferred_in_language.blank?
    preferred_in_language[0].name.string.firstcap
  end
end
