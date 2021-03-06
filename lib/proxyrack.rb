require 'rubygems'
require 'yaml'
require 'curb'
require 'builder'
require 'rack'
require 'rack/cache'

class ProxyRack
  def initialize
    @proxy = YAML::load(File.open("#{File.dirname(__FILE__)}/config/proxy.yml"))
  end
  
  def call(env)
    # set local parameters
    headers   = YAML::load(File.open("#{File.dirname(__FILE__)}/config/headers.yml"))
    uri       = env['PATH_INFO']
    params    = env['QUERY_STRING'].split('&').collect {|k| k.split('=').first.downcase} unless env['QUERY_STRING'].nil?
    params    ||= []  # set empty params if the query string was empty
    
    # check for valid uri query
    if check_uri( uri, params )
      data = proxy_request(env)
      # compute the expiration time based off of the original request
      headers.merge!('Expires' => Time.parse( $1 ).rfc2822) if data =~ /<cachedUntil>(.*)<\/cachedUntil>/
      headers.merge!('Content-Length' => data.length.to_s)

      # return an HTTP 200 and proxy the request with a cache header
      [200, headers, data]
    else
      # return an HTTP 400 error if request isn't valid
      [400, {'Content-Type' => 'text/xml'}, error_message('Bad Request', env['PATH_INFO'], env['QUERY_STRING'])]
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
       return false unless p.empty?
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
  
  def error_message( message, request, query = nil )
    error = Builder::XmlMarkup.new.error do |b| 
              b.message( message )
              b.request( request )
              b.query( query ) unless query.nil?
            end
  end
  
end