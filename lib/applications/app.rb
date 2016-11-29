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

        private

        def get_response( foo )
            raise NotImplementedError
        end
    end
end
