describe Framework do
    describe "When loading framework class" do
        describe "and looking at the VERSION constant" do
            it "must be defined" do
                Framework::VERSION.wont_be_nil
            end
            it "must be a string" do
                Framework::VERSION.must_be_kind_of( String )
            end
        end
    end
end
