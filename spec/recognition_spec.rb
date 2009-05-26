require 'spec_helper'

describe "subdomain route recognition" do
  before(:each) do
    ActionController::Routing::Routes.clear!
    SubdomainRoutes::Config.stub!(:domain_length).and_return(2)
    @request = ActionController::TestRequest.new
    @request.host = "www.example.com"
    @request.request_uri = "/items/2"
  end

  it "should add the host's subdomain to the request environment" do
    request_environment = ActionController::Routing::Routes.extract_request_environment(@request)
    request_environment[:subdomain].should == "www"
  end
  
  it "should add an empty subdomain to the request environment if the host has no subdomain" do
    @request.host = "example.com"
    request_environment = ActionController::Routing::Routes.extract_request_environment(@request)
    request_environment[:subdomain].should == ""
  end
  
  context "for a single specified subdomain" do
    it "should recognise a route if the subdomain matches" do
      map_subdomain(:www) { |www| www.resources :items }
      params = recognize_path(@request)
      params[:controller].should == "www/items"
      params[:action].should == "show"
      params[:id].should == "2"
    end
  
    it "should not recognise a route if the subdomain doesn't match" do
      map_subdomain("admin") { |admin| admin.resources :items }
      lambda { recognize_path(@request) }.should raise_error(ActionController::RoutingError)
    end
  end
  
  context "for a nil or blank subdomain" do
    [ nil, "" ].each do |subdomain|
      it "should recognise a route if there is no subdomain present" do
        map_subdomain(subdomain) { |map| map.resources :items }
        @request.host = "example.com"
        params = recognize_path(@request)
        params[:controller].should == "items"
        params[:action].should == "show"
        params[:id].should == "2"
      end
    end
  end
  
  context "for multiple specified subdomains" do
    it "should recognise a route if the subdomain matches" do
      map_subdomain(:www, :admin, :name => nil) { |map| map.resources :items }
      params = recognize_path(@request)
      params[:controller].should == "items"
      params[:action].should == "show"
      params[:id].should == "2"
    end
  
    it "should not recognise a route if the subdomain doesn't match" do
      map_subdomain(:support, :admin, :name => nil) { |map| map.resources :items }
      lambda { recognize_path(@request) }.should raise_error(ActionController::RoutingError)
    end
  end
  
  context "for a :proc subdomain" do
    before(:each) do
      ActionController::Routing::Routes.verify_subdomain(:user) { |user| } # this block will be stubbed
      map_subdomain(:proc => :user) { |user| user.resources :articles }
      @request.request_uri = "/articles"
      @request.host = "mholling.example.com"
    end
    
    it "should call the verify proc only once per recognition" do
      pending
      [ true, false ].each do |value|
        [ '/articles', '/articles/new', '/articles/1', '/articles/1/edit' ].each do |path|
          @request.request_uri = path
          ActionController::Routing::Routes.should_receive(:user_subdomain?).once.with("mholling").and_return(value)
          recognize_path(@request)
        end
      end
    end   
  
    it "should match the route if the verify proc returns true or an object" do
      [ true, Object.new ].each do |value|
        ActionController::Routing::Routes.subdomain_procs.should_receive(:verify).any_number_of_times.with(:user, "mholling").and_return(value)
        lambda { recognize_path(@request) }.should_not raise_error
      end
    end
    
    it "should not match the route if the verify proc returns false or nil" do
      [ false, nil ].each do |value|
        ActionController::Routing::Routes.subdomain_procs.should_receive(:verify).any_number_of_times.with(:user, "mholling").and_return(value)
        lambda { recognize_path(@request) }.should raise_error(ActionController::RoutingError)
      end
    end
  end
  
  # 1. TODO: can we stub out anything else instead of contrived examples?
  # 
  # 2. TODO: Investigate how to optimise :verify_subdomain proc-based recognition condition.
  #    It gets called once for every route under that subdomain (unless the route gets
  #    recognised first). So that could be very expensive if the proc makes a db call.
  #    The result of the method call needs to be cached somehow (but cache needs to be reset
  #    on every request cycle, otherwise it could get stale). THIS IS IMPORTANT! (Maybe we
  #    could use memoize?)
end
