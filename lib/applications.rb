# ADD ANY CLASSES UNDER APPLICATIONS/ TO THIS FILE
require 'erb'
require_relative 'mysql'
require_relative 'alarm'

$LOAD_PATH << File.expand_path('..', __FILE__)

module Applications
    autoload :Application, 'applications/app'
    autoload :Alexa, 'applications/alexa'
    autoload :Sensor, 'applications/sensor'
    autoload :Database, 'mysql'
    autoload :Alarm, 'alarm'
end


