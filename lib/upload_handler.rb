# main class handling uploads
class UploadHandler
  attr_accessor :error

  # set up initial values for the request
  def initialize(id, expected)
    @error = nil

    @expected = expected.to_i
    @received = 0

    @chunklimit = 5*1024*1024 # split files bigger than 5MB into a multipart upload

    @multipart = @expected > @chunklimit

    clear_buffer
    @upload = Upload.find id
    @uploader = @multipart ? MultipartUpload.new(@upload) : SmallUpload.new(@upload)
  end

  def initiate
    @uploader.initiate
  end

  # queue received data in the buffer and check if it's time to flush
  def queue(env, data)
    if @error.nil?
      data.force_encoding('BINARY')

      @received = @received + data.bytesize
      if @received > @expected
        @error = "Invalid Content-Length value"
        clear_buffer
      end

      @buffer << data
      flush_buffer if @buffer.bytesize > @chunklimit # if multipart
    end
  end

  # last bits received, flush remaining bits and cleanup
  def complete(ticker, env)
    if @error.nil?
      flush_buffer if @buffer.bytesize > 0 # last part or non-multipart
      cleanup(ticker, env) if @uploader.complete?
    end
  end

  # flush received buffer to S3
   def flush_buffer
    data = @buffer.clone
    clear_buffer
    @uploader.queue(data)    
  end

  def abort
    @uploader.abort if !!@uploader
  end

  # clear buffer, close connections, finalize model
  def cleanup(ticker,env)
    ticker.cancel
    clear_buffer

    @upload.complete(@received).save
    
    env.chunked_stream_close
    env.logger.info 'received: ' + @received.to_s
    env.logger.info 'completed upload: ' + @upload.id.to_s
  end 

  def exist?
    !!@upload
  end

  protected
    def clear_buffer
      @buffer = "".force_encoding('BINARY')
    end
end