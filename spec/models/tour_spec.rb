require "rails_helper"

RSpec.describe Tour do
  it "leaves a prior tour's moves intact when a new tour is created" do
    old_tour = create(:tour)
    old_move = create(:move, tour: old_tour)

    create(:tour)

    expect(old_move.reload).to be_persisted
  end

  it "is invalid in the :save_tour context with no moves" do
    expect(build(:tour).valid?(:save_tour)).to be false
  end

  it "Tour.complete returns only 64-move tours" do
    complete = create(:tour, :complete)
    create(:tour)

    expect(Tour.complete).to eq([ complete ])
  end

  it "Tour.incomplete returns tours with fewer than 64 moves, including zero-move tours" do
    create(:tour, :complete)
    partial = create(:tour)
    create(:move, tour: partial, square: "a1", position: 1)
    empty = create(:tour)

    expect(Tour.incomplete).to contain_exactly(partial, empty)
  end

  describe ".distinct_complete_count" do
    it "counts a repeated move sequence once" do
      create(:tour, :complete)
      create(:tour, :complete)

      expect(Tour.distinct_complete_count).to eq(1)
    end

    it "counts tours with different move sequences separately" do
      create(:tour, :complete)
      other = create(:tour)
      Move.insert_all(
        COMPLETE_TOUR_SQUARES.reverse.each_with_index.map { |square, i| { tour_id: other.id, square:, position: i + 1 } }
      )

      expect(Tour.distinct_complete_count).to eq(2)
    end

    it "ignores incomplete tours" do
      create(:tour, :complete)
      incomplete = create(:tour)
      create(:move, tour: incomplete, square: "a1", position: 1)

      expect(Tour.distinct_complete_count).to eq(1)
    end
  end
end
