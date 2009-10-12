require 'lib/proxyrack'

app = Rack::Builder.new { 
  use Rack::CommonLogger, STDERR
  use Rack::Cache,
    :verbose     => true,
    :metastore   => "file:cache/meta",
    :entitystore => "file:cache/body",
    :prefix      => '/api-proxy'
  run ProxyRack.new
}

options = YAML::load(File.open('config/server.yml'))
Rack::Handler::Mongrel.run app, options
