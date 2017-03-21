# Make this 60seconds for real implementation
SLEEP_INTERVAL = 30

current_dir = File.expand_path(File.dirname(__FILE__))
sound_file = File.join(current_dir, 'woop_woop.wav')

delay = !ARGV.empty? && ARGV.first == "delay"
sleep(SLEEP_INTERVAL) if delay
# If the alarm is dismissed, the script will be aborted before the sound will play
while(true) # Just wait for the interrupt from daemon gem
    `aplay #{sound_file}`
    sleep(0.5)
end