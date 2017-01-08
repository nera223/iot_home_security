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
        def call(request_in)
            # Log the request in the database
            # Send request to subclass
            response_out = get_response(request_in)
            return response_out
        end
        
        # These methods will be available to all classes
        # convert_json_to_hash
        def convert_json_to_hash( json )
            JSON.parse( json["rack.input"].read )
        end # convert_json_to_hash

        # convert_hash_to_json
        # Returns a JSON string
        def convert_hash_to_json( hash )
            JSON.generate( hash )
        end

        # update_database
        # This method is a wrapper to run a query on a database
        def update_database( q )
            begin
                client = Database.new.connect
                client.query( q )
                # Handle invalid mysql requests here
            rescue => error
                build_response("There was an error communicating with the MySQL service")
            ensure
               client.close
            end
        end # update_database
        
        #===========================================================================

        private

        def get_response( foo )
            raise NotImplementedError
        end
    end
end
