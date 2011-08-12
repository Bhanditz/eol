class TurnContentPartnersIntoUsers < ActiveRecord::Migration
  def self.update_content_partners_user(content_partner, content_partner_agent, user)
    
    # there are only 2 content partners with existing users. Those uses will keep the user authentication
    # and not the agent authentication. For the rest, the user is created with the agent's authentication
    # info - so there are no authentication fields set in this method:
    #     :first_name => cp_agent.full_name,
    #     :email => cp_agent.email,
    #     :username => new_user_username,
    #     :hashed_password => new_user_password,
    #     :created_at => cp_agent.created_at,
    #     :email_reports_frequency_hours => cp_agent.email_reports_frequency_hours,
    #     :last_report_email => cp_agent.last_report_email
    
    user.acronym = content_partner_agent.acronym
    user.display_name = content_partner_agent.display_name
    user.homepage = content_partner_agent.homepage
    user.logo_url = content_partner_agent.logo_url
    user.logo_cache_url = content_partner_agent.logo_cache_url
    user.logo_file_name = content_partner_agent.logo_file_name
    user.logo_content_type = content_partner_agent.logo_content_type
    user.logo_file_size = content_partner_agent.logo_file_size
    user.agent_id = content_partner_agent.id
    user.save

    content_partner.content_partner_status_id = content_partner_agent.agent_status_id
    content_partner.user_id = user.id
    content_partner.save
    
    execute "UPDATE content_partner_agreements SET content_partner_id = #{content_partner.id} WHERE agent_id = #{content_partner_agent.id}"
    execute "UPDATE resources r JOIN agents_resources ar ON (r.id=ar.resource_id) SET r.content_partner_id = #{content_partner.id} WHERE ar.agent_id = #{content_partner_agent.id}"
    execute "UPDATE content_partner_contacts SET content_partner_id = #{content_partner.id} WHERE agent_id = #{content_partner_agent.id}"
    execute "UPDATE google_analytics_partner_summaries SET user_id = #{user.id} WHERE agent_id = #{content_partner_agent.id}"
    execute "UPDATE google_analytics_partner_taxa SET user_id = #{user.id} WHERE agent_id = #{content_partner_agent.id}"
  end

  def self.up
    execute "ALTER TABLE content_partners ADD `user_id` int unsigned NOT NULL AFTER `agent_id`"
    # agent_status comes from agent and was only used for content partners
    execute "ALTER TABLE content_partners ADD `content_partner_status_id` tinyint(4) NOT NULL AFTER `agent_id`"
    
    # add to users the fields we need for content partners
    execute "ALTER TABLE users ADD `display_name` varchar(255) AFTER `family_name`"
    execute "ALTER TABLE users ADD `acronym` varchar(20) AFTER `display_name`"
    execute "ALTER TABLE users ADD `homepage` varchar(255) AFTER `acronym`"
    execute "ALTER TABLE users ADD `logo_url` varchar(255) character set ascii default NULL"
    execute "ALTER TABLE users ADD `logo_cache_url` bigint(20) unsigned default NULL"
    execute "ALTER TABLE users ADD `logo_file_name` varchar(255) default NULL"
    execute "ALTER TABLE users ADD `logo_content_type` varchar(255) default NULL"
    execute "ALTER TABLE users ADD `logo_file_size` int(10) unsigned default '0'"
    
    execute "ALTER TABLE content_partner_agreements ADD `content_partner_id` int unsigned NOT NULL AFTER `agent_id`"
    
    execute "ALTER TABLE resources ADD `content_partner_id` int unsigned NOT NULL AFTER `id`"
    execute "CREATE INDEX content_partner_id ON resources(content_partner_id)"
    
    rename_table :agent_statuses, :content_partner_statuses
    rename_table :translated_agent_statuses, :translated_content_partner_statuses
    rename_column :translated_content_partner_statuses, :agent_status_id, :content_partner_status_id
    
    rename_table :agent_contact_roles, :contact_roles
    rename_table :translated_agent_contact_roles, :translated_contact_roles
    rename_column :translated_contact_roles, :agent_contact_role_id, :contact_role_id
    
    rename_table :agent_contacts, :content_partner_contacts
    execute "ALTER TABLE content_partner_contacts ADD `content_partner_id` int unsigned NOT NULL AFTER `agent_id`"
    rename_column :content_partner_contacts, :agent_contact_role_id, :contact_role_id
    
    execute "ALTER TABLE google_analytics_partner_summaries ADD `user_id` int unsigned NOT NULL AFTER `agent_id`"
    execute "ALTER TABLE google_analytics_partner_summaries DROP PRIMARY KEY"
    execute "CREATE INDEX user_id ON google_analytics_partner_summaries(user_id)"

    execute "ALTER TABLE google_analytics_partner_taxa ADD `user_id` int unsigned NOT NULL AFTER `agent_id`"
    execute "CREATE INDEX user_id ON google_analytics_partner_taxa(user_id)"
    
    # for each ContentPartner
    ContentPartner.find(:all).each do |cp|
      cp_agent = Agent.find_by_id(cp.agent_id)
      if cp_agent.nil? || cp_agent.username.blank? || cp_agent.hashed_password.blank?
        # every ContentPartner needs an agent, otherwise it is useless
        ContentPartner.delete(cp.id)
        next
      end
    
      # partner doesn't already have a user
      if cp_agent.user.nil?
        new_user_username = cp_agent.username
        new_user_password = cp_agent.hashed_password
          
        existing_user = User.find_by_username(cp_agent.username)
        if existing_user
          # same password so add to existing user
          if existing_user.hashed_password == cp_agent.hashed_password
            self.update_content_partners_user(cp, cp_agent, existing_user)
            next
          else # a user exists with the same username but different password, so create a new user
            # TODO: decide how to treat this case
            new_user_username = "newuser_" + cp.id.to_s
            new_user_password = User.hash_password("newuser_password_" + cp.id.to_s)
          end
        end
        new_user = User.create(
          :given_name => cp_agent.full_name,
          :email => cp_agent.email,
          :username => new_user_username,
          :hashed_password => new_user_password,
          :created_at => cp_agent.created_at,
          :email_reports_frequency_hours => cp_agent.email_reports_frequency_hours,
          :last_report_email => cp_agent.last_report_email,
          :entered_password => "doesntmatter")
        self.update_content_partners_user(cp, cp_agent, new_user)
      else
        # partner already has a user
        self.update_content_partners_user(cp, cp_agent, cp_agent.user)
      end
    end
    
    # AgentsResources went away as we only used one role. So now there is a content_partner_id in Resource
    # ResourceAgentRoles - same, we only used one role
    # AgentDataTypes - Content Partners will no longer indicate the data types they might provide
    drop_table :agents_resources
    drop_table :resource_agent_roles
    drop_table :agent_data_types
    drop_table :translated_agent_data_types
    drop_table :agent_provided_data_types
    
    # we no longer need agent_id - it has become user_id
    remove_column :content_partners, :agent_id
    remove_column :content_partner_contacts, :agent_id
    remove_column :content_partner_agreements, :agent_id
    remove_column :google_analytics_partner_summaries, :agent_id
    remove_column :google_analytics_partner_taxa, :agent_id
    
    # get rid of the fields we added to agents just to accommodate content partners
    remove_column :agents, :acronym
    remove_column :agents, :display_name
    remove_column :agents, :email
    remove_column :agents, :username
    remove_column :agents, :hashed_password
    remove_column :agents, :remember_token
    remove_column :agents, :remember_token_expires_at
    remove_column :agents, :logo_file_name
    remove_column :agents, :logo_content_type
    remove_column :agents, :logo_file_size
    remove_column :agents, :agent_status_id
    remove_column :agents, :email_reports_frequency_hours
    remove_column :agents, :last_report_email
    
    # Finally get rid of orphaned rows which are no longer associated with content partners
    execute "DELETE FROM content_partner_agreements WHERE content_partner_id = 0"
    execute "DELETE FROM resources WHERE content_partner_id = 0"
    execute "DELETE FROM content_partner_contacts WHERE content_partner_id = 0"
    execute "DELETE FROM google_analytics_partner_summaries WHERE user_id = 0"
    execute "DELETE FROM google_analytics_partner_taxa WHERE user_id = 0"
    
    execute "ALTER TABLE google_analytics_partner_summaries ADD PRIMARY KEY (user_id, year, month)"
  end

  def self.down
    execute "ALTER TABLE agents ADD `acronym` varchar(20) NOT NULL AFTER `full_name`"
    execute "ALTER TABLE agents ADD `display_name` varchar(255) NOT NULL AFTER `acronym`"
    execute "ALTER TABLE agents ADD `email` varchar(75) NOT NULL AFTER `homepage`"
    execute "ALTER TABLE agents ADD `username` varchar(100) NOT NULL AFTER `email`"
    execute "ALTER TABLE agents ADD `hashed_password` varchar(100) NOT NULL AFTER `username`"
    execute "ALTER TABLE agents ADD `remember_token` varchar(255) default NULL AFTER `hashed_password`"
    execute "ALTER TABLE agents ADD `remember_token_expires_at` timestamp NULL default NULL AFTER `remember_token`"
    execute "ALTER TABLE agents ADD `logo_file_name` varchar(255) default NULL AFTER `logo_cache_url`"
    execute "ALTER TABLE agents ADD `logo_content_type` varchar(255) default NULL AFTER `logo_file_name`"
    execute "ALTER TABLE agents ADD `logo_file_size` int(10) unsigned default '0' AFTER `logo_content_type`"
    execute "ALTER TABLE agents ADD `agent_status_id` tinyint(4) NOT NULL AFTER `logo_file_size`"
    execute "ALTER TABLE agents ADD `email_reports_frequency_hours` int(11) default '24' AFTER `updated_at`"
    execute "ALTER TABLE agents ADD `last_report_email` datetime default NULL AFTER `email_reports_frequency_hours`"

    execute "ALTER TABLE content_partners ADD `agent_id` int(11) NOT NULL AFTER `id`"
    execute "ALTER TABLE content_partner_contacts ADD `agent_id` int(10) unsigned NOT NULL AFTER `content_partner_id`"
    execute "ALTER TABLE content_partner_agreements ADD `agent_id` int(11) NOT NULL AFTER `content_partner_id`"
    execute "ALTER TABLE google_analytics_partner_summaries ADD `agent_id` int(11) NOT NULL default '0' AFTER `user_id`"
    execute "ALTER TABLE google_analytics_partner_taxa ADD `agent_id` int(10) unsigned NOT NULL AFTER `user_id`"

    execute "CREATE TABLE `agents_resources` (
      `agent_id` int(10) unsigned NOT NULL,
      `resource_id` int(10) unsigned NOT NULL,
      `resource_agent_role_id` tinyint(3) unsigned NOT NULL,
      PRIMARY KEY  (`agent_id`,`resource_id`,`resource_agent_role_id`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8"

    execute "CREATE TABLE `resource_agent_roles` (
      `id` tinyint(3) unsigned NOT NULL auto_increment,
      `label` varchar(100) character set ascii NOT NULL,
      PRIMARY KEY  (`id`),
      KEY `label` (`label`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8"

    execute "CREATE TABLE `agent_data_types` (
      `id` tinyint(3) unsigned NOT NULL auto_increment,
      `label` varchar(100) character set ascii NOT NULL,
      PRIMARY KEY  (`id`),
      KEY `label` (`label`)
    ) ENGINE=InnoDB AUTO_INCREMENT=5 DEFAULT CHARSET=utf8"

    execute "CREATE TABLE `translated_agent_data_types` (
      `id` int(11) NOT NULL auto_increment,
      `agent_data_type_id` tinyint(3) unsigned NOT NULL,
      `language_id` smallint(5) unsigned NOT NULL,
      `label` varchar(255) NOT NULL,
      `phonetic_label` varchar(255) default NULL,
      PRIMARY KEY  (`id`),
      UNIQUE KEY `agent_data_type_id` (`agent_data_type_id`,`language_id`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8"

    execute "CREATE TABLE `agent_provided_data_types` (
      `agent_data_type_id` int(10) unsigned NOT NULL,
      `agent_id` int(10) unsigned NOT NULL,
      PRIMARY KEY  (`agent_data_type_id`,`agent_id`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8 COMMENT='simple join table.'"

    remove_column :google_analytics_partner_summaries, :user_id
    remove_column :google_analytics_partner_taxa, :user_id

    rename_table :content_partner_contacts, :agent_contacts
    rename_column :agent_contacts, :contact_role_id, :agent_contact_role_id
    remove_column :agent_contacts, :content_partner_id

    rename_table :contact_roles, :agent_contact_roles
    rename_table :translated_contact_roles, :translated_agent_contact_roles
    rename_column :translated_agent_contact_roles, :contact_role_id, :agent_contact_role_id

    rename_table :content_partner_statuses, :agent_statuses
    rename_table :translated_content_partner_statuses, :translated_agent_statuses
    rename_column :translated_agent_statuses, :content_partner_status_id, :agent_status_id

    remove_column :resources, :content_partner_id

    remove_column :content_partner_agreements, :content_partner_id

    remove_column :users, :display_name
    remove_column :users, :acronym
    remove_column :users, :homepage
    remove_column :users, :logo_url
    remove_column :users, :logo_cache_url
    remove_column :users, :logo_file_name
    remove_column :users, :logo_content_type
    remove_column :users, :logo_file_size

    remove_column :content_partners, :user_id
    remove_column :content_partners, :content_partner_status_id
  end
end
