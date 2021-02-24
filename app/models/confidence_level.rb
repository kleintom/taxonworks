# A user-defined level of data quality vi Confidences.  
class ConfidenceLevel < ControlledVocabularyTerm
  has_many :confidences, foreign_key: :confidence_level_id, dependent: :destroy, inverse_of: :confidence_level

  scope :used_on_klass, -> (klass) { joins(:confidences).where(confidences: {confidence_object_type: klass} ) }

  # @return [Scope]
  #    the max 10 most recently used confidence levels
  def self.used_recently(user_id, project_id, klass)
    t = ConfidenceLevel.arel_table 
    c = Confidence.arel_table

    # i is a select manager
    i = c.project(c['confidence_level_id'], c['created_at']).from(c)
      .where(c['created_at'].gt( 1.weeks.ago ))
      .where(c['created_by_id'].eq(user_id))
      .where(c['project_id'].eq(project_id))
      .order(c['created_at'].desc)
     
    # z is a table alias 
    z = i.as('recent_c')

    ConfidenceLevel.used_on_klass(klass).joins(
      Arel::Nodes::InnerJoin.new(z, Arel::Nodes::On.new(z['confidence_level_id'].eq(t['id'])))
    ).pluck(:id).uniq
  end

  def confidenced_objects
    confidences.collect{|c| c.confidence_object}
  end

  def confidenced_object_class_names
    Confidence.where(confidence_level: self).pluck(:confidence_object_type)
  end

  # @param klass [like CollectionObject] required
  def self.select_optimized(user_id, project_id, klass)
    r = used_recently(user_id, project_id, klass)
    h = {
        quick: [],
        pinboard: ConfidenceLevel.pinned_by(user_id).where(project_id: project_id).to_a,
        recent: []
    }

    if r.empty?
      h[:quick] = ConfidenceLevel.pinned_by(user_id).pinboard_inserted.where(project_id: project_id).to_a
    else
      h[:recent] = ConfidenceLevel.where('"controlled_vocabulary_terms"."id" IN (?)', r.first(10) ).order(:name).to_a
      h[:quick] = (ConfidenceLevel.pinned_by(user_id).pinboard_inserted.where(project_id: project_id).to_a +
          ConfidenceLevel.where('"controlled_vocabulary_terms"."id" IN (?)', r.first(4) ).order(:name).to_a).uniq
    end

    h
  end

end
