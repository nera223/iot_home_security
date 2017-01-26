module Framework
	class AbstractServer
		attr_reader :stopping, :running
		
        # Allow clean interrupt
		def initialize(&block)
			@stopping = false
			@running = false
			shutdown_on_interrupt
			yield(configuration) if block_given?
		end

        # Pass optional hash for configuration options
		def configuration
			@configuration ||= {}
		end

        # Start the http server
		def start
			@running = true
			start_server
			
			@running = false
			@stopping = false
		end

        # Put the http server in background (daemon) state
        # # Still puts request information in log file
        def daemonize
            daemonize_server
        end

        # Stop the http server
		def stop
			@stopping = true
			stop_server
		end

        # Log function is used to write to the log file
		def log(message, level=:info)
			fail NotImplementedError
		end

		private

        def daemonize_server
            fail NotImplementedError
        end

		def start_server
			fail NotImplementedError
		end

		def stop_server
			fail NotImplementedError
		end

		def shutdown_on_interrupt
			trap('SIGINT') { shutdown unless @stopping if @running }
		end

		def shutdown
			print "\r"
			log('Shutdown signal received!')
			stop
		end

	end # AbstractServer
end # Framework
