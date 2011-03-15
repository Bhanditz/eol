# sets up a basic foundation - enough data to run the application, but no content

$CACHE.clear # because we are resetting everything!  Sometimes, say, iucn is set.
old_cache_value = $CACHE.clone
$CACHE = nil

# I AM NOT INDENTING THIS BLOCK (it seemed overkill)
if User.find_by_username('foundation_already_loaded').nil?

Language.gen_if_not_exists(:label => 'English', :iso_639_1 => 'en')

# This ensures the main menu is complete, with at least one (albeit bogus) item in each section:
ContentPage.gen_if_not_exists(:title => 'Home',
  :language_abbr => 'en', :content_section => ContentSection.gen(:name => 'Home Page'))
ContentPage.gen_if_not_exists(:title => 'Who We Are',
  :language_abbr => 'en', :content_section => ContentSection.gen(:name => 'About EOL'))
ContentPage.gen_if_not_exists(:title => 'Contact Us',
  :language_abbr => 'en', :content_section => ContentSection.gen(:name => 'Feedback'))
ContentPage.gen_if_not_exists(:title => 'Screencasts',
  :language_abbr => 'en', :content_section => ContentSection.gen(:name => 'Using the Site'))
ContentPage.gen_if_not_exists(:title => 'Press Releases',
  :language_abbr => 'en', :content_section => ContentSection.gen(:name => 'Press Room'))
ContentPage.gen_if_not_exists(:title => 'Terms Of Use',
  :language_abbr => 'en', :content_section => ContentSection.gen(:name => 'Footer'))

ContactSubject.gen_if_not_exists(:title => 'Media Contact', :recipients=>'test@test.com', :active=>true)

CuratorActivity.gen_if_not_exists(:code => 'delete')
CuratorActivity.gen_if_not_exists(:code => 'update')
CuratorActivity.gen_if_not_exists(:code => 'show')
CuratorActivity.gen_if_not_exists(:code => 'hide')
CuratorActivity.gen_if_not_exists(:code => 'inappropriate')
CuratorActivity.gen_if_not_exists(:code => 'approve')
CuratorActivity.gen_if_not_exists(:code => 'disapprove')
CuratorActivity.gen_if_not_exists(:code => 'unreviewed')

# what one can do with a data_object
ActionWithObject.gen_if_not_exists(:action_code => 'create')
ActionWithObject.gen_if_not_exists(:action_code => 'update')     #?
ActionWithObject.gen_if_not_exists(:action_code => 'delete')
ActionWithObject.gen_if_not_exists(:action_code => 'trusted')
ActionWithObject.gen_if_not_exists(:action_code => 'untrusted')
ActionWithObject.gen_if_not_exists(:action_code => 'show')
ActionWithObject.gen_if_not_exists(:action_code => 'hide')
ActionWithObject.gen_if_not_exists(:action_code => 'inappropriate')
ActionWithObject.gen_if_not_exists(:action_code => 'unreviewed')

# create_if_not_exists We don't technically *need* all three of these, but it's nice to have for the menu.  There are more, but we don't currently use
# them.  create_if_not_exists Once we do, they should get added here.
AgentContactRole.gen_if_not_exists(:label => 'Primary Contact')
AgentContactRole.gen_if_not_exists(:label => 'Administrative Contact')
AgentContactRole.gen_if_not_exists(:label => 'Technical Contact')

Agent.gen_if_not_exists(:full_name => 'IUCN')
ContentPartner.gen_if_not_exists(:agent => Agent.iucn)
AgentContact.gen_if_not_exists(:agent => Agent.iucn, :agent_contact_role => AgentContactRole.primary)
Agent.gen_if_not_exists(:full_name => 'Catalogue of Life', :logo_cache_url => '219000', :homepage => 'http://www.catalogueoflife.org/')
ContentPartner.gen_if_not_exists(:agent => Agent.catalogue_of_life)
AgentContact.gen_if_not_exists(:agent => Agent.catalogue_of_life, :agent_contact_role => AgentContactRole.primary)
Agent.gen_if_not_exists(:full_name => 'National Center for Biotechnology Information', :acronym => 'NCBI', :logo_cache_url => '921800', :homepage => 'http://www.ncbi.nlm.nih.gov/')


boa_agent = Agent.gen_if_not_exists(:full_name => 'Biology of Aging', :logo_cache_url => '318700')
liger_cat_hierarchy = Hierarchy.gen_if_not_exists(:label          => 'LigerCat',
                                   :description    => 'LigerCat Biomedical Terms Tag Cloud',
                                   :outlink_uri    => 'http://ligercat.ubio.org/eol/%%ID%%.cloud',
                                   :url            => 'http://ligercat.ubio.org',
                                   :agent_id => boa_agent.id)
