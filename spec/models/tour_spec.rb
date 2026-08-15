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
end
