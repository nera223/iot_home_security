require 'thin'
require_relative '../../applications'

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
                    run Applications::Alexa.new
                end
                map '/sensor' do
                    run Applications::Sensor.new
                end
                map '/camera' do
                    run Applications::Camera.new
                end
                map '/sensorcheck' do
                    run Applications::SensorCheck.new
                end
            end
        end
    
    end # ThinServer
end # Framework
