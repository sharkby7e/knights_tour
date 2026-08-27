require "rails_helper"

RSpec.describe "Stats", type: :request do
  describe "GET /stats" do
    it "is successful" do
      get stats_path

      expect(response).to be_successful
    end

    it "shows the tour and move summary numbers" do
      create(:tour, :complete)
      incomplete = create(:tour)
      create(:move, tour: incomplete, square: "a1", position: 1)

      get stats_path

      doc = Nokogiri::HTML5.fragment(response.body)
      expect(doc.at_css("[data-stat='total-tours'] dd").text).to eq("2")
      expect(doc.at_css("[data-stat='complete-tours'] dd").text).to eq("1")
      expect(doc.at_css("[data-stat='incomplete-tours'] dd").text).to eq("1")
      expect(doc.at_css("[data-stat='average-moves'] dd").text).to eq("32.5")
    end

    it "renders without error when there are no tours" do
      get stats_path

      doc = Nokogiri::HTML5.fragment(response.body)
      expect(doc.at_css("[data-stat='total-tours'] dd").text).to eq("0")
      expect(doc.at_css("[data-stat='average-moves'] dd").text).to eq("—")
    end

    it "shows the distinct discovered-tours count against the total possible" do
      create(:tour, :complete)

      get stats_path

      doc = Nokogiri::HTML5.fragment(response.body)
      expect(doc.at_css("[data-stat='discovered-tours'] dd").text).to eq("1")
      expect(doc.at_css("[data-stat='discovered-tours']").text).to include("19.6 Quadrillion")
      expect(doc.at_css("[data-stat='discovered-tours'] [title]")["title"]).to eq("19,591,828,170,979,904")
    end

    it "shows the discovery percentage and a proportional progress bar" do
      stub_const("Tour::TOTAL_POSSIBLE_TOURS", 4)
      create(:tour, :complete)

      get stats_path

      doc = Nokogiri::HTML5.fragment(response.body)
      expect(doc.at_css("[data-stat='discovery-percentage']").text).to eq("25.0%")
      expect(doc.at_css("[data-stat='discovery-bar']")["style"]).to eq("width: 25.0%")
    end

    it "floors the progress bar's visual width at 1% without changing the displayed percentage" do
      stub_const("Tour::TOTAL_POSSIBLE_TOURS", 1_000)
      create(:tour, :complete)

      get stats_path

      doc = Nokogiri::HTML5.fragment(response.body)
      expect(doc.at_css("[data-stat='discovery-percentage']").text).to eq("0.1%")
      expect(doc.at_css("[data-stat='discovery-bar']")["style"]).to eq("width: 1.0%")
    end

    it "renders the heatmap as dots colored along a viridis spectrum, scaled to the observed min/max" do
      create(:move, tour: create(:tour), position: 1, square: "a1")
      create(:move, tour: create(:tour), position: 1, square: "a1")
      create(:move, tour: create(:tour), position: 1, square: "h8")

      get stats_path

      doc = Nokogiri::HTML5.fragment(response.body)
      svg = doc.at_css("svg[data-stat='heatmap']")
      expect(svg.at_css("[data-square='a1'] circle")["fill"]).to eq("#fde725")
      expect(svg.at_css("[data-square='h8'] circle")["fill"]).to eq("#440154")
      expect(svg.at_css("[data-square='b1']").css("circle")).to be_empty
    end

    it "renders a heatmap legend and does not error with no visits at all" do
      get stats_path

      doc = Nokogiri::HTML5.fragment(response.body)
      expect(doc.at_css("[data-stat='heatmap-legend']")).to be_present
      expect(doc.at_css("svg[data-stat='heatmap']")).to be_present
    end

    it "links the Play, Tours, and Stats nav items, with Stats active" do
      get stats_path

      doc = Nokogiri::HTML5.fragment(response.body)
      links = doc.css("a").index_by(&:text)
      expect(links["Play"]["href"]).to eq(root_path)
      expect(links["Tours"]["href"]).to eq(tours_path)
      expect(links["Stats"]["href"]).to eq(stats_path)
      expect(links["Stats"]["class"]).to include("text-accent")
      expect(links["Play"]["class"]).not_to include("text-accent")
    end
  end
end
