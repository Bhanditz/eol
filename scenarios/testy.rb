# Put a few taxa (all within a new hierarchy) in the database with a range of accoutrements
#
#   TODO add a description here of what actually gets created!
#
#   This description block can be viewed (as well as other information
#   about this scenario) by running:
#     $ rake scenarios:show NAME=bootstrap
#
#---
#dependencies: [ :foundation ]

$CACHE.clear # Not *positive* we need this, but...
require 'spec/eol_spec_helpers'
require 'spec/scenario_helpers'
# This gives us the ability to build taxon concepts:
include EOL::Spec::Helpers

# NOTE - Because this can be pre-loaded, Factory strings will NOT be unique by themselves, so we add a little to them (if
# they need to be unique)

testy = {}

testy[:exemplar] = build_taxon_concept(:id => 910093) # That ID is one of the (hard-coded) exemplars.

testy[:empty_taxon_concept] =
  build_taxon_concept(:images => [], :toc => [], :flash => [], :youtube => [], :comments => [], :bhl => [])

testy[:overview]        = TocItem.overview
testy[:overview_text]   = 'This is a test Overview, in all its glory'
testy[:brief_summary]   = TocItem.brief_summary
testy[:brief_summary_text] = 'This is a test brief summary.'
testy[:toc_item_2]      = TocItem.gen_if_not_exists(:view_order => 2, :label => "test toc item 2")
testy[:toc_item_3]      = TocItem.gen_if_not_exists(:view_order => 3, :label => "test toc item 3")
testy[:canonical_form]  = Factory.next(:species) + 'tsty'
testy[:attribution]     = Faker::Eol.attribution
testy[:common_name]     = Faker::Eol.common_name.firstcap + 'tsty'
testy[:unreviewed_name] = Faker::Eol.common_name.firstcap + 'tsty'
testy[:untrusted_name]  = Faker::Eol.common_name.firstcap + 'tsty'
testy[:scientific_name] = "#{testy[:canonical_form]} #{testy[:attribution]}"
testy[:italicized]      = "<i>#{testy[:canonical_form]}</i> #{testy[:attribution]}"
testy[:iucn_status]     = Factory.next(:iucn)
testy[:gbif_map_id]     = '424242'
testy[:map_text]        = 'Test Map'
testy[:image_1]         = Factory.next(:image)
testy[:image_2]         = Factory.next(:image)
testy[:image_3]         = Factory.next(:image)
testy[:image_unknown_trust] = Factory.next(:image)
testy[:image_untrusted] = Factory.next(:image)
testy[:video_1_text]    = 'First Test Video'
testy[:video_2_text]    = 'Second Test Video'
testy[:video_3_text]    = 'YouTube Test Video'
testy[:comment_1]       = 'This is totally awesome'
testy[:comment_bad]     = 'This is totally inappropriate'
testy[:comment_2]       = 'And I can comment multiple times'

tc = build_taxon_concept(
  :parent_hierarchy_entry_id => testy[:empty_taxon_concept].hierarchy_entries.first.id,
  :rank            => 'species',
  :canonical_form  => testy[:canonical_form],
  :attribution     => testy[:attribution],
  :scientific_name => testy[:scientific_name],
  :italicized      => testy[:italicized],
  :iucn_status     => testy[:iucn_status],
  :gbif_map_id     => testy[:gbif_map_id],
  :map             => {:description => testy[:map_text]},
  :flash           => [{:description => testy[:video_1_text]}, {:description => testy[:video_2_text]}],
  :youtube         => [{:description => testy[:video_3_text]}],
  :comments        => [{:user => testy[:user], :body => testy[:comment_1]},
                       {:user => testy[:user], :body => testy[:comment_bad]},
                       {:user => testy[:user], :body => testy[:comment_2]}],
  :images          => [{:object_cache_url => testy[:image_1], :data_rating => 2},
                       {:object_cache_url => testy[:image_2], :data_rating => 3},
                       {:object_cache_url => testy[:image_untrusted], :vetted => Vetted.untrusted},
                       {:object_cache_url => testy[:image_3], :data_rating => 4},
                       {:object_cache_url => testy[:image_unknown_trust], :vetted => Vetted.unknown},
                       {}, {}, {}, {}, {}, {}], # We want more than 10 images, to test pagination, but the details don't mattr
  :toc             => [{:toc_item => testy[:overview], :description => testy[:overview_text]},
                       {:toc_item => testy[:brief_summary], :description => testy[:brief_summary_text]},
                       {:toc_item => testy[:toc_item_2]}, {:toc_item => testy[:toc_item_3]}, {:toc_item => testy[:toc_item_3]}]
)
testy[:id]            = tc.id
testy[:taxon_concept] = TaxonConcept.find(testy[:id]) # This just makes *sure* everything is loaded...
# The curator factory cleverly hides a lot of stuff that User.gen can't handle:
testy[:curator]       = build_curator(testy[:taxon_concept])
# TODO - I am slowly trying to convert all of the above options to methods to make testing clearer:
agent = testy[:curator].agent
(testy[:common_name_obj], testy[:synonym_for_common_name], testy[:tcn_for_common_name]) =
  testy[:taxon_concept].add_common_name_synonym(testy[:common_name], :agent => agent, :language => Language.english,
                                                :vetted => Vetted.trusted, :preferred => true)
