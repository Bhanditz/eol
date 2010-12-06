require File.dirname(__FILE__) + '/../spec_helper'

require 'solr_api'
def recreate_indexes
  solr = SolrAPI.new
  solr.delete_all_documents
  solr.build_indexes
end

def check_api_key(url, user)
  visit(url)
  log = ApiLog.last
  log.request_uri.should == url
  log.key.should_not be_nil
  log.key.should == user.api_key
  log.user_id.should == user.id
end

describe 'EOL APIs' do
  before(:all) do
    truncate_all_tables
    load_foundation_cache
    Capybara.reset_sessions!
    @user = User.gen(:api_key => User.generate_key)
  end
  
  describe 'ping' do 
    it 'should show success message' do
      visit("/api/ping")
      xml_response = Nokogiri.XML(body)
      xml_response.xpath('//response/message').inner_text.should == 'Success'
    end
    
    it 'should take api key and save it to the log' do
      check_api_key("/api/ping?key=#{@user.api_key}", @user)
    end
  end
  
  describe 'pages and data objects' do
    before(:all) do
      @overview        = TocItem.overview
      @overview_text   = 'This is a test Overview, in all its glory'
      @distribution      = TocItem.find_by_label('Ecology and Distribution')
      @distribution_text = 'This is a test Distribution'
      @description       = TocItem.find_by_label('Description')
      @description_text  = 'This is a test Description, in all its glory'
      @toc_item_2      = TocItem.gen(:view_order => 2)
      @toc_item_3      = TocItem.gen(:view_order => 3)
      @image_1         = Factory.next(:image)
      @image_2         = Factory.next(:image)
      @image_3         = Factory.next(:image)
      @video_1_text    = 'First Test Video'
      @video_2_text    = 'Second Test Video'
      @video_3_text    = 'YouTube Test Video'
    
      @taxon_concept   = build_taxon_concept(
         :flash           => [{:description => @video_1_text}, {:description => @video_2_text}],
         :youtube         => [{:description => @video_3_text}],
         :images          => [{:object_cache_url => @image_1}, {:object_cache_url => @image_2},
                              {:object_cache_url => @image_3}],
         :toc             => [{:toc_item => @overview, :description => @overview_text, :license => License.by_nc}, 
                              {:toc_item => @distribution, :description => @distribution_text, :license => License.cc}, 
                              {:toc_item => @description, :description => @description_text, :license => License.public_domain},
                              {:toc_item => @description, :description => 'test uknown', :vetted => Vetted.unknown, :license => License.by_nc},
                              {:toc_item => @description, :description => 'test untrusted', :vetted => Vetted.untrusted, :license => License.cc}])
      @taxon_concept.add_common_name_synonym(Faker::Eol.common_name.firstcap, :agent => Agent.last, :language => Language.english)
    
    
      @object = DataObject.create(
        :guid                   => '803e5930803396d4f00e9205b6b2bf21',
        :identifier             => 'doid',
        :data_type              => DataType.text,
        :mime_type              => MimeType.find_or_create_by_label('text/html'),
        :object_title           => 'default title',
        :language               => Language.find_or_create_by_iso_639_1('en'),
        :license                => License.by_nc,
        :rights_statement       => 'default rights © statement',
        :rights_holder          => 'default rights holder',
        :bibliographic_citation => 'default citation',
        :source_url             => 'http://example.com/12345',
        :description            => 'default description <a href="http://www.eol.org">with some html</a>',
        :object_url             => '',
        :thumbnail_url          => '',
        :location               => 'default location',
        :latitude               => 1.234,
        :longitude              => 12.34,
        :altitude               => 123.4,
        :vetted                 => Vetted.trusted,
        :visibility             => Visibility.visible,
        :published              => 1,
        :curated                => 0)
      @object.info_items << InfoItem.find_or_create_by_label('Distribution')
      @object.save!
    
      AgentsDataObject.create(:data_object_id => @object.id,
                              :agent_id => Agent.gen(:full_name => 'agent one', :homepage => 'http://homepage.com/?agent=one&profile=1').id,
                              :agent_role => AgentRole.gen(:label => 'writer'),
                              :view_order => 1)
      AgentsDataObject.create(:data_object_id => @object.id,
                              :agent => Agent.gen(:full_name => 'agent two'),
                              :agent_role => AgentRole.gen(:label => 'editor'),
                              :view_order => 2)
      @object.refs << Ref.gen(:full_reference => 'first reference')
      @object.refs << Ref.gen(:full_reference => 'second reference')
      @taxon_concept.add_data_object(@object)
      
      @text = @taxon_concept.data_objects.delete_if{|d| d.data_type_id != DataType.text.id}
      @images = @taxon_concept.data_objects.delete_if{|d| d.data_type_id != DataType.image.id}
    end
  
    # after(:all) do
    #   truncate_all_tables
    # end
  
  
  
    # Pages
      
    it 'should return only published concepts' do
      @taxon_concept.published = 0
      @taxon_concept.save!
    
      visit("/api/pages/#{@taxon_concept.id}")
      body.should include('<error>')
      body.should include('</response>')
    
      @taxon_concept.published = 1
      @taxon_concept.save!
    end
      
    it 'should show one data object per category' do
      visit("/api/pages/#{@taxon_concept.id}")
      xml_response = Nokogiri.XML(body)
      xml_response.xpath('//xmlns:taxon/xmlns:dataObject[xmlns:dataType="http://purl.org/dc/dcmitype/StillImage"]').length.should == 1
      xml_response.xpath('//xmlns:taxon/xmlns:dataObject[xmlns:dataType="http://purl.org/dc/dcmitype/Text"]').length.should == 1
      xml_response.xpath('//xmlns:taxon/xmlns:dataObject[xmlns:dataType="http://purl.org/dc/dcmitype/MovingImage"]').length.should == 1
    
      # shouldnt get details without asking for them
      xml_response.xpath('//xmlns:taxon/xmlns:dataObject/xmlns:mimeType').length.should == 0
      xml_response.xpath('//xmlns:taxon/xmlns:dataObject/dc:description').length.should == 0
    end
      
    it 'should be able to limit number of media returned' do
      visit("/api/pages/#{@taxon_concept.id}?images=2")
      xml_response = Nokogiri.XML(body)
      xml_response.xpath('//xmlns:taxon/xmlns:dataObject[xmlns:dataType="http://purl.org/dc/dcmitype/StillImage"]').length.should == 2
      xml_response.xpath('//xmlns:taxon/xmlns:dataObject[xmlns:dataType="http://purl.org/dc/dcmitype/Text"]').length.should == 1
      xml_response.xpath('//xmlns:taxon/xmlns:dataObject[xmlns:dataType="http://purl.org/dc/dcmitype/MovingImage"]').length.should == 1
      
      visit("/api/pages/#{@taxon_concept.id}?videos=2")
      xml_response = Nokogiri.XML(body)
      xml_response.xpath('//xmlns:taxon/xmlns:dataObject[xmlns:dataType="http://purl.org/dc/dcmitype/StillImage"]').length.should == 1
      xml_response.xpath('//xmlns:taxon/xmlns:dataObject[xmlns:dataType="http://purl.org/dc/dcmitype/Text"]').length.should == 1
      xml_response.xpath('//xmlns:taxon/xmlns:dataObject[xmlns:dataType="http://purl.org/dc/dcmitype/MovingImage"]').length.should == 2
    end
      
    it 'should be able to limit number of text returned' do
      visit("/api/pages/#{@taxon_concept.id}?text=2")
      xml_response = Nokogiri.XML(body)
      xml_response.xpath('//xmlns:taxon/xmlns:dataObject[xmlns:dataType="http://purl.org/dc/dcmitype/StillImage"]').length.should == 1
      xml_response.xpath('//xmlns:taxon/xmlns:dataObject[xmlns:dataType="http://purl.org/dc/dcmitype/Text"]').length.should == 2
      xml_response.xpath('//xmlns:taxon/xmlns:dataObject[xmlns:dataType="http://purl.org/dc/dcmitype/MovingImage"]').length.should == 1
    end
      
    it 'should be able to take a | delimited list of subjects' do
      visit("/api/pages/#{@taxon_concept.id}?images=0&text=3&subjects=TaxonBiology&details=1")
      xml_response = Nokogiri.XML(body)
      xml_response.xpath('//xmlns:taxon/xmlns:dataObject[xmlns:dataType="http://purl.org/dc/dcmitype/Text"]').length.should == 1
    
      visit("/api/pages/#{@taxon_concept.id}?images=0&text=3&subjects=Distribution&details=1")
      xml_response = Nokogiri.XML(body)
      xml_response.xpath('//xmlns:taxon/xmlns:dataObject[xmlns:dataType="http://purl.org/dc/dcmitype/Text"]').length.should == 2
    
      # %7C == |
      visit("/api/pages/#{@taxon_concept.id}?images=0&text=3&subjects=TaxonBiology%7CDistribution&details=1")
      xml_response = Nokogiri.XML(body)
      xml_response.xpath('//xmlns:taxon/xmlns:dataObject[xmlns:dataType="http://purl.org/dc/dcmitype/Text"]').length.should == 3
    end
      
    it 'should be able to return ALL subjects' do 
      visit("/api/pages/#{@taxon_concept.id}?text=5&subjects=all&vetted=1")
      xml_response = Nokogiri.XML(body)
      xml_response.xpath('//xmlns:taxon/xmlns:dataObject[xmlns:dataType="http://purl.org/dc/dcmitype/Text"]').length.should == 4
    end
    
    it 'should be able to take a | delimited list of licenses' do
      visit("/api/pages/#{@taxon_concept.id}?images=0&text=3&licenses=cc-by-nc&details=1")
      xml_response = Nokogiri.XML(body)
      xml_response.xpath('//xmlns:taxon/xmlns:dataObject[xmlns:dataType="http://purl.org/dc/dcmitype/Text"]').length.should == 2
      
      visit("/api/pages/#{@taxon_concept.id}?images=0&text=3&licenses=pd&details=1")
      xml_response = Nokogiri.XML(body)
      xml_response.xpath('//xmlns:taxon/xmlns:dataObject[xmlns:dataType="http://purl.org/dc/dcmitype/Text"]').length.should == 1
      
      # %7C == |
      visit("/api/pages/#{@taxon_concept.id}?images=0&text=3&licenses=cc-by-nc%7Cpd&details=1")
      xml_response = Nokogiri.XML(body)
      xml_response.xpath('//xmlns:taxon/xmlns:dataObject[xmlns:dataType="http://purl.org/dc/dcmitype/Text"]').length.should == 3
    end
      
    it 'should be able to return ALL licenses' do 
      visit("/api/pages/#{@taxon_concept.id}?text=5&licenses=all&subjects=all&vetted=1")
      xml_response = Nokogiri.XML(body)
      xml_response.xpath('//xmlns:taxon/xmlns:dataObject[xmlns:dataType="http://purl.org/dc/dcmitype/Text"]').length.should == 4
    end
    
      
    it 'should be able to get more details on data objects' do
      visit("/api/pages/#{@taxon_concept.id}?image=1&text=0&details=1")
      xml_response = Nokogiri.XML(body)
      # should get 1 image, 1 video and their metadata
      xml_response.xpath('//xmlns:taxon/xmlns:dataObject[xmlns:dataType="http://purl.org/dc/dcmitype/StillImage"]').length.should == 1
      xml_response.xpath('//xmlns:taxon/xmlns:dataObject[xmlns:dataType="http://purl.org/dc/dcmitype/MovingImage"]').length.should == 1
      xml_response.xpath('//xmlns:taxon/xmlns:dataObject/xmlns:mimeType').length.should == 2
      xml_response.xpath('//xmlns:taxon/xmlns:dataObject/dc:description').length.should == 2
    end
    
    it 'should not filter vetted objects by default' do
      visit("/api/pages/#{@taxon_concept.id}?images=0&text=10&videos=0&details=1")
      xml_response = Nokogiri.XML(body)
      last_guid = xml_response.xpath('//xmlns:taxon/xmlns:dataObject[xmlns:dataType="http://purl.org/dc/dcmitype/Text"][last()]/dc:identifier').inner_text
      data_object = DataObject.find_by_guid(last_guid)
      data_object.vetted_id.should == Vetted.untrusted.id
    end
    
    it 'should filter out all be vetted objects' do
      visit("/api/pages/#{@taxon_concept.id}?images=0&text=10&videos=0&details=1&vetted=1")
      xml_response = Nokogiri.XML(body)
      last_guid = xml_response.xpath('//xmlns:taxon/xmlns:dataObject[xmlns:dataType="http://purl.org/dc/dcmitype/Text"][last()]/dc:identifier').inner_text
      data_object = DataObject.find_by_guid(last_guid)
      data_object.vetted_id.should == Vetted.trusted.id
    end
    
    it 'should filter out untrusted objects' do
      visit("/api/pages/#{@taxon_concept.id}?images=0&text=10&videos=0&details=1&vetted=2")
      xml_response = Nokogiri.XML(body)
      last_guid = xml_response.xpath('//xmlns:taxon/xmlns:dataObject[xmlns:dataType="http://purl.org/dc/dcmitype/Text"][last()]/dc:identifier').inner_text
      data_object = DataObject.find_by_guid(last_guid)
      data_object.vetted_id.should == Vetted.unknown.id
    end
    
    
      
    it 'should be able to render an HTML version of the page' do
      visit("/api/pages/#{@taxon_concept.id}?subjects=Distribution&text=2&format=html")
      body.should include '<html'
      body.should include '</html>'
      body.should match /<title>\s*EOL API:\s*#{@taxon_concept.entry.name_object.string}/
      body.should include @object.description
      body.should include DataObject.cache_url_to_path(@taxon_concept.images[0].object_cache_url)
    end
      
    it 'should be able to toggle common names' do
      visit("/api/pages/#{@taxon_concept.id}")
      body.should_not include '<commonName'
    
      visit("/api/pages/#{@taxon_concept.id}?common_names=1")
      body.should include '<commonName'
    end
    
    it 'should be able to render a JSON response' do
      visit("/api/pages/#{@taxon_concept.id}.json?subjects=all&common_names=1&details=1&text=1&images=1")
      response_object = JSON.parse(body)
      response_object.class.should == Hash
      response_object['identifier'].should == @taxon_concept.id
      response_object['scientificName'].should == @taxon_concept.entry.name_object.string
      response_object['dataObjects'].length.should == 3
    end
      
    it 'should take api key and save it to the log' do
      check_api_key("/api/pages/#{@taxon_concept.id}.json?key=#{@user.api_key}", @user)
    end
      
      
    # DataObjects
      
    it "shouldn't show invisible or unpublished objects" do
      @object.published = 0
      @object.save!
      
      visit("/api/data_objects/#{@object.guid}")
      body.should include('<error>')
      body.should include('</response>')
      
      @object.published = 1
      @object.save!
    end
      
    it "should show a taxon element for the data object request" do
      visit("/api/data_objects/#{@object.guid}")
      xml_response = Nokogiri.XML(body)
      xml_response.xpath('/').inner_html.should_not == ""
    
      xml_response.xpath('//xmlns:taxon/dc:identifier').inner_text.should == @object.taxon_concepts[0].id.to_s
    end
      
    it "should show all information for text objects" do
      # this should be defined in the foundation and linked to its TOC
      @info_item = InfoItem.find_or_create_by_schema_value('http://rs.tdwg.org/ontology/voc/SPMInfoItems#GeneralDescription');
      DataObjectsTableOfContent.create(:data_object_id => @object.id, :toc_id => @info_item.toc_id)
    
      visit("/api/data_objects/#{@object.guid}")
      xml_response = Nokogiri.XML(body)
      xml_response.xpath('/').inner_html.should_not == ""
      xml_response.xpath('//xmlns:dataObject/dc:identifier').inner_text.should == @object.guid
      xml_response.xpath('//xmlns:dataObject/xmlns:dataType').inner_text.should == @object.data_type.schema_value
      xml_response.xpath('//xmlns:dataObject/xmlns:mimeType').inner_text.should == @object.mime_type.label
      xml_response.xpath('//xmlns:dataObject/dc:title').inner_text.should == @object.object_title
      xml_response.xpath('//xmlns:dataObject/dc:language').inner_text.should == @object.language.iso_639_1
      xml_response.xpath('//xmlns:dataObject/xmlns:license').inner_text.should == @object.license.source_url
      xml_response.xpath('//xmlns:dataObject/dc:rights').inner_text.should == @object.rights_statement
      xml_response.xpath('//xmlns:dataObject/dcterms:rightsHolder').inner_text.should == @object.rights_holder
      xml_response.xpath('//xmlns:dataObject/dcterms:bibliographicCitation').inner_text.should == @object.bibliographic_citation
      xml_response.xpath('//xmlns:dataObject/dc:source').inner_text.should == @object.source_url
      xml_response.xpath('//xmlns:dataObject/xmlns:subject').inner_text.should == @object.data_objects_table_of_contents[0].toc_item.info_items[0].schema_value
      xml_response.xpath('//xmlns:dataObject/dc:description').inner_text.should == @object.description
      xml_response.xpath('//xmlns:dataObject/xmlns:location').inner_text.should == @object.location
      xml_response.xpath('//xmlns:dataObject/geo:Point/geo:lat').inner_text.should == @object.latitude.to_s
      xml_response.xpath('//xmlns:dataObject/geo:Point/geo:long').inner_text.should == @object.longitude.to_s
      xml_response.xpath('//xmlns:dataObject/geo:Point/geo:alt').inner_text.should == @object.altitude.to_s
    
      # testing agents
      xml_response.xpath('//xmlns:dataObject/xmlns:agent').length.should == 2
      xml_response.xpath('//xmlns:dataObject/xmlns:agent[1]').inner_text.should == @object.agents[0].full_name
      xml_response.xpath('//xmlns:dataObject/xmlns:agent[1]/@homepage').inner_text.should == @object.agents[0].homepage
      xml_response.xpath('//xmlns:dataObject/xmlns:agent[1]/@role').inner_text.should == @object.agents_data_objects[0].agent_role.label
      xml_response.xpath('//xmlns:dataObject/xmlns:agent[2]').inner_text.should == @object.agents[1].full_name
      xml_response.xpath('//xmlns:dataObject/xmlns:agent[2]/@role').inner_text.should == @object.agents_data_objects[1].agent_role.label
    
      #testing references
      xml_response.xpath('//xmlns:dataObject/xmlns:reference').length.should == 2
      xml_response.xpath('//xmlns:dataObject/xmlns:reference[1]').inner_text.should == @object.refs[0].full_reference
      xml_response.xpath('//xmlns:dataObject/xmlns:reference[2]').inner_text.should == @object.refs[1].full_reference
    end
    
    it 'should be able to render a JSON response' do
      visit("/api/data_objects/#{@object.guid}.json")
      response_object = JSON.parse(body)
      response_object.class.should == Hash
      response_object['dataObjects'][0]['identifier'].should == @object.guid
      response_object['dataObjects'][0]['dataType'].should == @object.data_type.schema_value
      response_object['dataObjects'][0]['mimeType'].should == @object.mime_type.label
      response_object['dataObjects'][0]['title'].should == @object.object_title
      response_object['dataObjects'][0]['language'].should == @object.language.iso_639_1
      response_object['dataObjects'][0]['license'].should == @object.license.source_url
      response_object['dataObjects'][0]['rights'].should == @object.rights_statement
      response_object['dataObjects'][0]['rightsHolder'].should == @object.rights_holder
      response_object['dataObjects'][0]['bibliographicCitation'].should == @object.bibliographic_citation
      response_object['dataObjects'][0]['source'].should == @object.source_url
      response_object['dataObjects'][0]['subject'].should == @object.info_items[0].schema_value
      response_object['dataObjects'][0]['description'].should == @object.description
      response_object['dataObjects'][0]['location'].should == @object.location
      response_object['dataObjects'][0]['latitude'].should == @object.latitude.to_s
      response_object['dataObjects'][0]['longitude'].should == @object.longitude.to_s
      response_object['dataObjects'][0]['altitude'].should == @object.altitude.to_s
    
      # testing agents
      response_object['dataObjects'][0]['agents'].length.should == 2
          
      #testing references
      response_object['dataObjects'][0]['references'].length.should == 2
    end
    
      
    it "should show all information for image objects" do
      @object.data_type = DataType.image
      @object.mime_type = MimeType.find_or_create_by_label('image/jpeg')
      @object.object_url = 'http://images.marinespecies.org/resized/23745_electra-crustulenta-pallas-1766.jpg'
      @object.object_cache_url = 200911302039366
      @object.save!
    
      visit("/api/data_objects/#{@object.guid}")
      xml_response = Nokogiri.XML(body)
      xml_response.xpath('/').inner_html.should_not == ""
      xml_response.xpath('//xmlns:dataObject/dc:identifier').inner_text.should == @object.guid
      xml_response.xpath('//xmlns:dataObject/xmlns:dataType').inner_text.should == @object.data_type.schema_value
      xml_response.xpath('//xmlns:dataObject/xmlns:mimeType').inner_text.should == @object.mime_type.label
    
      #testing images
      xml_response.xpath('//xmlns:dataObject/xmlns:mediaURL').length.should == 2
      xml_response.xpath('//xmlns:dataObject/xmlns:mediaURL[1]').inner_text.should == @object.object_url
      xml_response.xpath('//xmlns:dataObject/xmlns:mediaURL[2]').inner_text.gsub(/\//, '').should include(@object.object_cache_url.to_s)
    end
      
    it 'should be able to render an HTML version of the page' do
      visit("/api/data_objects/#{@object.guid}?format=html")
      body.should include '<html'
      body.should include '</html>'
      body.should match /<title>\s*EOL API:\s*#{@object.taxon_concepts[0].entry.name_object.string}/
      body.should include @object.description
    end
      
    it 'should be able to toggle common names' do
      visit("/api/data_objects/#{@object.guid}")
      body.should_not include '<commonName'
    
      visit("/api/data_objects/#{@object.guid}?common_names=1")
      body.should include '<commonName'
    end
    
    it 'should take api key and save it to the log' do
      check_api_key("/api/data_objects/#{@object.guid}?key=#{@user.api_key}", @user)
    end
  end
  
  describe 'hierarchy entries and synonyms' do
    before(:all) do
      @canonical_form = CanonicalForm.create(:string => 'Aus bus')
      @name = Name.create(:canonical_form => @canonical_form, :string => 'Aus bus Linnaeus 1776')
      @hierarchy = Hierarchy.gen(:label => 'Test Hierarchy', :browsable => 1)
      @rank = Rank.gen(:label => 'species')
      @hierarchy_entry = HierarchyEntry.gen(:identifier => '123abc', :hierarchy => @hierarchy, :name => @name, :published => 1, :rank => @rank)
      
      canonical_form = CanonicalForm.create(:string => 'Dus bus')
      name = Name.create(:canonical_form => @canonical_form, :string => 'Dus bus Linnaeus 1776')
      relation = SynonymRelation.find_or_create_by_label('synonym')
      @synonym = Synonym.gen(:hierarchy_entry => @hierarchy_entry, :name => name, :synonym_relation => relation)
      
      name = Name.create(:string => 'Some critter')
      relation = SynonymRelation.find_or_create_by_label('common name')
      language = Language.gen(:label => 'english', :iso_639_1 => 'en')
      @common_name = Synonym.gen(:hierarchy_entry => @hierarchy_entry, :name => name, :synonym_relation => relation, :language => language)
    end
    
    it 'should return only published hierarchy_entries' do
      @hierarchy_entry.published = 0
      @hierarchy_entry.save!
      
      visit("/api/hierarchy_entries/#{@hierarchy_entry.id}")
      body.should include('<error>')
      body.should include('</response>')
      
      @hierarchy_entry.published = 1
      @hierarchy_entry.save!
    end
    
    it 'should show all information for hierarchy entries in DWC format' do
      visit("/api/hierarchy_entries/#{@hierarchy_entry.id}")
      xml_response = Nokogiri.XML(body)
      xml_response.xpath("//dwc:Taxon[dwc:taxonID=#{@hierarchy_entry.id}]/dc:identifier").inner_text.should == @hierarchy_entry.identifier
      xml_response.xpath("//dwc:Taxon[dwc:taxonID=#{@hierarchy_entry.id}]/dwc:taxonID").inner_text.should == @hierarchy_entry.id.to_s
      xml_response.xpath("//dwc:Taxon[dwc:taxonID=#{@hierarchy_entry.id}]/dwc:parentNameUsageID").inner_text.should == @hierarchy_entry.parent_id.to_s
      xml_response.xpath("//dwc:Taxon[dwc:taxonID=#{@hierarchy_entry.id}]/dwc:taxonConceptID").inner_text.should == @hierarchy_entry.taxon_concept_id.to_s
      xml_response.xpath("//dwc:Taxon[dwc:taxonID=#{@hierarchy_entry.id}]/dwc:scientificName").inner_text.should == @name.string
      xml_response.xpath("//dwc:Taxon[dwc:taxonID=#{@hierarchy_entry.id}]/dwc:taxonRank").inner_text.downcase.should == @rank.label
      xml_response.xpath("//dwc:Taxon[dwc:taxonID=#{@hierarchy_entry.id}]/dwc:nameAccordingTo").inner_text.should == @hierarchy.label
      xml_response.xpath("//dwc:Taxon[dwc:taxonID=#{@hierarchy_entry.id}]/dwc:vernacularName").inner_text.should == @common_name.name.string
      xml_response.xpath("//dwc:Taxon[dwc:taxonID=#{@hierarchy_entry.id}]/dwc:vernacularName/@xml:lang").inner_text.should == @common_name.language.iso_639_1
      xml_response.xpath("//dwc:vernacularName").length.should == 1
      xml_response.xpath("//dwc:Taxon[dwc:taxonomicStatus='synonym']").length.should == 1
    end
    
    it 'should be able to filter out common names' do
      visit("/api/hierarchy_entries/#{@hierarchy_entry.id}?common_names=0")
      xml_response = Nokogiri.XML(body)
      xml_response.xpath("//dwc:vernacularName").length.should == 0
      xml_response.xpath("//dwc:Taxon[dwc:taxonomicStatus='synonym']").length.should == 1
    end
    
    it 'should be able to filter out synonyms' do
      visit("/api/hierarchy_entries/#{@hierarchy_entry.id}?synonyms=0")
      xml_response = Nokogiri.XML(body)
      xml_response.xpath("//dwc:vernacularName").length.should == 1
      xml_response.xpath("//dwc:Taxon[dwc:taxonomicStatus='synonym']").length.should == 0
    end
    
    
    it 'should show all information for hierarchy entries in TCS format' do
      visit("/api/hierarchy_entries/#{@hierarchy_entry.id}?format=tcs")
      xml_response = Nokogiri.XML(body)
      xml_response.xpath('//xmlns:TaxonNames/xmlns:TaxonName/@id').inner_text.should == "n#{@name.id}"
      xml_response.xpath('//xmlns:TaxonNames/xmlns:TaxonName/xmlns:Simple').inner_text.should == @name.string
      xml_response.xpath('//xmlns:TaxonNames/xmlns:TaxonName/xmlns:CanonicalName/xmlns:Simple').inner_text.should == @canonical_form.string
      xml_response.xpath('//xmlns:TaxonNames/xmlns:TaxonName/xmlns:Rank').inner_text.downcase.should == @rank.label
      xml_response.xpath('//xmlns:TaxonNames/xmlns:TaxonName/xmlns:Rank/@code').inner_text.should == @rank.tcs_code
      xml_response.xpath('//xmlns:TaxonNames/xmlns:TaxonName/xmlns:ProviderSpecificData/xmlns:NameSources/xmlns:NameSource/xmlns:Simple').inner_text.should == @hierarchy.label
      xml_response.xpath('//xmlns:TaxonConcepts/xmlns:TaxonConcept/@id').inner_text.should == "#{@hierarchy_entry.id}"
      xml_response.xpath('//xmlns:TaxonConcepts/xmlns:TaxonConcept/xmlns:Name').inner_text.should == "#{@name.string}"
      xml_response.xpath('//xmlns:TaxonConcepts/xmlns:TaxonConcept/xmlns:Name/@scientific').inner_text.should == "true"
      xml_response.xpath('//xmlns:TaxonConcepts/xmlns:TaxonConcept/xmlns:Name/@ref').inner_text.should == "n#{@name.id}"
      xml_response.xpath('//xmlns:TaxonConcepts/xmlns:TaxonConcept/xmlns:Rank').inner_text.downcase.should == @rank.label
      xml_response.xpath('//xmlns:TaxonConcepts/xmlns:TaxonConcept/xmlns:Rank/@code').inner_text.should == @rank.tcs_code
      xml_response.xpath('//xmlns:TaxonConcepts/xmlns:TaxonConcept/xmlns:TaxonRelationships/xmlns:TaxonRelationship[1]/xmlns:ToTaxonConcept/@ref').inner_text.should include(@synonym.id.to_s)
      xml_response.xpath('//xmlns:TaxonConcepts/xmlns:TaxonConcept/xmlns:TaxonRelationships/xmlns:TaxonRelationship[1]/@type').inner_text.should == 'has synonym'
      xml_response.xpath('//xmlns:TaxonConcepts/xmlns:TaxonConcept/xmlns:TaxonRelationships/xmlns:TaxonRelationship[2]/xmlns:ToTaxonConcept/@ref').inner_text.should include(@common_name.id.to_s)
      xml_response.xpath('//xmlns:TaxonConcepts/xmlns:TaxonConcept/xmlns:TaxonRelationships/xmlns:TaxonRelationship[2]/@type').inner_text.should == 'has vernacular'
    end
  
    it 'should take api key and save it to the log' do
      check_api_key("/api/hierarchy_entries/#{@hierarchy_entry.id}?format=tcs&key=#{@user.api_key}", @user)
    end
    
    it 'should show all information for synonyms in TCS format' do
      visit("/api/synonyms/#{@synonym.id}")
      xml_response = Nokogiri.XML(body)
      xml_response.xpath('//xmlns:TaxonNames/xmlns:TaxonName/@id').inner_text.should == "n#{@synonym.name.id}"
      xml_response.xpath('//xmlns:TaxonNames/xmlns:TaxonName/xmlns:Simple').inner_text.should == @synonym.name.string
      xml_response.xpath('//xmlns:TaxonNames/xmlns:TaxonName/xmlns:CanonicalName/xmlns:Simple').inner_text.should == @synonym.name.canonical_form.string
      xml_response.xpath('//xmlns:TaxonConcepts/xmlns:TaxonConcept/@id').inner_text.should == "s#{@synonym.id}"
      xml_response.xpath('//xmlns:TaxonConcepts/xmlns:TaxonConcept/xmlns:Name').inner_text.should == "#{@synonym.name.string}"
      xml_response.xpath('//xmlns:TaxonConcepts/xmlns:TaxonConcept/xmlns:Name/@scientific').inner_text.should == "true"
    end
    
    it 'should show all information for common names in TCS format' do
      visit("/api/synonyms/#{@common_name.id}")
      xml_response = Nokogiri.XML(body)
      xml_response.xpath('//xmlns:TaxonNames/xmlns:TaxonName/@id').inner_text.should == "n#{@common_name.name.id}"
      xml_response.xpath('//xmlns:TaxonNames/xmlns:TaxonName/xmlns:Simple').inner_text.should == @common_name.name.string
      # canonical form not included for common names
      xml_response.xpath('//xmlns:TaxonNames/xmlns:TaxonName/xmlns:CanonicalName/xmlns:Simple').inner_text.should == ""
      xml_response.xpath('//xmlns:TaxonConcepts/xmlns:TaxonConcept/@id').inner_text.should == "s#{@common_name.id}"
      xml_response.xpath('//xmlns:TaxonConcepts/xmlns:TaxonConcept/xmlns:Name').inner_text.should == "#{@common_name.name.string}"
      xml_response.xpath('//xmlns:TaxonConcepts/xmlns:TaxonConcept/xmlns:Name/@scientific').inner_text.should == "false"
      xml_response.xpath('//xmlns:TaxonConcepts/xmlns:TaxonConcept/xmlns:Name/@language').inner_text.should == @common_name.language.iso_639_1
    end
  
    it 'should take api key and save it to the log' do
      check_api_key("/api/synonyms/#{@common_name.id}?key=#{@user.api_key}", @user)
    end
  
  end
  
  describe 'search' do
    before(:all) do
      @dog_name      = 'Dog'
      @domestic_name = "Domestic #{@dog_name}"
      @dog_sci_name  = 'Canis lupus familiaris'
      @wolf_name     = 'Wolf'
      @wolf_sci_name = 'Canis lupus'
      @dog  = build_taxon_concept(:scientific_name => @dog_sci_name, :common_names => [@domestic_name])
      @wolf = build_taxon_concept(:scientific_name => @wolf_sci_name, :common_names => [@wolf_name])
      SearchSuggestion.gen(:taxon_id => @dog.id, :term => @dog_name, :scientific_name => @dog.scientific_name,
                           :common_name => @dog.common_name)
      SearchSuggestion.gen(:taxon_id => @wolf.id, :term => @dog_name, :scientific_name => @wolf.scientific_name,
                           :common_name => @wolf.common_name)
      recreate_indexes
    end
    
    it 'should do a contains search by default' do
      visit("/api/search/Canis%20lupus.json")
      response_object = JSON.parse(body)
      response_object['results'].length.should == 2
    end
    
    it 'should do an exact search' do
      visit("/api/search/Canis%20lupus.json?exact=1")
      response_object = JSON.parse(body)
      response_object['results'].length.should == 1
      response_object['results'][0]['title'].should == @wolf_sci_name
      
      visit("/api/search/Canis.json?exact=1")
      response_object = JSON.parse(body)
      response_object['results'].length.should == 0
    end
  
    it 'should take api key and save it to the log' do
      check_api_key("/api/search/Canis.json?exact=1&key=#{@user.api_key}", @user)
    end
  end
  
  describe 'provider search and hierarchy roots' do
    before(:all) do
      @test_hierarchy = Hierarchy.gen(:label => 'Some test hierarchy', :browsable => 1)
      @second_test_hierarchy = Hierarchy.gen(:label => 'Another test hierarchy', :browsable => 1)
      @test_hierarchy_entry_published = HierarchyEntry.gen(:hierarchy => @test_hierarchy, :identifier => 'Animalia', :parent_id => 0, :published => 1, :visibility_id => Visibility.visible.id)
      @test_hierarchy_entry_unpublished = HierarchyEntry.gen(:hierarchy => @test_hierarchy, :identifier => 'Plantae', :parent_id => 0, :published => 0, :visibility_id => Visibility.invisible.id)
      @second_test_hierarchy_entry = HierarchyEntry.gen(:hierarchy => @second_test_hierarchy, :identifier => 54321, :parent_id => 0, :published => 1, :visibility_id => Visibility.visible.id)
    end
    
    it 'should return a list of all providers' do
      visit("/api/provider_hierarchies")
      xml_response = Nokogiri.XML(body)
      our_result = xml_response.xpath("//hierarchy[@id='#{@test_hierarchy.id}']")
      our_result.length.should == 1
      our_result.inner_text.should == @test_hierarchy.label
      
      visit("/api/provider_hierarchies.json")
      response_object = JSON.parse(body)
      response_object.length.should > 0
      response_object.collect{ |r| r['id'].to_i == @test_hierarchy.id && r['label'] == @test_hierarchy.label }.length == 2
    end
    
    it 'should return the EOL page ID for a provider identifer' do
      visit("/api/search_by_provider/#{@test_hierarchy_entry_published.identifier}?hierarchy_id=#{@test_hierarchy_entry_published.hierarchy_id}")
      xml_response = Nokogiri.XML(body)
      our_result = xml_response.xpath("//eol_page_id")
      our_result.length.should == 1
      our_result.inner_text.to_i.should == @test_hierarchy_entry_published.taxon_concept_id
      visit("/api/search_by_provider/#{@test_hierarchy_entry_published.identifier}.json?hierarchy_id=#{@test_hierarchy_entry_published.hierarchy_id}")
      response_object = JSON.parse(body)
      response_object.length.should > 0
      response_object.collect{ |r| r['eol_page_id'].to_i == @test_hierarchy_entry_published.taxon_concept_id}.length == 1
    end
    
    it 'should not return the EOL page ID for a provider identifer' do
      visit("/api/search_by_provider/#{@test_hierarchy_entry_unpublished.identifier}?hierarchy_id=#{@test_hierarchy_entry_unpublished.hierarchy_id}")
      xml_response = Nokogiri.XML(body)
      our_result = xml_response.xpath("//eol_page_id")
      our_result.length.should == 0
      visit("/api/search_by_provider/#{@test_hierarchy_entry_unpublished.identifier}.json?hierarchy_id=#{@test_hierarchy_entry_unpublished.hierarchy_id}")
      response_object = JSON.parse(body)
      response_object.length.should == 0     
    end
    
    it 'should take api key and save it to the log' do
      check_api_key("/api/search_by_provider/#{@test_hierarchy_entry_unpublished.identifier}.json?hierarchy_id=#{@test_hierarchy_entry_unpublished.hierarchy_id}&key=#{@user.api_key}", @user)
    end
  
    it 'should list the hierarchy roots' do
      visit("/api/hierarchies/#{@test_hierarchy.id}")
      xml_response = Nokogiri.XML(body)
      our_result = xml_response.xpath("//dc:title").inner_text.should == @test_hierarchy.label
      our_result = xml_response.xpath("//dc:contributor").inner_text.should == @test_hierarchy.agent.full_name
      our_result = xml_response.xpath("//dc:dateSubmitted").inner_text.should == @test_hierarchy.indexed_on.mysql_timestamp
      our_result = xml_response.xpath("//dc:source").inner_text.should == @test_hierarchy.url
      our_result = xml_response.xpath("//dwc:Taxon").length.should == 1
      our_result = xml_response.xpath("//dwc:Taxon/dwc:taxonID").inner_text.should == @test_hierarchy_entry_published.id.to_s
      our_result = xml_response.xpath("//dwc:Taxon/dwc:parentNameUsageID").inner_text.should == 0.to_s
      our_result = xml_response.xpath("//dwc:Taxon/dwc:taxonConceptID").inner_text.should == @test_hierarchy_entry_published.taxon_concept_id.to_s
      our_result = xml_response.xpath("//dwc:Taxon/dwc:scientificName").inner_text.should == @test_hierarchy_entry_published.name_object.string
      our_result = xml_response.xpath("//dwc:Taxon/dwc:taxonRank").inner_text.should == @test_hierarchy_entry_published.rank.label
      
      visit("/api/hierarchies/#{@test_hierarchy.id}.json")
      response_object = JSON.parse(body)
      response_object['title'].should == @test_hierarchy.label
      response_object['contributor'].should == @test_hierarchy.agent.full_name
      response_object['dateSubmitted'].should == @test_hierarchy.indexed_on.mysql_timestamp
      response_object['source'].should == @test_hierarchy.url
      response_object['roots'].length.should == 1
      response_object['roots'][0]['taxonID'].should == @test_hierarchy_entry_published.id.to_s
      response_object['roots'][0]['parentNameUsageID'].should == 0.to_s
      response_object['roots'][0]['taxonConceptID'].should == @test_hierarchy_entry_published.taxon_concept_id.to_s
      response_object['roots'][0]['scientificName'].should == @test_hierarchy_entry_published.name_object.string
      response_object['roots'][0]['taxonRank'].should == @test_hierarchy_entry_published.rank.label
    end
  
    it 'should take api key and save it to the log' do
      check_api_key("/api/hierarchies/#{@test_hierarchy.id}?key=#{@user.api_key}", @user)
    end
  end
end

