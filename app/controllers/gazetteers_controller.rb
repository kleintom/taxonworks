class GazetteersController < ApplicationController
  include DataControllerConfiguration::ProjectDataControllerConfiguration
  before_action :set_gazetteer, only: %i[ show edit update destroy ]

  # GET /gazetteers
  # GET /gazetteers.json
  def index
    respond_to do |format|
      format.html do
        @recent_objects = Gazetteer.recent_from_project_id(sessions_current_project_id).order(updated_at: :desc).limit(10)
        render '/shared/data/all/index'
      end
      format.json do
        # TODO gzs, not gas
        @geographic_areas = ::Queries::GeographicArea::Filter.new(params).all
          .includes(:geographic_items)
          .page(params[:page])
          .per(params[:per])
          # .order('geographic_items.cached_total_area, geographic_area.name')
      end
    end
  end

  # GET /gazetteers/1 or /gazetteers/1.json
  def show
  end

  # GET /gazetteers/new
  def new
    @gazetteer = Gazetteer.new
  end

  # GET /gazetteers/1/edit
  def edit
  end

  # GET /gazetteers/list
  def list
    @gazetteers = Gazetteer
      .with_project_id(sessions_current_project_id)
      .page(params[:page]).per(params[[:per]])
  end

  # POST /gazetteers.json
  def create
    @gazetteer = Gazetteer.new(gazetteer_params)

    begin
      shape = Gazetteer.combine_shapes_to_rgeo(shape_params['shapes'])
    # TODO make sure these errors work
    rescue RGeo::Error::RGeoError => e
      @gazetteer.errors.add(:base, "Invalid WKT: #{e}")
    rescue RGeo::Error::InvalidGeometry => e
      @gazetteer.errors.add(:base, "Invalid geometry: #{e}")
    rescue TaxonWorks::Error => e
      @gazetteer.errors.add(:base, e)
    end

    if @gazetteer.errors.include?(:base) || shape.nil?
      render json: @gazetteer.errors, status: :unprocessable_entity
      return
    end

    # TODO does this bypass save and set_cached_area? If not, how does that happen?
    @gazetteer.geographic_item = GeographicItem.new(geography: shape)

    if @gazetteer.save
      render :show, status: :created, location: @gazetteer
      # TODO make this notice work
      flash[:notice] = 'Gazetteer created.'
    else
      render json: @gazetteer.errors, status: :unprocessable_entity
    end
  end

  # PATCH/PUT /gazetteers/1
  # PATCH/PUT /gazetteers/1.json
  def update
    respond_to do |format|
      if @gazetteer.update(gazetteer_params)
        format.html { redirect_to gazetteer_url(@gazetteer), notice: "Gazetteer was successfully updated." }
        # TODO Add updated message
        format.json { render :show, status: :ok }
      else
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: @gazetteer.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /gazetteers/1 or /gazetteers/1.json
  def destroy
    @gazetteer.destroy!

    respond_to do |format|
      format.html { redirect_to gazetteers_url, notice: "Gazetteer was successfully destroyed." }
      format.json { head :no_content }
    end
  end

  private

  def set_gazetteer
    @gazetteer = Gazetteer.find(params[:id])
  end

  def gazetteer_params
    params.require(:gazetteer).permit(:name, :parent_id, :iso_3166_a2, :iso_3166_a3)
  end

  def shape_params
    params.require(:gazetteer).permit(shapes: { geojson: [], wkt: []})
  end


end
