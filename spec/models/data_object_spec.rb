require File.dirname(__FILE__) + '/../spec_helper'
require File.dirname(__FILE__) + '/../scenario_helpers'

def set_content_variables
  @big_int = 20081014234567
  @image_cache_path = %r/2008\/10\/14\/23\/4567/
  @content_server_match = $CONTENT_SERVERS[0] + $CONTENT_SERVER_CONTENT_PATH
  @content_server_match.gsub(/\d+/, '\\d+') # Because we don't care *which* server it hits...
  @content_server_match = %r/#{@content_server_match}/
  @dato = DataObject.gen(:data_type => DataType.find_by_translated(:label, 'flash'), :object_cache_url => @big_int)
end

describe DataObject do

  before(:all) do
    truncate_all_tables

    load_scenario_with_caching(:testy)
    @testy = EOL::TestInfo.load('testy')
    @taxon_concept = @testy[:taxon_concept]

    @curator         = @testy[:curator]
    @another_curator = create_curator
    @data_object     = @taxon_concept.add_user_submitted_text(:user => @curator)
    @image_dato      = @taxon_concept.images.last

    @dato = DataObject.gen(:description => 'That <b>description has unclosed <i>html tags')
    DataObjectsTaxonConcept.gen(:taxon_concept_id => @taxon_concept.id, :data_object_id => @data_object.id)
    DataObjectsTaxonConcept.gen(:taxon_concept_id => @taxon_concept.id, :data_object_id => @dato.id)
    @tag1 = DataObjectTag.gen(:key => 'foo',    :value => 'bar')
    @tag2 = DataObjectTag.gen(:key => 'foo',    :value => 'baz')
    @tag3 = DataObjectTag.gen(:key => 'boozer', :value => 'brimble')
    DataObjectTags.gen(:data_object_tag => @tag1, :data_object => @dato)
    DataObjectTags.gen(:data_object_tag => @tag2, :data_object => @dato)
    DataObjectTags.gen(:data_object_tag => @tag3, :data_object => @dato)

    @look_for_less_than_tags = true
    DataObjectTag.delete_all(:key => 'foos', :value => 'ball')
    @tag = DataObjectTag.gen(:key => 'foos', :value => 'ball')
    how_many = (DataObjectTags.minimum_usage_count_for_public_tags - 1)
    # In late April of 2008, we "dialed down" the number of tags that it takes... to one.  Which screws up
    # the tests that assume you need more than one tag to make a tag public.  This logic fixes that, but
    # in a way that's flexible enough that it will still work if we dial it back up.
    if how_many < 1
      how_many = 1
      @look_for_less_than_tags = false
    end
    how_many.times do
      DataObjectTags.gen(:data_object_tag => @tag, :data_object => @dato, :user => User.gen)
    end

    @num_lcd = LastCuratedDate.count
    @hierarchy_entry = HierarchyEntry.gen
    @image_dato.add_curated_association(@curator, @hierarchy_entry)
    @last_log_entry_after_adding_association = CuratorDataObjectLog.last
  end

