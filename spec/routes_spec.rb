require 'spec_helper'

describe "subdomain routes" do
  before(:each) do
    ActionController::Routing::Routes.clear!
    SubdomainRoutes::Config.stub!(:domain_length).and_return(2)
  end
    
  it "should check the validity of each subdomain" do
    SubdomainRoutes.should_receive(:valid_subdomain?).twice.and_return(true, true)
    lambda { map_subdomain(:www, :www1) { } }.should_not raise_error
  end
  
  it "should check the validity of each subdomain and raise an error if any are invalid" do
    SubdomainRoutes.should_receive(:valid_subdomain?).twice.and_return(true, false)
    lambda { map_subdomain(:www, :www!) { } }.should raise_error(ArgumentError)
  end
  
  it "should check not the validity of a nil subdomain" do
    SubdomainRoutes.should_not_receive(:valid_subdomain?)
    map_subdomain(nil) { }
  end
  
  it "should accept a nil subdomain" do
    map_subdomain(nil) { |map| map.options[:subdomains].should == [ "" ] }
  end

  it "should accept a blank subdomain" do
    map_subdomain("") { |map| map.options[:subdomains].should == [ "" ] }
  end

  it "should accept a single specified subdomain" do
    map_subdomain(:admin) { |admin| admin.options[:subdomains].should == [ "admin" ] }
  end
  
  it "should accept strings or symbols as subdomains" do
    map_subdomain(:admin)  { |admin| admin.options[:subdomains].should == [ "admin" ] }
    map_subdomain("admin") { |admin| admin.options[:subdomains].should == [ "admin" ] }
  end

  it "should accept multiple subdomains" do
    map_subdomain(:admin, :support) { |map| map.options[:subdomains].should == [ "admin", "support" ] }
  end

  it "should downcase the subdomains" do
    map_subdomain(:Admin, "SUPPORT") { |map| map.options[:subdomains].should == [ "admin", "support" ] }
  end
  
  it "should accept a :resources option as the subdomain" do
    map_subdomain(:resources => :names) { |name| name.options[:subdomains].should == { :resources => "names" } }
  end

  it "should raise ArgumentError if no subdomain is specified" do
    lambda { map_subdomain }.should raise_error(ArgumentError)
  end
  
  it "should not include repeated subdomains in the options" do
    map_subdomain(:admin, :support, :admin) { |map| map.options[:subdomains].should == [ "admin", "support" ] }
  end
  
  it "should be invoked by map.subdomains as well as map.subdomain" do
    ActionController::Routing::Routes.draw do |map|
      map.subdomains(:admin, :support) { |sub| sub.options[:subdomains].should == [ "admin", "support" ] }
    end
  end
  
  [ [ :admin ], [ :support, :admin ] ].each do |subdomains|
    context "mapping #{subdomains.size} subdomains" do
      it "should set the first subdomain as a namespace" do
        map_subdomain(*subdomains) { |map| map.options[:namespace].should == "#{subdomains.first}/" }
      end

      it "should prefix the first subdomain to named routes" do
        map_subdomain(*subdomains) { |map| map.options[:name_prefix].should == "#{subdomains.first}_" }
      end
      
      it "should instead set a namespace to the name if specified" do
        args = subdomains + [ :name => :something ]
        map_subdomain(*args) { |map| map.options[:namespace].should == "something/" }
      end

      it "should instead prefix the name to named routes if specified" do
        args = subdomains + [ :name => :something ]
        map_subdomain(*args) { |map| map.options[:name_prefix].should == "something_" }
      end

      it "should not set a namespace if name is specified as nil" do
        args = subdomains + [ :name => nil ]
        map_subdomain(*args) { |map| map.options[:namespace].should be_nil }
      end

      it "should not set a named route prefix if name is specified as nil" do
        args = subdomains + [ :name => nil ]
        map_subdomain(*args) { |map| map.options[:name_prefix].should be_nil }
      end
    end
  end
  
  it "should strip bad characters from the namespace and name prefix" do
    map_subdomain("just-do-it") { |map| map.options[:namespace].should == "just_do_it/" }
    map_subdomain("just-do-it") { |map| map.options[:name_prefix].should == "just_do_it_" }
    map_subdomain(nil, :name => "just-do-it") { |map| map.options[:namespace].should == "just_do_it/" }
    map_subdomain(nil, :name => "just-do-it") { |map| map.options[:name_prefix].should == "just_do_it_" }
    map_subdomain(nil, :name => "Just do it!") { |map| map.options[:namespace].should == "just_do_it/" }
    map_subdomain(nil, :name => "Just do it!") { |map| map.options[:name_prefix].should == "just_do_it_" }
  end
  
  context "mapping the nil subdomain" do
    it "should not set a namespace" do
      [ nil, "" ].each do |none|
        map_subdomain(none) { |map| map.options[:namespace].should be_nil }
      end
    end

    it "should not set a named route prefix" do
      [ nil, "" ].each do |none|
        map_subdomain(none) { |map| map.options[:name_prefix].should be_nil }
      end
    end
  end
  
  context "mapping nil and other subdomains" do
    it "should set the first non-nil subdomain as a namespace" do
      [ nil, "" ].each do |none|
        map_subdomain(none, :www) { |map| map.options[:namespace].should == "www/" }
      end
    end

    it "should prefix the first non-nil subdomain to named routes" do
      [ nil, "" ].each do |none|
        map_subdomain(none, :www) { |map| map.options[:name_prefix].should == "www_" }
      end
    end
  end
        
  context "for a :resources subdomain" do
    it "should not set a namespace" do
      map_subdomain(:resources => :cities) { |city| city.options[:namespace].should be_nil }
    end
  
    it "should prefix the resource name to named routes" do
      map_subdomain(:resources => :cities) { |city| city.options[:name_prefix].should == "city_" }
    end
  
    it "should not accept a :name option" do
      map_subdomain(:resources => :cities, :name => :birds) { |city| city.options[:namespace].should be_nil }
      map_subdomain(:resources => :cities, :name => :birds) { |city| city.options[:name_prefix].should == "city_" }
    end

    it "should add a resource index route" do
      map_subdomain(:resources => :cities) { |city| city.resources :events }
      ActionController::Routing::Routes.routes.find do |route|
        route.conditions == { :method => :get } &&
        route.requirements == { :controller => "cities", :action => "index", :subdomains => [""] }
      end.should be_true
      with_host "boston.example.com" do
        cities_path.should == "http://example.com/"
         cities_url.should == "http://example.com/"
      end
      with_host "example.com" do
        cities_path.should == "/"
         cities_url.should == "http://example.com/"
      end
    end

    it "should add a resource show route" do
      map_subdomain(:resources => :cities) { |city| city.resources :events }
      ActionController::Routing::Routes.routes.find do |route|
        route.conditions == { :method => :get, :subdomains => "cities" } &&
        route.requirements == { :controller => "cities", :action => "show", :subdomains => "cities" }
      end.should be_true
      with_host "boston.example.com" do
        city_path("hobart").should == "http://hobart.example.com/"
         city_url("hobart").should == "http://hobart.example.com/"
      end
      with_host "hobart.example.com" do
        city_path("hobart").should == "/"
         city_url("hobart").should == "http://hobart.example.com/"
      end
    end
      
    it "should pluralize and stringify the argument"
    
    it "should test segment_keys"
    
    it "should test recognition_extraction? (or have I already done that?)"
  end
end
