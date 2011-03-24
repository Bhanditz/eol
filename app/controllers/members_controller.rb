class MembersController < ApplicationController
  layout 'main'
  before_filter :load_community_and_current_member
  before_filter :load_member, :except => [:index]
  before_filter :restrict_edit, :only => [:edit, :update]
  before_filter :restrict_delete, :only => [:delete]

  def index
    @members = Member.paginate(:page => params[:page]) 

    respond_to do |format|
      format.html # index.html.erb
      format.xml  { render :xml => @members }
    end
  end

  # This for non-members and members WITHOUT access to change privileges:
  def show
    # This is for community managers who have access to change privileges:
    @privileges = Privilege.all_for_community(@member.community)
    respond_to do |format|
      format.html # show.html.erb
      format.xml  { render :xml => @member }
    end
  end

  # You must be a community manager with privilege granting/revoking access to get here.
  def update
    respond_to do |format|
      if @member.update_attributes(params[:member])
        format.html { redirect_to(@member, :notice =>  I18n.t(:updated_member) ) }
        format.xml  { head :ok }
      else
        format.html { render :action => "edit" }
        format.xml  { render :xml => @member.errors, :status => :unprocessable_entity }
      end
    end
  end

  def destroy
    @community.remove_member(@member)
    respond_to do |format|
      format.html { redirect_to(@community, :notice =>  I18n.t(:you_removed_the_member_from_the_community) ) }
    end
  end

  def grant_privilege_to
    @member.grant_privilege Privilege.find(params[:member][:new_privilege_id])
    redirect_to([@community, @member], :notice =>  I18n.t(:updated_member) )
  end

  def revoke_privilege_from
    @member.revoke_privilege Privilege.find(params[:member][:removed_privilege_id])
    redirect_to([@community, @member], :notice =>  I18n.t(:updated_member) )
  end

  def add_role_to
    @member.add_role Role.find(params[:member][:new_role_id])
    redirect_to([@community, @member], :notice =>  I18n.t(:updated_member) )
  end

  def remove_role_from
    @member.remove_role Role.find(params[:member][:removed_role_id])
    redirect_to([@community, @member], :notice =>  I18n.t(:updated_member) )
  end

private

  def load_community_and_current_member
    @community = Community.find(params[:community_id])
    @current_member = current_user.member_of(@community)
  end

  def load_member
    @member = Member.find(params[:id] || params[:member_id])
    unless @member && @member.community_id == @community.id
      flash[:error] =  I18n.t(:cannot_find_member) 
      return redirect_to(@community)
    end
  end

  def restrict_edit
    @current_member ||= current_user.member_of(@community)
    raise EOL::Exceptions::SecurityViolation unless @current_member && @current_member.can_edit_members?
  end

  def restrict_delete
    @current_member ||= current_user.member_of(@community)
    raise EOL::Exceptions::SecurityViolation unless @current_member && @current_member.can?(Privilege.remove_members)
  end

end

