require 'spec_helper'
require 'rack/test'

describe Push::Transport::HttpLongPoll do
  include EM::Ventually
  
  before(:each) do
    Push.config.backend = :amqp
  end

  def app
    config = Push::Transport::Configuration.new
    config.timeout = 3
    Push::Transport::HttpLongPoll.new config
  end

  context "rack" do
    # include Rack::Test::Methods

    # it "should extract consumer_id from env" do
    #   get '/', {}, {'HTTP_CONSUMER_ID' => 10}
    #   last_request.env['push.consumer'].id.should eql(10)
    # end
  end

  context "streaming" do
    context "successful request" do
      it "should be a 200 status code" do
        Push::Backend::AMQP.connection.reconnect
        message, channel = 'hooowdy', '/thin/10'

        Push::Test.thin(app) do |server, http|
          http.get(channel, :headers => {'HTTP_CONSUMER_ID' => 'brad'}) {|resp|
            @response_status = resp.response_header.status
          }
        end
        EM.add_timer(1){
          Push::Backend::AMQP.new.publish(message, channel)
        }

        ly(200){ @response_status }
      end

      it "should have message body" do
        Push::Backend::AMQP.connection.reconnect
        message, channel = 'duuuude', '/thin/11'

        Push::Test.thin(app) do |server, http|
          http.get(channel, :headers => {'HTTP_CONSUMER_ID' => 'brad'}) {|resp|
            @message = resp.response
          }
        end
        EM.add_timer(1){
          Push::Backend::AMQP.new.publish(message, channel)
        }

        ly(message){ @message }
      end
    end

    it "should timeout and return a 204" do
      Push::Backend::AMQP.connection.reconnect
      
      Push::Test.thin(app) do |server, http|
        http.get('/never/ending/stream', :headers => {'HTTP_CONSUMER_ID' => 'brad'}) {|resp|
          @response_status = resp.response_header.status
        }
      end
      Push::Backend::AMQP.new.publish('message', '/never/never/land')

      ly(204){ @response_status }
    end
  end
end