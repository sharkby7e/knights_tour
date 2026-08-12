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
end
