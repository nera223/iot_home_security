# This file will handle all notifications that will be sent out via email or SMS to
#   # the user specified in the emergency_contacts database

module Applications
    CONFIG_PATH = "/home/pi/iot_home_security/lib/applications/email_configuration"
    LIVESTREAM_URL = "securiotech.owendroth.com:304"
    EMAIL_CONTROL_FILE = File.join( File.expand_path( File.dirname(__FILE__) ), 'email_configuration', 'email_control.rb' )
    # Pseudocode
    # Generate a text file with the necessary configuration options
    #   # Will contain destination email, phone number, message, URL to camera feed (if applicable)
    class Notification
        # initialize
        #   # alarm_sensors is an array of all alarms that are showing a 1 status
        def initialize( db_client, alarm_sensors )
            # A connection to the database is passed around the different classes
            @db_client = db_client
            @sensors = alarm_sensors
            generate_text_file
            call_email_script
        end # initialize
    
        private
        # generate_text_file
        def generate_text_file
            # Get the contact information for the default emergency contact
            first_name, last_name, email, phone = get_default_contact_information
            # Generate a user message dynamic to the number of sensors tripped
            message = "An alarm was triggered at your home for the #{@sensors.join(", and ")} sensor#{@sensors.size > 1 ? "s" : ""}."
            if @sensors.member?( "camera" ) 
                # Fetch photo path information
                photo_path = fetch_photo_path
            end
            #TODO change this to be more random so multiple config files can exist
            config_file = "email_config.txt"
            File.open( File.join( CONFIG_PATH, config_file ), "w" ) do |f|
                f.puts "First, #{first_name}\n"
                f.puts "Last, #{last_name}\n"
                f.puts "Email, #{email}\n"
                f.puts "Phone, #{phone}\n"
                f.puts "Sensor, #{@sensors.join(", ")}\n"
                f.puts "Message, #{message}\n"
                f.puts "Photo, #{photo_path}\n" if !photo_path.nil? && !photo_path.empty?
                f.puts "Livestream, #{LIVESTREAM_URL}\n"
            end
        end # generate_text_file
        
        # call_email_script
        def call_email_script
            # This needs to be run as a background process because sending the email could take some time
            #exec("#{EMAIL_CONTROL_FILE} start")
        end # call_email_script
        
        # fetch_photo_path
        def fetch_photo_path
            []
        end # fetch_photo_path
        
        # get_default_contact_information
        def get_default_contact_information
            #NOTE In the future, should this email maybe go out to every email listed in the database?
            response = @db_client.query( "SELECT * FROM #{EMERGENCY_CONTACT} WHERE default_contact=1" ).entries.first
            return [response["first_name"], response["last_name"], response["email"], response["phone_number"]]
        end # get_default_contact_information
    end # Notification
end # module