testy[:taxon_concept].add_common_name_synonym(testy[:unreviewed_name], :agent => agent, :language => Language.english,
                                              :vetted => Vetted.unknown, :preferred => false)
testy[:taxon_concept].add_common_name_synonym(testy[:untrusted_name], :agent => agent, :language => Language.english,
                                              :vetted => Vetted.untrusted, :preferred => false)
# References for overview text object
testy[:taxon_concept].overview[0].add_ref('A published visible reference for testing.',
  1, Visibility.visible)
testy[:taxon_concept].overview[0].add_ref('A published invisible reference for testing.',
  1, Visibility.invisible)
testy[:taxon_concept].overview[0].add_ref('An unpublished visible reference for testing.',
  0, Visibility.visible)
testy[:taxon_concept].overview[0].add_ref('A published visible reference with an invalid identifier for testing.',
  1, Visibility.visible).add_identifier('invalid', 'An invalid reference identifier.')
testy[:taxon_concept].overview[0].add_ref('A published visible reference with a DOI identifier for testing.',
  1, Visibility.visible).add_identifier('doi', '10.12355/foo/bar.baz.230')
testy[:taxon_concept].overview[0].add_ref('A published visible reference with a URL identifier for testing.',
  1, Visibility.visible).add_identifier('url', 'some/url.html')

# Feeds:
testy[:taxon_concept].feed.post testy[:feed_body_1] = "Something"
testy[:taxon_concept].feed.post testy[:feed_body_2] = "Something Else"
testy[:taxon_concept].feed.post testy[:feed_body_3] = "Something More"
# And we want one comment that the world cannot see:
Comment.find_by_body(testy[:comment_bad]).hide User.last
testy[:user] = User.gen

testy[:child1] = build_taxon_concept(:parent_hierarchy_entry_id => testy[:taxon_concept].hierarchy_entries.first.id)
testy[:child2] = build_taxon_concept(:parent_hierarchy_entry_id => testy[:taxon_concept].hierarchy_entries.first.id)
testy[:sub_child] = build_taxon_concept(:parent_hierarchy_entry_id => testy[:child1].hierarchy_entries.first.id)

testy[:good_title] = %Q{"Good title"}
testy[:bad_title] = testy[:good_title].downcase
testy[:taxon_concept_with_bad_title] = build_taxon_concept(:canonical_form => testy[:bad_title])

testy[:taxon_concept_with_unpublished_iucn] = build_taxon_concept()
testy[:bad_iucn_value] = 'bad value'
iucn_entry = build_iucn_entry(testy[:taxon_concept_with_unpublished_iucn], testy[:bad_iucn_value])
iucn_entry.published = 0
iucn_entry.save

testy[:taxon_concept_with_no_common_names] = build_taxon_concept(
  :common_names => [],
  :toc => [ {:toc_item => TocItem.common_names} ])

testy[:tcn_count] = TaxonConceptName.count
testy[:syn_count] = Synonym.count
testy[:name_count] = Name.count
testy[:name_string] = "Piping plover"
testy[:agent] = agent
testy[:synonym] = testy[:taxon_concept].add_common_name_synonym(testy[:name_string], :agent => testy[:agent], :language => Language.english)
testy[:name] = testy[:synonym].name
testy[:tcn] = testy[:synonym].taxon_concept_name

testy[:taxon_concept].current_user = testy[:curator]
testy[:syn1] = testy[:taxon_concept].add_common_name_synonym('Some unused name', :agent => testy[:agent], :language => Language.english)
testy[:tcn1] = TaxonConceptName.find_by_synonym_id(testy[:syn1].id)
testy[:name_obj] ||= Name.last
testy[:he2]  ||= build_hierarchy_entry(1, testy[:taxon_concept], testy[:name_obj])
# Slightly different method, in order to attach it to a different HE:
testy[:syn2] = Synonym.generate_from_name(testy[:name_obj], :entry => testy[:he2], :language => Language.english, :agent => testy[:agent])
testy[:tcn2] = TaxonConceptName.find_by_synonym_id(testy[:syn2].id)

testy[:superceded_taxon_concept] = TaxonConcept.gen(:supercedure_id => testy[:id])
testy[:unpublished_taxon_concept] = TaxonConcept.gen(:published => 0, :supercedure_id => 0)

testy[:before_all_check] = User.gen(:username => 'testy_scenario')


EOL::TestInfo.save('testy', testy)
