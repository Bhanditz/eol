class Administrator::ContentPartnerReportController < AdminController
  helper :resources
  helper_method :current_agent, :agent_logged_in?
  layout 'admin'
  
  access_control :DEFAULT => 'Administrator - Content Partners'
  
  def index
    @page_title = 'Content Partners'
    @partner_search_string=params[:partner_search_string] || ''
    @only_show_agents_with_unpublished_content=EOLConvert.to_boolean(params[:only_show_agents_with_unpublished_content])
    @agent_status=AgentStatus.find(:all,:order=>'label')
    @agent_status_id=params[:agent_status_id] || AgentStatus.active.id
    where_clause = (@agent_status_id.blank? ? '' : "agent_status_id=#{@agent_status_id} AND ")
    search_string_parameter='%' + @partner_search_string + '%' 
    page=params[:page] || '1'
    order_by=params[:order_by] || 'full_name ASC'
    @agents = Agent.paginate_by_sql(["select a.id,a.full_name,a.agent_status_id,partner_complete_step,show_on_partner_page,cp.vetted,cp.created_at from agents a inner join content_partners cp on cp.agent_id=a.id WHERE #{where_clause} full_name like ? ORDER BY #{order_by}",search_string_parameter],:page=>page)
  end

  def export
    @agents = Agent.find_by_sql('select a.* from agents a inner join content_partners cp on cp.agent_id=a.id order by a.full_name ASC')

    report = StringIO.new
    CSV::Writer.generate(report, ',') do |row|
        row << ['Partner Name', 'Registered Date', 'Resources','Status','Agent_ID']
        row << ['','Role', 'Contact', 'Email', 'Telephone','Address','Homepage']
        @agents.each do |agent|
          if agent.created_at.blank?
            created_at=''
          else
            created_at=agent.created_at.strftime("%m/%d/%y - %I:%M %p %Z") 
          end if
          if agent.agent_status.blank?
            agent_status = 'unknown'
          else
            agent_status = agent.agent_status.label
          end
          row << [agent.project_name,agent.created_at,agent.resources.count,agent_status,agent.id]       
          agent.agent_contacts.each do |contact|
            row << ['',contact.agent_contact_role.label,contact.title + ' ' + contact.full_name,contact.email,contact.telephone,contact.address,contact.homepage]
          end
          row << ''
        end
     end
     report.rewind
     send_data(report.read,:type=>'text/csv; charset=iso-8859-1; header=present',:filename => 'EOL_content_partners_export_' + Time.now.strftime("%m_%d_%Y-%I%M%p") + '.csv', :disposition =>'attachment', :encoding => 'utf8')
     return false
    
  end
  
  def show
    @page_title = 'Content Partner Detail'
    @agent = Agent.find_by_id(params[:id])
    if @agent.blank?
      redirect_to :action=>'index' 
      return
    end
    @agent_status=AgentStatus.find(:all,:order=>'label')    
    @agent.content_partner=ContentPartner.new if @agent.content_partner.nil?
    @current_agreement=ContentPartnerAgreement.find_by_agent_id_and_is_current(@agent.id,true,:order=>'created_at DESC')
    if @current_agreement == nil || @current_agreement.signed_by.blank?
      @agreement_signed='Not accepted'
    else
      @agreement_signed='Accepted by ' + @current_agreement.signed_by + '<br /> on ' + @current_agreement.signed_on_date.to_s
    end
  end
  
  def show_contacts
    @agent=Agent.find(params[:id],:include=>:agent_contacts)
    @page_title = "Content Partner Contacts - #{@agent.project_name}"
    @contacts=@agent.agent_contacts
  end

  def edit_profile

    @agent=Agent.find(params[:id],:include=>:content_partner)   
    @page_title = "Edit Profile: #{@agent.display_name}"
    return unless request.post?

    if @agent.update_attributes(params[:agent])

      upload_logo(@agent) unless @agent.logo_file_name.blank?
      flash[:notice] = "Profile updated"[]
      redirect_to :action => 'show',:id=>@agent.id 

    end
      
  end
  
  def login_as_agent
      
    @agent=Agent.find_by_id(params[:id])   
    
    if !@agent.blank?
      reset_session
      self.current_agent=@agent
      redirect_to :controller=>'/content_partner',:action=>'index'
    end
    return
      
  end
  
  def edit_agreement
    
    @page_title = 'Edit Content Partner Agreement'
    @agent=Agent.find(params[:id])

    # if we are posting, create the new agreement
    if request.post?
      agreement=params[:agreement].merge(:agent_id=>@agent.id)
      @agreement=ContentPartnerAgreement.create_new(agreement)
      if @agreement.valid?
        flash[:notice]='Content partner agreement was updated.'
        redirect_to :action=>'show',:id=>params[:id]
        return
      end
    else
      # find their agreement
      @agreement=ContentPartnerAgreement.find_by_agent_id_and_is_current(@agent.id,true,:order=>'created_at DESC')

      # if this is the first time they are viewing the agreement, create it from the default template
      @agreement=ContentPartnerAgreement.create_new(:agent_id=>@agent.id) if @agreement.nil?

    end

    # find previous agreements
    @previous_agreements=ContentPartnerAgreement.find_all_by_agent_id_and_is_current(@agent.id,false,:order=>'created_at DESC')
    @primary_contact=@agent.primary_contact
        
  end  
  
  def show_on_partner_page
    @agent = Agent.find(params[:id])
    @agent.content_partner.toggle!(:show_on_partner_page)

    render :update do |page|
      if @agent.show_on_partner_page?
        page << "$('show_on_cp_page_img').src = '/images/checked.png'"
      else
        page << "$('show_on_cp_page_img').src = '/images/not-checked.png'"
      end
    end
  end

  def show_mou_on_partner_page
    @agent = Agent.find(params[:id])
    @agent.content_partner.toggle!(:show_mou_on_partner_page)

    render :update do |page|
      if @agent.show_mou_on_partner_page?
        page << "$('show_mou_on_cp_page_img').src = '/images/checked.png'"
      else
        page << "$('show_mou_on_cp_page_img').src = '/images/not-checked.png'"
      end
    end
  end
  
  def show_gallery_on_partner_page
    @agent = Agent.find(params[:id])
    @agent.content_partner.toggle!(:show_gallery_on_partner_page)
    
    render :update do |page|
      if @agent.show_gallery_on_partner_page?
        page << "$('show_gallery_on_cp_page_img').src = '/images/checked.png'"
      else
        page << "$('show_gallery_on_cp_page_img').src = '/images/not-checked.png'"
      end
    end
  end
  
  def show_stats_on_partner_page
    @agent = Agent.find(params[:id])
    @agent.content_partner.toggle!(:show_stats_on_partner_page)
    
    render :update do |page|
      if @agent.show_stats_on_partner_page?
        page << "$('show_stats_on_cp_page_img').src = '/images/checked.png'"
      else
        page << "$('show_stats_on_cp_page_img').src = '/images/not-checked.png'"
      end
    end
  end
  
  
  def vet_partner
    @agent = Agent.find(params[:id])
    @agent.content_partner.toggle!(:vetted)
    @agent.content_partner.set_vetted_status(@agent.content_partner.vetted)
    render :update do |page|
      if @agent.vetted?
        page << "$('vet_partner_img').src = '/images/checked.png'"
      else
        page << "$('vet_partner_img').src = '/images/not-checked.png'"
      end
    end
  end

  def set_agent_status
    @agent = Agent.find(params[:id])
    @agent.agent_status_id = params[:agent_status_id]
    @agent.save!
    render :nothing=>true
  end
  
  def auto_publish
    @agent = Agent.find(params[:id])
    @agent.content_partner.toggle!(:auto_publish)

    render :update do |page|
      if @agent.auto_publish?
        page << "$('auto_publish_img').src = '/images/checked.png'"
      else
        page << "$('auto_publish_img').src = '/images/not-checked.png'"
      end
    end
  end

  def monthly_stats_email    
    last_month = Time.now - 1.month
    @year = last_month.year.to_s
    @month = last_month.month.to_s
       
    Agent.content_partners_contact_info(@month,@year).each do |recipient|
      Notifier.deliver_monthly_stats(recipient,@month,@year)
    end
    
    #for testing the query result
    @rset = Agent.content_partners_contact_info(@month,@year)    
  end
  
  def get_year_month_list    
    arr=[]
    start="2008_01"
    str=""
    var_date = Time.now
    while( start != str)      
      str = var_date.year.to_s + "_" + "%02d" % var_date.month.to_s
      arr << str
      var_date = var_date - 1.month
    end    
    return arr
  end 
  
  def report_monthly_published_partners
    @page_title = 'Published Content Partners'
    @year_month_list = get_year_month_list()
    if(params[:year_month]) then
      params[:year], params[:month] = params[:year_month].split("_") if params[:year_month]    
      @report_year  = params[:year].to_i
      @report_month = params[:month].to_i
      @year_month   = params[:year] + "_" + "%02d" % params[:month].to_i
    else
      last_month = Time.now - 1.month
      @report_year = last_month.year.to_s
      @report_month = last_month.month.to_s
      @year_month   = @report_year + "_" + "%02d" % @report_month.to_i
    end        
    page = params[:page] || 1
    @published_agents = Agent.published_agent(@report_year, @report_month, page)    
  end


  def report_partner_curated_data
    @page_header = 'Content Partner Curated Data'
    
    if(params[:agent_id]) then
      @agent_id = params[:agent_id]
      session[:form_agent_id] = params[:agent_id]
    elsif(session[:form_agent_id]) then
      @agent_id = session[:form_agent_id]
    else
      @agent_id = 1  
    end    
    
    @content_partners_with_published_data = Agent.content_partners_with_published_data  

    if(@agent_id == "All") then 
      @partner_fullname = "All Curation"
      arr_dataobject_ids = []
    else                        
      partner = Agent.find(@agent_id, :select => [:full_name])
      @partner_fullname = partner.full_name
      @latest_harvest_id = Agent.latest_harvest_event_id(@agent_id)        
      arr_dataobject_ids = HarvestEvent.data_object_ids_from_harvest(@latest_harvest_id)
    end        

    arr = User.curated_data_object_ids(arr_dataobject_ids,@agent_id)
      @arr_dataobject_ids = arr[0]
      @arr_user_ids = arr[1]

    if(@arr_dataobject_ids.length == 0) then 
      @arr_dataobject_ids = [1] #no data objects
    end

    @arr_obj_tc_id = DataObject.tc_ids_from_do_ids(@arr_dataobject_ids);
    page = params[:page] || 1
    @partner_curated_objects = User.curated_data_objects(@arr_dataobject_ids, page)

    @cur_page = (page.to_i - 1) * 30
  end

  def report_partner_objects_stats
    @page_header = 'Content Partner Data Objects Stats'
    
    if(params[:agent_id]) then
      @agent_id = params[:agent_id]
      session[:form_agent_id] = params[:agent_id]
    elsif(session[:form_agent_id]) then
      @agent_id = session[:form_agent_id]
    else
      @agent_id = 1  
    end
    
    @content_partners_with_published_data = Agent.content_partners_with_published_data  
    
    if(@agent_id == "All") then @agent_id=1
    end
    partner = Agent.find(@agent_id, :select => [:full_name])
    @partner_fullname = partner.full_name

    page = params[:page] || 1
    @partner_harvest_events = Agent.resources_harvest_events(@agent_id, page)        

    @cur_page = (page.to_i - 1) * 30
  end

  def show_data_object_stats
    @harvest_id = params[:harvest_id]
    @partner_fullname = params[:partner_fullname]

    @page_header = 'Harvest Event Data Objects Stats'
    arr = DataObject.generate_dataobject_stats(@harvest_id)
      @stats = arr[0]
      @data_types = arr[1]
      @vetted_types = arr[2]
      @total_data_objects = arr[3]
      @total_taxa = arr[4]
  end  

end