#  it 'should be able to replace wikipedia articles' do
#    TocItem.gen_if_not_exists(:label => 'wikipedia')
#    published_do = DataObject.gen(:published => 1, :vetted => Vetted.trusted, :visibility => Visibility.visible)
#    published_do.toc_items << TocItem.wikipedia
#    preview_do = DataObject.gen(:guid => published_do.guid, :published => 1, :vetted => Vetted.unknown, :visibility => Visibility.preview)
#    preview_do.toc_items << TocItem.wikipedia
#
#    published_do.published.should == true
#    preview_do.visibility.should == Visibility.preview
#    preview_do.vetted.should == Vetted.unknown
#
#    preview_do.publish_wikipedia_article
#    published_do.reload
#    preview_do.reload
#
#    published_do.published.should == false
#    preview_do.published.should == true
#    preview_do.visibility.should == Visibility.visible
#    preview_do.vetted.should == Vetted.trusted
#  end
#
#  it 'curation should set to unreviewed' do
#    @data_object.curate(@curator, :vetted_id => Vetted.untrusted.id)
#    @data_object.untrusted?.should eql(true)
#    @data_object.curate(@curator, :vetted_id => Vetted.unknown.id)
#    @data_object.unknown?.should eql(true)
#  end
#
#  it 'curation should save a newly added curation comment with any curation action' do
#    [Vetted.unknown.id, Vetted.untrusted.id, Vetted.trusted.id].each do |vetted_id|
#      comments_count = @data_object.all_comments.size
#      @data_object.curate(@curator, :vetted_id => vetted_id, :comment => 'new smart comment')
#      @data_object.reload  # comments get eager loaded and cached
#      (@data_object.all_comments.size - comments_count).should == 1
#    end
#  end
#
#  it 'curation should set to untrusted' do
#    @data_object.curate(@curator, :vetted_id => Vetted.untrusted.id)
#    @data_object.untrusted?.should eql(true)
#  end
#
#  it 'curation should set to trusted' do
#    @data_object.curate(@curator, :vetted_id => Vetted.trusted.id)
#    @data_object.trusted?.should eql(true)
#  end
#
#  it 'curation should set to untrusted and hidden' do
#    @data_object.curate(@curator, :vetted_id => Vetted.untrusted.id, :visibility_id => Visibility.invisible.id)
#    @data_object.untrusted?.should eql(true)
#    @data_object.invisible?.should eql(true)
#  end
#
#  it 'curation should set untrust reasons' do
#    @data_object.curate(@curator, :vetted_id => Vetted.untrusted.id, :visibility_id => Visibility.visible.id, :untrust_reason_ids => [UntrustReason.misidentified.id, UntrustReason.poor.id, UntrustReason.other.id])
#    @data_object.untrust_reasons.length.should eql(3)
#    @data_object.curate(@curator, :vetted_id => Vetted.untrusted.id, :visibility_id =>  Visibility.visible.id, :untrust_reason_ids => [UntrustReason.misidentified.id, UntrustReason.poor.id])
#    @data_object = DataObject.find(@data_object.id)
#    @data_object.untrust_reasons.length.should eql(2)
#    @data_object.curate(@curator, :vetted_id => Vetted.trusted.id, :visibility_id => Visibility.visible.id)
#    @data_object = DataObject.find(@data_object.id)
#    @data_object.untrust_reasons.length.should eql(0)
#  end
#
#  it 'curation should add comment when untrusting' do
#    comment_count = @data_object.comments.length
#    @data_object.curate(@curator, :vetted_id => Vetted.untrusted.id, :visibility_id => Visibility.visible.id, :comment => 'new comment')
#    @data_object.comments.length.should eql(comment_count + 1)
#    @data_object.curate(@curator, :vetted_id => Vetted.untrusted.id, :visibility_id => Visibility.visible.id, :untrust_reasons_comment => 'comment generated from untrust reasons')
#    @data_object.comments.length.should eql(comment_count + 2)
#  end
#
 it 'ratings should have a default rating of 2.5' do
   d = DataObject.new
   d.data_rating.should eql(2.5)
 end

 it 'ratings should create new rating' do
   UsersDataObjectsRating.count.should eql(0)

   d = DataObject.gen
   u = User.gen
   d.rate(u,5)

   UsersDataObjectsRating.count.should eql(1)
   d.data_rating.should eql(5.0)
   r = UsersDataObjectsRating.find_by_user_id_and_data_object_guid(u.id, d.guid)
   r.rating.should eql(5)
 end

 it 'ratings should generate average rating' do
   d = DataObject.gen
   u1 = User.gen
   u2 = User.gen
   d.rate(u1,4)
   d.rate(u2,2)
   d.data_rating.should eql(3.0)
 end

 it "should be able to recalculate rating" do
   d = DataObject.gen
   u1 = User.gen
   u2 = User.gen
   d.data_rating.should == 2.5
   d.data_rating = 0
   d.save!
   d.data_rating.should == 0
   d.recalculate_rating
   d.data_rating.should == 2.5
   d.rate(u1, 4)
   d.rate(u2, 3)
   d.data_rating.should == 3.5
   d.data_rating = 0
   d.save!
   d.data_rating.should == 0
   d.recalculate_rating
   d.data_rating.should == 3.5
 end

 it 'ratings should show rating for old and new version of re-harvested dato' do
   text_dato  = @taxon_concept.overview.last
   image_dato = @taxon_concept.images.last

   text_dato.rate(@another_curator, 4)
   image_dato.rate(@another_curator, 4)

   text_dato.data_rating.should eql(4.0)
   image_dato.data_rating.should eql(4.0)

   new_text_dato  = DataObject.build_reharvested_dato(text_dato)
   new_image_dato = DataObject.build_reharvested_dato(image_dato)

   new_text_dato.data_rating.should eql(4.0)
   new_image_dato.data_rating.should eql(4.0)

   new_text_dato.rate(@another_curator, 2)
   new_image_dato.rate(@another_curator, 2)

   new_text_dato.data_rating.should eql(2.0)
   new_image_dato.data_rating.should eql(2.0)
 end

 it 'ratings should verify uniqueness of pair guid/user in users_data_objects_ratings' do
   UsersDataObjectsRating.count.should eql(0)
   d = DataObject.gen
   u = User.gen
   d.rate(u,5)
   UsersDataObjectsRating.count.should eql(1)
   d.rate(u,1)
   UsersDataObjectsRating.count.should eql(1)
 end

 it 'ratings should update existing rating' do
   d = DataObject.gen
   u = User.gen
   d.rate(u,1)
   d.rate(u,5)
   d.data_rating.should eql(5.0)
   UsersDataObjectsRating.count.should eql(1)
   r = UsersDataObjectsRating.find_by_user_id_and_data_object_guid(u.id, d.guid)
   r.rating.should eql(5)
 end


