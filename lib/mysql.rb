require 'mysql2'
# This file will contains methods to connect to database
# This table will be updated with the reading of the current sensor status
SENSOR_STATUS       = "sensor_status"
# This table will hold information of the information for the emergency contact
EMERGENCY_CONTACT   = "emergency_contacts"
# Holds information for the primary user and other system information like the alarm password
ALEXA_INFORMATION   = "alexa"
# Holds information for the motion detection events
CAMERA_HISTORY      = "camera_history"
# Holds information for the camera status
CAMERA_STATUS       = "camera_status"
# Holds an event log for sensor alarm states
EVENT_LOG           = "sensor_history"

class Database

    MAIN_DATABASE = "system"
    USERNAME = "iot"
    PASSWORD = "securiotech"
    HOST = "localhost"
    DATABASE = "system"

    # Function to connect to a MYSQL database with pre-determined configuration options
    # Returns a client that can be used to query the database
    def connect
        client = Mysql2::Client.new(:host     => HOST,
                                    :username => USERNAME,
                                    :password => PASSWORD,
                                    :database => DATABASE)
    end


end # class Database
