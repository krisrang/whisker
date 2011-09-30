require 'rubygems'
require 'bundler'
Bundler.require

class Receive < Goliath::API
  #def on_headers(env, headers)
  #  env.logger.info 'received headers: ' + headers.inspect
  #  env['async-headers'] = headers
  #end

  def on_body(env, data)
    env.logger.info 'received data: ' + data.size.to_s
    sleep(2)
    #(env['async-body'] ||= '') << data
  end  

  def response(env)
    env.logger.info 'response'

    # This timer keeps the connection alive later in the stream when
    # the number generation slows down sufficiently for > 30s response time.
    # Yes, the timer is something like 55s but I like 30s, okay? ;)
    keepalive = EM.add_periodic_timer(29) do
      env.stream_send("Heartbeat.\n")
      env.logger.info "heartbeat sent"

      keepalive.cancel
      env.stream_send("End of stream.")
      env.stream_close
    end
    
    # The below cuts off the connection at some point if this is desired.
    # EM.add_timer(30) do
    #   keepalive.cancel
    #   
    #   env.stream_send("End of stream.")
    #   env.stream_close
    # end
    #env.stream_close

    [200, {}, Goliath::Response::STREAMING]
    #[200, {}, {body: env['async-body'].size.to_s, head: env['async-headers']}]
  end

  def on_close(env)
    env.logger.info 'closing connection'
  end
end