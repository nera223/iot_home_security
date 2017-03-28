#!/usr/bin/env ruby

# This file is a test for the alarm sound
#   # by calling a separate process in Ruby and 
#   # keeping track of the PID to kill it whenever
#   # necessary.

require 'daemons'

options = {
    :log_output => false
}
email_script = File.join( File.expand_path( File.dirname( __FILE__ ) ), "run_python_script.rb" )
Daemons.run(email_script, options)
