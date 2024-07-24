# Helpers for gazetteer-related queries
#
# !! You must have `#from_wkt` defined in the module to use this concern
# !! You must call set_gazetteer_params in initialize()
#
# Concern specs are in
#   spec/lib/queries/source/filter_spec.rb
module Queries::Concerns::Gazetteers
  extend ActiveSupport::Concern

  included do
    # @param gazetteer_id [Array, Integer, String]
    # @return [Array]
    attr_accessor :gazetteer_id

    def gazetteer_id
      [@gazetteer_id].flatten.compact
    end
  end

  def set_gazetteer_params(params)
    @gazetteer_id = params[:gazetteer_id]
  end

  def gazetteer_id_facet
    return nil if gazetteer_id.empty?

    a = ::Gazetteer.where(id: gazetteer_id)

    i = ::GeographicItem.joins(:gazetteer).where(gazetteer: a)
    wkt_shape = ::Queries::GeographicItem.st_union(i).to_a.first['st_union'].to_s

    from_wkt(wkt_shape)
  end

end
