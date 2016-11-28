require 'thin'
require_relative '../../applications/alexa'

module Framework
	class ThinServer < Framework::AbstractServer
		def log(message, level=:info)
            case level
                when :info
                    http_server.logger.public_send(log_info, message)
                when :debug
                    http_server.logger.public_send(log_debug, message)
                when :error
                    http_server.logger.public_send(log_error, message)
            end
		end

		private

		def start_server
			http_server.start
		end

        def daemonize_server
            http_server.log_file = "/tmp/log/thin.log"
            http_server.pid_file = "/tmp/pids/thin.pid"
            http_server.daemonize
        end

		def stop_server
			http_server.stop
			@http_server = nil
		end
	
		def http_server
			@http_server ||= Thin::Server.new(configuration) do
                # Block for Server here
                use Rack::CommonLogger
                map '/alexa' do
                    run Alexa.new
                end
                #map '/' do
                #    run Alexa.new
                #end
            end
		end
	
	end # WEBrickServer
end # Framework
