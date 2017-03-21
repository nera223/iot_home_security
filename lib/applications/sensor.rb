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
            # The MAC address should be uppercase!
            sensor_mac      = request["mac"].upcase
            sensor_status   = request["status"]
            sensor_battery  = request["battery"] # in mV for now but must be a percentage later on
            sensor_type     = request["type"]
            if sensor_exists?( sensor_mac )
                # Find the sensor in the database
                # Update the battery life, status, etc.
                # If the sensor is showing a status greater than 1, update the database. Do not 
                # update if sensor status is 0 because this will just turn off the alarm
                if sensor_status > 0
                    query_database( "UPDATE #{SENSOR_STATUS} SET status=#{sensor_status},battery=#{sensor_battery} WHERE mac='#{sensor_mac}'" )
                elsif safe_to_reset_sensor?( sensor_mac )
                    # Only set sensor status back to 0 if the dismiss flag is on or the sensor has been disabled
                    query_database( "UPDATE #{SENSOR_STATUS} SET status=#{sensor_status},dismiss=0" )
                end
            else
                # add the sensor to the database
                query_database( "INSERT INTO #{SENSOR_STATUS} (name, status, enabled, mac, type, battery) VALUES ('#{sensor_type}','#{sensor_status}',1,'#{sensor_mac}','#{sensor_type}',#{sensor_battery})")
            end
        end # determine_sensor

        # safe_to_reset_sensor?
        def safe_to_reset_sensor?( mac )
            status = query_database( "SELECT enabled,dismiss FROM #{SENSOR_STATUS} WHERE mac='#{mac}'" ).entries.first
            status["enabled"] == 0 || status["dismiss"] == 1
        end # safe_to_reset_sensor?
        
        # sensor_exists?
        def sensor_exists?( mac )
            all_rows = query_database( "SELECT mac FROM #{SENSOR_STATUS}").entries
            all_rows.map{|entry| entry["mac"]}.member?( mac.upcase )
        end # sensor_exists?

        # request_valid?
        # Check the request for all of the necessary information
        def request_valid?( request )
            # Request must contain status update, mac address, sensor type
            #TODO ONLY WORKS FOR DOOR SENSOR RIGHT NOW
            required_keys = ["mac", "status", "battery", "type"]
            required_keys.each do |key|
                if !request.has_key?(key)
                    return false
                end
            end
            return true
        end # request_valid?

    end # Sensor
end
