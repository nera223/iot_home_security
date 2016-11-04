require 'erb'

$LOAD_PATH << File.expand_path('..', __FILE__)

module Framework
	autoload :VERSION, 'framework/version'
	autoload :WEBrickServer, 'framework/servers/webrick_server'
	autoload :AbstractServer, 'framework/servers/abstract_server'
end