#  # TODO - DataObject.search_by_tag needs testing, but comments in the file suggest it will be changed significantly.
#  # TODO - DataObject.search_by_tags needs testing, but comments in the file suggest it will be changed significantly.
#
#  it 'tagging should create a tag hash' do
#    result = @dato.tags_hash
#    result['foo'].should    == ['bar', 'baz']
#    result['boozer'].should == ['brimble']
#  end
#
#  it 'tagging should create tag keys' do
#    @dato.tag_keys.should == ['foo', 'boozer', 'foos']
#  end
#
#  it 'tagging should create tag saving guid of the data_object into DataObjectTags' do
#    count = DataObjectTags.count
#    @dato.tag("key1", "value1", @curator)
#    DataObjectTags.count.should == count + 1
#    DataObjectTags.last.data_object_guid.should == @dato.guid
#  end
#
#  it 'tagging should verify uniqness of data_object_guid/data_object_tag_id/user_id combination during create' do
#    dot = DataObjectTags.last
#    lambda { DataObject.gen(:data_object_guid => dot.data_object_guid, :data_object_tag_id => dot.data_object_tag_id,
#                   :user_id => dot.user_id) }.should raise_error
#  end
#
#  it 'tagging should show up public and private tags for old and new version of dato after re-harvesting' do
#    count         = DataObjectTags.count
#
#    @image_dato.tag("key-private-old", "value-private-old", @curator)
#    @image_dato.tag("key-old", "value-old", @another_curator)
#    new_image_dato = DataObject.build_reharvested_dato(@image_dato)
#    new_image_dato.tag("key-private_new", "value-private-new", @curator)
#    new_image_dato.tag("key-new", "value-new", @another_curator)
#
#    DataObjectTags.count.should == count + 4
#    @image_dato.public_tags.size.should == 4
#    @curator.tags_for(@image_dato).size.should == 2
#  end
#
#  it 'tagging should mark tags as public if added by a curator' do
#    commit_transactions # We're looking at curators, here, we need cross-database joins.
#    @taxon_concept.reload
#    @image_dato.reload
#    @image_dato.tag 'color', 'blue', @another_curator
#    dotag = DataObjectTag.find_by_key_and_value('color', 'blue')
#    DataObjectTag.find_by_key_and_value('color', 'blue').is_public.should be_true
#  end
#
#  it 'should not find tags for which there are less than DEAFAULT_MIN_BLAHBLAHBLHA instances' do
#    if @look_for_less_than_tags
#      DataObject.search_by_tags([[[:foo, 'bar']]]).should be_empty
#    end
#  end
#
#  it 'should find tags specifically flagged as public, regardless of count' do
#    @tag.is_public = true
#    @tag.save!
#    DataObject.search_by_tags([[[:foo, 'bar']]]).map {|d| d.id }.should include(@dato.id)
#  end
#
#  it 'should return true if this is an image' do
#    @dato = DataObject.gen(:data_type_id => DataType.image_type_ids.first)
#    @dato.image?.should be_true
#  end
#
#  it 'should return false if this is NOT an image' do
#    @dato = DataObject.gen(:data_type_id => DataType.image_type_ids.sort.last + 1) # Clever girl...
#    @dato.image?.should_not be_true
#  end
#
#  it 'should use object_url if non-flash' do
#    @dato.data_type = DataType.gen_if_not_exists(:label => 'AnythingButFlash')
#    @dato.video_url.should == @dato.object_url
#  end
#
#  # This one dosn't work, i was trying to fix it when I had to abort...
#  #
#  # it 'should use object_cache_url (plus .flv) if available' do
#  #   @dato.object_cache_url = @image_int
#  #   @dato.video_url.should =~ /#{@test_str}\.flv$/
#  # end
#
#  it 'should return empty string if no thumbnail (when Flash)' do
#    @dato.object_cache_url = nil
#    @dato.video_url.should == ''
#    @dato.object_cache_url = ''
#    @dato.video_url.should == ''
#  end
#
#  # Also broken but I have NO IDEA WHY, and it's very frustrating.  Clearly my regex above (replacing the
#  # number with \d+) isn't working, but WHY?!?
#
#  #it 'should use content servers' do
#    #@dato.video_url.should match(@content_server_match)
#  #end
#
#  it 'should use store citable entities in an array' do
#    @dato.citable_entities.class.should == Array
#  end
#
#  it 'should add an attribution based on data_supplier_agent' do
#    supplier = Agent.gen
#    @dato.should_receive(:data_supplier_agent).at_least(1).times.and_return(supplier)
#    @dato.citable_entities.map {|c| c.display_string }.should include(supplier.full_name)
#  end
#
#  it 'should add an attribution based on license' do
#    license = License.gen()
#    @dato.should_receive(:license).at_least(1).times.and_return(license)
#    # Not so please with the hard-coded relationship between project_name and description, but can't think of a better way:
#    @dato.citable_entities.map {|c| c.display_string }.should include(license.description)
#  end
#
#  it 'should add an attribution based on rights statement (and license description)' do
#    rights = 'life, liberty, and the persuit of happiness'
#    @dato.should_receive(:rights_statement).at_least(1).times.and_return(rights)
#    @dato.citable_entities.map {|c| c.display_string }.should include(rights)
#  end
#
#  it 'should add an attribution based on location' do
#    location = 'life, liberty, and the persuit of happiness'
#    @dato.should_receive(:location).at_least(1).times.and_return(location)
#    @dato.citable_entities.map {|c| c.display_string }.should include(location)
#  end
#
#  it 'should add an attribution based on Source URL' do
#    source = 'http://some.biological.edu/with/good/data'
#    @dato.should_receive(:source_url).at_least(1).times.and_return(source)
#    @dato.citable_entities.map {|c| c.link_to_url }.should include(source) # Note HOMEPAGE, not project_name
#  end
#
#  it 'should add an attribution based on Citation' do
#    citation = 'http://some.biological.edu/with/good/data'
#    @dato.should_receive(:bibliographic_citation).at_least(1).times.and_return(citation)
#    @dato.citable_entities.map {|c| c.display_string }.should include(citation)
#  end
#
#  it 'should create a new LastCuratedDate pointing to the right TC and user' do
#    @data_object.curator_activity_flag(@curator, @taxon_concept.id)
#    LastCuratedDate.count.should == @num_lcd + 1
#    LastCuratedDate.last.taxon_concept_id.should == @taxon_concept.id
#    LastCuratedDate.last.user_id.should == @curator.id
#  end
#
#  it 'should do nothing if the current user cannot curate this DataObject' do
#    new_user   = User.gen
#    @data_object.curator_activity_flag(new_user, @taxon_concept.id)
#    LastCuratedDate.count.should_not == @num_lcd + 1
#  end
#
#  it 'should set a last curated date when a curator curates this data object' do
#    current_count = @num_lcd
#    [Vetted.trusted.id, Vetted.untrusted.id].each do |vetted_method|
#      [Visibility.invisible.id, Visibility.visible.id, Visibility.inappropriate.id].each do |visibility_method|
#        @image_dato.curate(@curator, :vetted_id => vetted_method, :visibility_id => visibility_method)
#        LastCuratedDate.count.should == (current_count += 1)
#      end
#    end
#  end
#
#  it 'should set a last curated date when a curator creates a new text object' do
#    DataObject.create_user_text(
#      {:data_object => {:description => "fun!",
#                        :title => 'funnerer',
#                        :license_id => License.last.id,
#                        :language_id => Language.english.id},
#       :taxon_concept_id => @taxon_concept.id,
#       :data_objects_toc_category => {:toc_id => TocItem.overview.id}},
#      @curator)
#    LastCuratedDate.count.should == @num_lcd + 1
#  end
#
#  it 'should set a last curated date when a curator updates a text object' do
#    # I tried gen here, but it wasn't working (JRice)
#    UsersDataObject.create(:data_object_id => @data_object.id,
#                           :user_id => @curator.id)
#    DataObject.update_user_text(
#      {:data_object => {:description => "fun!",
#                        :title => 'funnerer',
#                        :license_id => License.last.id,
#                        :language_id => Language.english.id},
#       :id => @data_object.id,
#       :taxon_concept_id => @taxon_concept.id,
#       :data_objects_toc_category => {:toc_id => TocItem.overview.id}},
#      @curator)
#    LastCuratedDate.count.should == @num_lcd + 1
#  end
#
#  # 'Gofas, S.; Le Renard, J.; Bouchet, P. (2001). Mollusca, <B><I>in</I></B>: Costello, M.J. <i>et al.</i> (Ed.) (2001). <i>European register of marine species: a check-list of the marine species in Europe and a bibliography of guides to their identification.'
#
#  it 'should close tags in data_objects (incl. users)' do
#    dato_descr_before = @dato.description
#    dato_descr_after  = @dato.description.balance_tags
#
#    dato_descr_after.should == 'That <b>description has unclosed <i>html tags</b></i>'
#  end
#
#  it 'should close tags in references' do
#    full_ref         = 'a <b>b</div></HTML><i'
#    repaired_ref     = '<div>a <b>b</div></HTML><i</b>'
#
#    @dato.refs << ref = Ref.gen(:full_reference => full_ref, :published => 1, :visibility => Visibility.visible)
#    ref_after = @dato.visible_references[0].full_reference.balance_tags
#    ref_after.should == repaired_ref
#  end
#
#  it 'feeds should find text data objects for feeds' do
#    res = DataObject.for_feeds(:text, @taxon_concept.id)
#    res.class.should == Array
#    data_types = res.map {|i| i['data_type_id']}.uniq
#    data_types.size.should == 1
#    DataType.find(data_types[0]).should == DataType.find_by_translated(:label, "Text")
#  end
#
#  it 'feeds should find image data objects for feeds' do
#    res = DataObject.for_feeds(:images, @taxon_concept.id)
#    res.class.should == Array
#    data_types = res.map {|i| i['data_type_id']}.uniq
#    data_types.size.should == 1
#    DataType.find(data_types[0]).should == DataType.find_by_translated(:label, "Image")
#  end
#
#  it 'feeds should find image and text data objects for feeds' do
#    res = DataObject.for_feeds(:all, @taxon_concept.id)
#    res.class.should == Array
#    data_types = res.map {|i| i['data_type_id']}.uniq
#    data_types.size.should == 2
#    data_types = data_types.map {|i| DataType.find(i).label}.sort
#    data_types.should == ["Image", "Text"]
#  end
#
#  it 'should delegate #cache_path to ContentServer' do
#    ContentServer.should_receive(:cache_path).with(:foo, :bar).and_return(:worked)
#    DataObject.cache_path(:foo, :bar).should == :worked
#  end
#
#  it 'should default to the object_title' do
#    dato = DataObject.gen(:object_title => 'Something obvious')
#    dato.short_title.should == 'Something obvious'
#  end
#
#  it 'should resort to the first line of the description if the object_title is empty' do
#    dato = DataObject.gen(:object_title => '', :description => "A long description\nwith multiple lines of stuff")
#    dato.short_title.should == "A long description"
#  end
#
#  it 'should resort to the first 32 characters (plus three dots) if the decsription is too long and one-line' do
#    dato = DataObject.gen(:object_title => '', :description => "The quick brown fox jumps over the lazy dog, and now is the time for all good men to come to the aid of their country")
#    dato.short_title.should == "The quick brown fox jumps over t..."
#  end
#
#  # TODO - ideally, this should be something like "Image of Procyon lotor", but that would be a LOT of work to extract
#  # froom the data_objects/show view (mainly because it builds links).
#  it 'should resort to the data type, if there is no description' do
#    dato = DataObject.gen(:object_title => '', :description => '', :data_type => DataType.image)
#    dato.short_title.should == "Image"
#  end
#
#  it 'should update the Solr record when the object is curated' do
#    d = DataObject.gen(:vetted => Vetted.trusted, :visibility => Visibility.visible)
#    @solr = SolrAPI.new($SOLR_SERVER, $SOLR_DATA_OBJECTS_CORE)
#    @solr.delete_all_documents
#    @solr.build_data_object_index
#    response = @solr.query_lucene("data_object_id:#{d.id}")
#    data_object_hash = response['response']['docs'][0]
#    data_object_hash['vetted_id'][0].should == Vetted.trusted.id
#    data_object_hash['visibility_id'][0].should == Visibility.visible.id
#
#    # Making it untrusted
#    d.curate(@curator, :vetted_id => Vetted.untrusted.id)
#    response = @solr.query_lucene("data_object_id:#{d.id}")
#    curated_data_object_hash = response['response']['docs'][0]
#    curated_data_object_hash['vetted_id'][0].should == Vetted.untrusted.id
#    curated_data_object_hash['visibility_id'][0].should == Visibility.visible.id
#
#    # Making it invisible
#    d.curate(@curator, :visibility_id => Visibility.invisible.id)
#    response = @solr.query_lucene("data_object_id:#{d.id}")
#    curated_data_object_hash = response['response']['docs'][0]
#    curated_data_object_hash['vetted_id'][0].should == Vetted.untrusted.id
#    curated_data_object_hash['visibility_id'][0].should == Visibility.invisible.id
#
#    # Making it trusted and visible
#    d.curate(@curator, :vetted_id => Vetted.trusted.id, :visibility_id => Visibility.visible.id)
#    response = @solr.query_lucene("data_object_id:#{d.id}")
#    curated_data_object_hash = response['response']['docs'][0]
#    curated_data_object_hash['vetted_id'][0].should == Vetted.trusted.id
#    curated_data_object_hash['visibility_id'][0].should == Visibility.visible.id
#  end
#
#  it 'should have a feed' do
#    dato = DataObject.gen
#    dato.respond_to?(:feed).should be_true
#    dato.feed.should be_a EOL::Feed
#  end
#
#  it 'should post a note to the feed when a curator rates the object' do
#    @image_dato.rate(@curator, 3)
#    @image_dato.feed.last.body.should =~ /(rating|rated)/
#    @image_dato.feed.last.feed_item_type.should == FeedItemType.curator_activity
#    @image_dato.feed.last.user.should == @curator
#  end
#
#  it 'should post a note to the feed when a curator trusts the object' do
#    @image_dato.curate(@curator, :vetted_id => Vetted.trusted.id)
#    @image_dato.feed.last.body.should =~ /trusted/
#    @image_dato.feed.last.feed_item_type.should == FeedItemType.curator_activity
#    @image_dato.feed.last.user.should == @curator
#  end
#
#  it 'should post a note to the feed (with reasons) when a curator untrusts the object' do
#    @image_dato.curate(@curator, :vetted_id => Vetted.untrusted.id, :untrust_reasons_comment => 'testing the comments')
#    @image_dato.feed.last.body.should =~ /untrusted/
#    @image_dato.feed.last.body.should =~ /testing the comments/
#    @image_dato.feed.last.feed_item_type.should == FeedItemType.curator_activity
#    @image_dato.feed.last.user.should == @curator
#  end
#
#  it 'should post a note to the feed when a curator "unreviews" the object' do
#    @image_dato.curate(@curator, :vetted_id => Vetted.unknown.id)
#    @image_dato.feed.last.body.should =~ /marked.*as unreviewed/
#    @image_dato.feed.last.feed_item_type.should == FeedItemType.curator_activity
#    @image_dato.feed.last.user.should == @curator
#  end
#
#  it 'should post a note to the feed when a curator marks the object as invisible' do
#    @image_dato.curate(@curator, :visibility_id => Visibility.invisible.id)
#    @image_dato.feed.last.body.should =~ /hid an image/i
#    @image_dato.feed.last.feed_item_type.should == FeedItemType.curator_activity
#    @image_dato.feed.last.user.should == @curator
#  end
#
#  it 'should post a note to the feed when a curator marks the object as inappropriate' do
#    @image_dato.curate(@curator, :visibility_id => Visibility.inappropriate.id)
#    @image_dato.feed.last.body.should =~ /marked an image as inappropriate/i
#    @image_dato.feed.last.feed_item_type.should == FeedItemType.curator_activity
#    @image_dato.feed.last.user.should == @curator
#  end
#
#  it 'should post a note to the feed when a curator shows the object' do
#    @image_dato.curate(@curator, :visibility_id => Visibility.visible.id)
#    @image_dato.feed.last.body.should =~ /made this image visible/i
#    @image_dato.feed.last.feed_item_type.should == FeedItemType.curator_activity
#    @image_dato.feed.last.user.should == @curator
#  end

  it 'should add an entry in curated_data_objects_hierarchy_entries when a curator adds an association' do
    cdohe = CuratedDataObjectsHierarchyEntry.find_by_hierarchy_entry_id_and_data_object_id(@hierarchy_entry.id,
                                                                                           @image_dato.id)
    cdohe.should_not == nil
  end

  it 'should add an entry to the curator activity log when a curator adds an association' do
    type = ChangeableObjectType.curated_data_objects_hierarchy_entry
    type.should_not == nil
    action = ActionWithObject.add_association
    action.should_not == nil
    curator_action = CuratorActivity.add_association
    curator_action.should_not == nil
    @last_log_entry_after_adding_association.user.should == @curator
    @last_log_entry_after_adding_association.data_object.should == @image_dato
    @last_log_entry_after_adding_association.curator_activity.should == curator_action
    last_action = CuratorActivityLog.last
    last_action.action_with_object.should == action
    last_action.changeable_object_type.should == type
    last_action.user.should == @curator
  end

  it 'should trust associations added by curators' do
    cdohe = CuratedDataObjectsHierarchyEntry.find_by_hierarchy_entry_id_and_data_object_id(@hierarchy_entry.id,
                                                                                           @image_dato.id)
    cdohe.trusted?.should eql(true)
  end

  it 'should remove the entry in curated_data_objects_hierarchy_entries when a curator removes their association' do
    cdohe_count = CuratedDataObjectsHierarchyEntry.count(:conditions => "hierarchy_entry_id = #{@hierarchy_entry.id}")
    @image_dato.remove_curated_association(@another_curator, @hierarchy_entry)
    CuratedDataObjectsHierarchyEntry.count(:conditions => "hierarchy_entry_id = #{@hierarchy_entry.id}").should ==
        cdohe_count - 1
    cdohe = CuratedDataObjectsHierarchyEntry.find_by_hierarchy_entry_id_and_data_object_id(@hierarchy_entry.id,
                                                                                           @image_dato.id)
    cdohe.should == nil
  end

  it '#untrust_reasons should return the untrust reasons'

  it '#curate_association should curate given association'

  it '#published_entries should read data_objects_hierarchy_entries' do
    @data_object.should_receive(:hierarchy_entries).and_return([])
    @data_object.published_entries.should == []
  end

  it '#published_entries should have a user_id on hierarchy entries that were added by curators' do
    @data_object.published_entries.should == []
  end

end
