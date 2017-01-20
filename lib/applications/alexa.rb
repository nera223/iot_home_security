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
            @request = convert_json_to_hash(request_in)
            type = determine_type
            case type
            when "LaunchRequest"
                response = respond_to_launch
            when "IntentRequest"
                response = respond_to_intent
            end
            # Make this into a nicer function
            [GOOD_RESPONSE_CODE, {'Content-Type' => 'applicatino/json;charset=UTF-8'}, [convert_hash_to_json( response )]]
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
                response = disable_system
            when "EnableSystem"
                response = enable_system
            when "DisableSensor"
                response = disable_sensor
            when "EnableSensor"
                response = enable_sensor
            when "SendHelp"
                response = send_help
            when "EmergencyContact"
                response = manage_emergency_contact
            else
                response = build_response("You forgot to code this intent")
            end
            if response.nil?
                response = build_response("I did not understand your request")
            end
            return response
        end # respond_to_intent

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
                if @request["request"]["intent"]["slots"]["contact_response"]["value"] == "yes" ||
                        !@request["session"]["attributes"]["continue"].nil?
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
                    phone_number = @request["request"]["intent"]["slots"]["phone_number"]["value"]
                    #TODO code to check for valid phone number
                    first_name = @request["session"]["attributes"]["first_name"]
                    last_name = @request["session"]["attributes"]["last_name"]
                    query_database( "UPDATE #{EMERGENCY_CONTACT} SET phone_number='#{phone_number}' WHERE (first_name='#{first_name}') AND (last_name='#{last_name}')" )
                    return build_response("Got it. Done adding contact to the system.")
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
                    byebug
                    #TODO test only given first name
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
                    message = "You have #{current_contacts.count} contacts stored. These are #{contact_string}. Which one would you like to remove?"
                    return build_response( message,
                            {"intent" => "EmergencyContact", "contact_action" => "remove", "continue" => "remove__name"},
                            false)
                end
            end
        end # remove_emergency_contact

        def change_emergency_contact
            build_response("Changing")
        end # change_emergency_contact

        def display_emergency_contact
            build_response("Displaying")
        end # display_emergency_contact
        
        # get_emergency_contact
        # Returns an array of the hashes of the emergency contact details
        def get_emergency_contact
            response = query_database("SELECT * FROM #{EMERGENCY_CONTACT}")
            response.entries
        end # get_emergency_contact

        def disable_system
            message = "Okay, deactivating the alarm"
            build_response( message )
        end

        def enable_system
            message = "Okay, I'm going to activate the alarm"
            build_response( message )
        end

        def disable_sensor
            sensor_type = @request["request"]["intent"]["slots"]["Sensor"]["value"]
            message = "Alright, deactivating the #{sensor_type} sensor"
            #TODO The online interface needs to be able to understand the different senosr names
            query_database( "UPDATE #{SENSOR_STATUS} SET enabled='0' WHERE name='#{sensor_type}'" )
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
            message = "Notifying your emergency contact"
            build_response( message )
            #TODO Connect to Ahmed's notification system here
            # Trigger alarm immediately no matter what the sensors say
            Alarm.new( true )
        end

        #TODO verify_request
        def verify_request(request_in)
            # Must verify that the request came from Amazon and not some junkie
            # In the case that the request is invalid, must respond with invalid error code
        end # verify_request
    end # Alexa
end
