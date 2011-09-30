class Glue
  include HTTParty
  base_uri "http://pawdrop.com"

  def initialize
    @auth = { username: "auth", password: "" }
  end

  def fetch
    options = { body: { }, basic_auth: @auth }
    self.class.post('/uploads', options)
  end
end