class UploadHandler
  def initialize(id)
    @error = nil
    @expected = 0
    @received = 0
    @chunk = 1
    @chunklimit = 5*1024*1024 # 5MB
    @parts = []
    clear_buffer
    setup_storage
    @upload = Upload.find id
  end

  def initiate
    if @expected > @chunklimit
      response = @storage.initiate_multipart_upload(@bucket, @upload.key, @upload.headers)
      @uploadid = response.body["UploadId"]
    end
  end

  def queue(env, data)
    if @error.nil?
      data.force_encoding('BINARY')

      @received = @received + data.bytesize
      if @received > @expected
        @error = "Invalid Content-Length value"
        clear_buffer
      end

      if @expected > @chunklimit
        put_part if @buffer.bytesize > @chunklimit
         
        @buffer << data
      end
    end
  end

  def complete(ticker, env)
    if @error.nil?
      if @expected <= @chunklimit
        @storage.put_object(@bucket, @upload.key, @buffer, @upload.headers)
      else
        put_part if @buffer.bytesize > 0 # last part
        @storage.complete_multipart_upload(@bucket, @upload.key, @uploadid, @parts)
        env.logger.info "multipart finished: " + @uploadid
        env.logger.info "received: " + @received.to_s
      end

      @upload.complete(@received).save
    end

    clear_buffer
    # keep checking for completion and close up when done
    ticker.cancel
    env.stream_close
  end

  def put_part
    response = @storage.upload_part(@bucket, @upload.key, @uploadid, @chunk, @buffer)
    @parts = @parts.dup.insert(@chunk-1, response.headers["ETag"])
    @chunk = @chunk+1
    clear_buffer
  end

  def id
    @upload.id
  end

  def exist?
    !!@upload
  end

  def error
    @error
  end

  def expected=(size)
    @expected = size.to_i
  end

  protected
    def clear_buffer
      @buffer = "".force_encoding('BINARY')
    end

    def setup_storage
      @storage = Fog::Storage.new(
        provider: 'AWS',
        #region: Settings.s3_region,
        aws_access_key_id: ENV['S3_KEY'],
        aws_secret_access_key: ENV['S3_SECRET'],
        port: 80,
        scheme: "http"
      )

      @bucket = "pawdrop"
    end
end