require File.dirname(__FILE__) + '/../spec_helper'

describe 'Admin Pages' do
  
  before(:all) do
    truncate_all_tables
    EolScenario.load('foundation')
    # load_foundation_cache
    Capybara.reset_sessions!
    @user = User.gen(:username => 'ourtestadmin')
    @user.roles = Role.find(:all, :conditions => 'title LIKE "Admin%"')
    @user.save!
  end

  after :each do
    visit('/logout')
  end
  
  it 'should load the admin homepage' do
    login_as(@user)
    current_path.should == '/'
    visit('/admin')
    body.should include('Welcome to the EOL Administration Console')
    body.should include('Site CMS')
    body.should include('News Items')
    body.should include('Comments and Tags')
    body.should include('Web Users')
    body.should include('Contact Us Functions')
    body.should include('Technical Functions')
    body.should include('Content Partners')
    body.should include('Statistics')
    body.should include('Data Usage Reports')
  end
  
  describe ': hierarchies' do
    before :all do
      @agent = Agent.gen(:full_name => 'HierarchyAgent')
      @hierarchy = Hierarchy.gen(:label => 'TreeofLife', :description => 'contains all life', :agent => @agent)
      @hierarchy_entry = HierarchyEntry.gen(:hierarchy => @hierarchy)
    end
    
    it 'should show the list of hierarchies' do
      login_as(@user)
      current_path.should == '/'
      visit('/administrator/hierarchy')
      body.should include(@agent.full_name)
      body.should include(@hierarchy.label)
      body.should include(@hierarchy.description)
    end
    
    it 'should be able to edit a hierarchy' do
      login_as(@user)
      current_path.should == '/'
      visit("/administrator/hierarchy/edit/#{@hierarchy.id}")
      body.should include('<input id="hierarchy_label"')
      body.should include(@hierarchy.label)
      body.should include(@hierarchy.description)
    end
    
    it 'should be able to view a hierarchy' do
      login_as(@user)
      current_path.should == '/'
      visit("/administrator/hierarchy/browse/#{@hierarchy.id}")
      body.should include(@hierarchy.label)
    end
  end
  
  describe ': glossary' do    
    it 'should load an empty glossary page' do
      login_as(@user)
      current_path.should == '/'
      visit('/administrator/glossary')
      body.should include("glossary is empty")
    end
    
    it 'should show glossary terms' do
      glossary_term = GlossaryTerm.gen(:term => 'Some new term', :definition => 'and its definition')
      login_as(@user)
      current_path.should == '/'
      visit("/administrator/glossary")
      body.should include(glossary_term.term)
      body.should include(glossary_term.definition)
    end
  end
  
  describe ': monthly published partners' do
    before(:all) do
      last_month = Time.now - 1.month      
      @report_year = last_month.year.to_s
      @report_month = last_month.month.to_s
      @year_month   = @report_year + "_" + "%02d" % @report_month.to_i      
      @agent = Agent.gen(:full_name => 'FishBase')
      @resource = Resource.gen(:title => "FishBase Resource")
      @agent_resource = AgentsResource.gen(:agent_id => @agent.id, :resource_id => @resource.id)
      @harvest_event = HarvestEvent.gen(:resource_id => @resource.id, :published_at => last_month)      
    end  
    it "should show report_monthly_published_partners page" do      
      login_as(@user)
      current_path.should == '/'      
      visit("/administrator/content_partner_report/report_monthly_published_partners")
      body.should include "New content partners for the month"
    end

    it "should get data from a form and display published partners" do          
      login_as(@user)
      current_path.should == '/'      
      visit("/administrator/content_partner_report/report_monthly_published_partners", :method => :post, :params => {:year_month => @year_month})
      #visit("/administrator/content_partner_report/report_monthly_published_partners")
      #select "", :year_month => @year_month

      body.should have_tag("form[action=/administrator/content_partner_report/report_monthly_published_partners]")
      body.should include "New content partners for the month"
      body.should include @agent.full_name
    end
  end
  
  describe ': content partner curated data' do
    before(:all) do
      last_month = Time.now - 1.month      
      @report_year = last_month.year.to_s
      @report_month = last_month.month.to_s
      @year_month   = @report_year + "_" + "%02d" % @report_month.to_i      
      
      @agent = Agent.gen(:full_name => 'FishBase')
      @resource = Resource.gen(:title => "test resource")
      @agent_resource = AgentsResource.gen(:agent_id => @agent.id, :resource_id => @resource.id)
      last_month = Time.now - 1.month      
      @harvest_event = HarvestEvent.gen(:resource_id => @resource.id, :published_at => last_month)
      @data_object = DataObject.gen(:published => 1, :vetted_id => Vetted.trusted.id)
      @data_objects_harvest_event = DataObjectsHarvestEvent.gen(:data_object_id => @data_object.id, :harvest_event_id => @harvest_event.id)
      
      @taxon_concept = TaxonConcept.gen(:published => 1, :supercedure_id => 0)
      @data_objects_taxon_concept = DataObjectsTaxonConcept.gen(:data_object_id => @data_object.id, :taxon_concept_id => @taxon_concept.id)

      @action_with_object = ActionWithObject.gen()
      @changeable_object_type = ChangeableObjectType.gen()#id = 1 = data_object
      @action_history = ActionsHistory.gen(:object_id => @data_object.id, :action_with_object_id => @action_with_object.id, :changeable_object_type_id => @changeable_object_type.id)
     
    end  

    it "should show report_partner_curated_data page" do      
      login_as(@user)
      current_path.should == '/'      
      visit("/administrator/content_partner_report/report_partner_curated_data")
      body.should include "Curation activity:"
    end

    it "should get data from a form and display curation activity" do
      login_as(@user)
      current_path.should == '/'      
      visit("/administrator/content_partner_report/report_partner_curated_data", :method => :post, :params => {:agent_id => @agent.id})
      #visit("/administrator/content_partner_report/report_partner_curated_data")
      #select "", :agent_id => @agent.id

      body.should have_tag("form[action=/administrator/content_partner_report/report_partner_curated_data]")
      body.should include "Curation activity:"
      body.should include @agent.full_name      
    end

    it "should get data from a form and display a month's curation activity" do          
      login_as(@user)
      current_path.should == '/'      
      visit("/administrator/content_partner_report/report_partner_curated_data", :method => :post, :params => {:agent_id => @agent.id, :year_month => @year_month})
      #visit("/administrator/content_partner_report/report_partner_curated_data")      
      #select "", :agent_id => @agent.id, :year_month => @year_month

      body.should have_tag("form[action=/administrator/content_partner_report/report_partner_curated_data]")
      body.should include "Curation activity:"
      body.should include @agent.full_name      
    end
  end      
  
  describe ': content partner objects stats' do
    before(:each) do
      last_month = Time.now - 1.month      
      @agent = Agent.gen(:full_name => 'FishBase')
      @resource = Resource.gen(:title => "FishBase Resource")
      @agent_resource = AgentsResource.gen(:agent_id => @agent.id, :resource_id => @resource.id)
      @harvest_event = HarvestEvent.gen(:resource_id => @resource.id, :published_at => last_month)
    end

    it "should show report_partner_objects_stats page" do      
      login_as(@user)
      current_path.should == '/'      
      visit("/administrator/content_partner_report/report_partner_objects_stats")
      body.should include "Viewing Partner:"
    end

    it "should get data from a form and display harvest events" do          
      login_as(@user)
      current_path.should == '/'      
      visit("/administrator/content_partner_report/report_partner_objects_stats")
      select @agent.full_name, :from => "agent_id"
      click_button "Change"
      body.should have_tag("form[action=/administrator/content_partner_report/report_partner_objects_stats]")
      body.should include "Viewing Partner:"
      body.should include @agent.full_name
      body.should include @resource.title
    end

    it "should link to data objects stats per harvest event" do          
      login_as(@user)
      current_path.should == '/'      
      visit("/administrator/content_partner_report/show_data_object_stats?harvest_id=#{@harvest_event.id}&partner_fullname=#{URI.escape(@agent.full_name)}")
      body.should include "Total Data Objects:"
      body.should include @agent.full_name
      body.should include "#{@harvest_event.id}\n"
    end
  end  

  describe ': table of contents breakdown' do
    it "should show table of contents breakdown page" do      
      login_as(@user)
      visit("/administrator/stats/toc_breakdown")
      body.should include "Table of Contents Breakdown"
    end
  end  

  describe ': user activity view' do
    before(:each) do
      @activity = Activity.gen(:name => "sample activity")
      @user_with_activity = User.gen(:given_name => "John", :family_name => "Doe")
      @activity_log = ActivityLog.gen(:user_id => @user_with_activity.id, :activity_id => @activity.id)
    end
    it "should get data from a form and display user activity" do          
      login_as(@user)
      current_path.should == '/'            
      visit("/administrator/user/view_user_activity", :method => :post, :params => {:user_id => @user_with_activity.id})
      body.should have_tag("form[action=/administrator/user/view_user_activity]")
      body.should include "User Activity"
      body.should include @user_with_activity.family_name
      body.should include @activity.name
    end
  end  
  
end

