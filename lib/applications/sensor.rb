# This file contains a class to communicate with all the sensor classes

require_relative 'app'

module Applications
    class Sensor < Application
        # get_response
        # Inputs: raw request
        # Outputs: response
        def get_response(request_in)
            # Change the value for the sensor in the database
            # Determine if alarm needs to be raised based on ALL
            #   # sensor status' in the database
            # Convert request to Hash format
            request = convert_json_to_hash( request_in )
            determine_sensor( request )
            Alarm.new
            [GOOD_RESPONSE_CODE, {'Content-Type' => 'text/plain'}, ["GOOD"]]
        end # get_response
        
        private 

        # determine_sensor
        def determine_sensor( request )
            # Update database status of appropriate sensor
            sensor_type = request["sensor"]
            sensor_status = request["status"]
            #TODO update database also with timestamp
            query_database( "UPDATE #{SENSOR_STATUS} SET status='#{sensor_status}' WHERE name='#{sensor_type}'" )
        end # determine_sensor

    end # Sensor
end
