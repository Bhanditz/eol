require File.dirname(__FILE__) + '/../spec_helper'

# I just want to avoid using #gen (which would require foundation scenario):
def bogus_hierarchy_entry
  HierarchyEntry.create(:guid => 'foo', :ancestry => '1', :depth => 1, :lft => 1, :rank_id => 1, :vetted_id => 1,
                        :parent_id => 1, :name_id => 1, :identifier => 'foo', :rgt => 2, :taxon_concept_id => 1,
                        :visibility_id => 1, :source_url => 'foo', :hierarchy_id => 1)
end

def rebuild_convenience_method_data
  @user = User.gen
  @descriptions = ['these', 'do not really', 'matter much'].sort
  @datos = @descriptions.map {|d| DataObject.gen(:description => d) }
  @dato_ids = @datos.map{|d| d.id}.sort
  @datos.each {|dato| UsersDataObject.create(:user_id => @user.id, :data_object_id => dato.id) }
end

describe User do

  before(:all) do
    @password = 'dragonmaster'
    load_foundation_cache
    @user = User.gen :username => 'KungFuPanda', :password => @password
    @user.should_not be_a_new_record
    @admin = User.gen(:username => 'MisterAdminToYouBuddy')
    @admin.grant_admin
    @he = bogus_hierarchy_entry
    @curator = User.gen(:credentials => 'whatever', :curator_scope => 'whatever')
  end

  it "should generate a random hexadecimal key" do
    key = User.generate_key
    key.should match /[a-f0-9]{40}/
    User.generate_key.should_not == key
  end

  it 'should tell us if an account is active on master' do
    User.should_receive(:with_master).and_return(true)
    status = User.active_on_master?("invalid@some-place.org")
    status.should be_true
  end

  it 'should hash passwords with MD5' do
    @pass = 'boogers'
    User.hash_password(@pass).should == Digest::MD5.hexdigest(@pass)
  end

  it 'should have a log method that creates a UserActivityLog entry (when enabled)' do
    old_log_val = $LOG_USER_ACTIVITY
    begin
      $LOG_USER_ACTIVITY = true
      count = UserActivityLog.count
      @user.log_activity(:clicked_link)
      wait_for_insert_delayed do
        UserActivityLog.count.should == count + 1
      end
      UserActivityLog.last.user_id.should == @user.id
    ensure
      $LOG_USER_ACTIVITY = old_log_val
    end
  end

  it 'should provide a nice, empty version of a user with #create_new' do
    test_name = "Krampus"
    user = User.create_new(:username => test_name)
    user.username.should == test_name
    user.default_taxonomic_browser.should == $DEFAULT_TAXONOMIC_BROWSER
    user.expertise.should == $DEFAULT_EXPERTISE.to_s
    user.language.should == Language.english
    user.mailing_list.should == false
    user.content_level.should == $DEFAULT_CONTENT_LEVEL.to_i
    user.vetted.should == $DEFAULT_VETTED
    user.credentials.should == ''
    user.curator_scope.should == ''
    user.active.should == true
    user.flash_enabled.should == true
  end

  it 'should NOT log activity on a "fake" (unsaved, temporary, non-logged-in) user' do
    user = User.create_new
    count = UserActivityLog.count
    user.log_activity(:clicked_link)
    UserActivityLog.count.should == count
  end

  it 'should authenticate existing user with correct password, returning true and user back' do
    success, user=User.authenticate( @user.username, @password)
    success.should be_true
    user.id.should == @user.id
  end

  it 'should authenticate existing user with correct email address and password, returning true and user back' do
    success, user=User.authenticate( @user.email, @password )
    success.should be_true
    user.id.should == @user.id
  end

  it 'should return false as first return value for non-existing user' do
    success, user = User.authenticate('idontexistATALL', @password)
    success.should be_false
    user.should be_blank
  end

  it 'should return false as first return value for user with incorrect password' do
    success, user = User.authenticate(@user.username, 'totally wrong password')
    success.should be_false
    user.first.id.should == @user.id
  end

  it 'should generate reset password token' do
    token = User.generate_key
    token.size.should == 40
    token.should match /[\da-f]/
  end

  it 'should say a new username is unique' do
    User.unique_user?('this name does not exist').should be_true
  end

  it 'should say an existing username is not unique' do
    User.unique_user?(@user.username).should be_false
  end

  it 'should check for unique usernames on master' do
    User.should_receive(:with_master).and_return(true)
    User.unique_user?('whatever').should be_true
  end

  it 'should say a new email is unique' do
    User.unique_email?('this email does not exist').should be_true
  end

  it 'should say an existing email is not unique' do
    User.unique_email?(@user.email).should be_false
  end

  it 'should check for unique email on master' do
    User.should_receive(:with_master).and_return(true)
    User.unique_email?('whatever').should be_true
  end

  it 'should alias password to entered_password' do
    pass = 'something new'
    @user.entered_password = pass
    @user.password.should == pass
  end

  it 'should have defaults when creating a new user' do
    user = User.create_new
    user.expertise.should             == $DEFAULT_EXPERTISE.to_s
    user.mailing_list.should          == false
    user.content_level.should         == $DEFAULT_CONTENT_LEVEL.to_i
    user.vetted.should                == $DEFAULT_VETTED
    user.default_taxonomic_browser    == $DEFAULT_TAXONOMIC_BROWSER
    user.flash_enabled                == true
    user.active                       == true
  end

  it 'should fail validation if the email is in the wrong format' do
    user = User.create_new(:email => 'wrong(at)format(dot)com')
    user.valid?.should_not be_true
  end

  it 'should fail validation if the secondary hierarchy is the same as the first' do
    user = User.create_new(:default_hierarchy_id => 1, :secondary_hierarchy_id => 1)
    user.valid?.should_not be_true
  end

  it 'should fail validation if a curator requests a new account without credentials' do
    user = User.create_new(:curator_request => true, :credentials => '')
    user.valid?.should_not be_true
  end

  it 'should fail validation if a curator requests a new account without either a scope or a clade' do
    user = User.create_new(:curator_request => true, :curator_scope => nil)
    user.valid?.should_not be_true
  end

  it 'should build a full name out of a given name if that is all they provided' do
    given = 'bubba'
    user = User.create_new(:given_name => given, :family_name => '')
    user.full_name.should == given
  end

  it 'should build a full name out of a given and family names' do
    given = 'santa'
    family = 'klaws'
    user = User.create_new(:given_name => given, :family_name => family)
    user.full_name.should == "#{given} #{family}"
  end

  it 'should save some variables temporarily (by responding to some methods)' do
    @user.respond_to?(:entered_password).should be_true
    @user.respond_to?(:entered_password=).should be_true
    @user.respond_to?(:entered_password_confirmation).should be_true
    @user.respond_to?(:entered_password_confirmation=).should be_true
    @user.respond_to?(:curator_request).should be_true
    @user.respond_to?(:curator_request=).should be_true
  end

  it 'should not allow you to add a user that already exists' do
    User.create_new( :username => @user.username ).save.should be_false
  end

  it '(curator user) should allow curator rights to be revoked' do
    Role.gen(:title => 'Curator') rescue nil
    @curator.approve_to_curate
    @curator.save!
    @curator.curator_level_id.nil?.should_not be_true
    @curator.revoke_curator
    @curator.reload
    @curator.curator_level_id.nil?.should be_true
  end

  it 'convenience methods should return all of the data objects for the user' do
    rebuild_convenience_method_data
    @user.all_submitted_datos.map {|d| d.id }.should == @dato_ids
  end

  it 'convenience methods should return all data objects descriptions' do
    rebuild_convenience_method_data
    @user.all_submitted_dato_descriptions.sort.should == @descriptions
  end

  # TODO - This test should be modified/rewritten while working on WEB-2542
  it 'convenience methods should be able to mark all data objects invisible and unvetted' # do
   #    rebuild_convenience_method_data
   #    Vetted.gen_if_not_exists(:label => 'Untrusted') unless Vetted.find_by_translated(:label, 'Untrusted')
   #    Visibility.gen_if_not_exists(:label => 'Invisible') unless Visibility.find_by_translated(:label, 'Invisible')
   #    @user.hide_all_submitted_datos
   #    @datos.each do |stored_dato|
   #      
   #      new_dato = DataObject.find(stored_dato.id) # we changed the values, so must re-load them.
   #      new_dato.vetted.should == Vetted.untrusted
   #      new_dato.visibility.should == Visibility.invisible
   #    end
   #  end

  it 'should set the active boolean' do
    inactive_user = User.gen(:active => false)
    inactive_user.active?.should_not be_true
    inactive_user.activate
    inactive_user.active?.should be_true
  end

  it 'should create a "watch" collection' do
    inactive_user = User.gen(:active => false)
    inactive_user.activate
    inactive_user.watch_collection.should_not be_nil
  end

  it 'community membership should be able to join a community' do
    community = Community.gen
    community.members.should be_blank
    @user.join_community(community)
    @user.members.map {|m| m.community_id}.should include(community.id)
  end

  it 'community membership should be able to answer member_of?' do
    community = Community.gen
    @user.member_of?(community).should_not be_true
    another_user = User.gen
    community.add_member(@user)
    @user.member_of?(community).should be_true
    another_user.member_of?(community).should_not be_true
  end

  it 'community membership should be able to leave a community' do
    community = Community.gen
    community.add_member(@user)
    @user.member_of?(community).should be_true
    @user.leave_community(community)
    @user.member_of?(community).should_not be_true
  end

  it 'should have an activity log' do
    user = User.gen
    user.respond_to?(:activity_log).should be_true
    user.activity_log.should be_a WillPaginate::Collection
  end

  it '#is_admin? should return true if current user is admin, otherwise false' do
    user = User.gen
    user.admin = 0                  # non-admin user
    user.is_admin?.should == false
    user.grant_admin                # admin user
    user.is_admin?.should == true
    user.admin = nil                # anonymous user
    user.is_admin?.should == false
  end

end
