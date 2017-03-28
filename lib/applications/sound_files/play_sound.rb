# Make this 60seconds for real implementation
SLEEP_INTERVAL = 30

current_dir     = File.expand_path(File.dirname(__FILE__))
sound_file      = File.join(current_dir, 'woop_woop.wav')
countdown_file  = File.join(current_dir, '10s_countdown.wav')

delay = !ARGV.empty? && ARGV.first == "delay"
#sleep(SLEEP_INTERVAL) if delay
# Play countdown for about 20 seconds
#   to alert the user that the alarm is armed and will turn on soon!
if delay
    # Play the sound file twice
    `aplay #{countdown_file}`
    `aplay #{countdown_file}`
end
# If the alarm is dismissed, the script will be aborted before the sound will play
while(true) # Just wait for the interrupt from daemon gem
    `aplay #{sound_file}`
    sleep(0.5)
end