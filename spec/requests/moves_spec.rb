require "rails_helper"

RSpec.describe "Moves", type: :request do
  describe "POST /tours/:tour_id/moves" do
    it "creates a move for a legal square and redirects to root" do
      tour = create(:tour)

      expect {
        post tour_moves_path(tour), params: { square: "a1" }
      }.to change(Move, :count).by(1)

      expect(response).to redirect_to(root_path)
      expect(tour.moves.last.square).to eq("a1")
    end

    it "does not create a move for an illegal square and responds unprocessable" do
      tour = create(:tour)
      create(:move, tour: tour, square: "a1", position: 1)

      expect {
        post tour_moves_path(tour), params: { square: "h8" }
      }.not_to change(Move, :count)

      expect(response).to have_http_status(:unprocessable_content)
    end

    it "grays out the whole board when the move results in being stuck" do
      tour = create(:tour)
      create(:move, tour:, square: "c2", position: 1)
      create(:move, tour:, square: "d4", position: 2)
      create(:move, tour:, square: "b3", position: 3)

      post tour_moves_path(tour), params: { square: "a1" }

      get root_path
      doc = Nokogiri::HTML5.fragment(response.body)
      expect(doc.css("#board .bg-zinc-700").count).to eq(64)
      expect(doc.css("#board a")).to be_empty
    end

    it "shows Congrats when the final move wins the tour" do
      tour = create(:tour)
      target = Square.from_notation("a1")
      predecessor = Square.from_notation("c2")
      remaining = Square.all - [ target, predecessor ]

      remaining.each_with_index { |square, i| create(:move, tour:, square: square.notation, position: i + 1) }
      create(:move, tour:, square: predecessor.notation, position: 63)

      post tour_moves_path(tour), params: { square: target.notation }

      get root_path
      doc = Nokogiri::HTML5.fragment(response.body)
      expect(doc.css("#tour_control a").map(&:text)).to include("Congrats!")
      expect(doc.at_css("#visited_count").text).to include("64")
    end

    it "supports a short sequential real happy path" do
      tour = create(:tour)
      path = %w[a1 b3 c5 d7 f8]

      path.each do |square|
        expect {
          post tour_moves_path(tour), params: { square: }
        }.to change(Move, :count).by(1)

        expect(response).to redirect_to(root_path)
      end

      expect(tour.moves.order(:position).pluck(:square)).to eq(path)
    end
  end

  describe "DELETE /tours/:tour_id/moves/:id" do
    it "destroys the tour's last move and redirects to root" do
      tour = create(:tour)
      move = create(:move, tour: tour, square: "a1", position: 1)

      expect {
        delete tour_move_path(tour, move)
      }.to change(Move, :count).by(-1)

      expect(response).to redirect_to(root_path)
    end

    it "un-grays the whole board when undo resolves a stuck state" do
      tour = create(:tour)
      create(:move, tour:, square: "c2", position: 1)
      create(:move, tour:, square: "d4", position: 2)
      create(:move, tour:, square: "b3", position: 3)
      move = create(:move, tour:, square: "a1", position: 4)

      delete tour_move_path(tour, move)

      get root_path
      doc = Nokogiri::HTML5.fragment(response.body)
      expect(doc.css("#board .bg-zinc-700")).to be_empty
      expect(doc.at_css("#square_a1 a.bg-emerald-400")).to be_present
    end
  end
end