liget_cat_resource = Resource.gen_if_not_exists(:title => 'LigerCat resource')
AgentsResource.gen(:resource => liget_cat_resource, :agent => boa_agent)
links = CollectionType.gen_if_not_exists(:label => "Links")
lit   = CollectionType.gen_if_not_exists(:label => "Literature")
CollectionTypesHierarchy.gen(:hierarchy => liger_cat_hierarchy, :collection_type => links)
CollectionTypesHierarchy.gen(:hierarchy => liger_cat_hierarchy, :collection_type => lit)


AgentDataType.gen_if_not_exists(:label => 'Audio')
AgentDataType.gen_if_not_exists(:label => 'Image')
AgentDataType.gen_if_not_exists(:label => 'Text')
AgentDataType.gen_if_not_exists(:label => 'Video')

AgentRole.gen_if_not_exists(:label => 'Author')
AgentRole.gen_if_not_exists(:label => 'Photographer')
AgentRole.gen_if_not_exists(:label => 'Contributor')
AgentRole.gen_if_not_exists(:label => 'Source')

AgentStatus.gen_if_not_exists(:label => 'Active')
AgentStatus.gen_if_not_exists(:label => 'Archived')
AgentStatus.gen_if_not_exists(:label => 'Pending')

Audience.gen_if_not_exists(:label => 'Children')
Audience.gen_if_not_exists(:label => 'Expert users')
Audience.gen_if_not_exists(:label => 'General public')

DataType.gen_if_not_exists(:label => 'Image',     :schema_value => 'http://purl.org/dc/dcmitype/StillImage')
DataType.gen_if_not_exists(:label => 'Sound',     :schema_value => 'http://purl.org/dc/dcmitype/Sound')
DataType.gen_if_not_exists(:label => 'Text',      :schema_value => 'http://purl.org/dc/dcmitype/Text')
DataType.gen_if_not_exists(:label => 'Video',     :schema_value => 'http://purl.org/dc/dcmitype/MovingImage')
DataType.gen_if_not_exists(:label => 'GBIF Image')
DataType.gen_if_not_exists(:label => 'IUCN',      :schema_value => 'IUCN')
DataType.gen_if_not_exists(:label => 'Flash',     :schema_value => 'Flash')
DataType.gen_if_not_exists(:label => 'YouTube',   :schema_value => 'YouTube')

Hierarchy.gen_if_not_exists(:agent => Agent.catalogue_of_life, :label => $DEFAULT_HIERARCHY_NAME, :browsable => 1)
default_hierarchy = Hierarchy.gen_if_not_exists(:agent => Agent.catalogue_of_life, :label => "Species 2000 & ITIS Catalogue of Life: Annual Checklist 2010", :browsable => 1)
Hierarchy.gen_if_not_exists(:agent => Agent.catalogue_of_life, :label =>  "Species 2000 & ITIS Catalogue of Life: Annual Checklist 2007", :browsable => 0)
Hierarchy.gen_if_not_exists(:label => "Encyclopedia of Life Contributors")
first_ncbi = Hierarchy.gen_if_not_exists(:agent => Agent.ncbi, :label => "NCBI Taxonomy", :browsable => 1)
first_ncbi.hierarchy_group_id = 101
first_ncbi.hierarchy_group_version = 1
first_ncbi.save!
second_ncbi = Hierarchy.gen_if_not_exists(:agent => Agent.ncbi, :label => "NCBI Taxonomy", :browsable => 1)
second_ncbi.hierarchy_group_id = 101
second_ncbi.hierarchy_group_version = 2
second_ncbi.save!



Language.gen_if_not_exists(:label => 'French', :iso_639_1 => 'fr', :iso_639_2 => 'fre') # Bootstrap uses this, tests i18n
Language.gen_if_not_exists(:label => 'Scientific Name', :iso_639_1 => '')
Language.gen_if_not_exists(:label => 'Unknown', :iso_639_1 => '')


License.gen_if_not_exists(:title => 'public domain',
                          :description => 'No rights reserved',
                          :source_url => 'http://creativecommons.org/licenses/publicdomain/')
License.gen_if_not_exists(:title => 'all rights reserved',
                          :description => '&#169; All rights reserved',
                          :show_to_content_partners => 0)
License.gen_if_not_exists(:title => 'cc-by-nc 3.0',
                          :description => 'Some rights reserved',
                          :source_url => 'http://creativecommons.org/licenses/by-nc/3.0/',
                          :logo_url => '/images/licenses/cc_by_nc_small.png')
License.gen_if_not_exists(:title => 'cc-by 3.0',
                          :description => 'Some rights reserved',
                          :source_url => 'http://creativecommons.org/licenses/by/3.0/',
                          :logo_url => '/images/licenses/cc_by_small.png')
