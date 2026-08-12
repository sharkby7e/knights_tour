require "rails_helper"

RSpec.describe "Moves", type: :request do
  let(:turbo_stream_headers) { { "Accept" => "text/vnd.turbo-stream.html" } }

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

    it "responds with turbo streams replacing only the changed squares" do
      tour = create(:tour)
      create(:move, tour:, square: "a1", position: 1)

      post tour_moves_path(tour), params: { square: "b3" }, headers: turbo_stream_headers

      # previous current (a1), new current (b3), a1's old legal moves (b3, c2),
      # and b3's new legal moves (c5, d4, d2, c1, a5, minus visited a1)
      %w[a1 b3 c2 c5 d4 d2 c1 a5].each do |notation|
        assert_turbo_stream action: "replace", target: "square_#{notation}"
      end
      assert_turbo_stream action: "replace", target: "visited_count"
      assert_turbo_stream action: "replace", target: "tour_control"
      assert_no_turbo_stream action: "replace", target: "board"
    end

    it "replaces the whole board when the move results in being stuck" do
      tour = create(:tour)
      create(:move, tour:, square: "c2", position: 1)
      create(:move, tour:, square: "d4", position: 2)
      create(:move, tour:, square: "b3", position: 3)

      post tour_moves_path(tour), params: { square: "a1" }, headers: turbo_stream_headers

      assert_turbo_stream action: "replace", target: "board" do
        assert_select "template [id^='square_']", count: 64
        assert_select "template .bg-zinc-700", count: 64
      end
      assert_turbo_stream action: "replace", target: "visited_count"
      assert_turbo_stream action: "replace", target: "tour_control"
    end

    it "shows Congrats when the final move wins the tour" do
      tour = create(:tour)
      target = Square.from_notation("a1")
      predecessor = Square.from_notation("c2")
      remaining = Square.all - [ target, predecessor ]

      remaining.each_with_index { |square, i| create(:move, tour:, square: square.notation, position: i + 1) }
      create(:move, tour:, square: predecessor.notation, position: 63)

      post tour_moves_path(tour), params: { square: target.notation }, headers: turbo_stream_headers

      assert_turbo_stream action: "replace", target: "tour_control" do
        assert_select "template a", text: "Congrats!"
      end
      assert_turbo_stream action: "replace", target: "visited_count" do
        assert_select "template p", text: "64"
      end
    end

    it "supports a short sequential real happy path via turbo stream" do
      tour = create(:tour)
      path = %w[a1 b3 c5 d7 f8]

      path.each_with_index do |square, i|
        expect {
          post tour_moves_path(tour), params: { square: }, headers: turbo_stream_headers
        }.to change(Move, :count).by(1)

        expect(response.media_type).to eq("text/vnd.turbo-stream.html")
        assert_turbo_stream action: "replace", target: "visited_count" do
          assert_select "template p", text: (i + 1).to_s
        end
      end

      expect(tour.moves.order(:position).pluck(:square)).to eq(path)
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

    it "responds with a turbo stream replacing only the changed squares" do
      tour = create(:tour)
      create(:move, tour:, square: "a1", position: 1)
      move = create(:move, tour:, square: "b3", position: 2)

      delete tour_move_path(tour, move), headers: turbo_stream_headers

      %w[a1 b3 c2 c5 d4 d2 c1 a5].each do |notation|
        assert_turbo_stream action: "replace", target: "square_#{notation}"
      end
      assert_turbo_stream action: "replace", target: "visited_count"
      assert_turbo_stream action: "replace", target: "tour_control"
      assert_no_turbo_stream action: "replace", target: "board"
    end

    it "un-grays the whole board when undo resolves a stuck state" do
      tour = create(:tour)
      create(:move, tour:, square: "c2", position: 1)
      create(:move, tour:, square: "d4", position: 2)
      create(:move, tour:, square: "b3", position: 3)
      move = create(:move, tour:, square: "a1", position: 4)

      delete tour_move_path(tour, move), headers: turbo_stream_headers

      assert_turbo_stream action: "replace", target: "board" do
        assert_select "template .bg-zinc-700", count: 0
      end
      assert_turbo_stream action: "replace", target: "visited_count"
      assert_turbo_stream action: "replace", target: "tour_control"
    end
  end
end
