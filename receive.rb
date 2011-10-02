require 'rubygems'
require 'bundler'
Bundler.require

$:<< 'lib'

require 'em-synchrony/em-http'
require 'base_upload'
require 'small_upload'
require 'multipart_upload'
require 'upload'
require 'upload_handler'

class Receive < Goliath::API
  include Goliath::Validation
  use Goliath::Rack::Validation::RequestMethod, %w(POST PUT OPTIONS)

  def on_headers(env, headers)
    id = headers["Uploadid"]

    return if id.nil?

    begin
      handler = UploadHandler.new(id, headers["Content-Length"])
      handler.initiate

      env['uploadhandler'] = handler
      env.logger.info 'initiated upload: ' + id
    rescue Exception => e
      env['uploadhandler'] = nil
      env.logger.info 'error: ' + e.inspect
    end
  end

  def on_body(env, data)
    begin
      env['uploadhandler'].queue(env,data) if !!env['uploadhandler']
    rescue Exception => e
      env['uploadhandler'] = nil
      env.logger.info 'error: ' + e.inspect
    end
  end  

  def response(env)
    env.logger.info 'response'

    if env["REQUEST_METHOD"] == "OPTIONS"
      return [200, cors_headers, {}]
    end

    handler = env['uploadhandler']

    if handler.nil? || !handler.exist?
      invalid_upload_error
    elsif !!handler.error
      invalid_upload_error handler.error
    else
      begin
        keepalive = EM.add_periodic_timer(2) do
          env.chunked_stream_send("processing\n")
          handler.complete keepalive, env   
        end

        timeout = EM.add_timer(600) do # 10 minute timeout
          keepalive.cancel
          handler.abort
          env['uploadhandler'] = nil
          env.chunked_stream_close
        end

        chunked_streaming_response 200, cors_headers
      rescue Exception => e
        timeout.cancel if !!timeout
        keepalive.cancel if !!keepalive
        env['uploadhandler'] = nil
        env.chunked_stream_close
        env.logger.info 'error: ' + e.inspect
      end
    end    
  end

  def on_close(env)
    env['uploadhandler'].abort if !!env['uploadhandler']
    env.logger.info 'closing connection'
  end

  def cors_headers
    {
      "Access-Control-Allow-Origin" => "*",
      "Access-Control-Allow-Methods" => "POST,PUT",
      "Access-Control-Allow-Headers" => "Origin,Content-Type,Uploadid"
    }
  end

  def invalid_upload_error(error = "Invalid upload")
    raise Goliath::Validation::BadRequestError.new error
  end
end