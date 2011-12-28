# uploads files bigger than the chunk limit in multiple parts using the S3 multipart API
class MultipartUpload < BaseUpload
  def initiate
    @chunks = 0
    @uploaded = 0
    @assembled = false
    @uploadid = nil
    @etags = {}

    @complete = false
  end
    
  def queue(buffer)
    if @chunks == 0
      # parse file metadata
      resp = @storage.initiate_multipart_upload(@bucket, @upload.key, @upload.headers)
      @uploadid = resp.body["UploadId"]
    end

    data = parse_data(buffer)
    headers = {}
    headers['Content-Length'] = data[:headers]['Content-Length']
    response = request({
      :body       => data[:body],
      :expects    => 200,
      :headers    => headers,
      :host       => "#{@bucket}.#{@host}",
      :method     => 'PUT',
      :path       => CGI.escape(@upload.key),
      :query      => {'uploadId' => @uploadid, 'partNumber' => @chunks+1}
    })    

    response.errback do
      @complete = true
      @storage.abort_multipart_upload(@bucket, @upload.key, @uploadid)
    end

    response.callback do
      etag = response.response_header["ETAG"]
      part = response.req.query["partNumber"]
      @etags[part] = etag
      @uploaded += 1
    end

    @chunks += 1
  end

  def complete?
    # try completing file
    if @chunks == @uploaded
      parts = @etags.sort{ |a,b| a[0] <=> b[0] }.map { |a| a[1] }
      resp = @storage.complete_multipart_upload(@bucket, @upload.key, @uploadid, parts)
      @storage.abort_multipart_upload(@bucket, @upload.key, @uploadid) if resp.status != 200
      @complete = true
    end

    @complete
  end
end