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
      link = doc.css("a").find { |a| a.text == "Knight's Tour" }
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
    it "does not create a tour" do
      expect { get root_path }.not_to change(Tour, :count)
    end

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
  end

  describe "GET /tours/:id" do
    it "is successful" do
      tour = create(:tour)

      get tour_path(tour)

      expect(response).to be_successful
    end
  end

  describe "POST /tours" do
    it "creates a new tour and redirects to root, leaving the old tour's moves intact" do
      old_tour = create(:tour)
      old_move = create(:move, tour: old_tour)

      expect { post tours_path }.to change(Tour, :count).by(1)

      expect(response).to redirect_to(root_path)
      expect(old_move.reload).to be_persisted
    end
  end
end
