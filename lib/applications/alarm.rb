# This file contains a class used to determine whether to raise an alarm

module Applications
    class Alarm
        def initialize( db_client, immediate=false )
            # Sending db_client across classes
            @db_client = db_client
            determine_alarm( immediate )            
        end

        private
        
        # determine_alarm
        def determine_alarm( immediate )
            raise_alarm = false
            if immediate
                raise_alarm = true
            else
                # Long way to determine alarm
                # Get the status of all sensors from the database
                # Get the function of all sensors from the database
                # Logic to determine if alarm should be on or not
                current_sensor_status = get_sensor_statuses
                current_sensor_status.each do |sensor|
                    #NOTE this is a simplified version of the code for now
                    if sensor["enabled"] == 1 && sensor["status"] == 1
                        raise_alarm = true
                    end
                end
            end
            turn_on_speaker if raise_alarm
        end # determine_alarm

        # get_sensor_statuses
        def get_sensor_statuses
            response = @db_client.query( "SELECT name,status,enabled,type FROM #{SENSOR_STATUS}" )
            return response.entries
        end # get_sensor_statuses
        
        # turn_on_speaker
        def turn_on_speaker
            #TODO actually play sound on the speaker
            puts "SPEAKER ON"
            # The daemons gem will handle the starting and stopping of the 
            #   # audio file playing process
            # Call the ruby script
            sound_control_file = File.join( File.expand_path( File.dirname(__FILE__) ), 'sound_files', 'sound_control.rb' )
            #exec("#{sound_control_file} start")
        end # turn_on_speaker
    end # class Alarm
end # module Applications
