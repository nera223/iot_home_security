#!/usr/bin/env ruby
# This file is a test for the alarm sound
#   # by calling a separate process in Ruby and 
#   # keeping track of the PID to kill it whenever
#   # necessary.
require 'daemons'

# Delay argument can be passed to this file that will be executed with the sound_file call
options = {
    :log_output => false
}
sound_file = File.join( File.expand_path( File.dirname( __FILE__ ) ), "play_sound.rb" )
Daemons.run(sound_file, options)