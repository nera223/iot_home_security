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
            # Check validity of the request
            if request_valid?( request )
                determine_sensor( request )
            else
                return [BAD_RESPONSE_CODE, {'Content-Type' => 'text/plain'}, ["The request sent did not have all of the required information"]]
            end
            #Alarm.new
            return [GOOD_RESPONSE_CODE, {'Content-Type' => 'text/plain'}, ["GOOD"]]
        end # get_response
        
        private 

        # determine_sensor
        # Sensor can send request for this reason:
        # Update sensor status in the database
        #   Also, retrieve the battery level to update that in the system
        def determine_sensor( request )
            # Update database status of appropriate sensor
            sensor_type = request["sensor_type"]
            sensor_mac = request["sensor_mac"]
            sensor_status = request["status"]
            #TODO update database also with timestamp
            # Find the sensor in the database
            if sensor_registered?( sensor_type, sensor_mac )
                # Update the battery life, status, etc
            end
            query_database( "UPDATE #{SENSOR_STATUS} SET status='#{sensor_status}' WHERE name='#{sensor_type}'" )
        end # determine_sensor

        # request_valid?
        # Check the request for all of the necessary information
        def request_valid?( request )
            # Request must contain status update, mac address, sensor type
            # optional to have battery level for now
            required_keys = ["sensor_type", "sensor_mac", "status"]
            required_keys.each do |key|
                if !request.has_key?(key)
                    return false
                end
            end
            return true
        end # request_valid?

        # sensor_registered?
        def sensor_registered?( sensor_mac, sensor_type )
            # Returns true if sensor mac and type exist in the database
            # Check if it exists in the database
            sensor_dump = query_database("SELECT sensor_type, sensor_mac FROM #{SENSOR_STATUS}")
        end # sensor_registered?

    end # Sensor
end
