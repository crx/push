module Push
  module Transport
    autoload :HttpLongPoll, 'push/transport/http_long_poll'

    # This is a workaround for a bug in booting this websocket lib with
    # that I documented at https://github.com/imanel/websocket-rack/issues/5
    # In an ideal world, this would also be an autoload entry
    # autoload :WebSocket, 'push/transport/web_socket'
    require 'push/transport/web_socket'

    # Figure out which transport transport we're going to use to service the request.
    class Dispatcher
      def initialize(&block)
        block.call(config) if block
      end
      
      def call(env)
        p env
        handler_method = websocket_request?(env) ?
          :web_socket_handler : :http_long_poll_handler
        self.send(handler_method).call env
      end

      # Create an instance of a HTTP Long Poll Rack app and memoize.
      def http_long_poll_handler
        @http_long_poll_handler ||= HttpLongPoll.new config
      end

      # Create an instance of a WebSocket Rack app and memoize.
      def web_socket_handler
        @web_socket_handler ||= WebSocket.new config
      end

      # Configuration object for transports
      def config
        @config ||= Configuration.new
      end
      alias :configuration :config
      
    private
      def websocket_request?(env)
        env['HTTP_UPGRADE'] =~ /websocket/i
      end
    end
    
    class Configuration
      # Setup a timeout value that we'll use to gracefully end streams with
      # a status code that can communicate to our client to gracefully reconnect
      Timeout = 30

      # Default proc for extracting the channel name out of the rack environment.
      Channel = Proc.new {|env| env['PATH_INFO'] }

      # Default proc for extracting the consumer out of the rack environment.
      Consumer = Proc.new {|env| Push::Consumer.new env['HTTP_CONSUMER_ID'] }
      
      def verbose_logging=(val)
        @verbose_logging = !!val
      end
      
      def verbose_logging
        @verbose_logging || false
      end
      
      def timeout=(val)
        @timeout = val
      end
      
      def timeout
        @timeout || Timeout
      end
      
      def consumer=(block)
        @consumer = block
      end
      
      def consumer env
        (@consumer || Consumer).call env
      end
      
      def channel=(block)
        @channel = block
      end
      
      def channel env
        (@channel || Channel).call env
      end
    end
    
  end
end