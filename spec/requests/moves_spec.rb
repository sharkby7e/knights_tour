require "rails_helper"

RSpec.describe "Moves", type: :request do
  describe "POST /tours/:tour_id/moves" do
    it "creates a move for a legal square and redirects to the tour" do
      tour = create(:tour)

      expect {
        post tour_moves_path(tour), params: { square: "a1" }
      }.to change(Move, :count).by(1)

      expect(response).to redirect_to(tour_path(tour))
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
  end

  describe "DELETE /tours/:tour_id/moves/:id" do
    it "destroys the tour's last move and redirects to the tour" do
      tour = create(:tour)
      move = create(:move, tour: tour, square: "a1", position: 1)

      expect {
        delete tour_move_path(tour, move)
      }.to change(Move, :count).by(-1)

      expect(response).to redirect_to(tour_path(tour))
    end
  end
end
