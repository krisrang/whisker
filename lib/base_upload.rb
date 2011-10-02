class BaseUpload
  def initialize(upload)
    @upload = upload
    
    @scheme = "http"
    @host = "s3.amazonaws.com"
    @port = 80
    @bucket = "pawdrop"

    @key = ENV['S3_KEY']
    @signature = ENV['S3_SECRET']

    @storage = Fog::Storage.new(
      provider: 'AWS',
      #region: Settings.s3_region,
      aws_access_key_id: @key,
      aws_secret_access_key: @signature,
      port: @port,
      host: @host,
      scheme: @scheme
    )
  end

  def initiate
    raise Exception.new "Not implemented"
  end

  def queue(buffer)
    raise Exception.new "Not implemented"
  end

  def complete?
    raise Exception.new "Not implemented"
  end

  def abort
  end

  protected

    def parse_data(data)
      metadata = {
        :body => nil,
        :headers => {}
      }

      metadata[:body] = data
      metadata[:headers]['Content-Length'] = data.bytesize

      metadata
    end

    def request(params, async = true)
      params[:headers]['Date'] = Fog::Time.now.to_date_header
      params[:headers]['Authorization'] = "AWS #{@key}:#{@storage.signature(params)}"

      method = async ? "a" : ""
      method << params[:method].to_s.downcase

      EventMachine::HttpRequest.new("#{@scheme}://#{params[:host]}:#{@port}/#{params[:path]}").send(method, 
        timeout: 10, query: params[:query], head: params[:headers], body: params[:body], redirects: 1)
    end
end