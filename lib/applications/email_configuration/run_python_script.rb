#!/usr/bin/env ruby
# This script is executed as a daemon and will run the python emailsms.py script
email_script = File.join( File.expand_path( File.dirname( __FILE__ ) ), "emailsms.py" )
`python #{email_script}`
