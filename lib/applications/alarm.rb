# This file contains a class used to determine whether to raise an alarm

module Applications
    # This script will control the alarm service
    SOUND_CONTROL_FILE = File.join( File.expand_path( File.dirname(__FILE__) ), 'sound_files', 'sound_control.rb' )
    
    class Alarm
        def initialize( db_client, send_help=false )
            # Sending db_client across classes
            @db_client = db_client
            determine_alarm( send_help )
        end

        private
        
        # determine_alarm
        def determine_alarm( send_help )
            alarm_sensors = []
            # This ensures a ONE-TIME alarm start
            if send_help
                alarm_sensors = ["alexa"]
            else
                # Long way to determine alarm
                # Get the status of all sensors from the database
                # Get the function of all sensors from the database
                # Logic to determine if alarm should be on or not
                current_sensor_status = get_sensor_statuses
                current_sensor_status.each do |sensor|
                    #TODO need to add proximity code here
                    # IF Sensor is ENABLED AND Sensor is NOT 0 AND Sensor is not in a dismissed state
                    if sensor["enabled"] == 1 && sensor["status"] != 0 && sensor["dismiss"] == 0
                        alarm_sensors << sensor["type"]
                    end
                end
            end
            if alarm_sensors.empty?
                turn_off_speaker
            else
                turn_on_speaker
                #TODO Send this only once
                Notification.new( @db_client, alarm_sensors )
            end
            
        end # determine_alarm

        # get_sensor_statuses
        def get_sensor_statuses
            response = @db_client.query( "SELECT name,status,enabled,type,dismiss FROM #{SENSOR_STATUS}" )
            return response.entries
        end # get_sensor_statuses
        
        # turn_off_speaker
        def turn_off_speaker
            puts "SPEAKER OFF"
            # The daemons gem will handle the stopping of the 
            #   # audio file playing process
            `#{SOUND_CONTROL_FILE} stop`
        end # turn_off_speaker
        
        # turn_on_speaker
        def turn_on_speaker
            puts "SPEAKER ON"
            # The daemons gem will handle the starting of the 
            #   # audio file playing process
            # Call the ruby script
            #TODO If already running, the script returns an error internally,
            #   # you should clean this up!
            `#{SOUND_CONTROL_FILE} start`
        end # turn_on_speaker
    end # class Alarm
end # module Applications
