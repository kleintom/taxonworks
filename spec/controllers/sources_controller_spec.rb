require 'rails_helper'

# This spec was generated by rspec-rails when you ran the scaffold generator.
# It demonstrates how one might use RSpec to specify the controller code that
# was generated by Rails when you ran the scaffold generator.
#
# It assumes that the implementation code is generated by the rails scaffold
# generator.  If you are using any extension libraries to generate different
# controller code, this generated spec may or may not pass.
#
# It only uses APIs available in rails and/or rspec-rails.  There are a number
# of tools you can use to make these specs even more expressive, but we're
# sticking to rails and rspec-rails APIs to keep things simple and stable.
#
# Compared to earlier versions of this generator, there is very limited use of
# stubs and message expectations in this spec.  Stubs are only used when there
# is no simpler way to get a handle on the object needed for the example.
# Message expectations are only used when there is no simpler way to specify
# that an instance is receiving a specific message.

describe SourcesController, :type => :controller do
  before(:each) {
    sign_in
  }


  # This should return the minimal set of attributes required to create a valid
  # Source. As you add validations to Source, be sure to
  # adjust the attributes here as well.
  let(:valid_attributes) { 
   strip_housekeeping_attributes( FactoryGirl.build(:valid_source).attributes )
  }

  # This should return the minimal set of values that should be in the session
  # in order to pass any filters (e.g. authentication) defined in
  # SourcesController. Be sure to keep this updated too.
  let(:valid_session) { {} }

  describe "GET index" do
    it "assigns all sources as @recent_objects" do
      source = Source.create! valid_attributes
      get :index, {}, valid_session
      expect(assigns(:recent_objects)).to include(source)
    end
  end

  describe "GET show" do
    it "assigns the requested source as @source" do
      source = Source.create! valid_attributes
      get :show, {:id => source.to_param}, valid_session
      expect(assigns(:source)).to eq(source)
    end
  end

  describe "GET new" do
    it "assigns a new source as @source" do
      get :new, {}, valid_session
      expect(assigns(:source)).to be_a_new(Source)
    end
  end

  describe "GET edit" do
    it "assigns the requested source as @source" do
      source = Source.create! valid_attributes
      get :edit, {:id => source.to_param}, valid_session
      expect(assigns(:source)).to eq(source)
    end
  end

  describe "POST create" do
    describe "with valid params" do
      it "creates a new Source" do
        expect {
          post :create, {:source => valid_attributes}, valid_session
        }.to change(Source, :count).by(1)
      end

      it "assigns a newly created source as @source" do
        post :create, {:source => valid_attributes}, valid_session
        expect(assigns(:source)).to be_a(Source)
        expect(assigns(:source)).to be_persisted
      end

      it "redirects to the created source" do
        post :create, {:source => valid_attributes}, valid_session
        expect(response).to redirect_to(Source.last.metamorphosize)
      end
    end

    describe "with invalid params" do
      it "assigns a newly created but unsaved source as @source" do
        # Trigger the behavior that occurs when invalid params are submitted
        allow_any_instance_of(Source).to receive(:save).and_return(false)
        post :create, {:source => { "serial_id" => "invalid value" }}, valid_session
        expect(assigns(:source)).to be_a_new(Source)
      end

      it "re-renders the 'new' template" do
        # Trigger the behavior that occurs when invalid params are submitted
        allow_any_instance_of(Source).to receive(:save).and_return(false)
        post :create, {:source => { "serial_id" => "invalid value" }}, valid_session
        expect(response).to render_template("new")
      end
    end
  end

  describe "PUT update" do
    describe "with valid params" do
      it "updates the requested source" do
        source = Source.create! valid_attributes
        # Assuming there are no other sources in the database, this
        # specifies that the Source created on the previous line
        # receives the :update_attributes message with whatever params are
        # submitted in the request.
        expect_any_instance_of(Source).to receive(:update).with( {"serial_id"=>"1", "project_sources_attributes"=>[{"project_id"=>"1"}]}   )
        put :update, {:id => source.to_param, :source => { "serial_id" => "1" }}, valid_session
      end

      it "assigns the requested source as @source" do
        source = Source.create! valid_attributes
        put :update, {:id => source.to_param, :source => valid_attributes}, valid_session
        expect(assigns(:source)).to eq(source)
      end

      it "redirects to the source" do
        source = Source.create! valid_attributes
        put :update, {:id => source.to_param, :source => valid_attributes}, valid_session
        expect(response).to redirect_to(source.becomes(Source))
      end
    end

    describe "with invalid params" do
      it "assigns the source as @source" do
        source = Source.create! valid_attributes
        # Trigger the behavior that occurs when invalid params are submitted
        allow_any_instance_of(Source).to receive(:save).and_return(false)
        put :update, {:id => source.to_param, :source => { "serial_id" => "invalid value" }}, valid_session
        expect(assigns(:source)).to eq(source)
      end

      it "re-renders the 'edit' template" do
        source = Source.create! valid_attributes
        # Trigger the behavior that occurs when invalid params are submitted
        allow_any_instance_of(Source).to receive(:save).and_return(false)
        put :update, {:id => source.to_param, :source => { "serial_id" => "invalid value" }}, valid_session
        expect(response).to render_template("edit")
      end
    end
  end

  describe "DELETE destroy" do
    it "destroys the requested source" do
      source = Source.create! valid_attributes
      expect {
        delete :destroy, {:id => source.to_param}, valid_session
      }.to change(Source, :count).by(-1)
    end

    it "redirects to the sources list" do
      source = Source.create! valid_attributes
      delete :destroy, {:id => source.to_param}, valid_session
      expect(response).to redirect_to(sources_url)
    end
  end

end
