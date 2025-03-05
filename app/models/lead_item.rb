class LeadItem < ApplicationRecord
  include Housekeeping

  acts_as_list scope: [:lead_id, :project_id]

  belongs_to :otu, inverse_of: :lead_items
  belongs_to :lead, inverse_of: :lead_items
  belongs_to :project

  has_one :taxon_name, through: :otu

  validates_presence_of :otu, :lead

  def self.batch_populate(lead_id, otus)
    otus.each do |o|
      # TODO check result
      puts 'BBBBBBBBBBBBBB'
      LeadItem.find_or_create_by!(lead_id:, otu: o)
    end
  end
end
