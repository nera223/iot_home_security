module Framework
	class VERSIONTest < Minitest::Test
		def test_version_is_defined
			assert defined?(Framework::VERSION)
		end # test_version_is_defined

		def test_version_is_a_string
			assert_kind_of String, Framework::VERSION
		end # test_version_is_a_string
	end # class VERSIONTest
end # module Framework
