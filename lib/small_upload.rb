# uploads files smaller than chunk limit as a single file
class SmallUpload < BaseUpload
  def initiate
    @complete = false
  end
    
  def queue(buffer)
    # parse file metadata
    
    data = parse_data(buffer)
    headers = data[:headers].merge!(@upload.headers)
    @response = request({
      :body       => data[:body],
      :expects    => 200,
      :headers    => headers,
      :host       => "#{@bucket}.#{@host}",
      :idempotent => true,
      :method     => 'PUT',
      :path       => CGI.escape(@upload.key)
    })

    @response.errback { handle_callback }
    @response.callback { handle_callback }
  end

  def complete?
    @complete
  end

  protected

    def handle_callback
      if @response.response_header.status != 200
        puts "Error uploading: " + @response.response_header.status.to_s + " " + @response.response
      end
      @complete = true
    end
end