require "rails_helper"

RSpec.describe PeopleController, type: :routing do
  describe "routing" do
    it "routes to #show" do
      expect(get: "/people/1.json").to route_to("people#show", id: "1", format: "json")
    end
  end
end
