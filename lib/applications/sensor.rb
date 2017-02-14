# This file contains a class to communicate with all the sensor classes

#require_relative 'app'

module Applications
    class Sensor < Application
        # get_response
        # Inputs: raw request
        # Outputs: response
        def get_response( request_in )
            # Change the value for the sensor in the database
            # Determine if alarm needs to be raised based on ALL
            #   # sensor status' in the database
            # Convert request to Hash format
            request = convert_json_to_hash( request_in )
            # Check validity of the request
            #TODO maybe there will be two types of requests, one where sensors are being set update
            #   # and another where sensor statuses are being updated
            if request_valid?( request )
                determine_sensor( request )
            else
                return [BAD_RESPONSE_CODE, 
                        {'Content-Type' => 'text/plain'},
                        ["The request sent did not have all of the required information\n"]
                       ]
            end
            Alarm.new( @db_client )
            return [GOOD_RESPONSE_CODE, 
                    {'Content-Type' => 'text/plain'},
                    ["GOOD\n"]
                   ]
        end # get_response
        
        private

        # determine_sensor
        # Sensor can send request for this reason:
        # Update sensor status in the database
        #   # Also, retrieve the battery level to update that in the system
        def determine_sensor( request )
            # Update database status of appropriate sensor
            sensor_mac = request["MAC"]
            sensor_status = request["status"]
            # Find the sensor in the database
            # Update the battery life, status, etc.
            query_database( "UPDATE #{SENSOR_STATUS} SET status='#{sensor_status}' WHERE mac='#{sensor_mac}'" )
        end # determine_sensor

        # request_valid?
        # Check the request for all of the necessary information
        def request_valid?( request )
            # Request must contain status update, mac address, sensor type
            # optional to have battery level for now
            required_keys = ["MAC", "status"]
            required_keys.each do |key|
                if !request.has_key?(key)
                    return false
                end
            end
            return true
        end # request_valid?

        # sensor_registered?
        # Check if the sensor's MAC address exists in the database
        #   # May have to do this if there is a possibility of a sensor
        #   # sending a signal to the app server that has not gone through
        #   # the setup process.
        def sensor_registered?( sensor_mac, sensor_type )
            # Returns true if sensor mac and type exist in the database
            # Check if it exists in the database
            #sensor_dump = query_database("SELECT sensor_type, sensor_mac FROM #{SENSOR_STATUS}")
        end # sensor_registered?

    end # Sensor
end
