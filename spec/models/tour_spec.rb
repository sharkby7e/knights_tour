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
end
