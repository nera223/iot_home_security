current_dir = File.expand_path(File.dirname(__FILE__))
sound_file = File.join(current_dir, 'woop_woop.wav')
while(true) # Just wait for the interrupt from daemon gem
    `aplay #{sound_file}`
    sleep(0.5)
end