require File.dirname(__FILE__) + '/../spec_helper'
require File.dirname(__FILE__) + '/../scenario_helpers'

def set_content_variables
  @big_int = 20081014234567
  @image_cache_path = %r/2008\/10\/14\/23\/4567/
  @content_server_match = $CONTENT_SERVERS[0] + $CONTENT_SERVER_CONTENT_PATH
  @content_server_match.gsub(/\d+/, '\\d+') # Because we don't care *which* server it hits...
  @content_server_match = %r/#{@content_server_match}/
  @dato = DataObject.gen(:data_type => DataType.find_by_label('flash'), :object_cache_url => @big_int)
end

def create_user_text_object
  taxon_concept = TaxonConcept.last ||
                  build_taxon_concept(:rank => 'kingdom', :canonical_form => 'Animalia',
                                      :common_names => ['Animals'])
  toc_item = TocItem.gen({:label => 'Overview'})
  params = {
    :taxon_concept_id => taxon_concept.id,
    :data_objects_toc_category => { :toc_id => toc_item.id}
  }

  do_params = {
    :license_id => License.find_by_title('cc-by-nc 3.0').id,
    :language_id => Language.find_by_label('English').id,
    :description => 'a new text object',
    :object_title => 'new title'
  }

  params[:data_object] = do_params

  params[:references] = ['foo','bar']

  DataObject.create_user_text(params, User.gen)
end

