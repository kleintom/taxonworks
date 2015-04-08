class GeographicAreasController < ApplicationController
  include DataControllerConfiguration::SharedDataControllerConfiguration

  before_action :set_geographic_area, only: [:show]
  before_action :disable_turbolinks, only: [:show, :list, :index]

  # GET /geographic_areas
  # GET /geographic_areas.json
  def index
    @recent_objects = GeographicArea.updated_in_last(2.months).order(updated_at: :desc).limit(10)
    render '/shared/data/all/index'
  end

  # GET /geographic_areas/1
  # GET /geographic_areas/1.json
  def show
    # GeographicArea.idontknow()
  end

  def display_coordinates
    @asserted_distribution = AssertedDistribution.new
    @json_coors = params.to_json
    render partial: '/asserted_distributions/quick_form'
  end

  def list
    @geographic_areas = GeographicArea.order(:id).page(params[:page])
  end

  def search
    if params[:id].blank?
      redirect_to geographic_area_path, notice: 'You must select an item from the list with a click or tab press before clicking show.'
    else
      redirect_to geographic_area_path(params[:id])
     end
  end

  def autocomplete
    @geographic_areas = GeographicArea.find_for_autocomplete(params)
    data = @geographic_areas.collect do |t|
      show_this = GeographicAreasHelper.geographic_area_autocomplete_tag(t, params[:term])
      {id:              t.id,
       label:           GeographicAreasHelper.geographic_area_tag(t),
       response_values: {
         params[:method] => t.id
       },
       label_html:      show_this
      }
    end
    render :json => data
  end

  # GET /geographic_areas/download
  def download
    send_data GeographicArea.generate_download( GeographicArea.all ), type: 'text', filename: "geographic_areas_#{DateTime.now.to_s}.csv"
  end

  private

  # TODO: move to a concern?

  # Use callbacks to share common setup or constraints between actions.
  def set_geographic_area
    @geographic_area = GeographicArea.find(params[:id])
    @recent_object = @geographic_area 
  end

  # Never trust parameters from the scary internet, only allow the white list through.
  def geographic_area_params
    params.require(:geographic_area).permit(:name, :level0_id, :level1_id, :level2_id, :parent_id,
                                            :geographic_area_type_id, :iso_3166_a2, :iso_3166_a3, :tdwgID,
                                            :data_origin)
  end
end
