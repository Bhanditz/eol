module EOL
  # A relatively simple Enumerable class for handling the results from EOL's Solr search, since there's some sorting and
  # re-populating of the data that needs to happen before anything is displayed.
  class SearchResultsCollection

    include Enumerable

    attr_reader :results
    attr_reader :total_results

    def initialize(results, options = {})
      @results       = results
      @total_results = options[:total_results] || results.length
      @type          = options[:type] # Used to flag special behavior that gets the 'best' common name match
      @querystring   = options[:querystring]
      options[:lookup_trees] = true unless options[:lookup_trees] == false

      # The follwing are not yet options, but will be someday:
      @best_match_field_name         = 'best_matched_common_name'
      @default_best_match_field_name = 'preferred_common_name'
      @match_field_name              = 'common_name'
      @shown_as_field_name           = 'common_shown_as'

      if @type == :scientific
        @find_match                    = true
        @best_match_field_name         = 'best_matched_scientific_name'
        @default_best_match_field_name = 'preferred_scientific_name'
        @match_field_name              = 'scientific_name'
        @shown_as_field_name           = 'scientific_shown_as'
      else # common
        @find_match                    = true
      end
      
      # We don't actually want to do this next step unless we *know* the results are based on TaxonConcept... but, for the
      # time being, we always are.  In the future, this will want to be abstracted out, so that we inherit all the common
      # behaviour and add this behaviour if it's a TC-based search:
      update_results_with_current_data
      add_mini_tree_and_attribution if options[:lookup_trees]
      adapt_results_for_view
    end

    def each
      @results.each {|i| yield i }
    end

    def paginate(options)
      WillPaginate::Collection.create(options[:page], options[:per_page], @total_results) do |pager|
        pager.replace @results
      end
    end

    # This removes some of the 'work' from the view, providing convenient access to some of the more common information that
    # we want to see in the results
    def adapt_results_for_view
      results.map! do |result|
        result['id'] = result['taxon_concept_id'][0].to_i
        best_match_name = result[@best_match_field_name]
        best_match_name = best_match_name[0] if best_match_name.class == Array
        default_best_match_name = result[@default_best_match_field_name]
        default_best_match_name = default_best_match_name[0] if default_best_match_name.class == Array
        if (best_match_name.blank? or
            default_best_match_name.blank? or
            default_best_match_name.downcase == best_match_name.downcase)
          result[@shown_as_field_name] = '' 
        else 
          result[@shown_as_field_name] = "shown as '#{default_best_match_name}'"
        end
        result['top_image'] = result['top_image_id'] ? DataObject.find(result['top_image_id']) : nil rescue nil
        result['unknown']   = true if result['vetted_id'] and result['vetted_id'][0].to_i == Vetted.unknown.id
        result['untrusted'] = true if result['vetted_id'] and result['vetted_id'][0].to_i == Vetted.untrusted.id
        result['best_matched_common_name']     ||= result['preferred_common_name']
        result['best_matched_scientific_name'] ||= result['preferred_scientific_name']
        result
      end
    end

    # This is also a nice illustration of what the view expects to see.  ;)
    def self.adapt_old_tag_search_results_to_solr_style_results(results)
      results.map do |tag_result|
        tc = tag_result[0]
        dato = tag_result[1]
        common_name = tc.common_name(@session_hierarchy)
        scientific_name = tc.scientific_name(@session_hierarchy)
        {'taxon_concept_id'          => [tc.id],
         'id'                        => tc.id,
         'vetted_id'                 => [tc.vetted_id],
         'unknown'                   => tc.vetted_id == Vetted.unknown.id,
         'untrusted'                 => tc.vetted_id == Vetted.untrusted.id,
         'scientific_name'           => [scientific_name],
         'preferred_scientific_name' => [scientific_name],
         'best_matched_scientific_name' => scientific_name,
         'common_name'               => [common_name],
         'preferred_common_name'     => [common_name],
         'common_shown_as'           => '',
         'scientific_shown_as'       => '',
         'best_matched_common_name'  => common_name,
         'top_image'                 => dato,
         'top_image_id'              => dato.id }
      end
    end

  private
    
    def update_results_with_current_data
      taxon_concept_ids = @results.collect{|r| r['taxon_concept_id'][0]}
      @scientific_names = TaxonConcept.scientific_names_for_concepts(taxon_concept_ids, @session_hierarchy)
      @common_names = TaxonConcept.common_names_for_concepts(taxon_concept_ids, @session_hierarchy)
      
      @results.each do |result|
        result.merge!(get_current_data(result['taxon_concept_id'][0], result))
        repair_missing_match_fields(result)
        if @find_match
          find_best_match(result)
        else
          result.merge!(@best_match_field_name => result[@default_best_match_field_name]) # Show them the preferred name
        end
      end
    end
    
    def get_current_data(id, result)
      begin
        tc = TaxonConcept.find(id)
        raise if tc.nil?
        return {'preferred_scientific_name' => (@scientific_names[id] ||
                                                result["preferred_scientific_name"] || ''),
                'preferred_common_name'     => (@common_names[id] || result["preferred_common_name"] || ''),
                # There are some "expensive" operations done later, so store tc here:
                'taxon_concept'             => tc }
      # Really, we don't want to save these exceptions, since what good is a search result if the TC is missing?
      # However, tests sometimes create situations where this is possible and not "wrong", (creating TCs is expensive!) so:
      rescue ActiveRecord::RecordNotFound
        return {'preferred_common_name' => (result["preferred_common_name"][0] || ''),
                'preferred_scientific_name' => (result["preferred_scientific_name"][0] || ''),
                'taxon_concept' => nil }
      end
    end

    def find_best_match(search_result)
      return if search_result[@match_field_name].length <= 1 and search_result[@match_field_name].first.blank? # Nothing to do
      matches = create_sorted_list_of_intersection_distances(search_result[@match_field_name])
      best_name = search_result[@default_best_match_field_name]
      best_name = search_result[@default_best_match_field_name][0] if best_name.class == Array
      # if we have only 0s, return the preferred name (NOTE - this should no longer happen!):
      if matches.first[:intersection] == 0
        search_result[@best_match_field_name] = best_name
      else
        # if the best matches *include* the preferred name, use that:
        best_matches = best_matched_names(matches)
        if best_matches.include?(best_name.normalize)
          search_result[@best_match_field_name] = best_name
        else # Otherwise, just use the best match:
          search_result[@best_match_field_name] = matches.first[:name]
        end
      end
    end

    def create_sorted_list_of_intersection_distances(original_matches)
      matches = original_matches.clone
      querystrings = @querystring.normalize.split(' ').to_set
      matches.map! do |name|
        name_set  = name.normalize.split(' ').to_set
        intersect = name_set.intersection(querystrings)
        {:name => name, :intersection => intersect.size}
      end
      matches.sort_by {|pair| pair[:intersection] }.reverse 
    end

    def best_matched_names(names)
      best_intersection = names.first[:intersection]
      names.select {|pair| pair[:intersection] == best_intersection}.map {|pair| pair[:name].normalize }
    end

    def repair_missing_match_fields(result)
      result[@match_field_name]      ||= ['']
      result[@best_match_field_name] ||= ''
    end
    
    def add_mini_tree_and_attribution
      return nil unless @results
      taxon_concept_ids = @results.collect{|r| r['taxon_concept_id'][0]}
      ancestries = TaxonConcept.ancestries_for_concepts(taxon_concept_ids)
      hierarchies = TaxonConcept.hierarchies_for_concepts(taxon_concept_ids)
      @results.each do |result|
        tc = result["taxon_concept"]
        if !tc.blank? && ancestor_info = ancestries[tc.id]
          result["parent_scientific"] = ancestor_info['parent_name_string']
          result["ancestor_scientific"] = ancestor_info['grandparent_name_string']
        end
        if !tc.blank? && hierarchy = hierarchies[tc.id]
          result["recognized_by"] = hierarchy.label
        else
          result["recognized_by"] = 'unknown'
        end
      end
    end
  end
end

