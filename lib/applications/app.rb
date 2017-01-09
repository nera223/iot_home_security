# This class will be the parent class for subclasses
require 'json'

module Applications
    class Application
        # The response codes must be sent as part of the response
        GOOD_RESPONSE_CODE  = 200
        BAD_RESPONSE_CODE   = 404
        
        # call()
        # Inputs:
        #   [+request_in+ (CLASS)] = raw request to the app server
        # Outputs:
        #   (Array) = The response code, content type, and response body
        #NOTE DO NOT CHANGE THE NAME OF THIS FUNCTION
        def call(request_in)
            # Establish a connection with the database
            #   # creates instance variable @db_client that can be used throughout the
            #   # class to query the database
            establish_database_connection
            # Log the request in the database
            # Send request to subclass
            response_out = get_response(request_in)
            # Close the database connection
            close_database_connection
            # Return response to the application server
            return response_out
        end
        
        # These methods will be available to all classes ===========================
        # convert_json_to_hash
        def convert_json_to_hash( json )
            JSON.parse( json["rack.input"].read )
        end # convert_json_to_hash

        # convert_hash_to_json
        # Returns a JSON string
        def convert_hash_to_json( hash )
            JSON.generate( hash )
        end

        # query_database
        # This method is a wrapper to run a query on a database
        def query_database( q )
            begin
                response = @db_client.query( q )
                # Handle invalid mysql queries here
            rescue => error
                puts "There was an error querying the database"
            end
            return response
        end # query_database
        
        #===========================================================================

        private

        def establish_database_connection
            begin
                @db_client = Database.new.connect
            rescue => error
                puts "There was an error establishing a connection with the My S Q L server"
            end
        end # establish_database_connection

        def close_database_connection
            @db_client.close if @db_client.respond_to?(:close, true)
        end # close_database_connection

        def get_response( foo )
            raise NotImplementedError
        end
    end
end
