class TaxonName < ActiveRecord::Base

  acts_as_nested_set

  has_many :taxon_name_relationships, foreign_key: :subject_taxon_name_id

  validates_presence_of :type
  validates_presence_of :rank_class, if: Proc.new { |tn| [TaxonName].include?(tn.class)}
  validates_presence_of :name, if: Proc.new { |tn| [TaxonName].include?(tn.class)}

  # TODO: validates_format_of :name, with: "something", if: "some proc"

  before_validation :set_type_if_empty,
                    :check_format_of_name,
                    :validate_rank_class_class

  after_validation :set_cached_name

  def rank
    ::RANKS.include?(self.rank_class) ? self.rank_class.rank_name : nil
  end

  def rank_class=(value)
    write_attribute(:rank_class, value.to_s)
  end

  def rank_class
    r = read_attribute(:rank_class)
    Ranks.valid?(r) ? r.constantize : r 
  end

  def ancestor_at_rank(rank)
    r = Ranks.lookup(self.rank_class.nomenclatural_code, rank)
    return RANKS.index(r) >= RANKS.index(self.rank_class) ? nil :
      self.ancestors.detect { |ancestor| ancestor.rank_class == r }
  end

  protected 
  
  def set_type_if_empty
    self.type = 'Protonym' if self.type.nil?
  end

  def validate_rank_class_class
    # TODO: refactor properly
    return true if self.class == Chresonym && self.rank_class.nil? 
    errors.add(:rank_class, "rank not found") if !Ranks.valid?(rank_class)
  end

  # TODO: This should be based on the logic of the related rank
  def set_cached_name
    true 
  end

  def check_format_of_name
    if self.rank_class && self.rank_class.respond_to?(:validate_name_format)
      self.rank_class.validate_name_format(self)
    end
  end

end


