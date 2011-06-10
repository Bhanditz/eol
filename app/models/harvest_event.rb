class HarvestEvent < SpeciesSchemaModel

  belongs_to :resource
  has_many :data_objects_harvest_events
  has_many :data_objects, :through => :data_objects_harvest_events
  has_and_belongs_to_many :hierarchy_entries

  before_destroy :remove_related_data_objects

  def self.last_published
    last_published=HarvestEvent.find(:all,:conditions=>"published_at != 'null'",:limit=>1,:order=>'published_at desc')
    return (last_published.blank? ? nil : last_published[0])
  end

  def self.data_object_ids_from_harvest(harvest_event_id)
    query = "Select dohe.data_object_id
    From harvest_events he
    Join data_objects_harvest_events dohe ON he.id = dohe.harvest_event_id
    Where he.id = #{harvest_event_id}"
    rset = self.find_by_sql [query]
    arr=[]
    for fld in rset
	    arr << fld["data_object_id"]
    end
    return arr
  end

  def content_partner
    resource.content_partner
  end

  def taxa_contributed(he_id)
    SpeciesSchemaModel.connection.execute(
      "SELECT n.string scientific_name, he.taxon_concept_id, (dohe.data_object_id IS NOT null) has_data_object
         FROM harvest_events_hierarchy_entries hehe
           JOIN hierarchy_entries he ON (hehe.hierarchy_entry_id = he.id)
           JOIN names n ON (he.name_id = n.id)
           LEFT JOIN data_objects_hierarchy_entries dohe ON (hehe.hierarchy_entry_id = dohe.hierarchy_entry_id)
         WHERE hehe.harvest_event_id=#{he_id.to_i}
         GROUP BY he.taxon_concept_id
         ORDER BY (dohe.data_object_id IS NULL), n.string")
  end

  def curated_data_objects(params = {})
    year = params[:year] || nil
    month = params[:month] || nil

    unless year || month
      year = Time.now.year if year.nil?
      month = Time.now.month if month.nil?
    end

    year = Time.now.year if year.nil?
    month = 0 if month.nil?
    lower_date_range = "#{year}-#{month}-00"
    if month == 0
      upper_date = Time.local(year, 1) + 1.year
      upper_date_range = "#{upper_date.year}-#{upper_date.month}-00"
    else
      upper_date = Time.local(year, month) + 1.month
      upper_date_range = "#{upper_date.year}-#{upper_date.month}-00"
    end

    date_condition = ""
    if lower_date_range
      date_condition = "AND curator_activity_logs.updated_at BETWEEN '#{lower_date_range}' AND '#{upper_date_range}'"
    end

    curator_activity_logs = CuratorActivityLog.find(:all,
      :joins => "JOIN #{DataObjectsHarvestEvent.full_table_name} dohe ON (curator_activity_logs.object_id=dohe.data_object_id)",
      :conditions => "curator_activity_logs.action_with_object_id IN (#{ActionWithObject.trusted.id}, #{ActionWithObject.untrusted.id}, #{ActionWithObject.inappropriate.id}, #{ActionWithObject.delete.id}) AND curator_activity_logs.changeable_object_type_id = #{ChangeableObjectType.data_object.id} AND dohe.harvest_event_id = 2 #{date_condition}",
      :select => 'id')

    curator_activity_logs = CuratorActivityLog.find_all_by_id(curator_activity_logs.collect{ |ah| ah.id },
      :include => [ :user, :comment, :action_with_object, :changeable_object_type,
        { :data_object => { :hierarchy_entries => :name } } ],
      :select => {
        :curator_activity_logs => :updated_at,
        :users => [ :given_name, :family_name ],
        :comments => :body,
        :data_objects => [:object_cache_url, :source_url, :data_type_id ],
        :hierarchy_entries => [ :published, :visibility_id, :taxon_concept_id ],
        :names => :string })
    curator_activity_logs.sort_by{ |ah| Invert(ah.id) }
  end

protected

  def remove_related_data_objects
    # get data objects
    data_objects=SpeciesSchemaModel.connection.select_values("SELECT do.id FROM data_objects do JOIN data_objects_harvest_events dohe ON dohe.data_object_id=do.id WHERE dohe.status_id != #{Status.unchanged.id} and dohe.harvest_event_id=#{self.id}").join(",")
    #remove data_objects_hierarchy_entries
    SpeciesSchemaModel.connection.execute("DELETE FROM data_objects_hierarchy_entries WHERE data_object_id IN (#{data_objects})")
    #remove data objects that have been inserted or updated
    SpeciesSchemaModel.connection.execute("DELETE FROM data_objects WHERE id in (#{data_objects})")
    #remove data_objects_harvest_events
    DataObjectsHarvestEvent.delete_all(['harvest_event_id=?',self.id])
    #remove harvest_events_taxa
    HarvestEventsHierarchyEntry.delete_all(['harvest_event_id=?',self.id])
  end

end
