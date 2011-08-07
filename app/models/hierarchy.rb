# Represents a version of the Tree of Life
#
# Because the tree changes as new species are discovered and other species are
# reclassified, etc, there's a Hierarchy object available for each version
# of the Tree of Life that's been imported, eg.
#
#   >> Hierarchy.all.map &:label
#   => [
#        "Species 2000 & ITIS Catalogue of Life: Annual Checklist 2007",
#        "Species 2000 & ITIS Catalogue of Life: Annual Checklist 2008"
#      ]
#
require 'invert' # TEMP - Ant and JRice are attempting a fix

class Hierarchy < SpeciesSchemaModel
  CACHE_ALL_ROWS = true
  belongs_to :agent           # This is the attribution.
  has_and_belongs_to_many :collection_types
  has_one :resource
  has_many :hierarchy_entries

  named_scope :browsable, :conditions => {:browsable => 1}


  alias entries hierarchy_entries
  
  def self.sort_by_user_or_agent_name(hierarchies)
    hierarchies.sort_by do |h|
      [ h.request_publish ? 0 : 1,
        h.browsable * -1,
        h.user_or_agent_or_label_name ]
    end
  end

  def self.browsable_by_label
    cached('browsable_by_label') do
      Hierarchy.browsable.sort_by {|h| h.form_label }
    end
  end

  def self.taxonomy_providers
    cached('taxonomy_providers') do
      ['Integrated Taxonomic Information System (ITIS)', 'CU*STAR Classification', 'NCBI Taxonomy', 'Index Fungorum', $DEFAULT_HIERARCHY_NAME].collect{|label| Hierarchy.find_by_label(label, :order => "hierarchy_group_version desc")}
    end
  end

  def self.iucn_hierarchies
    cached('iucn_hierarchies') do
      Hierarchy.find_all_by_id(Agent.iucn.resources.collect{ |r| r.hierarchy_id })
    end
  end

  def self.default
    cached_find(:label, $DEFAULT_HIERARCHY_NAME)
  end
  
  def self.gbif
    cached_find(:label, 'GBIF Nub Taxonomy')
  end

  # This is the first hierarchy we used, and we need it to serve "old" URLs (ie: /taxa/16222828 => Roenbergensis)
  def self.original
    cached_find(:label, "Species 2000 & ITIS Catalogue of Life: Annual Checklist 2007")
  end

  def self.eol_contributors
    cached_find(:label, "Encyclopedia of Life Contributors")
  end

  def self.ncbi
    cached('ncbi') do
      Hierarchy.find_by_label("NCBI Taxonomy", :order => "hierarchy_group_version desc")
    end
  end

  def self.browsable_for_concept(taxon_concept)
    Hierarchy.find_all_by_browsable(1, :select => { :hierarchies => [ :id, :label, :descriptive_label ] },
      :joins => "JOIN hierarchy_entries ON hierarchies.id=hierarchy_entries.hierarchy_id",
      :conditions => "hierarchy_entries.taxon_concept_id=#{taxon_concept.id}")
  end

  def form_label
    return descriptive_label unless descriptive_label.blank?
    return label
  end

  def attribution
    citable_agent = agent.citable
    citable_agent.display_string = label # To change the name from just "Catalogue of Life"
    return citable_agent
  end

  def kingdoms(params = {})
    # this is very hacky - another case where reading from the cache in development mode throws an error
    # becuase several classes have not been loaded yet. The only fix is to somehow load them before reading
    # from the cache
    HierarchyEntry
    Rank
    HierarchiesContent
    Name
    CanonicalForm
    Hierarchy.cached("kingdoms_for_#{id}") do
      add_include = []
      add_select = {}
      unless params[:include_stats].blank?
        add_include << :hierarchy_entry_stat
        add_select[:hierarchy_entry_stats] = '*'
      end
      if params[:include_common_names]
        add_include << {:taxon_concept => {:preferred_common_names => :name}}
        add_select[:taxon_concept_names] = :language_id
      end

      vis = [Visibility.visible.id, Visibility.preview.id]
      k = HierarchyEntry.core_relationships(:add_include => add_include, :add_select => add_select).find_all_by_hierarchy_id_and_parent_id_and_visibility_id(id, 0, vis)
      if params[:include_common_names]
        HierarchyEntry.sort_by_common_name(k, params[:common_name_language])
      else
        HierarchyEntry.sort_by_name(k)
      end
    end
  end
  
  def user_or_agent
    if resource && resource.content_partner && resource.content_partner.user
      resource.content_partner.user
    elsif agent
      agent
    else
      nil
    end
  end
  
  def user_or_agent_or_label_name
    if user_or_agent
      user_or_agent.full_name
    else
      label
    end
  end
end
