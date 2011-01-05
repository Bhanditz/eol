require File.dirname(__FILE__) + '/../spec_helper' 
require File.dirname(__FILE__) + '/../../lib/eol_data'
class EOL::NestedSet; end
EOL::NestedSet.send :extend, EOL::Data

require 'solr_api'

def animal_kingdom
  @animal_kingdom ||= build_taxon_concept(:canonical_form => 'Animals',
                                          :parent_hierarchy_entry_id => 0,
                                          :depth => 0)
end

def recreate_indexes
  solr = SolrAPI.new
  solr.delete_all_documents
  solr.build_indexes
end

# Checks the table of results, makes sure it has the right string(s) and number of rows.
def assert_results(options)
  search_string = options[:search_string] || 'tiger'
  per_page = options[:per_page] || 10
  visit("/search?q=#{search_string}&per_page=#{per_page}#{options[:page] ? "&page=#{options[:page]}" : ''}")
  body.should have_tag('table[class=results_table]') do |table|
    header_index = 1
    result_index = header_index + options[:num_results_on_this_page]
    with_tag("tr:nth-child(#{result_index})")
    without_tag("tr:nth-child(#{result_index + 1})").should be_false
  end
end

def assert_tag_results(options)
  visit("/search?search_type=tag&q=value#{options[:page] ? "&page=#{options[:page]}" : ''}")
  body.should have_tag('div[class=serp_pagination]')
  body.should have_tag('table[class=results_table]') do |table|
    header_index = 1
    result_index = header_index + 1
    table.should have_tag("tr:nth-child(#{header_index})")
    options[:num_results_on_this_page].times do
      table.should have_tag("tr:nth-child(#{result_index})")
      result_index += 1
    end
    table.should_not have_tag("tr:nth-child(#{result_index})")
  end
end

describe 'Search' do

  before :all do
    truncate_all_tables
    load_foundation_cache
    Capybara.reset_sessions!
    visit('/logout')
    visit('/content_partner/logout')
  end

  after :all do
    truncate_all_tables
  end

  it 'should return a helpful message if no results' do
    TaxonConcept.should_receive(:search_with_pagination).at_least(2).times.and_return([])
    visit("/search?q=bozo")
    body.should have_tag('h3', :text => 'No search results were found')
  end

  describe '(text)' do

    before :all do
      # TODO - move these to a foundation for searching?
      @panda_name = 'panda'
      @panda = build_taxon_concept(:common_names => [@panda_name])
      @tiger_name = 'Tiger'
      @tiger = build_taxon_concept(:common_names => [@tiger_name],
                                   :vetted       => 'untrusted')
      @tiger_lilly_name = "#{@tiger_name} lilly"
      @tiger_lilly = build_taxon_concept(:common_names => 
                                          [@tiger_lilly_name, 'Panther tigris'],
                                         :vetted => 'unknown')
      @tiger_moth_name = "#{@tiger_name} moth"
      @tiger_moth = build_taxon_concept(:common_names => 
                                         [@tiger_moth_name, 'Panther moth'])
      @plantain_name   = 'Plantago major'
      @plantain_common = 'Plantain'
      @plantain_synonym= 'Synonymous toplantagius'
      @plantain = build_taxon_concept(:scientific_name => @plantain_name, :common_names => [@plantain_common])
      @plantain.add_scientific_name_synonym(@plantain_synonym)
      another = build_taxon_concept(:scientific_name => "#{@plantain_name} L.", :common_names => ["big #{@plantain_common}"])
      another.add_scientific_name_synonym(@plantain_synonym) # I'm only doing this so we get two results and not redirected.
      SearchSuggestion.gen(:taxon_id => @plantain.id, :scientific_name => @plantain_name,
                           :term => @plantain_name, :common_name => @plantain_common)
      @dog_name      = 'Dog'
      @domestic_name = "Domestic #{@dog_name}"
      @dog_sci_name  = 'Canis lupus familiaris'
      @wolf_name     = 'Wolf'
      @wolf_sci_name = 'Canis lupus'
      @dog  = build_taxon_concept(:scientific_name => @dog_sci_name, :common_names => [@domestic_name])
      @wolf = build_taxon_concept(:scientific_name => @wolf_sci_name, :common_names => [@wolf_name])
      SearchSuggestion.gen(:taxon_id => @dog.id, :term => @dog_name, :scientific_name => @dog.scientific_name,
                           :common_name => @dog.common_name)
      SearchSuggestion.gen(:taxon_id => @wolf.id, :term => @dog_name, :scientific_name => @wolf.scientific_name,
                           :common_name => @wolf.common_name)
      
      @tricky_search_suggestion = 'Bacteria'
      @bacteria_common = @tricky_search_suggestion
      @bacteria = build_taxon_concept(:scientific_name => @tricky_search_suggestion, :common_names => [@bacteria_common])
      SearchSuggestion.gen(:taxon_id => @bacteria.id, :scientific_name => @tricky_search_suggestion,
                          :term => @tricky_search_suggestion, :common_name => @bacteria_common)
      
      # I'm only doing this so we get two results and not redirected.
      another = build_taxon_concept(:scientific_name => @tricky_search_suggestion)
      
      recreate_indexes
      visit("/search?q=#{@tiger_name}")
      @tiger_search = body 
    end
    
    it 'should redirect to species page if only 1 possible match is found (also for pages/searchterm)' do
      visit("/search?q=#{@panda_name}")
      current_path.should == "/pages/#{@panda.id}"
      visit("/search/#{@panda_name}")
      current_path.should == "/pages/#{@panda.id}"    
    end
    
    it 'should redirect to search page if a string is passed to a species page' do
      visit("/pages/#{@panda_name}")
      current_path.should == "/pages/#{@panda.id}"
    end
    
    it 'should show a list of possible results (linking to /found) if more than 1 match is found  (also for pages/searchterm)' do
    
      body = @tiger_search
      body.should have_tag('td', :text => @tiger_name)
      body.should have_tag('td', :text => @tiger_lilly_name)
      body.should have_tag('a[href*=?]', %r{/found/#{@tiger_lilly.id}})
      body.should have_tag('a[href*=?]', %r{/found/#{@tiger.id}})
    
    end
    
    it 'should paginate' do
      results_per_page = 2
      extra_results    = 1
      assert_results(:num_results_on_this_page => results_per_page, :per_page => results_per_page)
      assert_results(:num_results_on_this_page => extra_results, :page => 2, :per_page => results_per_page)
    end
    
    it 'return no suggested results for tiger' do
      body = @tiger_search
      body.should_not have_tag('table[summary=Suggested Search Results]')
    end
    
    it 'should return one suggested search' do
      visit("/search?q=#{URI.escape @plantain_name.gsub(/ /, '+')}&search_type=text")
      body.should have_tag('table[summary=Suggested Search Results]') do |table|
        table.should have_tag("td", :text => @plantain_common)
      end
    end
    
    # When we first created suggested results, it worked fine for one, but failed for two, so we feel we need to test
    # two entires AND one entry...
    it 'should return two suggested searches' do
      visit("/search?q=#{@dog_name}&search_type=text")
      body.should have_tag('table[summary=Suggested Search Results]') do |table|
        table.should have_tag("td", :text => @domestic_name)
        table.should have_tag("td", :text => @wolf_name)
      end
    end
    
    it 'should be able to return suggested results for "bacteria"' do
      visit("/search?q=#{@tricky_search_suggestion}&search_type=text")
      body.should have_tag('table[summary=Suggested Search Results]') do |table|
        table.should have_tag("td", :text => @tricky_search_suggestion)
      end
    end
    
    it 'should treat empty string search gracefully when javascript is switched off' do
      visit('/search?q=')
      body.should_not include "500 Internal Server Error"
    end
    
    it 'should detect untrusted and unknown Taxon Concepts' do
      body = @tiger_search
      body.should match /td class=("|')(search_result_cell )?(odd|even)_untrusted/
      body.should match /td class=("|')(search_result_cell )?(odd|even)_unvetted/
    end
    
    it 'should show only common names which include whole search query' do
      visit("/search?q=#{URI.escape @tiger_lilly_name}")
      # should find only common names which have 'tiger lilly' in the name
      # we have only one such record in the test, so it redirects directly 
      # to the species page
      current_path.should == "/pages/#{@tiger_lilly.id}"
    end
    
    it 'should return preferred common name as "shown" name' do
      visit("/search?q=panther")
      body.should include "shown as 'Tiger lilly'"
    end
    
    it 'should have odd and even rows in search result table' do
      body = @tiger_search
      body.should include "td class='search_result_cell odd"
      body.should include "td class='search_result_cell even"
    end 
    
    it 'should show "shown as" for scientific matches that hit a synonym.' do
      visit("/search?q=#{@plantain_synonym.split[0]}")
      body.should include @plantain_synonym
      body.should include "shown as '#{@plantain_name}'"
    end

  end

  describe '(tags)' do
  
    it 'should find tags' do
      taxon_concept = build_taxon_concept(:images => [{}])
      image_dato   = taxon_concept.images.last
      user = User.gen :username => 'username', :password => 'password'
      image_dato.tag("key-old", "value-old", user)
      # during reharvesting this object will be recreated with the same guid and different id
      # it should still find all tags because it uses guid, not id for finding relevant information
      new_image_dato = DataObject.build_reharvested_dato(image_dato)
      new_image_dato.tag("key-new", "value-new", user)
      DataObjectsTaxonConcept.gen(:taxon_concept => taxon_concept, :data_object => new_image_dato)
      
      visit('/search?q=value-old&search_type=tag')
      body.should include(taxon_concept.scientific_name)
    end
  
    # REMOVE AFTER PAGINATION IMPLEMENTING TODO
    it 'should show > 10 tags' do
      user   = User.gen :username => 'username', :password => 'password'
      all_tc = []
      number_of_taxa  = 12
      
      number_of_taxa.times do
        taxon_concept = build_taxon_concept(:images => [{}])
        image_dato    = taxon_concept.images.last
        image_dato.tag("key", "value", user)
        all_tc << taxon_concept.scientific_name
      end
          
      visit('/search?search_type=tag&q=value')
      for tc_name in all_tc
        body.should include(tc_name.gsub("&","&amp;"))
      end
    end
  
    it 'should show unvetted status for tag search' do
      user   = User.gen :username => 'username', :password => 'password'
      all_tc = []
      vetted_methods  = ['untrusted', 'unknown', 'trusted']
      
      vetted_methods.each do |v_method|
        taxon_concept = build_taxon_concept(:images => [{}], :vetted => v_method)
        image_dato    = taxon_concept.images.last
        image_dato.tag("key", "value", user)
        all_tc << taxon_concept.scientific_name
      end
          
      visit('/search?search_type=tag&q=value')
      body.should match /(odd|even)[^_]/
      body.should match /(odd|even)_untrusted/
      body.should match /(odd|even)_unvetted/    
    end
      
    # WHEN WE HAVE PAGINATION FOR TAGS (TODO):
    #
    #   it 'should show pagination if there are > 10 tags' do
    #     user   = User.gen :username => 'username', :password => 'password'
    #     all_tc = []
    #     results_per_page = 10
    #     extra_results    = 3
    #     number_of_taxa   = results_per_page + extra_results
    #     
    #     number_of_taxa.times do
    #       taxon_concept = build_taxon_concept(:images => [{}])
    #       image_dato    = taxon_concept.images.last
    #       image_dato.tag("key", "value", user)
    #     end
    #         
    #     assert_tag_results(:num_results_on_this_page => results_per_page)
    #     assert_tag_results(:num_results_on_this_page => extra_results, :page => 2)    
    #   end
  
  end
    
end
