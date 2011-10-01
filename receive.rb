require 'rubygems'
require 'bundler'
Bundler.require

$:<< 'lib'

require 'upload'
require 'upload_handler'

class Receive < Goliath::API
  use ::Rack::Reloader, 0 if Goliath.dev?
  use Goliath::Rack::Validation::RequestMethod, %w(POST PUT OPTIONS)

  def on_headers(env, headers)
    id = headers["Uploadid"]

    unless id.nil?
      begin
        handler = UploadHandler.new(id)
        handler.expected = headers["Content-Length"]
        handler.initiate

        env['uploadhandler'] = handler
        env.logger.info 'initiated upload: ' + id
      rescue
        env.logger.info 'invalid upload, skip'
      end
    end
  end

  def on_body(env, data)
    env['uploadhandler'].queue(env,data) unless env['uploadhandler'].nil?
  end  

  def response(env)
    env.logger.info 'response'

    if env["REQUEST_METHOD"] == "OPTIONS"
      return [200, cors_headers, {}]
    end

    handler = env['uploadhandler']

    if handler.nil? || !handler.exist?
      error_response "invalid upload"
    elsif !handler.error.nil?
      error_response handler.error
    else
      keepalive = EM.add_periodic_timer(1) do
        env.stream_send("\0")
        handler.complete keepalive, env

        env.logger.info 'completed upload: ' + handler.id.to_s
        env['uploadhandler'] = handler = nil        
      end

      [200, cors_headers, Goliath::Response::STREAMING]
    end    
  end

  def on_close(env)
    env.logger.info 'closing connection'
  end

  def cors_headers
    {
      "Access-Control-Allow-Origin" => "*",
      "Access-Control-Allow-Methods" => "POST,PUT",
      "Access-Control-Allow-Headers" => "Origin,Content-Type,Uploadid"
    }
  end

  def error_response(error)
    [422, cors_headers, {error: error}]
  end
end