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

        # determine_type
        def determine_type( request )
            request["request"]["type"]
        end # determine_type

        # convert_json_to_hash
        def convert_json_to_hash( json )
            JSON.parse( json["rack.input"].read )
        end # convert_json_to_hash

        # convert_hash_to_json
        # Returns a JSON string
        def convert_hash_to_json( hash )
            JSON.generate( hash )
        end

        # respond_to_launch
        def respond_to_launch( request )
           # For now, just give a simple hello message 
           response = {
                   :version => "1.0",
                   :sessionAttributes => {},
                   :response => {
                           :outputSpeech => {
                                   :type => "PlainText",
                                   :text => "Welcome to your Securitech I O T Home Security System. You can tell me commands such as. Ask Securitech to disable the alarm. Or. Tell Securitech to enable the window sensor"
                           },
                           :shouldEndSession => true
                   }
           }
           return response
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
            end
            return response
        end # respond_to_intent
        
        def disable_system( request )
            # For now, just respond with a simple message
            response = {
                   :version => "1.0",
                   :sessionAttributes => {},
                   :response => {
                           :outputSpeech => {
                                   :type => "PlainText",
                                   :text => "Okay, deactivating the alarm"
                           },
                           :shouldEndSession => true
                   }
            }
        end

        def enable_system( request )
            # For now, just respond with a simple message
            response = {
                   :version => "1.0",
                   :sessionAttributes => {},
                   :response => {
                           :outputSpeech => {
                                   :type => "PlainText",
                                   :text => "Okay, I'm going to activate the alarm"
                           },
                           :shouldEndSession => true
                   }
            }
        end

        def disable_sensor( request )
            sensor_type = request["request"]["intent"]["slots"]["Sensor"]["value"]
            # For now, just respond with a simple message
            response = {
                   :version => "1.0",
                   :sessionAttributes => {},
                   :response => {
                           :outputSpeech => {
                                   :type => "PlainText",
                                   :text => "Alright, deactivating the #{sensor_type} sensor"
                           },
                           :shouldEndSession => true
                   }
            }
        end

        def enable_sensor( request )
            # For now, just respond with a simple message
            sensor_type = request["request"]["intent"]["slots"]["Sensor"]["value"]
            response = {
                   :version => "1.0",
                   :sessionAttributes => {},
                   :response => {
                           :outputSpeech => {
                                   :type => "PlainText",
                                   :text => "Alright, I'm going to activate the #{sensor_type} sensor"
                           },
                           :shouldEndSession => true
                   }
            }
        end

        # verify_request
        def verify_request(request_in)
            # Must verify that the request came from Amazon and not some junkie
            # In the case that the request is invalid, must respond with invalid error code
        end # verify_request
    end # Alexa
end
