# This file contains a class used to determine whether to raise an alarm

class Alarm
    
    def initialize( immediate=false )
        determine_alarm( immediate )
    end

    private
    
    # determine_alarm
    def determine_alarm( immediate )
        if immediate
            turn_on_speaker
        else
            # Long way to determine alarm
            # Get the status of all sensors from the database
            # Get the function of all sensors from the database
            # Logic to determine if alarm should be on or not
        end
    end # determine_alarm

    # turn_on_speaker
    def turn_on_speaker
        puts "SPEAKER ON"
    end # turn_on_speaker
end # class Alarm
