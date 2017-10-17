# A Confidence is an annotation that links a user-defined confidence level to a
# data object. It is an assertion as to the quality of that data.
#
# @!attribute confidence_level_id
#   @return [Integer]
#     the controlled vocabulary term used in the confidence
#
# @!attribute confidence_object_id
#   @return [Integer]
#      Rails polymorphic. The id of of the object being annotated.
#
# @!attribute confidence_object_type
#   @return [String]
#      Rails polymorphic.  The type of the object being annotated.
#
# @!attribute project_id
#   @return [Integer]
#   the project ID
#
# @!attribute position
#   @return [Integer]
#     a user definable sort code on the tags on an object, handled by acts_as_list
#
class Confidence < ApplicationRecord
  include Housekeeping
  include Shared::IsData
  include Shared::PolymorphicAnnotator
  polymorphic_annotates(:confidence_object)

  acts_as_list scope: [:confidence_level_id]

  belongs_to :confidence_level
  belongs_to :controlled_vocabulary_term, foreign_key: :confidence_level_id

  validates :confidence_level, presence: true
  validates_uniqueness_of :confidence_level_id, scope: [:confidence_object_id, :confidence_object_type]

  accepts_nested_attributes_for :confidence_level, allow_destroy: true
end
