# Basically, I made this quick little class because the sort method required in two places and it didn't belong in
# one or t'other.
class TaxonDataSet

  include Enumerable
  
  def initialize(rows, options = {})
    virtuoso_results = rows
    @taxon_concept = options[:taxon_concept]
    @language = options[:language] || Language.default
    KnownUri.add_to_data(virtuoso_results)
    DataPointUri.preload_data_point_uris!(virtuoso_results, @taxon_concept.try(:id))
    @data_point_uris = virtuoso_results.collect{ |r| r[:data_point_instance] }
    @data_point_uris = remove_duplicates(@data_point_uris)
    unless options[:preload] == false
      DataPointUri.preload_associations(@data_point_uris, [ :taxon_concept, :comments, :taxon_data_exemplars, { resource: :content_partner } ])
      DataPointUri.preload_associations(@data_point_uris.select{ |d| d.association? }, target_taxon_concept:
        [ { preferred_entry: { hierarchy_entry: { name: :ranked_canonical_form } } } ])
      TaxonConcept.load_common_names_in_bulk(@data_point_uris.select{ |d| d.association? }.collect(&:target_taxon_concept), @language.id)
      DataPointUri.initialize_labels_in_language(@data_point_uris, @language)
    end
    convert_units
  end

  # NOTE - this is not provided by Enumerable
  def [](which)
    @data_point_uris[which]
  end

  # NOTE - not provided by Enumerable.
  def delete_at(which)
    @data_point_uris.delete_at(which)
    self
  end

  # NOTE - not provided by Enumerable.
  def select(&block)
    @data_point_uris.select do
      yield
    end
  end

  def each
    @data_point_uris.each { |data_point_uri| yield(data_point_uri) }
  end

  def empty?
    @data_point_uris.nil? || @data_point_uris.empty?
  end

  # NOTE - this is 'destructive', since we don't ever need it to not be. If that changes, make the corresponding method and add a bang to this one.
  def sort
    last = KnownUri.count + 2
    @data_point_uris.sort_by! do |data_point_uri|
      attribute_label = EOL::Sparql.uri_components(data_point_uri.predicate_uri)[:label]
      attribute_pos = data_point_uri.predicate_known_uri ? data_point_uri.predicate_known_uri.position : last
      attribute_label = safe_downcase(attribute_label)
      value_label = safe_downcase(data_point_uri.value_string(@language))
      [ attribute_pos, attribute_label, value_label ]
    end
    self
  end

  def safe_downcase(what)
    what = what.to_s if what.respond_to?(:to_s)
    what.downcase if what.respond_to?(:downcase)
  end

  # Yet another NOT provided by Enumerable... grrrr...
  def select(&block)
    @data_point_uris.select { |data_point_uri| yield(data_point_uri) }
  end

  # Yet another NOT provided by Enumerable... grrrr...
  def delete_if(&block)
    @data_point_uris.delete_if { |data_point_uri| yield(data_point_uri) }
    self
  end

  # TODO - in my sample data (which had a single duplicate value for 'weight'), running this then caused the "more"
  # to go away.  :\  We may not care about such cases, though.
  def uniq
    h = {}
    @data_point_uris.each { |data_point_uri| h["#{data_point_uri.predicate}:#{data_point_uri.object}"] = data_point_uri }
    @data_point_uris = h.values
    self # Need to return self in order to get chains to work.  :\
  end

  def data_point_uris
    @data_point_uris.dup
  end

  def convert_units
    @data_point_uris.each do |data_point_uri|
      data_point_uri.convert_units
    end
  end

  # Returns a HASH where the keys are KnownUris and the values are ARRAYS of DataPointUris.
  def categorized
    categorized = @data_point_uris.group_by { |data_point_uri| data_point_uri.predicate_uri }
    categorized
  end

  def to_jsonld
    raise "Cannot build JSON+LD without taxon concept" unless @taxon_concept
    jsonld = { '@graph' => [ @taxon_concept.to_jsonld ] }
    if wikipedia_entry = @taxon_concept.wikipedia_entry
      jsonld['@graph'] << wikipedia_entry.mapping_jsonld
    end
    @taxon_concept.common_names.map do |tcn|
      jsonld['@graph'] << tcn.to_jsonld
    end
    @taxon_concept.hierarchy_entries.map do |he|
      unless he.scientific_synonyms.blank?
        jsonld['@graph'] << he.to_jsonld
      end
    end
    @data_point_uris.map do |dpuri|
      jsonld['@graph'] << dpuri.to_jsonld(metadata: true)
    end
    fill_context(jsonld)
    jsonld
  end

  def remove_duplicates(data_point_uris)
    if !data_point_uris.nil? && data_point_uris.count > 0
      filtered = Hash.new
      filtered[:key] = []
      begin
        dpo = data_point_uris.first
        filtered[:key] << dpo
        data_point_uris = data_point_uris.reject{ |d| d.predicate == dpo.predicate && d.object == dpo.object } 
      end while data_point_uris.count > 0 
      return filtered[:key]
    end
    return data_point_uris
  end
  
  private

  def fill_context(jsonld)
    default_context(jsonld)
    context_from_uris(jsonld)
  end

  def default_context(jsonld)
    # TODO: @context doesn't need all of these. Look through the @graph and
    # add things as needed based on the Sparql headers, then add the @ids.
    jsonld['@context'] = {
      'dc' => 'http://purl.org/dc/terms/',
      'dwc' => 'http://rs.tdwg.org/dwc/terms/',
      'eol' => 'http://eol.org/schema/',
      'eolterms' => 'http://eol.org/schema/terms/',
      'rdfs' => 'http://www.w3.org/2000/01/rdf-schema#',
      'gbif' => 'http://rs.gbif.org/terms/1.0/',
      'foaf' => 'http://xmlns.com/foaf/0.1/',
      'dwc:taxonID' => { '@type' => '@id' },
      'dwc:resourceID' => { '@type' => '@id' },
      'dwc:relatedResourceID' => { '@type' => '@id' },
      'dwc:relationshipOfResource' => { '@type' => '@id' },
      'dwc:vernacularName' => { '@container' => '@language' },
      'eol:associationType' => { '@type' => '@id' },
      'rdfs:label' => { '@container' => '@language' } }
    jsonld
  end

  def context_from_uris(jsonld)
    jsonld['@graph'].each do |graph|
      graph.keys.each do |key|
        if key.is_a? KnownUri
          value = graph.delete(key)
          if graph.has_key(key.name)
            graph[key.name] = Array(graph[key.name]) << value
          else
            jsonld['@context'][key.name] = key.uri
            graph[key.name] = value
          end
        end
      end
    end
  end
end
