# This file contains a class to communicate with all the sensor classes

require_relative 'app'

module Applications
    class Sensor < Application
        # get_response
        # Inputs: raw request
        # Outputs: response
        def get_response(request_in)
            [GOOD_RESPONSE_CODE, {'Content-Type' => 'text/plain'}, ["GOOD"]]
        end # get_response
        
        private 

    end # Sensor
end
