require 'rubygems'
require 'bundler'
Bundler.require

$:<< './'
require 'lib/glue'
require 'lib/upload_info'

class Receive < Goliath::API
  use Goliath::Rack::Validation::RequestMethod, %w(POST PUT)

  def on_headers(env, headers)
    id = headers["uploadid"]

    unless id.nil?
      info = UploadInfo.new(id)
      env['uploadinfo'] = info

      # fetch upload model
      # initiate multipart

      env.logger.info 'initiate upload: ' + id
    end
  end

  def on_body(env, data)
    unless env['uploadinfo'].nil?
      #env.logger.info 'received data: ' + data.size.to_s

      # buffer up 5 mbs worth -> upload part
      # buffer up 100 kbs worth -> process metadata
    end
  end  

  def response(env)
    env.logger.info 'response'

    unless env['uploadinfo'].nil?
      keepalive = EM.add_periodic_timer(1) do
        env.stream_send("Heartbeat.\n")
        env.logger.info "heartbeat sent"

        keepalive.cancel
        env.stream_send("End of stream.")
        env.stream_close

        env.logger.info env['uploadinfo'].id

        # keep checking if all parts are uploaded -> complete multipart -> save metadata
      end

      [200, {}, Goliath::Response::STREAMING]
    else
      [422, {}, {error: "invalid upload"}]
    end    
  end

  def on_close(env)
    env.logger.info 'closing connection'
  end
end