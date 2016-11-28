# This file contains the Alexa class to respond to Amazon Web Services HTTPS requests sent through the user's Amazon Echo device
require_relative 'app'

class Alexa < Application
    # The class only must respond to get_response()
    def get_response(request_in)
        [200, {'Content-Type' => 'text/plain'}, ["Hello THERE"]]
    end
end # Alexa
