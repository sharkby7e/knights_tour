require "rails_helper"

RSpec.describe "Tours", type: :request do
  describe "GET /tours" do
    it "works" do
      get tours_path

      expect(response).to be_successful
    end

    it "renders one row per tour" do
      create_list(:tour, 2)

      get tours_path

      doc = Nokogiri::HTML5.fragment(response.body)
      expect(doc.css("li").count).to eq(2)
    end

    it "shows Complete for a 64-move tour and Incomplete for a shorter one" do
      create(:tour, :complete)
      incomplete = create(:tour)
      create(:move, tour: incomplete, square: "a1", position: 1)

      get tours_path

      doc = Nokogiri::HTML5.fragment(response.body)
      pill_texts = doc.css("li span").map { |el| el.text.strip }
      expect(pill_texts).to include("Complete", "Incomplete")
    end

    it "links the wordmark home" do
      get tours_path

      doc = Nokogiri::HTML5.fragment(response.body)
      link = doc.at_css("a.font-title")
      expect(link["href"]).to eq(root_path)
    end

    it "links the Play and Tours nav items, with Tours active" do
      get tours_path

      doc = Nokogiri::HTML5.fragment(response.body)
      links = doc.css("a").index_by(&:text)
      expect(links["Play"]["href"]).to eq(root_path)
      expect(links["Tours"]["href"]).to eq(tours_path)
      expect(links["Tours"]["class"]).to include("text-accent")
      expect(links["Play"]["class"]).not_to include("text-accent")
    end

    it "filters to only Complete tours when status=complete" do
      create(:tour, :complete)
      create(:tour)

      get tours_path(status: "complete")

      doc = Nokogiri::HTML5.fragment(response.body)
      expect(doc.css("li").count).to eq(1)
      expect(doc.css("li span").map { |el| el.text.strip }).to include("Complete")
    end

    it "filters to only Incomplete tours when status=incomplete" do
      create(:tour, :complete)
      create(:tour)

      get tours_path(status: "incomplete")

      doc = Nokogiri::HTML5.fragment(response.body)
      expect(doc.css("li").count).to eq(1)
      expect(doc.css("li span").map { |el| el.text.strip }).to include("Incomplete")
    end

    it "ignores an invalid status value and shows everything" do
      create(:tour, :complete)
      create(:tour)

      get tours_path(status: "bogus")

      doc = Nokogiri::HTML5.fragment(response.body)
      expect(doc.css("li").count).to eq(2)
    end

    it "highlights All by default and Complete/Incomplete when filtered" do
      get tours_path

      doc = Nokogiri::HTML5.fragment(response.body)
      filter_links = doc.at_css("nav.pill-filters").css("a").index_by(&:text)
      expect(filter_links["All"]["class"]).to include("bg-accent")
      expect(filter_links["Complete"]["class"]).not_to include("bg-accent")
      expect(filter_links["Incomplete"]["class"]).not_to include("bg-accent")

      get tours_path(status: "complete")

      doc = Nokogiri::HTML5.fragment(response.body)
      filter_links = doc.at_css("nav.pill-filters").css("a").index_by(&:text)
      expect(filter_links["Complete"]["class"]).to include("bg-accent")
      expect(filter_links["All"]["class"]).not_to include("bg-accent")
    end

    it "orders tours newest first" do
      older = create(:tour, created_at: 2.days.ago)
      newer = create(:tour, created_at: 1.day.ago)

      get tours_path

      doc = Nokogiri::HTML5.fragment(response.body)
      ids = doc.css("[data-tour-id]").map { |el| el["data-tour-id"] }
      expect(ids).to eq([ newer.id.to_s, older.id.to_s ])
    end
  end

  describe "GET /" do
    it "renders the board skeleton with a Stimulus-controlled play area" do
      get root_path

      expect(response).to be_successful
      doc = Nokogiri::HTML5.fragment(response.body)
      expect(doc.at_css("[data-controller='tour']")).to be_present
      expect(doc.css("[data-square-notation]").count).to eq(64)
    end

    it "shows the title bar with Play active" do
      get root_path

      doc = Nokogiri::HTML5.fragment(response.body)
      links = doc.css("a").index_by(&:text)
      expect(links["Play"]["class"]).to include("text-accent")
      expect(links["Tours"]["class"]).not_to include("text-accent")
    end

    it "renders the move ticker" do
      get root_path

      doc = Nokogiri::HTML5.fragment(response.body)
      expect(doc.at_css(".move-ticker")).to be_present
    end
  end

  describe "GET /tours/:id" do
    it "is successful" do
      tour = create(:tour)

      get tour_path(tour)

      expect(response).to be_successful
    end

    it "shows the move count for a finished tour" do
      tour = create(:tour, :complete)

      get tour_path(tour)

      doc = Nokogiri::HTML5.fragment(response.body)
      expect(doc.at_css("[data-tour-playback-target='stepTotal']").text).to eq("64")
    end

    it "shows the move count for a partial tour" do
      tour = create(:tour)
      create(:move, tour:, position: 1, square: "a1")

      get tour_path(tour)

      doc = Nokogiri::HTML5.fragment(response.body)
      expect(doc.at_css("[data-tour-playback-target='stepTotal']").text).to eq("1")
    end

    it "includes the tour's move notations in order on the board root's moves data attribute" do
      tour = create(:tour)
      create(:move, tour:, position: 1, square: "e4")
      create(:move, tour:, position: 2, square: "f6")

      get tour_path(tour)

      doc = Nokogiri::HTML5.fragment(response.body)
      root = doc.at_css("[data-tour-playback-moves-value]")
      expect(JSON.parse(root["data-tour-playback-moves-value"])).to eq([ "e4", "f6" ])
    end
  end

  describe "POST /tours" do
    def post_tour(moves)
      post tours_path, params: { moves: moves }.to_json, headers: { "Content-Type" => "application/json" }
    end

    def error_messages
      JSON.parse(response.body).values.flatten
    end

    it "creates a tour with the submitted moves in order and responds with a redirect_url to the new tour" do
      expect { post_tour([ "e4", "f6", "d5" ]) }.to change(Tour, :count).by(1)

      expect(response).to be_successful
      expect(Tour.last.moves.order(:position).pluck(:square)).to eq([ "e4", "f6", "d5" ])
      expect(JSON.parse(response.body)["redirect_url"]).to eq(tour_path(Tour.last))
    end

    it "rejects a move that is not a legal knight's-move and creates nothing" do
      expect { post_tour([ "e4", "e5" ]) }.not_to change(Tour, :count)

      expect(response.status).to eq(422)
      expect(error_messages).to include("is not a legal knight's-move from the previous move")
    end

    it "rejects an empty moves array and creates nothing" do
      expect { post_tour([]) }.not_to change(Tour, :count)

      expect(response.status).to eq(422)
      expect(error_messages).to include("can't be blank")
    end
  end
end
