# This file contains a class that will handle the period request sent
# in order to check that the sensors in the database are still alive

module Applications
    class SensorCheck < Application
        # Constant to set the time of the "alive" ping from sensor to hub
        SENSOR_PING_TIME = 15 # minutes
        # get_response
        # Inputs: raw request
        # Outputs: response
        def get_response( request_in )
            # Nothing to do with the request for now,
            #   # just check the sensor table
            dead_sensors = get_disconnected_sensors
            alert_user( dead_sensors ) if !dead_sensors.empty?
            return [GOOD_RESPONSE_CODE, {'Content-Type' => 'text/plain'}, ["Dead Sensors: #{dead_sensors.join(", ")}\n"]]
        end # get_response
        
        private
        
        # get_disconnected_sensors
        # Return a list of sensor id's that are no longer communicating to the hub
        def get_disconnected_sensors
            sensors = query_database( "SELECT id FROM #{SENSOR_STATUS} WHERE (TIMESTAMPDIFF(MINUTE, updated_time, NOW()) > #{SENSOR_PING_TIME+1})" )
            # Only return the id field
            return sensors.entries.map{|m| m["id"]}
        end
        # get_disconnected_sensors

        # alert_user
        def alert_user( sensor_ids )
            # Update database verbose column with "disconnected" description
                sensor_ids.each do |id|
                    query_database( "UPDATE #{SENSOR_STATUS} SET verbose='disconnected', status=1, enabled=1, dismiss=0 WHERE id=#{id}" )
                end
            # Call Alarm class
                Alarm.new( @db_client, false, true )
        end # alert_user

    end # SensorCheck
end
