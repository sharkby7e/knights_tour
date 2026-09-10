require "rails_helper"

RSpec.describe "About", type: :request do
  describe "GET /about" do
    it "is successful" do
      get about_path

      expect(response).to be_successful
    end

    it "links the Play, Tours, Stats, and About nav items, with About active" do
      get about_path

      doc = Nokogiri::HTML5.fragment(response.body)
      links = doc.css("a").index_by(&:text)
      expect(links["About"]["href"]).to eq(about_path)
      expect(links["About"]["class"]).to include("text-accent")
      expect(links["Play"]["class"]).not_to include("text-accent")
    end
  end
end
