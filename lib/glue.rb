class Glue
  include HTTParty
  #base_uri "http://pawdrop.com"
  base_uri "http://0.0.0.0:3000"

  def initialize
    @auth = { username: "auth", password: ENV['ADMIN_KEY'] }
  end

  def fetch(id)
    options = { body: { }, basic_auth: @auth }
    self.class.get("/uploads/#{id}.json", options)
  end
end