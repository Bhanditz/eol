module EOL

  class CommonNameDisplay

    attr_accessor :name_id
    attr_accessor :name_string
    attr_accessor :iso_639_1
    attr_accessor :language_label
    attr_accessor :language_name
    attr_accessor :language_id
    attr_accessor :sources
    attr_accessor :synonym_ids
    attr_accessor :preferred
    attr_accessor :trusted
    attr_accessor :duplicate
    attr_accessor :duplicate_with_curator
    attr_accessor :vetted_id
 
    # NOTE - this uses TaxonConceptNames, not Synonyms.  For now, that's because TCN is a denormlized version of Synonyms.
    def self.find_by_taxon_concept_id(tc_id)
      names = Name.find_by_sql([%q{
        SELECT names.id name_id, names.string name_string,
               l.label language_label, l.name language_name, l.id language_id, l.iso_639_1,
               tcn.synonym_id synonym_id, tcn.preferred preferred,
               tcn.vetted_id vetted_id
        FROM taxon_concept_names tcn
          JOIN names ON (tcn.name_id = names.id)
          LEFT JOIN languages l ON (tcn.language_id = l.id)
        WHERE tcn.taxon_concept_id = ? AND vern = 1
      }, tc_id]).map {|n| EOL::CommonNameDisplay.new(n)}
      EOL::CommonNameDisplay.group_by_name(names)
    end

    def self.group_by_name(names)
      new_names = []
      previous = nil
      names.sort.each do |name|
        if previous
          if previous === name
            new_names.last.merge!(name)
          else
            new_names << name
          end
        else # this is the first one.
          new_names << name
        end
        previous = name
      end
      new_names
    end

    def initialize(name)
      @name_id        = name[:name_id].to_i
      @name_string    = name[:name_string]
      @iso_639_1      = name[:iso_639_1]
      @language_label = name[:language_label] || Language.unknown.label
      @language_name  = name[:language_name]
      @language_id    = name[:language_id].to_i
      @synonym_ids    = [name[:synonym_id].to_i]
      @preferred      = name[:preferred].class == String ? name[:preferred].to_i > 0 : name[:preferred]
      @vetted_id      = name[:vetted_id].to_i
      @sources        = get_sources
      @trusted        = trusted_by_agent?
      # TODO - the methods that set these are in taxa_helper.  Move the methods here.  (Or, better, to an Enumerable for CNDs.)
      @duplicate      = false
      @duplicate_with_curator = false
    end

    alias :id :name_id
    alias :string :name_string

    # In other words, "the only source is the agent/user in question":
    def added_by_user?(user)
      @sources.length == 1 && @sources[0].id == user.agent.id
    end

    def trusted_by_agent?
      not @sources.map {|a| a.user }.compact.blank?
    end

    def trusted?
      @vetted_id == Vetted.trusted.id
    end

    def untrusted?
      @vetted_id == Vetted.untrusted.id
    end

    def unreviewed?
      @vetted_id == Vetted.unknown.id
    end

    # This is only used in the scope of a single TaxonConcept... otherwise I would add that (at the cost of some obfuscation).
    def unique_id
      "name-#{@language_id}-#{@name_id}"
    end

    def agent_names
      names = @sources.map {|a| a.user ? a.user.full_name : nil }.compact.join(', ')
      names = "Unknown"
    end

    def merge!(other)
      @sources += other.sources
      @synonym_ids += other.synonym_ids
    end

    # Sort by language label first, then by name, then by source.
    def <=>(other)
      if self.language_label == other.language_label
        self.name_string <=> other.name_string 
      else
        self.language_label.to_s <=> other.language_label.to_s
      end
    end

    def ===(other)
      self.name_string == other.name_string && self.language_label == other.language_label && self.vetted_id == other.vetted_id
    end

private

    def get_sources
      @@sources_sql ||= %q{
        SELECT a1.*
        FROM synonyms syn1
          JOIN hierarchies h ON (syn1.hierarchy_id = h.id)
          JOIN agents a1 ON (h.agent_id = a1.id)
        WHERE syn1.id IN (?)
          AND syn1.hierarchy_id != ?
        UNION
        SELECT a2.*
        FROM synonyms syn2
          JOIN agents_synonyms agsyn ON (syn2.id = agsyn.synonym_id)
          JOIN agents a2 ON (agsyn.agent_id = a2.id)
        WHERE syn2.id IN (?)
      }
      sources = Agent.find_by_sql([@@sources_sql, @synonym_ids, Hierarchy.eol_contributors.id, @synonym_ids])
      # This is *kind of* a hack.  Long, long ago, we kinda mangled our data by converting a bunch of uBio names without
      # giving the TCNs source he ids (or synonyms).  I'm actually kinda-sorta okay with this; if someone else develops a
      # system to add TCNs in a similar manner, this allows them to specify a default common name source, which could just be
      # an "empty" agent with a display name like "Source unknown".  :)
      if sources.blank?
        sources << Agent.find($AGENT_ID_OF_DEFAULT_COMMON_NAME_SOURCE) rescue nil
      end
      sources
    end

  end

end
