require 'uri'

uri = URI.parse(ENV['MONGOLAB_URI'])

Mongoid.configure do |config|
  config.logger = Logger.new($stdout, :warn)
  config.master = Mongo::Connection.from_uri(ENV['MONGOLAB_URI']).db(uri.path[1..-1])
end