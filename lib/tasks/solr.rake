require 'escape'

namespace :solr do
  desc 'Start the Solr instance'
  task :start => :environment do
    puts "** Starting Background Solr instance for EOL..."
    if RUBY_PLATFORM =~ /w(in)?32$/
      abort('This command does not work on Windows. Please use rake solr:run to run Solr in the foreground.')
    end
    port = $SOLR_SERVER.gsub(/^.*:(\d+).*$/, '\\1')
    FileUtils.cd(File.join($SOLR_DIR)) do
      command = ["#{RAILS_ROOT}/bin/solr", 'start', '--', '-p', port.to_s]
      if $SOLR_DIR
        command << '-s' << $SOLR_DIR
      end
      system(Escape.shell_command(command))
    end
  end

  desc 'Run the Solr instance in the foreground'
  task :run => :environment do
    puts "** Starting Foreground Solr instance for EOL..."
    if RUBY_PLATFORM =~ /w(in)?32$/
      abort('This command does not work on Windows.')
    end
    # data_path = Sunspot::Rails.configuration.data_path
    # FileUtils.mkdir_p(data_path)
    port = $SOLR_SERVER
    port.gsub!(/^.*:(\d+).*$/, '\\1')
    command = ["#{RAILS_ROOT}/bin/solr", 'run', '--', '-p', port.to_s]
    if $SOLR_DIR
      command << '-s' << $SOLR_DIR
    end
    exec(Escape.shell_command(command))
  end

  desc 'Stop the Solr instance'
  task :stop => :environment do
    puts "** Stopping Background Solr instance for EOL..."
    FileUtils.cd($SOLR_DIR) do
      system(Escape.shell_command(["#{RAILS_ROOT}/bin/solr", 'stop']))
    end
  end

  desc 'Build the Solr indexes based on the existing TaxonConcepts'
  # TODO - when we have other indexes, we may want sub-tasks to do TCs, Tags, images, and whatever else...
  task :build => 'solr:start' do
    require 'solr_api'
    solr = SolrAPI.new
    puts "** Deleting all existing entries..."
    solr.delete_all_documents
    puts "** Creating indexes..."
    count = TaxonConcept.count
    puts "** You have #{count} Taxon Concepts.  In the interest of time, this task will only add the first 100." if 
      count > 100
    solr.build_indexes(TaxonConcept.all[0..99])
  end
  
  desc 'Build the elevate.xml file using Search Suggestions'
  task :build_concept_elevate => :environment do
    suggestions = SearchSuggestion.find(:all, :select => 'term, taxon_id', :order => 'term ASC, sort_order DESC')
    
    taxon_concept_elevate_path = File.join(RAILS_ROOT, 'solr', 'solr', 'data', 'taxon_concepts', 'elevate.xml')
    File.open(taxon_concept_elevate_path, 'w') do |f|
      f.write("<?xml version='1.0' encoding='UTF-8' ?>\n")
      f.write("<elevate>\n")
      unless suggestions.empty?
        last_suggestion = nil
        suggestions.each do |s|
          if last_suggestion.nil? || last_suggestion.term != s.term
            unless last_suggestion.nil?
              f.write("  </query>\n")
            end
            f.write("  <query text='#{s.term}'>\n")
          end
          f.write("    <doc id='#{s.taxon_id}'/>\n")
          last_suggestion = s
        end
        f.write("  </query>\n")
      end
      f.write("</elevate>\n")
    end
  end
  
end
