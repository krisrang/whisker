require 'rubygems'
require 'bundler'
Bundler.require

require 'upload_info'

class Receive < Goliath::API
  def on_headers(env, headers)
    env.logger.info 'received headers: ' + headers.inspect
    #env['async-headers'] = headers

    #id = headers[:]

    # fetch upload model
    # initiate multipart
  end

  def on_body(env, data)
    env.logger.info 'received data: ' + data.size.to_s
    #(env['async-body'] ||= '') << data

    # buffer up 5 mbs worth -> upload part
    # buffer up 100 kbs worth -> process metadata
  end  

  def response(env)
    env.logger.info 'response'

    keepalive = EM.add_periodic_timer(1) do
      env.stream_send("Heartbeat.\n")
      env.logger.info "heartbeat sent"

      keepalive.cancel
      env.stream_send("End of stream.")
      env.stream_close

      # keep checking if all parts are uploaded -> complete multipart -> save metadata
    end

    [200, {}, Goliath::Response::STREAMING]
  end

  def on_close(env)
    env.logger.info 'closing connection'
  end
end