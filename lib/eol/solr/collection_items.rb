module EOL
  module Solr
    class CollectionItems
      def self.search_with_pagination(collection_id, options = {})
        options[:page]        ||= 1
        options[:per_page]    ||= 50
        options[:per_page]      = 50 if options[:per_page] == 0

        response = solr_search(collection_id, options)
        total_results = response['response']['numFound']
        results = response['response']['docs']
        add_resource_instances!(results)

        results = WillPaginate::Collection.create(options[:page], options[:per_page], total_results) do |pager|
          pager.replace(results)
        end
        results
      end

      private

      def self.add_resource_instances!(docs)
        return if docs.empty?
        ids = docs.map{ |d| d['collection_item_id'] }
        instances = CollectionItem.find_all_by_id(ids)
        return if ids.empty?
        raise "No CollectionItem instances found from IDs #{ids.join(', ')}.  Rebuild indexes." if instances.empty?
        docs.each do |d|
          d['instance'] = instances.detect{ |i| i.id == d['collection_item_id'].to_i }
        end

        add_community!(docs.select{ |d| d['object_type'] == 'Community' })
        add_collection!(docs.select{ |d| d['object_type'] == 'Collection' })
        add_user!(docs.select{ |d| d['object_type'] == 'User' })
        add_taxon_concept!(docs.select{ |d| d['object_type'] == 'TaxonConcept' })
        add_data_object!(docs.select{ |d| ['Image', 'Video', 'Sound', 'Text', 'DataObject'].include? d['object_type'] })
      end

      def self.add_community!(docs)
        return if docs.empty?
        ids = docs.map{ |d| d['object_id'] }
        instances = Community.find_all_by_id(ids)
        docs.map! do |d|
          d['instance'].object = instances.detect{ |i| i.id == d['object_id'].to_i }
        end
      end

      def self.add_collection!(docs)
        return if docs.empty?
        ids = docs.map{ |d| d['object_id'] }
        instances = Collection.find_all_by_id(ids)
        docs.map! do |d|
          d['instance'].object = instances.detect{ |i| i.id == d['object_id'].to_i }
        end
      end

      def self.add_user!(docs)
        return if docs.empty?
        ids = docs.map{ |d| d['object_id'] }
        instances = User.find_all_by_id(ids)
        docs.map! do |d|
          d['instance'].object = instances.detect{ |i| i.id == d['object_id'].to_i }
        end
      end

      def self.add_taxon_concept!(docs)
        return if docs.empty?
        includes = [
          { :published_hierarchy_entries => [ { :name => :canonical_form } , :hierarchy, :vetted, { :flattened_ancestors => { :ancestor => [ :name, :rank ] } } ] },
          { :preferred_common_names => [ :name, :language ] },
          { :taxon_concept_content => :image_object } ]
        selects = {
          :taxon_concepts => '*',
          :hierarchy_entries => [ :id, :rank_id, :identifier, :hierarchy_id, :parent_id, :published, :visibility_id, :lft, :rgt, :taxon_concept_id, :source_url ],
          :names => [ :string, :italicized, :canonical_form_id ],
          :canonical_forms => [ :string ],
          :hierarchies => [ :agent_id, :browsable, :outlink_uri, :label ],
          :vetted => :view_order,
          :hierarchy_entries_flattened => '*',
          :taxon_concept_content => [ :taxon_concept_id, :image_object_id ],
          :data_objects => [ :id, :object_cache_url, :data_type_id ]
        }
        ids = docs.map{ |d| d['object_id'] }
        instances = TaxonConcept.core_relationships(:include => includes, :select => selects).find_all_by_id(ids)
        docs.each do |d|
          if d['instance']
            d['instance'].object = instances.detect{ |i| i.id == d['object_id'].to_i }
          end
        end
      end

      def self.add_data_object!(docs)
        return if docs.empty?
        includes = [ { :hierarchy_entries => { :name => :canonical_form } }, :curated_data_objects_hierarchy_entries, { :toc_items => :translations } ]
        selects = {
          :data_objects => '*',
          :translated_table_of_contents => '*',
          :hierarchy_entries => [ :published, :visibility_id, :taxon_concept_id ],
          :names => :string,
          :canonical_forms => :string
        }
        ids = docs.map{ |d| d['object_id'] }
        instances = DataObject.core_relationships(:include => includes, :select => selects).find_all_by_id(ids)
        docs.each do |d|
          if i = instances.detect{ |i| i.id == d['object_id'].to_i }
            if d['instance'] 
              d['instance'].object = i
            end
          end
        end
      end

      def self.solr_search(collection_id, options = {})
        url =  $SOLR_SERVER + $SOLR_COLLECTION_ITEMS_CORE + '/select/?wt=json&q=' + CGI.escape(%Q[{!lucene}])
        url << CGI.escape(%Q[(collection_id:#{collection_id})])

        # add facet filtering
        if options[:facet_type]
          object_type = nil
          case options[:facet_type].downcase
          when 'taxa', 'taxonconcept', 'taxon'
            object_type = 'TaxonConcept'
          when 'articles', 'text'
            object_type = 'Text'
          when 'videos', 'video'
            object_type = 'Video'
          when 'images', 'image'
            object_type = 'Image'
          when 'sounds', 'sound'
            object_type = 'Sound'
          when 'communities', 'community'
            object_type = 'Community'
          when 'people', 'user'
            object_type = 'User'
          when 'collections', 'collection'
            object_type = 'Collection'
          end
          url << "&fq=object_type:#{object_type}" if object_type
        end

        # add sorting
        if options[:sort_by] == SortStyle.newest
          url << '&sort=date_modified+desc'
        elsif options[:sort_by] == SortStyle.oldest
          url << '&sort=date_modified+asc'
        elsif options[:sort_by] == SortStyle.alphabetical
          url << '&sort=title_exact+asc'
        elsif options[:sort_by] == SortStyle.reverse_alphabetical
          url << '&sort=title_exact+desc'
        elsif options[:sort_by] == SortStyle.richness
          url << '&sort=richness_score+desc'
        elsif options[:sort_by] == SortStyle.rating
          url << '&sort=data_rating+desc'
        end

        # add paging
        limit  = options[:per_page] ? options[:per_page].to_i : 10
        page = options[:page] ? options[:page].to_i : 1
        offset = (page - 1) * limit
        url << '&start=' << URI.encode(offset.to_s)
        url << '&rows='  << URI.encode(limit.to_s)
        res = open(url).read
        JSON.load res
      end

      def self.get_facet_counts(collection_id)
        url =  $SOLR_SERVER + $SOLR_COLLECTION_ITEMS_CORE + '/select/?wt=json&q=' + CGI.escape(%Q[{!lucene}])
        url << CGI.escape(%Q[collection_id:#{collection_id}])
        url << '&facet.field=object_type&facet=on&rows=0'
        res = open(url).read
        response = JSON.load(res)

        facets = {}
        f = response['facet_counts']['facet_fields']['object_type']
        f.each_with_index do |rt, index|
          next if index % 2 == 1 # if its odd, skip this. Solr has a strange way of returning the facets in JSON
          facets[rt] = f[index+1]
        end
        total_results = response['response']['numFound']
        facets['All'] = total_results
        facets
      end
    end
  end
end
