unless data_object.blank?
  xml.dataObject do
    xml.dataObjectID data_object.guid
    if taxon_concept_id.blank?
      xml.taxonConceptID data_object.first_taxon_concept.id unless data_object.first_taxon_concept.blank?
    else
      xml.taxonConceptID taxon_concept_id
    end
    xml.dataType data_object.data_type.schema_value
    
    unless minimal
      xml.mimeType data_object.mime_type.label unless data_object.mime_type.blank?
      
      if udo = data_object.users_data_object
        xml.agent data_object.user.full_name, :homepage => "", :role => (AgentRole.author.label.downcase rescue nil)
        xml.agent data_object.user.full_name, :homepage => "", :role => (AgentRole.provider.label.downcase rescue nil)
      else
        for ado in data_object.agents_data_objects
          next unless ado.agent
          xml.agent ado.agent.full_name, :homepage => ado.agent.homepage, :role => (ado.agent_role.label.downcase rescue nil)
        end
        xml.agent data_object.content_partner.name, :homepage => data_object.content_partner.homepage, :role => (AgentRole.provider.label.downcase rescue nil) if data_object.content_partner
      end
      
      xml.dcterms :created, data_object.object_created_at unless data_object.object_created_at.blank?
      xml.dcterms :modified, data_object.object_modified_at unless data_object.object_modified_at.blank?
      xml.dc :title, data_object.object_title unless data_object.object_title.blank?
      xml.dc :language, data_object.language.iso_639_1 unless data_object.language.blank?
      xml.license data_object.license.source_url unless data_object.license.blank?
      xml.dc :rights, data_object.rights_statement unless data_object.rights_statement.blank?
      xml.dcterms :rightsHolder, data_object.rights_holder unless data_object.rights_holder.blank?
      xml.dcterms :bibliographicCitation, data_object.bibliographic_citation unless data_object.bibliographic_citation.blank?
      # leaving out audience
      xml.dc :source, data_object.source_url unless data_object.source_url.blank?
    end
    
    if data_object.is_text?
      if data_object.created_by_user?
        data_object.toc_items.each do |toci|
          toci.info_items.each do |ii|
            xml.subject ii.schema_value unless ii.schema_value.blank?
          end
        end
      else
        data_object.info_items.each do |ii|
          xml.subject ii.schema_value unless ii.schema_value.blank?
        end
      end
    end
    
    unless minimal
      xml.dc :description, data_object.description unless data_object.description.blank?
      xml.mediaURL data_object.object_url unless data_object.object_url.blank?
      if data_object.is_image?
        xml.mediaURL DataObject.image_cache_path(data_object.object_cache_url, :orig, $SINGLE_DOMAIN_CONTENT_SERVER) unless data_object.object_cache_url.blank?
        xml.thumbnailURL DataObject.image_cache_path(data_object.object_cache_url, '98_68', $SINGLE_DOMAIN_CONTENT_SERVER) unless data_object.object_cache_url.blank?
      elsif data_object.is_video?
        xml.mediaURL data_object.video_url unless data_object.video_url.blank? || data_object.video_url == data_object.object_url
        xml.thumbnailURL DataObject.image_cache_path(data_object.thumbnail_cache_url, '260_190', $SINGLE_DOMAIN_CONTENT_SERVER) unless data_object.thumbnail_cache_url.blank?
      elsif data_object.is_sound?
        xml.mediaURL data_object.sound_url unless data_object.sound_url.blank? || data_object.sound_url == data_object.object_url
        xml.thumbnailURL DataObject.image_cache_path(data_object.thumbnail_cache_url, '260_190', $SINGLE_DOMAIN_CONTENT_SERVER) unless data_object.thumbnail_cache_url.blank?
      end
      xml.location data_object.location unless data_object.location.blank?
      
      unless data_object.latitude == 0 && data_object.longitude == 0 && data_object.altitude == 0
        xml.geo :Point do
          xml.geo :lat, data_object.latitude unless data_object.latitude == 0
          xml.geo :long, data_object.longitude unless data_object.longitude == 0
          xml.geo :alt, data_object.altitude unless data_object.altitude == 0
        end
      end
      
      data_object.published_refs.each do |r|
        xml.reference r.full_reference
      end
    end
    
    xml.additionalInformation do
      xml.dataSubtype data_object.data_subtype.label if data_object.data_subtype
      xml.vettedStatus data_object.association_with_best_vetted_status.vetted.label if data_object.association_with_best_vetted_status
      xml.dataRating data_object.data_rating
    end
  end
end
