$LOAD_PATH.unshift(File.dirname(__FILE__))
require 'proxyrack'
require 'test/unit'
require 'rack/test'

class ProxyTest < Test::Unit::TestCase
  include Rack::Test::Methods
  
  def app
    Rack::Builder.new { 
      use Rack::CommonLogger, STDERR
      use Rack::Cache,
        :verbose     => true,
        :metastore   => "file:cache/meta",
        :entitystore => "file:cache/body",
        :prefix      => '/api-proxy'
    }
  end
    
  def test_make_api_call_without_parameters
    get "/server/ServerStatus.xml.aspx"
    assert last_response.ok?
  end
end