License.gen_if_not_exists(:title => 'cc-by-sa 3.0',
                          :description => 'Some rights reserved',
                          :source_url => 'http://creativecommons.org/licenses/by-sa/3.0/',
                          :logo_url => '/images/licenses/cc_by_sa_small.png')
License.gen_if_not_exists(:title => 'cc-by-nc-sa 3.0',
                          :description => 'Some rights reserved',
                          :source_url => 'http://creativecommons.org/licenses/by-nc-sa/3.0/',
                          :logo_url => '/images/licenses/cc_by_nc_sa_small.png')

MimeType.gen_if_not_exists(:label => 'image/jpeg')
MimeType.gen_if_not_exists(:label => 'text/html')
MimeType.gen_if_not_exists(:label => 'text/plain')
MimeType.gen_if_not_exists(:label => 'video/x-flv')


# create_if_not_exists These don't exist yet, but will in the future:
# create_if_not_exists NormalizedQualifier :label => 'Name'
# create_if_not_exists NormalizedQualifier :label => 'Author'
# create_if_not_exists NormalizedQualifier :label => 'Year'

%w{kingdom phylum order class family genus species subspecies infraspecies variety form}.each do |rank|
  Rank.gen_if_not_exists(:label => rank)
end

ChangeableObjectType.gen_if_not_exists(:ch_object_type => 'comment')
ChangeableObjectType.gen_if_not_exists(:ch_object_type => 'data_object')
ChangeableObjectType.gen_if_not_exists(:ch_object_type => 'synonym')
ChangeableObjectType.gen_if_not_exists(:ch_object_type => 'taxon_concept_name')
ChangeableObjectType.gen_if_not_exists(:ch_object_type => 'tag')
ChangeableObjectType.gen_if_not_exists(:ch_object_type => 'users_submitted_text')

RefIdentifierType.gen_if_not_exists(:label => 'url')

iucn_hierarchy = Hierarchy.gen_if_not_exists(:label => 'IUCN')
iucn_resource = Resource.gen_if_not_exists(:title => 'Initial IUCN Import', :hierarchy => iucn_hierarchy)
iucn_agent = Agent.iucn
raise "IUCN is nil" if iucn_agent.nil?
AgentsResource.gen_if_not_exists(:resource => iucn_resource, :agent => Agent.iucn)

# This is out of ourder, of course, because it depends on the IUCN resource.
HarvestEvent.gen_if_not_exists(:resource_id => iucn_resource.id)

ResourceAgentRole.gen_if_not_exists(:label => 'Data Supplier')        # content_partner_upload_role

Role.gen_if_not_exists(:title => $CURATOR_ROLE_NAME)
Role.gen_if_not_exists(:title => 'Moderator')
Role.gen_if_not_exists(:title => $ADMIN_ROLE_NAME)
Role.gen_if_not_exists(:title => 'Administrator - News Items')
Role.gen_if_not_exists(:title => 'Administrator - Comments and Tags')
Role.gen_if_not_exists(:title => 'Administrator - Web Users')
Role.gen_if_not_exists(:title => 'Administrator - Contact Us Submissions')
Role.gen_if_not_exists(:title => 'Administrator - Content Partners')
Role.gen_if_not_exists(:title => 'Administrator - Technical')
Role.gen_if_not_exists(:title => 'Administrator - Site CMS')
Role.gen_if_not_exists(:title => 'Administrator - Usage Reports')

TocItem.gen_if_not_exists(:label => 'Overview', :view_order => 1)
description = TocItem.gen_if_not_exists(:label => 'Description', :view_order => 2)
TocItem.gen_if_not_exists(:label => 'Nucleotide Sequences', :view_order => 3, :parent_id => description.id)
ecology_and_distribution = TocItem.gen_if_not_exists(:label => 'Ecology and Distribution', :view_order => 4)
TocItem.gen_if_not_exists(:label => 'Wikipedia', :view_order => 5)
#--
names_and_taxonomy = TocItem.gen_if_not_exists(:label => 'Names and Taxonomy', :view_order => 50)
TocItem.gen_if_not_exists(:label => 'Related Names', :view_order => 51, :parent_id => names_and_taxonomy.id)
TocItem.gen_if_not_exists(:label => 'Synonyms', :view_order => 52, :parent_id => names_and_taxonomy.id)
TocItem.gen_if_not_exists(:label => 'Common Names', :view_order => 53, :parent_id => names_and_taxonomy.id)
#--
page_stats = TocItem.gen_if_not_exists(:label => 'Page Statistics', :view_order => 57)
TocItem.gen_if_not_exists(:label => 'Content Summary', :view_order => 58, :parent_id => page_stats.id)
#--
TocItem.gen_if_not_exists(:label => 'Biodiversity Heritage Library', :view_order => 61)
ref_and_info = TocItem.gen_if_not_exists(:label => 'References and More Information', :view_order => 62)

