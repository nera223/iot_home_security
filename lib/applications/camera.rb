# This file contains the camera class which is responsible for handling the JSON
#   # requests sent by the camera hub software

module Applications
    class Camera < Application
        # get_response
        def get_response( request_in )
            # Convert request to Hash format
            request = convert_json_to_hash( request_in )
            # Check validity of the request
            #TODO maybe there will be two types of requests, one where sensors are being set update
            #   # and another where sensor statuses are being updated
            if type = request_valid?( request )
                case type
                when 1
                    # Update camera history
                    query_database( "INSERT INTO #{CAMERA_HISTORY} (id, type, name, description, trigger_time) VALUES ('#{request["id"]}','#{request["type"]}','#{request["name"]}','#{request["description"]}','#{request["trigger_time"]}')" )
                when 2
                    # Update camera status
                    query_database( "INSERT INTO #{CAMERA_STATUS} (id, name, status, updated_time, enabled, mac, type, live_url) VALUES ('#{request["id"]}','#{request["name"]}','#{request["status"]}','#{request["updated_time"]}','#{request["enabled"]}','#{request["mac"]}','#{request["type"]}','#{request["live_url"]}')" )
                when 3
                    # Create notification
                    Notification.new( @db_client, [request["path"], request["description"], request["live_url"]] )
                end
            else
                return [BAD_RESPONSE_CODE, 
                        {'Content-Type' => 'text/plain'},
                        ["The request sent did not have all of the required information\n"]
                       ]
            end
            # Uncomment if this class should check for the alarm condition
            #Alarm.new( @db_client )
            return [GOOD_RESPONSE_CODE, 
                    {'Content-Type' => 'text/plain'},
                    ["GOOD\n"]
                   ]
        end # get_response
        
        private
        
        # request_valid?
        def request_valid?( request )
			# The camera sends a few different requests
			# First type of request updates the camera history
			# Second type of request updates the camera statuses
			# Third type of request contains a path to a file to send an email/SMS
            type1_request = ["id", "type", "name", "description", "trigger_time"]
			type2_request = ["id", "name", "status", "updated_time", "enabled", "mac", "type", "live_url"]
			type3_request = ["path", "live_url", "description", "time_stamp"]
			res = [type1_request, type2_request, type3_request].map do |required_keys|
				required_keys.each do |key|
					if !request.has_key?( key )
						return false
					end
				end
				return true
			end
			# If the request matched one of the types, return the type or nil
			if a = res.index( true )
				return a + 1
			else
				return false
			end
        end # request_valid?
    end # class
end # module
