# This file contains the Alexa class to respond to Amazon Web Services HTTPS requests sent through the user's Amazon Echo device
# Sample response looks like: [200, {'Content-Type' => 'text/plain'}, ["Message"]]

#require 'json'
#require_relative 'app'

module Applications
    # This constant defines the maximum number of password attempts allowed by the user to turn
    #   # off the alarm
    MAXIMUM_PASSWORD_ATTEMPTS = 3
    
    class Alexa < Application
        # get_response
        # Inputs: raw request
        # Outputs: response
        def get_response(request_in)
            # The request will be JSON format
            @request = convert_json_to_hash(request_in)
            type = determine_type
            case type
            when "LaunchRequest"
                response = respond_to_launch
            when "IntentRequest"
                response = respond_to_intent
            end
            # Make this into a nicer function
            [GOOD_RESPONSE_CODE, {'Content-Type' => 'application/json;charset=UTF-8'}, [convert_hash_to_json( response )]]
        end # get_response
        
        private 

        ######## Working with JSON Alexa Request
        #===========================================================================

        # determine_type
        def determine_type
            @request["request"]["type"]
        end # determine_type

        # build_response
        # By default, do not need to specify session attributes or shouldEndSession
        def build_response(spoken_text, sessionAttributes={}, end_session=true)
            #TODO write to database
            version = "1.0"
            response = {
                :version => version,
                :sessionAttributes => sessionAttributes,
                :response => {
                    :outputSpeech => {
                        :type => "PlainText",
                        :text => spoken_text
                    },
                    :shouldEndSession => end_session
                }
            }
            return response
        end # build_response

        #===========================================================================

        # respond_to_launch
        def respond_to_launch
            # Determine if the emergency contact has already been set up
            emergency_contact_available = !get_emergency_contact.empty?
            if emergency_contact_available
                # Respond with welcome message
                message = "Welcome to your Securitech I O T Home Security System."\
                " It appears you have already set up an emergency contact."\
                " You can tell me commands such as."\
                " Ask Securitech to add an emergency contact."\
                " Ask Securitech to disable the alarm. Or."\
                " Tell Securitech to enable the window sensor"
            else
                # Notify user to set up emergency contact
                message = "Welcome to your Securitech I O T Home Security system."\
                " It appears that you currently have no emergency contact information available."\
                " I recommend you add an emergency contact as soon as possible."\
                " To add an emergency contact, say. Tell Securitech to manage my emergency contacts."\
            end
            build_response( message )
        end # respond_to_launch
        
        # respond_to_intent
        def respond_to_intent
            # For now, just identify the type of intent and give a simple message
            # that acknowledges that request
            if @request["session"]["new"]
                intent = @request["request"]["intent"]["name"]
            else
                # Because of poor handling on Amazon's end, may need to
                #   # override intent based on session attribute
                intent = @request["session"]["attributes"]["intent"]
            end
            raise "intent not defined in code on live session!" if intent.nil?
            case intent
            when "DisableSystem"
                response = ask_password( "disable_system" )
            when "EnableSystem"
                response = enable_system
            when "DisableSensor"
                response = ask_password( "disable_sensor", true )
            when "DismissAlarm"
                response = ask_password( "dismiss" )
            when "EnableSensor"
                response = enable_sensor
            when "AskPassword"
                response = ask_password
            when "SendHelp"
                response = send_help
            when "EmergencyContact"
                response = manage_emergency_contact
            when "SetPassword"
                response = set_password
            when "LastEvent"
                response = last_event
            else
                response = build_response("You forgot to code this intent")
            end
            if response.nil?
                response = build_response("I did not understand your request")
            end
            return response
        end # respond_to_intent
        
		# ask_password
		# This function will be invoked when the user asks to turn off the alarm
		# 	# Must prompt for the password
		def ask_password( user_action=nil, sensor_set=false )
            if user_action.nil?
                user_action = @request["session"]["attributes"]["user_action"]
            end
            if sensor_set
                sensor_type = @request["request"]["intent"]["slots"]["Sensor"]["value"]
            elsif user_action == "disable_sensor"
                sensor_type = @request["session"]["attributes"]["sensor_type"]
            else
                sensor_type = "none"
            end
            is_new_session = @request["session"]["new"]
            if is_new_session
                # The user has just requested to turn off the alarm,
                #	# you must ask for the numeric password
                message = "What is the password?"
                return build_response(message,
                                      {"intent" => "AskPassword", "user_action" => user_action, "sensor_type" => sensor_type, "tries" => 1},
                                      false)
            else # the session is not new
                # Determine if the password given was correct
                correct_password = get_password_from_database
                if @request["request"]["intent"]["slots"]["number_sequence"]["value"] == correct_password
                    if @request["session"]["attributes"].has_key?( "original_intent" )
                        response = build_response( "Okay. What would you like your new numeric password to be?",
                                                   {"intent" => "SetPassword", "user_action" => user_action, "sensor_type" => sensor_type, "old_password" => correct_password, "confirm" => false},
                                                   false)
                    else
                        case user_action
                        when "dismiss" 
                            response = dismiss_alarm
                        when "disable_sensor"
                            response = disable_sensor( sensor_type )
                        when "disable_system"
                            response = disable_system
                        else
                            response = build_response( "Developer forgot to code this ask password user action" )
                        end
                    end
                    return response
                elsif (tries = @request["session"]["attributes"]["tries"].to_i) < MAXIMUM_PASSWORD_ATTEMPTS
                    # The pasword was not correct, so ask again until the number of tries has been exceeded
                    message = "The password was not correct. Try again."
                    return build_response(message,
                                   {"intent" => "AskPassword", "user_action" => user_action, "sensor_type" => sensor_type, "tries" => tries + 1},
                                   false)
                else
                    # You have run out of tries so you cannot turn off the alarm
                    message = "The maximum number of tries has been exceeded. I will notify the"\
                    " emergency contact."
                    #TODO notify emergency contact
                    return build_response(message)
                end
            end
		end # ask_password
        
        # set_password
        # This function will be called when the user wants to set the password
        #   # First, the current password must be given and then a new password can be set
        def set_password
            is_new_session = @request["session"]["new"]
            if is_new_session
                message = "To reset your password, you must first tell me the current password."
                build_response( message,
                                {"intent" => "AskPassword", "tries" => 1, "original_intent" => "SetPassword"},
                                false
                              )
            else
                new_password = @request["request"]["intent"]["slots"]["number_sequence"]["value"]
                if @request["session"]["attributes"]["confirm"]
                    # Check old password
                    if @request["session"]["attributes"]["new_password"] == new_password
                        query_database( "UPDATE #{ALEXA_INFORMATION} SET password=#{new_password}" )
                        build_response( "The password has been changed!" )
                    else
                        build_response( "The password confirmation was invalid. Restart the process to try again." )
                    end
                else
                    # Confirm the password once
                    build_response( "Please confirm the password",
                                {"intent" => "SetPassword", "new_password" => new_password, "confirm" => true},
                                false)
                end
            end
        end # set_password
        
        # last_event
        #   # This intent will handle getting information about the last logged event in the database
        def last_event
            # Default to saying that there has not been any event yet
            response = query_database( "SELECT * FROM #{SENSOR_STATUS} WHERE enabled=1 ORDER BY updated_time DESC LIMIT 1" ).entries.first
            message = "The system is disarmed or no sensor has had an event change"
            if !response.nil?
                sensor_type = response["type"]
                sensor_status = response["status"]
                case sensor_type
                when "window"
                    message = sensor_status == 0 ? "The window was just closed" : "The window was just opened"
                when "door"
                    message = sensor_status == 0 ? "The door was just closed" : "The door was just closed"
                when "smoke"
                    message = sensor_status == 0 ? "The smoke alarm just turned off" : "The smoke alarm just turned on"
                end
            end
            build_response( message )
        end # last_event
        
        # manage_emergency_contact
        # This function adds, removes, emergency contacts from the database
        #   # This will be an interactive function so the request input could
        #   # be a reply. Therefore the function has multiple return statements
        def manage_emergency_contact
            is_new_session = @request["session"]["new"]
            if is_new_session
                # Determine the action from the user
                #   # may be given in the request or may need to ask for it
                contact_action = @request["request"]["intent"]["slots"]["contact_action"]["value"]
                if contact_action != "manage"
                    call_emergency_contact_function( contact_action )
                else
                    # Ask the user exactly what they would like to do. Give the count of 
                    #   # the emergency contacts currently available to help the user out
                    emergency_contacts = get_emergency_contact
                    if emergency_contacts.empty?
                        message = "You currently have no emergency contacts stored,"\
                        " Would you like to add one now?"
                        # Do not end session. User can directly reply to this command
                        return build_response(message,
                               {"intent" => "EmergencyContact", "contact_action" => "add"},
                               false)
                    else
                        message = "You currently have #{emergency_contacts.count} contacts stored."\
                        " You can tell Securitech to add, change, or remove an emergency contact,"\
                        " or tell Securitech to read. out the current information"
                        return build_response(message)
                    end
                end
            else
                # determine if yes or no answer to question of whether user wants to perform an action now
                if !@request["session"]["attributes"]["continue"].nil? ||
                    @request["request"]["intent"]["slots"]["contact_response"]["value"] == "yes"
                        
                    # The contact action will be stored in a session attribute instead
                    contact_action = @request["session"]["attributes"]["contact_action"]
                    return call_emergency_contact_function( contact_action )
                else
                    return build_response("OK")
                end
            end
        end

        # call_emergency_contact_function
        def call_emergency_contact_function( action )
            # Get specific with the request
            case action
            when "add", "create", "insert"
                response = add_emergency_contact
            when "remove", "delete"
                response = remove_emergency_contact
            when "change", "edit"
                response = change_emergency_contact
            when "tell me", "read me"
                response = display_emergency_contact
            end
            return response
        end # call_emergency_contact_function
        
        # These methods shall use the "continue" attribute to arrive back here

        # add_emergency_contact
        def add_emergency_contact
            # Ask the user a series of questions corresponding to the fields for the database columns
            if @request["session"]["attributes"] && @request["session"]["attributes"]["continue"]
                # This is a response to a previous question
                case @request["session"]["attributes"]["continue"]
                when "add__full_name"
                    first, last = handle_full_name( @request["request"]["intent"]["slots"]["person_name"]["value"] )
                    query_database("INSERT INTO #{EMERGENCY_CONTACT} (first_name, last_name) VALUES ('#{first}', '#{last}')")
                    return build_response("OK, what is the phone number for #{first}?",
                            {"intent" => "EmergencyContact", "contact_action" => "add", "continue" => "add__phone", "first_name" => first, "last_name" => last},
                            false)
                when "add__phone"
                    phone_number = @request["request"]["intent"]["slots"]["number_sequence"]["value"]
                    #TODO code to check for valid phone number
                    first_name = @request["session"]["attributes"]["first_name"]
                    last_name = @request["session"]["attributes"]["last_name"]
                    query_database( "UPDATE #{EMERGENCY_CONTACT} SET phone_number='#{phone_number}' WHERE (first_name='#{first_name}') AND (last_name='#{last_name}')" )
                    message = "Got it. In order to receive E mail messages please log on to the web interface and add your E mail address"
                    return build_response(message)
                end
            else
                # First time request
                message = "To start off, tell me the first and last name"\
                " of the contact you would like to add."
                # Must return the right sessin attributes so that the request ends back in this method
                return build_response( message,
                        {"intent" => "EmergencyContact", "contact_action" => "add", "continue" => "add__full_name"},
                        false )
            end
            build_response("Adding")
        end # add_emergency_contact

        # handle_full_name
        def handle_full_name( full_name )
            #TODO ask for last name if only given first name?
            split_name = full_name.split(" ").map{ |m| m.capitalize }
            first = split_name.first
            last = split_name.size > 1 ? split_name.last : nil
            return [first,last]
        end # handle_full_name

        def remove_emergency_contact
            current_contacts = get_emergency_contact
            if @request["session"]["attributes"] && @request["session"]["attributes"]["continue"]
                case @request["session"]["attributes"]["continue"]
                when "remove__name"
                    # try to match name, else respond with error message
                    name = @request["request"]["intent"]["slots"]["person_name"]["value"]
                    first, last = handle_full_name( name )
                    removed_contact = []
                    if last.nil?
                        # can only compare with the first name
                        removed_contact = current_contacts.map{ |m| m["first_name"].downcase == first.downcase ? m["first_name"] : nil }.compact
                    else
                        # compare both the first and last name
                        removed_contact = current_contacts.map{ |m| m["first_name"].downcase == first.downcase && m["last_name"].downcase == last.downcase ? m["first_name"] : nil }.compact
                    end
                    if removed_contact.empty?
                        # Return error message
                        message = "I did not find any contact named #{first} #{last}."\
                        " Please try again."
                        return build_message( message )
                    else
                        # Remove the contact(s) from the database
                        removed_contact.each do |contact|
                            if last.nil?
                                query_database( "DELETE FROM #{EMERGENCY_CONTACT} WHERE first_name='#{first}'" )
                            else
                                query_database( "DELETE FROM #{EMERGENCY_CONTACT} WHERE (first_name='#{first}') AND (last_name='#{last}')" )
                            end
                        end
                    end
                    return build_response("Successfully removed #{first} from the data base.")
                end
            else
                # First time request
                if current_contacts.empty?
                    message = "You currently have no emergency contacts stored."
                    return build_response( message )
                else
                    contact_string = current_contacts.map{ |m| "#{m["first_name"]} #{m["last_name"]}"}.join(", ")
                    message = "You have #{current_contacts.count} contacts stored. These are #{contact_string}. Please say the full name of the contact you would like to remove?"
                    return build_response( message,
                            {"intent" => "EmergencyContact", "contact_action" => "remove", "continue" => "remove__name"},
                            false)
                end
            end
        end # remove_emergency_contact

        def change_emergency_contact
            build_response("Changing. This code has not been implemented")
        end # change_emergency_contact

        def display_emergency_contact
            build_response("Displaying. This code has not been implemented")
        end # display_emergency_contact
        
        # get_password_from_database
        def get_password_from_database
            # There should only be one row in the table so only one password
            response = query_database("SELECT password FROM #{ALEXA_INFORMATION}")
            response.entries.first["password"]
        end # get_password_from_database
        
        # get_emergency_contact
        # Returns an array of the hashes of the emergency contact details
        def get_emergency_contact
            response = query_database("SELECT * FROM #{EMERGENCY_CONTACT}")
            response.entries
        end # get_emergency_contact
        
        # dismiss_alarm
        def dismiss_alarm
            message = "Okay, ignoring this alarm"
            query_database( "UPDATE #{SENSOR_STATUS} SET dismiss=1 WHERE status=1" )
            # Update the alarm condition
            Alarm.new( @db_client )
            build_response( message )
        end # dismiss_alarm

        def disable_system
            message = "Okay, deactivating the alarm"
            query_database( "UPDATE #{SENSOR_STATUS} SET enabled=0" )
            Alarm.new( @db_client )
            build_response( message )
        end

        def enable_system
            message = "Okay, I'm going to activate the alarm"
            query_database( "UPDATE #{SENSOR_STATUS} SET enabled=1, dismiss=0")
            build_response( message )
        end

        def disable_sensor( sensor_type )
            if sensor_type == "none"
                raise "The sensor type was not set but should have been"
            end
            message = "Alright, deactivating the #{sensor_type} sensor"
            #TODO The online interface needs to be able to understand the different sensor names
            query_database( "UPDATE #{SENSOR_STATUS} SET enabled='0' WHERE name='#{sensor_type}'" )
            Alarm.new( @db_client )
            build_response( message )
        end

        def enable_sensor
            sensor_type = @request["request"]["intent"]["slots"]["Sensor"]["value"]
            message = "Alright, I'm going to activate the #{sensor_type} sensor"
            query_database( "UPDATE #{SENSOR_STATUS} SET enabled='1' WHERE name='#{sensor_type}'" )
            build_response( message )
        end

        # send_help
        def send_help
            message = "Notifying your emergency contact. Help is on the way!"
            #TODO Connect to Ahmed's notification system here
            # Trigger alarm immediately no matter what the sensors say
            Alarm.new( @db_client,  true )
            build_response( message )
        end

        #TODO verify_request
        def verify_request(request_in)
            # Must verify that the request came from Amazon and not some junkie
            # In the case that the request is invalid, must respond with invalid error code
        end # verify_request
    end # Alexa
end
