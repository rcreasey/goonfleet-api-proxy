$LOAD_PATH.unshift(File.dirname(__FILE__))
require 'proxyrack'
require 'ruby-debug'
require 'test/unit'
require 'rack/test'
require 'hpricot'
require 'pp'

FileUtils.rm_rf %w(test_cache/meta test_cache/body)

class ProxyTest < Test::Unit::TestCase
  include Rack::Test::Methods
  
  def app
    Rack::Builder.new { 
      use Rack::CommonLogger, STDERR
      use Rack::Cache,
        :verbose     => true,
        :metastore   => "file:test_cache/meta",
        :entitystore => "file:test_cache/body",
        :prefix      => '/api-proxy'
      run ProxyRack.new
    }
  end
  
  def test_uncached_api_call_and_cache_it
    get "/server/ServerStatus.xml.aspx"
    assert last_response.ok?
    assert last_response.headers.include? 'Cache-Control'
    assert last_response.headers['Cache-Control'] =~ /max-age=(\d+)/
    assert Time.parse( last_response.headers['Expires'] ) > Time.now
    assert last_response.headers['Age'].to_i < $1.to_i
  end
  
  def test_api_call_without_parameters
    get "/server/ServerStatus.xml.aspx"
    assert last_response.ok?
    assert last_response.headers['Content-Type'].eql? 'text/xml'
    doc = Hpricot.XML(last_response.body)
    assert doc.search("/eveapi/result/serverOpen").inner_text =~ /True|False/
  end
  
  def test_api_call_with_valid_parameters
    get "/eve/CharacterID.xml.aspx?names=Tarei"
    assert last_response.ok?
    assert last_response.headers['Content-Type'].eql? 'text/xml'
    doc = Hpricot.XML(last_response.body)
    assert doc.search("/eveapi/result/rowset/*[@name='Tarei' and @characterID='724817669']").length.eql? 1
  end
  
  def test_api_call_with_invalid_parameters
    get "/account/Characters.xml.aspx?userid=724817669"
    assert last_response.headers['Content-Type'].eql? 'text/xml'
    assert last_response.status.eql? 400
    doc = Hpricot.XML(last_response.body)
    assert doc.search("/error/message").inner_text =~ /Bad Request/
    assert last_response.headers['Cache-Control'].eql? 'private'
    assert last_response.headers.include?('Age').eql? false
  end
  
  def test_api_call_to_nonexistant_resource
    get "/foobar.xml.aspx"
    assert last_response.headers['Content-Type'].eql? 'text/xml'
    assert last_response.status.eql? 400
    doc = Hpricot.XML(last_response.body)
    assert doc.search("/error/message").inner_text =~ /Bad Request/
    assert last_response.headers['Cache-Control'].eql? 'private'
    assert last_response.headers.include?('Age').eql? false
  end
  
  def test_api_call_parameter_ordering
    userid = '12345'
    apikey = 'xxxxxxxxxxxxxxxx'
    sessions = []
    sessions <<  Rack::Test::Session.new( Rack::MockSession.new( app ) )
    sessions[0].get "/account/Characters.xml.aspx?apikey=#{apikey}&userid=#{userid}"
    sessions <<  Rack::Test::Session.new( Rack::MockSession.new( app ) )
    sessions[1].get "/account/Characters.xml.aspx?userid=#{userid}&apikey=#{apikey}"
    assert sessions[0].last_response.headers['X-Content-Digest'].eql? sessions[1].last_response.headers['X-Content-Digest']
    assert sessions[0].last_request.env['QUERY_STRING'].eql? sessions[1].last_request.env['QUERY_STRING']
  end
end