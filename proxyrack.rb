require 'rubygems'
require 'yaml'
require 'curb'
require 'rack/lib/rack'
require 'rack/lib/rack/cache'

class ProxyRack
  def initialize
    @proxy = YAML::load(File.open('config/proxy.yml'))
  end
  
  def call(env)
    # set local parameters
    headers   = YAML::load(File.open('config/headers.yml'))
    uri       = env['PATH_INFO']
    params    = env['QUERY_STRING'].split('&').collect {|k| k.split('=').first} unless env['QUERY_STRING'].nil?
    params  ||= []  # set empty params if the query string was empty
    
    # check for valid uri query
    if check_uri( uri, params )
      data = proxy_request(env)
      expires = (Time.now + 43200).utc.rfc2822
      
      # return an HTTP 200 and proxy the request with a cache header
      [200, headers.merge('Expires' => expires), data]
    else
      # return an HTTP 400 error if request isn't valid
      [400, {'Content-Type' => 'text/xml'}, '<error>Bad Request</error>']
    end
  end
  
  def check_uri(uri, params = [])
    # lookup the URI and see if it's a permitted request
    if u = @proxy[:valid_uris].find {|h| h.has_value?(uri)}
      # check for required params to the URI
      unless u[:required].nil?
        # take the intersection of the required params and submitted ones
        p = u[:required] - params
        # p should be empty if the required params are set
        return false if p.empty?
      end

    end
    
    # if the uri was found, it should have returned a hash
    return u.nil? ? false : true
  end
  
  def proxy_request(env)
    # build the full url
    url = @proxy[:url] + env['PATH_INFO']
    url << "?#{env['QUERY_STRING']}" unless env['QUERY_STRING'].nil?
    
    # curl from remote host
    Curl::Easy.perform( url ).body_str
  end
  
end

app = Rack::Builder.new { 
  use Rack::CommonLogger, STDERR
  use Rack::Cache,
    :verbose     => true,
    :metastore   => "file:cache/meta",
    :entitystore => "file:cache/body" 
  run ProxyRack.new
}

server  = Rack::Handler::WEBrick
options = YAML::load(File.open('config/server.yml'))
server.run app, options