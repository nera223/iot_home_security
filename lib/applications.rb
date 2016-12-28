# ADD ANY CLASSES UNDER APPLICATIONS/ TO THIS FILE
require 'erb'
require_relative 'mysql'

$LOAD_PATH << File.expand_path('..', __FILE__)

module Applications
    autoload :Application, 'applications/app'
    autoload :Alexa, 'applications/alexa'
    autoload :Sensor, 'applications/sensor'
end


