require "rails_helper"

RSpec.describe "Tours", type: :request do
  describe "GET /" do
    it "renders the current tour inline, creating one if none exists" do
      expect { get root_path }.to change(Tour, :count).by(1)

      expect(response).to be_successful
      doc = Nokogiri::HTML5.fragment(response.body)
      expect(doc.at_css("turbo-frame#tour")).to be_present
      expect(doc.css("#board [id^='square_']").count).to eq(64)
    end

    it "renders the existing current tour without creating another" do
      existing = create(:tour)
      create(:move, tour: existing, square: "a1", position: 1)

      expect { get root_path }.not_to change(Tour, :count)

      expect(response).to be_successful
      doc = Nokogiri::HTML5.fragment(response.body)
      expect(doc.at_css("#square_a1")).to be_present
    end
  end

  describe "GET /tours/:id" do
    it "is successful" do
      tour = create(:tour)

      get tour_path(tour)

      expect(response).to be_successful
    end

    it "renders the board, visited count, and restart control" do
      tour = create(:tour)

      get tour_path(tour)

      doc = Nokogiri::HTML5.fragment(response.body)

      expect(doc.at_css("#board")).to be_present
      expect(doc.css("#board [id^='square_']").count).to eq(64)
      expect(doc.at_css("#visited_count")).to be_present
      expect(doc.at_css("#tour_control")).to be_present
      expect(doc.css("#tour_control a").map(&:text)).to include("Restart")
    end

    it "highlights the legal move squares as clickable" do
      tour = create(:tour)
      create(:move, tour:, square: "a1", position: 1)

      get tour_path(tour)

      doc = Nokogiri::HTML5.fragment(response.body)

      expect(doc.at_css("#square_c2 a.bg-emerald-400")).to be_present
      expect(doc.at_css("#square_b3 a.bg-emerald-400")).to be_present
      expect(doc.at_css("#square_h8 a")).to be_nil
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

    it "makes the fresh tour current, not the old one's state" do
      old_tour = create(:tour)
      create(:move, tour: old_tour, square: "a1", position: 1)

      post tours_path
      get root_path

      doc = Nokogiri::HTML5.fragment(response.body)
      expect(doc.at_css("#square_a1 a.bg-emerald-400")).to be_present
      expect(doc.css("#board .bg-red-400")).to be_empty
    end
  end
end