describe DataObject do

  before(:all) do
    truncate_all_tables
    load_foundation_cache # Just so we have DataType IDs and the like.
    unless @already_built_tc
      build_taxon_concept
    end
    @already_built_tc = true
  end
  
  it 'should be able to replace wikipedia articles' do
    TocItem.gen(:label => 'wikipedia')
    published_do = DataObject.gen(:published => 1, :vetted => Vetted.trusted, :visibility => Visibility.visible)
    published_do.toc_items << TocItem.wikipedia
    preview_do = DataObject.gen(:guid => published_do.guid, :published => 1, :vetted => Vetted.unknown, :visibility => Visibility.preview)
    preview_do.toc_items << TocItem.wikipedia
    
    published_do.published.should == true
    preview_do.visibility.should == Visibility.preview
    preview_do.vetted.should == Vetted.unknown
    
    preview_do.publish_wikipedia_article
    published_do.reload
    preview_do.reload
    
    published_do.published.should == false
    preview_do.published.should == true
    preview_do.visibility.should == Visibility.visible
    preview_do.vetted.should == Vetted.trusted
  end

  describe 'curation' do
    before(:all) do
      @taxon_concept = TaxonConcept.last || build_taxon_concept
      @user          = @taxon_concept.acting_curators.to_a.last
      @data_object   = @taxon_concept.add_user_submitted_text(:user => @user)
    end

    it 'should set to untrusted' do
      @data_object.curate(@user, :vetted_id => Vetted.untrusted.id)
      @data_object.untrusted?.should eql(true)
    end

    it 'should set to trusted' do
      @data_object.curate(@user, :vetted_id => Vetted.trusted.id)
      @data_object.trusted?.should eql(true)
    end

    it 'should set to untrusted and hidden' do
      @data_object.curate(@user, :vetted_id => Vetted.untrusted.id, :visibility_id => Visibility.invisible.id)
      @data_object.untrusted?.should eql(true)
      @data_object.invisible?.should eql(true)
    end

    it 'should set untrust reasons' do
      @data_object.curate(@user, :vetted_id => Vetted.untrusted.id, :visibility_id => Visibility.visible.id, :untrust_reason_ids => [UntrustReason.misidentified.id, UntrustReason.poor.id, UntrustReason.other.id])
      @data_object.untrust_reasons.length.should eql(3)
      @data_object.curate(@user, :vetted_id => Vetted.untrusted.id, :visibility_id =>  Visibility.visible.id, :untrust_reason_ids => [UntrustReason.misidentified.id, UntrustReason.poor.id])
      @data_object = DataObject.find(@data_object.id)
      @data_object.untrust_reasons.length.should eql(2)
      @data_object.curate(@user, :vetted_id => Vetted.trusted.id, :visibility_id => Visibility.visible.id)
      @data_object = DataObject.find(@data_object.id)
      @data_object.untrust_reasons.length.should eql(0)
    end

    it 'should add comment when untrusting' do
      comment_count = @data_object.comments.length
      @data_object.curate(@user, :vetted_id => Vetted.untrusted.id, :visibility_id => Visibility.visible.id, :comment => 'new comment')
      @data_object.comments.length.should eql(comment_count + 1)
      @data_object.curate(@user, :vetted_id => Vetted.untrusted.id, :visibility_id => Visibility.visible.id, :untrust_reasons_comment => 'comment generated from untrust reasons')
      @data_object.comments.length.should eql(comment_count + 2)
    end
  end

  describe 'ratings' do

    it 'should have a default rating of 2.5' do
      d = DataObject.new
      d.data_rating.should eql(2.5)
    end

    it 'should create new rating' do
      UsersDataObjectsRating.count.should eql(0)

      d = DataObject.gen
      u = User.gen
      d.rate(u,5)

      UsersDataObjectsRating.count.should eql(1)
      d.data_rating.should eql(5.0)
      r = UsersDataObjectsRating.find_by_user_id_and_data_object_guid(u.id, d.guid)
      r.rating.should eql(5)
    end

    it 'should generate average rating' do
      d = DataObject.gen
      u1 = User.gen
      u2 = User.gen
      d.rate(u1,4)
      d.rate(u2,2)
      d.data_rating.should eql(3.0)
    end
    
    it 'should show rating for old and new version of re-harvested dato' do
      taxon_concept = TaxonConcept.last || build_taxon_concept
      curator    = create_curator(taxon_concept)  
      text_dato  = taxon_concept.overview.last 
      image_dato = taxon_concept.images.last 

      text_dato.rate(curator, 4)
      image_dato.rate(curator, 4)
   
      text_dato.data_rating.should eql(4.0)
      image_dato.data_rating.should eql(4.0)

      new_text_dato  = DataObject.build_reharvested_dato(text_dato)
      new_image_dato = DataObject.build_reharvested_dato(image_dato)

      new_text_dato.data_rating.should eql(4.0)
      new_image_dato.data_rating.should eql(4.0)

      new_text_dato.rate(curator, 2)
      new_image_dato.rate(curator, 2)

      new_text_dato.data_rating.should eql(2.0)
      new_image_dato.data_rating.should eql(2.0)
    end
    
    it 'should verify uniqueness of pair guid/user in users_data_objects_ratings' do
      UsersDataObjectsRating.count.should eql(0)
      d = DataObject.gen
      u = User.gen
      d.rate(u,5)
      UsersDataObjectsRating.count.should eql(1)
      d.rate(u,1)
      UsersDataObjectsRating.count.should eql(1)      
    end
    
    it 'should update existing rating' do
      d = DataObject.gen
      u = User.gen
      d.rate(u,1)
      d.rate(u,5)
      d.data_rating.should eql(5.0)
      UsersDataObjectsRating.count.should eql(1)
      r = UsersDataObjectsRating.find_by_user_id_and_data_object_guid(u.id, d.guid)
      r.rating.should eql(5)
    end
    
  end


  # TODO - DataObject.search_by_tag needs testing, but comments in the file suggest it will be changed significantly.
  # TODO - DataObject.search_by_tags needs testing, but comments in the file suggest it will be changed significantly.

  describe 'tagging' do
    
    before(:all) do
      @taxon_concept = TaxonConcept.last || build_taxon_concept
      @image_dato    = @taxon_concept.images.last       
    end
    

    before(:each) do
      @dato = DataObject.gen
      @user = User.gen
      @tag1 = DataObjectTag.gen(:key => 'foo',    :value => 'bar')
      @tag2 = DataObjectTag.gen(:key => 'foo',    :value => 'baz')
      @tag3 = DataObjectTag.gen(:key => 'boozer', :value => 'brimble')
      DataObjectTags.gen(:data_object_tag => @tag1, :data_object => @dato)
      DataObjectTags.gen(:data_object_tag => @tag2, :data_object => @dato)
      DataObjectTags.gen(:data_object_tag => @tag3, :data_object => @dato)
    end

    after(:all) do
      DataObjectTag.delete_all
      DataObjectTags.delete_all
    end

    it 'should create a tag hash' do
      result = @dato.tags_hash
      result['foo'].should    == ['bar', 'baz']
      result['boozer'].should == ['brimble']
    end

    it 'should create tag keys' do
      @dato.tag_keys.should == ['foo', 'boozer']
    end

    it 'should create tag saving guid of the data_object into DataObjectTags' do
      count = DataObjectTags.count
      @dato.tag("key1", "value1", @user)
      DataObjectTags.count.should == count + 1
      DataObjectTags.last.data_object_guid.should == @dato.guid
    end
    
    it 'should verify uniqness of data_object_guid/data_object_tag_id/user_id combination during create' do
      dot = DataObjectTags.last
      lambda { DataObject.gen(:data_object_guid => dot.data_object_guid, :data_object_tag_id => dot.data_object_tag_id, 
                     :user_id => dot.user_id) }.should raise_error
    end
    
    it 'should show up public and private tags for old and new version of dato after re-harvesting' do
      curator       = build_curator(@taxon_concept)  
      count         = DataObjectTags.count
      
      @image_dato.tag("key-private-old", "value-private-old", @user)
      @image_dato.tag("key-old", "value-old", curator)
      new_image_dato = DataObject.build_reharvested_dato(@image_dato)
      new_image_dato.tag("key-private_new", "value-private-new", @user)
      new_image_dato.tag("key-new", "value-new", curator)
      
      DataObjectTags.count.should == count + 4
      @image_dato.public_tags.size.should == 4
      @user.tags_for(@image_dato).size.should == 2
    end
    
    it 'should mark tags as public if added by a curator' do
      commit_transactions # We're looking at curators, here, we need cross-database joins.
      tc      = TaxonConcept.last || build_taxon_concept
      curator = build_curator(tc)
      # We CANNOT use @dato here, because it doesn't have all of the required relationships to our TaxonConcept:
      dato    = tc.add_user_submitted_text
      dato.tag 'color', 'blue', curator
      dotag = DataObjectTag.find_by_key_and_value('color', 'blue')
      DataObjectTag.find_by_key_and_value('color', 'blue').is_public.should be_true
    end
  end

  describe 'search_by_tags' do

    before(:each) do
      @look_for_less_than_tags = true
      @dato = DataObject.gen
      DataObjectTag.delete_all(:key => 'foo', :value => 'bar')
      @tag = DataObjectTag.gen(:key => 'foo', :value => 'bar')
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
    end

    it 'should not find tags for which there are less than DEAFAULT_MIN_BLAHBLAHBLHA instances' do
      if @look_for_less_than_tags
        DataObject.search_by_tags([[[:foo, 'bar']]]).should be_empty
      end
    end

    it 'should find tags specifically flagged as public, regardless of count' do
      @tag.is_public = true
      @tag.save!
      DataObject.search_by_tags([[[:foo, 'bar']]]).map {|d| d.id }.should include(@dato.id)
    end

  end

  describe '#image?' do

    it 'should return true if this is an image' do
      @dato = DataObject.gen(:data_type_id => DataType.image_type_ids.first)
      @dato.image?.should be_true
    end

    it 'should return false if this is NOT an image' do
      @dato = DataObject.gen(:data_type_id => DataType.image_type_ids.sort.last + 1) # Clever girl...
      @dato.image?.should_not be_true
    end

  end

  describe '#video_url' do
    before(:each) do
      set_content_variables
    end

    it 'should use object_url if non-flash' do
      @dato.data_type = DataType.gen(:label => 'AnythingButFlash')
      @dato.video_url.should == @dato.object_url
    end



    # This one dosn't work, i was trying to fix it when I had to abort...
    #
    # it 'should use object_cache_url (plus .flv) if available' do
    #   @dato.object_cache_url = @image_int
    #   @dato.video_url.should =~ /#{@test_str}\.flv$/
    # end

    it 'should return empty string if no thumbnail (when Flash)' do
      @dato.object_cache_url = nil
      @dato.video_url.should == ''
      @dato.object_cache_url = ''
      @dato.video_url.should == ''
    end

    # Also broken but I have NO IDEA WHY, and it's very frustrating.  Clearly my regex above (replacing the
    # number with \d+) isn't working, but WHY?!?

    #it 'should use content servers' do
      #@dato.video_url.should match(@content_server_match)
    #end

  end

  describe 'attributions' do

    before(:each) do
      set_content_variables
    end

    it 'should use Attributions object' do
      some_array = [:some, :array]
      @dato.attributions.class.should == Attributions
    end

    it 'should add an attribution based on data_supplier_agent' do
      supplier = Agent.gen
      @dato.should_receive(:data_supplier_agent).and_return(supplier)
      @dato.attributions.map {|ado| ado.agent }.should include(supplier)
    end

    it 'should add an attribution based on license' do
      license = License.gen()
      @dato.should_receive(:license).and_return(license)
      # Not so please with the hard-coded relationship between project_name and description, but can't think of a better way:
      @dato.attributions.map {|ado| ado.agent.project_name }.should include(license.description)
    end

    it 'should add an attribution based on rights statement (and license description)' do
      rights = 'life, liberty, and the persuit of happiness'
      @dato.should_receive(:rights_statement).and_return(rights)
      @dato.attributions.map {|ado| ado.agent.project_name }.should include(rights)
    end

    it 'should add an attribution based on location' do
      location = 'life, liberty, and the persuit of happiness'
      @dato.should_receive(:location).at_least(1).times.and_return(location)
      @dato.attributions.map {|ado| ado.agent.project_name }.should include(location)
    end

    it 'should add an attribution based on Source URL' do
      source = 'http://some.biological.edu/with/good/data'
      @dato.should_receive(:source_url).at_least(1).times.and_return(source)
      @dato.attributions.map {|ado| ado.agent.homepage }.should include(source) # Note HOMEPAGE, not project_name
    end
    
    # # this test isn't working right - in fact all of these need rethinking
    # it 'should show nothing if there is no Source URL' do
    #   source = ''
    #   @dato.should_receive(:source_url).at_least(1).times.and_return(source)
    #   @dato.attributions.map {|ado| ado.agent.homepage }.should_not include(source) 
    # end

    it 'should add an attribution based on Citation' do
      citation = 'http://some.biological.edu/with/good/data'
      @dato.should_receive(:bibliographic_citation).at_least(1).times.and_return(citation)
      @dato.attributions.map {|ado| ado.agent.project_name }.should include(citation)
    end

  end
  
  describe '#curator_activity_flag' do
    
    before(:each) do
      commit_transactions
      @taxon_concept = TaxonConcept.last || build_taxon_concept
      @user          = @taxon_concept.acting_curators.to_a.last
      @data_object   = @taxon_concept.add_user_submitted_text(:user => @user)
      @num_lcd       = LastCuratedDate.count
    end

    it 'should create a new LastCuratedDate pointing to the right TC and user' do
      @data_object.curator_activity_flag(@user, @taxon_concept.id)
      LastCuratedDate.count.should == @num_lcd + 1
      LastCuratedDate.last.taxon_concept_id.should == @taxon_concept.id
      LastCuratedDate.last.user_id.should == @user.id
    end
    
    it 'should do nothing if the current user cannot curate this DataObject' do
      new_user   = User.gen
      @data_object.curator_activity_flag(new_user, @taxon_concept.id)
      LastCuratedDate.count.should_not == @num_lcd + 1
    end
    
    it 'should set a last curated date when a curator curates this data object' do
      current_count = @num_lcd
      [Vetted.trusted.id, Vetted.untrusted.id].each do |vetted_method|
        [Visibility.invisible.id, Visibility.visible.id, Visibility.inappropriate.id].each do |visibility_method|
          @data_object.curate(@user, :vetted_id => vetted_method, :visibility_id => visibility_method)
          LastCuratedDate.count.should == (current_count += 1)
        end
      end
    end
    
    it 'should set a last curated date when a curator creates a new text object' do
      DataObject.create_user_text(
        {:data_object => {:description => "fun!",
                          :title => 'funnerer',
                          :license_id => License.last.id,
                          :language_id => Language.english.id},
         :taxon_concept_id => @taxon_concept.id,
         :data_objects_toc_category => {:toc_id => TocItem.overview.id}},
        @user)
      LastCuratedDate.count.should == @num_lcd + 1
    end
    
    it 'should set a last curated date when a curator updates a text object' do
      # I tried gen here, but it wasn't working (JRice)
      UsersDataObject.create(:data_object_id => @data_object.id,
                             :user_id => @user.id)
      DataObject.update_user_text(
        {:data_object => {:description => "fun!",
                          :title => 'funnerer',
                          :license_id => License.last.id,
                          :language_id => Language.english.id},
         :id => @data_object.id,
         :taxon_concept_id => @taxon_concept.id,
         :data_objects_toc_category => {:toc_id => TocItem.overview.id}},
        @user)
      LastCuratedDate.count.should == @num_lcd + 1
    end
    
  end
  
  describe 'close tag' do
    # 'Gofas, S.; Le Renard, J.; Bouchet, P. (2001). Mollusca, <B><I>in</I></B>: Costello, M.J. <i>et al.</i> (Ed.) (2001). <i>European register of marine species: a check-list of the marine species in Europe and a bibliography of guides to their identification.'
    before(:each) do
      @dato = DataObject.gen(:data_type_id => DataType.text_type_ids.first, :description => 'That <b>description has unclosed <i>html tags')
    end

    it 'should close tags in data_objects (incl. users)' do
      dato_descr_before = @dato.description
      dato_descr_after  = @dato.description.sanitize_html
      
      dato_descr_after.should eql('That <b>description has unclosed <i>html tags</i></b>')
    end

    it 'should close tags in references' do
      full_ref         = 'a <b>b</div></HTML><i'
      repaired_ref     = 'a <b>b</b><i></i>'
      alt_repaired_ref = 'a <b>b</b>' # It's okay if this is how it's cleaned
      
      @dato.refs << ref = Ref.gen(:full_reference => full_ref, :published => 1, :visibility => Visibility.visible)
      ref_before = @dato.visible_references[0].full_reference
      ref_after  = @dato.visible_references[0].full_reference.sanitize_html      
      (ref_after == repaired_ref or ref_after == alt_repaired_ref).should be_true
    end
  end

  describe '#harvested_ancestries' do
    before(:all) do
      commit_transactions
      @taxon_concept = TaxonConcept.last || build_taxon_concept
      @img_dato = @taxon_concept.images.first
    end

    #harvested_ancestries should return an array of one or more ancestries. Each ancestry
    #is an array of HierarchyEntry instances
    it "should return ancestry" do
      ancestries = @img_dato.harvested_ancestries
      ancestries.is_a?(Array).should be_true
      ancestries[0].is_a?(Array).should be_true
      ancestries[0][0].is_a?(HierarchyEntry).should be_true
    end
  end

  describe 'feeds functions' do
    before(:all) do
      truncate_all_tables
      load_foundation_cache
      DataObject.delete_all
      @tc = build_taxon_concept()
    end

    it 'should find text data objects for feeds' do
      res = DataObject.for_feeds(:text, @tc.id)
      res.class.should == Array
      data_types = res.map {|i| i['data_type_id']}.uniq
      data_types.size.should == 1
      DataType.find(data_types[0]).should == DataType.find_by_label("Text")
    end
    
    it 'should find image data objects for feeds' do
      res = DataObject.for_feeds(:images, @tc.id)
      res.class.should == Array
      data_types = res.map {|i| i['data_type_id']}.uniq
      data_types.size.should == 1
      DataType.find(data_types[0]).should == DataType.find_by_label("Image")
    end

    it 'should find image and text data objects for feeds' do
      res = DataObject.for_feeds(:all, @tc.id)
      res.class.should == Array
      data_types = res.map {|i| i['data_type_id']}.uniq
      data_types.size.should == 2
      data_types = data_types.map {|i| DataType.find(i).label}.sort
      data_types.should == ["Image", "Text"]
    end

  end

  it 'should delegate #cache_path to ContentServer' do
    ContentServer.should_receive(:cache_path).with(:foo, :bar).and_return(:worked)
    DataObject.cache_path(:foo, :bar).should == :worked
  end

end
