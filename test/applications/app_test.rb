module Applications
    describe Application do
        describe "When looking at the Application parent class" do
            before do
                @application = Application.new
            end
            it "must be defined" do
                @application.wont_be_nil
            end
            it "must raise NotImplementedError when calling call()" do
                proc {
                        @application.call("foo")
                }.must_raise( NotImplementedError )
            end
        end
    end
end