# Note that in all these "children", the view_order resets.  ...That reflects the real DB.
TocItem.gen_if_not_exists(:label => 'Literature References', :view_order => 64, :parent_id => ref_and_info.id)
TocItem.gen_if_not_exists(:label => 'Content Partners',      :view_order => 65, :parent_id => ref_and_info.id)
TocItem.gen_if_not_exists(:label => 'Biomedical Terms',      :view_order => 66, :parent_id => ref_and_info.id)
TocItem.gen_if_not_exists(:label => 'Search the Web',        :view_order => 67, :parent_id => ref_and_info.id)
education = TocItem.gen_if_not_exists(:label => 'Education',             :view_order => 68, :parent_id => ref_and_info.id)

InfoItem.gen_if_not_exists(:schema_value => 'http://rs.tdwg.org/ontology/voc/SPMInfoItems#TaxonBiology',
  :label => 'TaxonBiology', :toc_item => TocItem.overview)
InfoItem.gen_if_not_exists(:schema_value => 'http://rs.tdwg.org/ontology/voc/SPMInfoItems#GeneralDescription',
  :label => 'GeneralDescription', :toc_item => description)
InfoItem.gen_if_not_exists(:schema_value => 'http://rs.tdwg.org/ontology/voc/SPMInfoItems#Distribution',
  :label => 'Distribution', :toc_item => ecology_and_distribution)
InfoItem.gen_if_not_exists(:schema_value => 'http://rs.tdwg.org/ontology/voc/SPMInfoItems#Habitat',
  :label => 'Habitat', :toc_item => ecology_and_distribution)
InfoItem.gen_if_not_exists(:schema_value => 'http://rs.tdwg.org/ontology/voc/SPMInfoItems#Morphology',
  :label => 'Morphology', :toc_item => description)
InfoItem.gen_if_not_exists(:schema_value => 'http://rs.tdwg.org/ontology/voc/SPMInfoItems#Conservation',
  :label => 'Conservation', :toc_item => description)
InfoItem.gen_if_not_exists(:schema_value => 'http://rs.tdwg.org/ontology/voc/SPMInfoItems#Uses',
  :label => 'Uses', :toc_item => description)
InfoItem.gen_if_not_exists(:schema_value => 'http://www.eol.org/voc/table_of_contents#Education',
  :label => 'Education', :toc_item => education)

ServiceType.gen_if_not_exists(:label => 'EOL Transfer Schema')

Status.gen_if_not_exists(:label => 'Inserted')
Status.gen_if_not_exists(:label => 'Unchanged')
Status.gen_if_not_exists(:label => 'Updated')

UntrustReason.gen_if_not_exists(:label => 'Misidentified')
UntrustReason.gen_if_not_exists(:label => 'Incorrect')
UntrustReason.gen_if_not_exists(:label => 'Poor')
UntrustReason.gen_if_not_exists(:label => 'Duplicate')
UntrustReason.gen_if_not_exists(:label => 'Other')

Vetted.gen_if_not_exists(:label => 'Unknown', :view_order => 2)
Vetted.gen_if_not_exists(:label => 'Untrusted', :view_order => 3)
Vetted.gen_if_not_exists(:label => 'Trusted', :view_order => 1)

SynonymRelation.gen_if_not_exists(:label => "synonym")
SynonymRelation.gen_if_not_exists(:label => "common name")
SynonymRelation.gen_if_not_exists(:label => "genbank common name")


Visibility.gen_if_not_exists(:label => 'Invisible')
Visibility.gen_if_not_exists(:label => 'Visible')
Visibility.gen_if_not_exists(:label => 'Preview')
Visibility.gen_if_not_exists(:label => 'Inappropriate')


# The home-page doesn't render without random taxa.  Note that other scenarios, if they build legitimate RandomTaxa,
# will need to DELETE these before they make their own!  But for foundation's purposes, this is required:
RandomHierarchyImage.delete_all
d = DataObject.gen
he = HierarchyEntry.gen(:hierarchy => default_hierarchy)
5.times { RandomHierarchyImage.gen(:hierarchy => default_hierarchy, :hierarchy_entry => he, :data_object => d) }

# This prevents us from loading things twice, which it seems we were doing a lot!
User.gen :username => 'foundation_already_loaded'

$CACHE = old_cache_value.clone
$CACHE.clear

end # THIS WAS NOT INDENTED.  It was an 'if' over almost the whole file, and didn't make sense to.
