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
            if request_valid?( request )
                # Save path and description to database
                # The timestamp will be automatically updated
                query_database( "INSERT INTO #{MEDIA_ARCHIVE}} (path, description) VALUES ('#{request["path"]}', '#{request["description"]}')")
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
            required_keys = ["path", "description"]
            required_keys.each do |key|
                if !request.has_key?(key)
                    return false
                end
            end
            return true
        end # request_valid?
    end # class
end # module