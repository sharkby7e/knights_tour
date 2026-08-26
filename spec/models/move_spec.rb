require "rails_helper"

RSpec.describe Move do
  it "accepts valid algebraic notation" do
    move = build(:move, square: "e4")

    expect(move).to be_valid
  end

  it "rejects a file outside a-h" do
    move = build(:move, square: "z9")

    expect(move).not_to be_valid
  end

  it "rejects a rank outside 1-8" do
    move = build(:move, square: "e0")

    expect(move).not_to be_valid
  end

  it "requires position to be unique within a tour" do
    tour = create(:tour)
    create(:move, tour:, position: 1, square: "a1")
    dup = build(:move, tour:, position: 1, square: "b2")

    expect(dup).not_to be_valid
  end

  it "requires square to be unique within a tour" do
    tour = create(:tour)
    create(:move, tour:, position: 1, square: "a1")
    dup = build(:move, tour:, position: 2, square: "a1")

    expect(dup).not_to be_valid
  end

  it "allows the same square to be reused across different tours" do
    create(:move, tour: create(:tour), position: 1, square: "a1")
    other_tour_move = build(:move, tour: create(:tour), position: 1, square: "a1")

    expect(other_tour_move).to be_valid
  end

  it "rejects a move that is not a legal knight's-move from the previous move" do
    tour = create(:tour)
    create(:move, tour:, position: 1, square: "e4")
    move = build(:move, tour:, position: 2, square: "e5")

    expect(move).not_to be_valid
  end

  it "does not require the first move in a tour to be a knight's-move from anything" do
    tour = create(:tour)
    move = build(:move, tour:, position: 1, square: "a1")

    expect(move).to be_valid
  end

  it "validates legality against an in-memory previous move that hasn't been saved yet" do
    tour = Tour.new
    tour.moves.build(square: "e4", position: 1)
    second = tour.moves.build(square: "e5", position: 2)

    expect(second).not_to be_valid
  end

  describe ".visit_counts" do
    it "counts visits to a square across every tour" do
      create(:move, tour: create(:tour), position: 1, square: "e4")
      create(:move, tour: create(:tour), position: 1, square: "e4")

      expect(Move.visit_counts["e4"]).to eq(2)
    end

    it "omits squares with no visits" do
      create(:move, tour: create(:tour), position: 1, square: "e4")

      expect(Move.visit_counts).not_to have_key("a1")
    end
  end
end
