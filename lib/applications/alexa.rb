# This file contains the Alexa class to respond to Amazon Web Services HTTPS requests sent through the user's Amazon Echo device
# Sample response looks like: [200, {'Content-Type' => 'text/plain'}, ["Message"]]

require_relative 'app'

module Applications
    class Alexa < Application
        # The class only must respond to get_response()
        def get_response(request_in)
            # The request will be JSON format
            type = determine_type( request_in )
            
        end # get_response
        
        def determine_type( request_in )
        end # determine_type
    end # Alexa
end
