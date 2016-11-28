# This class will be the parent class for subclasses
require 'json'

class Application
    def call(request_in)
        # Log the request in the database
        # Send request to subclass
        response_out = get_response(request_in)
        return response_out
    end

    private

    def get_response(arg)
        fail NotImplementedError
    end
end
