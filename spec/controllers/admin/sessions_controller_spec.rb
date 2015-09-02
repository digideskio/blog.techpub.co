require File.dirname(__FILE__) + '/../../spec_helper'

describe Admin::SessionsController do
  describe 'handling GET to show (default)' do
    it 'redirects to new' do
      get :show
      response.should be_redirect
      response.should redirect_to(new_admin_session_path)
    end
  end

  describe 'handling GET to new' do
    before(:each) do
      get :new
    end

    it "should be successful" do
      response.should be_success
    end

    it "should render index template" do
      response.should render_template('new')
    end
  end

  describe 'handling DELETE to destroy' do
    before(:each) do
      delete :destroy
    end

    it 'logs out the current session' do
      session[:logged_in].should == false
    end

    it 'redirects to /' do
      response.should be_redirect
      response.should redirect_to('/')
    end
  end

  describe '#allow_login_bypass? when RAILS_ENV == production' do
    it 'returns false' do
      ::Rails.stub(:env).and_return('production')
      @controller.send(:allow_login_bypass?).should == false
    end
  end
end

shared_examples_for "logged in and redirected to /admin" do
  it "should set session[:logged_in]" do
    session[:logged_in].should be_truthy
  end
  it "should redirect to admin posts" do
    response.should be_redirect
    response.should redirect_to('/admin')
  end
end
shared_examples_for "not logged in" do
  it "should not set session[:logged_in]" do
    session[:logged_in].should be_nil
  end
  it "should render new" do
    response.should be_success
    response.should render_template("new")
  end
  it "should set flash.now[:error]" do
    flash.now[:error].should_not be_nil
  end
end

describe Admin::SessionsController, "handling CREATE with post" do
  before do
    @controller.instance_eval { flash.extend(DisableFlashSweeping) }
  end
  def stub_auth_response(auth_response)
    request.env["omniauth.auth"] = auth_response
  end
  def stub_enki_config
    @controller.stub(:enki_config).and_return(double("enki_config", :author_open_ids => [
        "http://enkiblog.com",
        "http://secondaryopenid.com"
      ].collect {|uri| URI.parse(uri)},
      :author_google_oauth2_email => "you@your-openid-connect-domain.com"
    ))
  end
  describe "with invalid URL http://evilman.com and OpenID authentication succeeding" do
    before do
      stub_enki_config
      stub_auth_response({ :provider => ApplicationController::OMNIAUTH_OPEN_ID_ADMIN_STRATEGY,
                           :uid => "http://evilman.com" })

      post :create
    end
    it_should_behave_like "not logged in"
  end
  describe "with valid URL http://enkiblog.com and OpenID authentication succeeding" do
    before do
      stub_enki_config
      stub_auth_response({ :provider => ApplicationController::OMNIAUTH_OPEN_ID_ADMIN_STRATEGY,
                            :uid => "http://enkiblog.com" })

      post :create
    end
    it_should_behave_like "logged in and redirected to /admin"
  end
  describe "with valid secondary URL http://secondaryopenid.com and OpenID authentication succeeding" do
    before do
      stub_enki_config
      stub_auth_response({ :provider => ApplicationController::OMNIAUTH_OPEN_ID_ADMIN_STRATEGY,
                            :uid => "http://secondaryopenid.com" })

      post :create
    end
    it_should_behave_like "logged in and redirected to /admin"
  end
  describe "with invalid email notyou@someotherdomain.com and Google OpenID Connect authentication succeeding" do
    before do
      stub_enki_config
      stub_auth_response({ :provider => ApplicationController::OMNIAUTH_GOOGLE_OAUTH2_STRATEGY,
                           :info => { :email => "notyou@someotherdomain.com" } })

      post :create
    end
    it_should_behave_like "not logged in"
  end
  describe "with valid email you@your-openid-connect-domain.com and Google OpenID Connect authentication succeeding" do
    before do
      stub_enki_config
      stub_auth_response({ :provider => ApplicationController::OMNIAUTH_GOOGLE_OAUTH2_STRATEGY,
                           :info => { :email => "you@your-openid-connect-domain.com" } })

      post :create
    end
    it_should_behave_like "logged in and redirected to /admin"
  end
  describe "with bypass login selected" do
    before do
      post :create, :bypass_login => "1"
    end
    it_should_behave_like "logged in and redirected to /admin"
  end
  describe "with bypass login selected but login bypassing disabled" do
    before do
      @controller.stub(:allow_login_bypass?).and_return(false)
      post :create, :bypass_login => "1"
    end
    it_should_behave_like "not logged in"
  end
end
