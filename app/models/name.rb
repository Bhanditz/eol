# encoding: utf-8
# Name is used for storing different variations of names of species (TaxonConcept)
#
# These names are not "official."  If they have a CanonicalForm, the CanonicalForm is the "accepted" scientific name for the
# species.
#
# Even common names have an italicized form, which the PHP side auto-generates.  They can't always be trusted, but there are cases
# where a name is both common and scientific, so it must be populated.
#
class Name < ActiveRecord::Base

  belongs_to :canonical_form
  belongs_to :ranked_canonical_form, class_name: CanonicalForm.to_s, foreign_key: :ranked_canonical_form_id

  has_many :taxon_concept_names
  has_many :hierarchy_entries

  validates_presence_of   :string
  # this is being commented out because we are enforcing the uniqueness of clean_name not string
  # string is not indexed so that was creating a query that took a long time to run
  # we could do soemthing better with before_save callbacks - checking the clean_name and making sure its unique there
  # validates_uniqueness_of :string
  validates_presence_of   :italicized
  validates_presence_of   :canonical_form

  validate :clean_name_must_be_unique
  before_validation :set_default_values, on: :create
  before_validation :create_clean_name, on: :create
  before_validation :create_canonical_form, on: :create
  before_validation :create_italicized, on: :create

  RED_FLAG_WORDS = [
    'incertae', 'sedis', 'incertaesedis', 'culture', 'clone', 'isolate',
    'phage', 'sp', 'cf', 'uncultured', 'DNA', 'unclassified', 'sect',
    'ß', 'str', 'biovar', 'type', 'strain', 'serotype', 'hybrid',
    'cultivar', 'x', '×', 'pop', 'group', 'environmental', 'sample',
    'endosymbiont', 'species', 'complex',
    'unassigned', 'n', 'gen', 'auct', 'non', 'aff',
    'mixed', 'library', 'genomic', 'unidentified', 'parasite', 'synthetic',
    'phytoplasma', 'bacterium'
  ]
  RED_FLAG_REGEX = /\b(#{RED_FLAG_WORDS.join('|')})\b/i
  SURROGATE_REGEXES = [
    RED_FLAG_REGEX,
    / [abcd] /i,
    /(_|'|")/i,
    /[0-9][a-z]/i,
    /[a-z][0-9]/i,
    /[a-z]-[0-9]/i,
    / [0-9]{1,3}$/,
    /\b[0-9]{1,3}-[0-9]{1,3}\b/,
    /[0-9]{5,}/,
    /[03456789][0-9]{3}/, # years should start with 1 or 2
    /1[02345][0-9]{2}/, # 1600 - 1999
    /2[1-9][0-9]{2}/, # 2000 - 2100
    /virus\b/i,
    /viruses\b/i
  ]


  attr_accessor :is_common_name

  # Takes a name string and returns a normalized string. The result of this
  # method *must* be identical to a result generated by eol_php_code method
  # Functions::clean_name TODO: Write a test that is universal for php and ruby
  # code for this method to ensure both methods are in sync
  def self.prepare_clean_name(name, options={})
    name = name.gsub(/[.,;]/," ").gsub(/[\-\(\)\[\]\{\}:&\*?×]/,' \0 ')
    name = name.gsub(/ (and|et) /," & ") unless options[:is_common_name]
    name = name.gsub(/ +/, " ").downcase
    name = name.gsub("À","à").gsub("Â","â").gsub("Å","å").gsub("Ã","ã").gsub("Ä","ä")
    name = name.gsub("Á","á").gsub("Æ","æ").gsub("C","c").gsub("Ç","ç").gsub("Č","č")
    name = name.gsub("É","é").gsub("È","è").gsub("Ë","ë").gsub("Í","í").gsub("Ì","ì")
    name = name.gsub("Ï","ï").gsub("Ň","ň").gsub("Ñ","ñ").gsub("Ó","ó")
    name = name.gsub("Ò","ò").gsub("Ô","ô").gsub("Ø","ø").gsub("Õ","õ").gsub("Ö","ö")
    name = name.gsub("Ú","ú").gsub("Ù","ù").gsub("Ü","ü").gsub("Ŕ","ŕ")
    name = name.gsub("Ř","ř").gsub("Ŗ","ŗ").gsub("Š","š").gsub("Ş","ş").gsub("Ž","ž").gsub("Œ","œ")
    name.strip
  end

  # Takes a name strings and creates new records for ... models.
  # Currently this method works well only for common (vernacular)
  # names, because we do not need insertion of scientific names
  # from ruby code at the moment. If we will need scientific names
  # in the future it migt make sense to overload 'create' method
  # of the model with this logic and speed everything up as well.
  def self.create_common_name(name_string, given_canonical_form = "")
    name_string = name_string.strip.gsub(/\s+/,' ') if name_string.class == String
    return nil if name_string.blank?

    Name.with_master do
      common_name = Name.find_by_string(name_string, is_common_name: true)
      if common_name
        common_name.update_attributes(string: name_string) unless name_string == common_name.string
        return common_name
      end
      attributes = {string: name_string, namebank_id: 0, is_common_name: true}
      unless given_canonical_form.blank?
        attributes[:canonical_form_id] = CanonicalForm.find_or_create_by_string(given_canonical_form).id
        attributes[:canonical_verified] = 1
      end
      return Name.create!(attributes)
    end
  end

  def self.find_or_create_by_string(string)
    if n = Name.find_by_string(string)
      return n
    end
    return Name.create(string: string)
  end

  def self.find_by_string(string, options={})
    clean_string = Name.prepare_clean_name(string, options)
    return Name.find_by_clean_name(clean_string)
  end

  def self.is_surrogate_or_hybrid?(string)
    SURROGATE_REGEXES.each do |re|
      return true if string =~ re
    end
    return false
  end

  def taxon_concepts
    return TaxonConcept.find(taxon_concept_names.map(&:taxon_concept_id).uniq)
  end

  def italicized_canonical
    # hoping these short-circuit messages help with debugging ... likely due to bad/incomplete fixture data?
    # return "(no canonical form, tc: #{ taxon_concepts.map(&:id).join(',') })" unless canonical_form
    return 'not assigned' unless canonical_form and canonical_form.string and not canonical_form.string.empty?
    return "<i>#{canonical_form.string}</i>"
  end

  # String representation of a Name is its Name#string
  def to_s
    string
  end

  def is_surrogate_or_hybrid?
    Name.is_surrogate_or_hybrid?(string)
  end

  def is_subgenus?
    string.match(/^[A-Z][^ ]+ \([A-Z][^ ]+\)($| [A-Z])/)
  end

private

  def clean_name_must_be_unique
    found_name = Name.find_by_string(self.string, is_common_name: self.is_common_name)
    errors[:base] << "Name string must be unique" unless found_name.nil?
  end

  def set_default_values
    self.namebank_id = 0
  end

  def create_clean_name
    self.namebank_id = 0
    if self.clean_name.nil? || self.clean_name.blank?
      self.clean_name = Name.prepare_clean_name(self.string, is_common_name: is_common_name)
    end
  end

  def create_canonical_form
    if self.canonical_form_id.nil? || self.canonical_form_id == 0
      self.canonical_form = CanonicalForm.find_or_create_by_string(self.string) #all we need to do for common names
      self.canonical_verified = 0
    else
      self.canonical_verified = 1
    end
  end

  def create_italicized
    if self.italicized.nil? || self.italicized.blank?
      self.italicized = "<i>#{string}</i>" #all we need to do for common names
      self.italicized_verified = 0
    else
      self.italicized_verified = 1
    end
  end
end
