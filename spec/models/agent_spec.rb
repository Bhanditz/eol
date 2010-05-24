require File.dirname(__FILE__) + '/../spec_helper'

def agent_attributes
  @agent_attributes ||= { :username => 'quentin', :password => 'test', :password_confirmation => 'test' }
end

describe Agent do

  before(:all) do
    Agent.delete_all
    @agent = Agent.gen agent_attributes
  end

  describe "authentication" do

    after(:each) do
      @agent.update_attributes(agent_attributes)
    end

    it 'authenticates' do
      Agent.authenticate('quentin', 'test').should == @agent
    end

    it 'works with reset password' do
      new_pass = @agent.reset_password!
      Agent.authenticate('quentin', new_pass).should == @agent.reload
    end

  end

  describe 'remember tokens' do

    it 'should set' do
      @agent.remember_me
      @agent.remember_token.should_not be_nil
      @agent.remember_token_expires_at.should_not be_nil
    end

    it 'unsets remember token' do
      @agent.remember_me
      @agent.remember_token.should_not be_nil
      @agent.forget_me
      @agent.remember_token.should be_nil
    end

    it 'remembers me for one week' do
      before = 1.week.from_now.utc
      @agent.remember_me_for 1.week
      after = 1.week.from_now.utc
      @agent.remember_token.should_not be_nil
      @agent.remember_token_expires_at.should_not be_nil
      @agent.remember_token_expires_at.between?(before, after).should be_true
    end

    it 'remembers me until one week' do
      time = 1.week.from_now.utc
      @agent.remember_me_until time
      @agent.remember_token.should_not be_nil
      @agent.remember_token_expires_at.should_not be_nil
      @agent.remember_token_expires_at.should == time
    end

    it 'remembers me default two weeks' do
      before = 2.weeks.from_now.utc
      @agent.remember_me
      after = 2.weeks.from_now.utc
      @agent.remember_token.should_not be_nil
      @agent.remember_token_expires_at.should_not be_nil
      @agent.remember_token_expires_at.between?(before, after).should be_true
    end
    
  end

  describe "overall agreement validation" do
    
    it 'should NOT be ready for agreement without contacts' do
      agent=Agent.new(:project_name => 'Project')
      agent.content_partner = ContentPartner.gen :partner_complete_step => Time.now, :ipr_accept => 1,
                                :attribution_accept => 1, :roles_accept => 1
      agent.terms_agreed_to?.should be_true
      agent.ready_for_agreement?.should_not be_true
    end

    it "should be ready for agreement when they enter enough info" do 
      agent=Agent.new(:project_name => 'Project')
      agent.agent_contacts << AgentContact.gen
      agent.content_partner = ContentPartner.gen :partner_complete_step => Time.now, :ipr_accept => 1,
                                :attribution_accept => 1, :roles_accept => 1
      agent.terms_agreed_to?.should be_true
      # TODO - these need separate testing... (except agent_contacts.any?, which is a rubyism)
        agent.agent_contacts.any?.should be_true
        agent.content_partner.partner_complete_step?.should be_true
        agent.terms_agreed_to?.should be_true
      agent.ready_for_agreement?.should be_true
    end

    it "should not be ready for agreement before all info is entered and agreements are made" do
      agent=Agent.new(:project_name => 'Project')
      agent.agent_contacts << AgentContact.gen
      agent.content_partner = ContentPartner.gen :partner_complete_step => 0, :ipr_accept => 0,
                                :attribution_accept => 1, :roles_accept => 1
      agent.terms_agreed_to?.should_not be_true
      agent.ready_for_agreement?.should_not be_true
    end
        
  end  

  describe 'from license' do

    before(:all) do
      @license          = License.gen
      @rights_statement = "This is the rights statement with too much white space    "
    end

    it 'should create a fake agent from a license and rights_statement' do
      fake_agent                       = Agent.from_license @license, @rights_statement
      fake_agent.project_name.should   match(/#{@rights_statement.strip}/)
      fake_agent.project_name.should   match(/#{@license.description.gsub(/\?/, '\\?')}/)
      fake_agent.homepage.should       == @license.source_url
      fake_agent.logo_file_name.should == @license.logo_url
    end

    it 'should create fake agent with default rights_statement of license description' do
      fake_agent                       = Agent.from_license @license
      fake_agent.project_name.should   match(/#{@license.description.gsub(/\?/, '\\?')}/)
    end

  end

  describe '#just_project_name' do

    it 'should create a fake agent from a string' do
      string = 'You are here'
      fake_agent = Agent.just_project_name string
      fake_agent.project_name.should == string
    end

  end

  describe 'from Source URL' do

    it 'should create a fake agent from a location' do
      url = 'You are here'
      fake_agent = Agent.from_source_url url
      fake_agent.project_name.should == 'View original data object'
      fake_agent.homepage.should == url
    end

  end

   describe '#agents_data' do

     before(:all) do
       Scenario.load :foundation
     end

     # # Find the data_objects "belongs" to an Agent.
     #  def agents_data
     #      HarvestEvent.find_by_sql(["
     #          SELECT DISTINCT he.id FROM agents a 
     #                JOIN agents_resources ar ON (ar.agent_id=a.id)
     #                JOIN harvest_events he ON (ar.resource_id=he.resource_id) 
     #          WHERE  ar.agent_id=?
     #              ORDER BY he.id DESC LIMIT 1", self.id])[0].data_objects
     #  end

    it 'should get all data_objects that came from an agents last harvest' do
      @agent       = Agent.gen
      @resource    = Resource.gen
      AgentsResource.gen(:agent => @agent, :resource => @resource)
      @first_event = HarvestEvent.gen(:resource => @resource)
      @first_datos = []
      5.times do
        @first_datos << DataObject.gen
        DataObjectsHarvestEvent.gen(:harvest_event => @first_event,
                                    :data_object   => @first_datos.last)
      end
      @last_event = HarvestEvent.gen(:resource => @resource)
      @last_datos = []
      5.times do
        @last_datos << DataObject.gen
        DataObjectsHarvestEvent.gen(:harvest_event => @last_event,
                                    :data_object   => @last_datos.last)
      end
      @agent.agents_data.map {|ob| ob.id}.sort.should == 
        @last_datos.map {|ob| ob.id}.sort
    end
      
  end

  describe 'latest harvest event contains...' do

    before(:all) do
      @contains_tc = TaxonConcept.gen # no need to do the build_taxon_concept thing
      @contains_he = HierarchyEntry.gen(:taxon_concept => @contains_tc)
      @doesnt_contain_tc = TaxonConcept.gen # no need to do the build_taxon_concept thing
      @doesnt_contain_he = HierarchyEntry.gen(:taxon_concept => @doesnt_contain_tc)
      @agent = Agent.gen
      resource = Resource.gen
      AgentsResource.gen(:agent => @agent, :resource => resource)
      event = HarvestEvent.gen(:resource => resource, :published_at => nil)
      HarvestEventsHierarchyEntry.gen(:harvest_event => event, :hierarchy_entry => @contains_he)
    end

    it 'should know if a taxon_concept was in its latest harvest event' do
      @agent.latest_unpublished_harvest_contains?(@contains_tc).should be_true    # Takes both a TaxonConcept...
      @agent.latest_unpublished_harvest_contains?(@contains_tc.id).should be_true # ...and just an ID
    end

    it 'should know if a taxon_concept was NOT in its latest harvest event' do
      @agent.latest_unpublished_harvest_contains?(@doesnt_contain_tc).should_not be_true    # Takes both a TaxonConcept...
      @agent.latest_unpublished_harvest_contains?(@doesnt_contain_tc.id).should_not be_true # ...and just an ID
    end

  end
     
end
