# This file contains the Alexa class to respond to Amazon Web Services HTTPS requests sent through the user's Amazon Echo device
# Sample response looks like: [200, {'Content-Type' => 'text/plain'}, ["Message"]]

require 'json'
require_relative 'app'

module Applications
    class Alexa < Application
        # get_response
        # Inputs: raw request
        # Outputs: response
        def get_response(request_in)
            # The request will be JSON format
            request = convert_json_to_hash(request_in)
            type = determine_type( request )
            case type
            when "LaunchRequest"
                response = respond_to_launch(request)
            when "IntentRequest"
                response = respond_to_intent(request)
            end
            # Make this into a nicer function
            [GOOD_RESPONSE_CODE, {'Content-Type' => 'applicatino/json;charset=UTF-8'}, [convert_hash_to_json( response )]]
        end # get_response
        
        private 

        ######## Working with JSON Alexa Request
        #===========================================================================

        # determine_type
        def determine_type( request )
            request["request"]["type"]
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
        def respond_to_launch( request )
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
        def respond_to_intent( request )
            # For now, just identify the type of intent and give a simple message
            # that acknowledges that request
            intent = request["request"]["intent"]["name"]
            case intent
            when "DisableSystem"
                response = disable_system( request )
            when "EnableSystem"
                response = enable_system( request )
            when "DisableSensor"
                response = disable_sensor( request )
            when "EnableSensor"
                response = enable_sensor( request )
            when "SendHelp"
                response = send_help( request )
            when "EmergencyContact"
                response = manage_emergency_contact( request )
            else
                response = build_response("You forgot to code this intent")
            end
            return response
        end # respond_to_intent

        # manage_emergency_contact
        # This function adds, removes, emergency contacts from the database
        #   # This will be an interactive function so the request input could
        #   # be a reply. Therefore the function has multiple return statements
        def manage_emergency_contact( request )
            is_new_session = request["session"]["new"]
            # Determine the action from the user
            #   # may be given in the request or may need to ask for it
            contact_action = request["request"]["intent"]["slots"]["contact_action"]["value"]
            if is_new_session
                if contact_action != "manage"
                    # Get specific with the request
                else
                    # Ask the user exactly what they would like to do. Give the count of 
                    #   # the emergency contacts currently available to help the user out
                    emergency_contacts = get_emergency_contact
                    if emergency_contacts.empty?
                        message = "You currently have no emergency contacts stored,"\
                        " Would you like to add one now?"
                        # Do not end session. User can directly reply to this command
                        return build_response(message, {"contact_action" => "add"}, false)
                    else
                        message = "You currently have #{emergency_contacts.count} contacts stored."\
                        " You can tell Securitech to add, change, or remove an emergency contact,"\
                        " or tell Securitech to read. out the current information"
                        return build_response(message)
                    end
                end
            else
                #TODO determine if yes or no answer
                if contact_action.nil?
                    # The contact action will be stored in a session attribute instead
                    contact_action = request["session"]["attributes"]["contact_action"]
                end
                case contact_action
                when "add", "create"
                end
            end
        end
        
        # get_emergency_contact
        # Returns a hash of the emergency contact details or nil if empty
        def get_emergency_contact
            response = query_database("SELECT * FROM #{EMERGENCY_CONTACT}")
            response.entries
        end # get_emergency_contact

        def disable_system( request )
            message = "Okay, deactivating the alarm"
            build_response( message )
        end

        def enable_system( request )
            message = "Okay, I'm going to activate the alarm"
            build_response( message )
        end

        def disable_sensor( request )
            sensor_type = request["request"]["intent"]["slots"]["Sensor"]["value"]
            message = "Alright, deactivating the #{sensor_type} sensor"
            query_database( "UPDATE #{SENSOR_FUNCTION} SET status='0' WHERE name='#{sensor_type}'" )
            build_response( message )
        end

        def enable_sensor( request )
            sensor_type = request["request"]["intent"]["slots"]["Sensor"]["value"]
            message = "Alright, I'm going to activate the #{sensor_type} sensor"
            query_database( "UPDATE #{SENSOR_FUNCTION} SET status='1' WHERE name='#{sensor_type}'" )
            build_response( message )
        end

        # send_help
        def send_help( request )
            message = "Notifying your emergency contact"
            build_response( message )
            #TODO Connect to Ahmed's notification system here
            # Trigger alarm immediately no matter what the sensors say
            Alarm.new( true )
        end

        # verify_request
        def verify_request(request_in)
            # Must verify that the request came from Amazon and not some junkie
            # In the case that the request is invalid, must respond with invalid error code
        end # verify_request
    end # Alexa
end
