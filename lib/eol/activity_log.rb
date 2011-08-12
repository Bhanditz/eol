# ActivityLog reads from curator_activity_logs, comments, users_data_objects,
# collection_activity_logs, community_activity_logs ...Note that EVERY table should have a user_id associated
# with it, as well as a foreign key to ... something it affected... as well as another FK to the Activity table
# explaining what kind of activity took place (and, thus, which partial to render).
module EOL

  class ActivityLog

    def self.find(source, options = {})
      if source
        klass = source.class.name
      end
      find_activities(klass, source, options)
    end

    def self.global(max = 0)
      max = $ACTIVITIES_ON_HOME_PAGE if max <= 0
      return find(nil, :per_page => max)
    end

    def self.find_activities(klass, source, options = {})
      options[:per_page] ||= 20
      options[:page] ||= 1
      case klass
      when nil
        global_activities(options)
      when "User"
        if options[:news]
          user_news_activities(source, options)
        else
          user_activities(source, options)
        end
      when "Community"
        community_activities(source, options)
      when "Collection"
        collection_activities(source, options)
      when "DataObject"
        data_object_activities(source, options)
      when "TaxonConcept"
        taxon_concept_activities(source, options)
      else # Anything else that you make loggable will track comments and ONLY comments:
        other_activities(source, options)
      end
    end

    def self.global_activities(options = {})
      EOL::Solr::ActivityLog.search_with_pagination("*:*", options.merge({ :group_field => 'user_id' }))
    end

    # TODO - it would make more sense to move these methods to the source models, passed in as an argument when the
    # loggable is declared. ...That way defining new loggable classes would not have to happen here.

    def self.user_activities(source, options = {})
      results = EOL::Solr::ActivityLog.search_with_pagination("feed_type_affected:User AND feed_type_primary_key:#{source.id}", options)
    end

    def self.user_news_activities(source, options = {})
      query = "(feed_type_affected:UserNews AND feed_type_primary_key:#{source.id})"
      if source.existing_watch_collection
        query += " OR (feed_type_affected:Collection AND feed_type_primary_key:#{source.existing_watch_collection.id} NOT user_id:#{source.id})"
      end
      results = EOL::Solr::ActivityLog.search_with_pagination(query, options)
    end

    def self.community_activities(source, options = {})
      results = EOL::Solr::ActivityLog.search_with_pagination("feed_type_affected:Community AND feed_type_primary_key:#{source.id}", options)
    end

    def self.collection_activities(source, options = {})
      results = EOL::Solr::ActivityLog.search_with_pagination("feed_type_affected:Collection AND feed_type_primary_key:#{source.id}", options)
    end

    def self.data_object_activities(source, options = {})
      results = EOL::Solr::ActivityLog.search_with_pagination("feed_type_affected:DataObject AND feed_type_primary_key:#{source.id}", options)
    end

    def self.taxon_concept_activities(source, options = {})
      results = EOL::Solr::ActivityLog.search_with_pagination("(feed_type_affected:TaxonConcept OR feed_type_affected:AncestorTaxonConcept) AND feed_type_primary_key:#{source.id}", options)
    end

    def self.other_activities(source, options = {})
      results = EOL::Solr::ActivityLog.search_with_pagination("feed_type_affected:NOTHING", options)
    end
  end
end
