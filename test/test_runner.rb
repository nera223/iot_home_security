# To run mini tests
require 'minitest/autorun'
# To load the framework files
require_relative '../lib/framework' # framework.rb requires other files
# Load test files
Dir[File.expand_path('../**/*_test.rb')].each do |f|
	load f
end

