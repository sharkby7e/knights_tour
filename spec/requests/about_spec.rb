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

    it "shows a photo carousel hero with multiple cards" do
      get about_path

      doc = Nokogiri::HTML5.fragment(response.body)
      expect(doc.css("[data-about='carousel'] figure").size).to be >= 2
    end

    it "shows a story section with a heading and body copy" do
      get about_path

      doc = Nokogiri::HTML5.fragment(response.body)
      story = doc.at_css("[data-about='story']")
      expect(story.at_css("h2").text).not_to be_empty
      expect(story.at_css("p").text).not_to be_empty
    end

    it "shows a right-now section with a heading and contact CTAs" do
      get about_path

      doc = Nokogiri::HTML5.fragment(response.body)
      currently = doc.at_css("[data-about='currently']")
      expect(currently.at_css("h2").text).not_to be_empty
      expect(currently.at_css("a[href='mailto:sgquin@gmail.com']").text).to eq("Email me")
      expect(currently.css("a").map(&:text)).to include("LinkedIn", "Résumé")
    end
  end
end
