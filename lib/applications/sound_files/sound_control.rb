#!/usr/bin/env ruby
# This file is a test for the alarm sound
#   # by calling a separate process in Ruby and 
#   # keeping track of the PID to kill it whenever
#   # necessary.
require 'daemons'

options = {
    :log_output => true
}
sound_file = File.join( File.expand_path( File.dirname( __FILE__ ) ), "play_sound.rb" )
Daemons.run(sound_file, options)