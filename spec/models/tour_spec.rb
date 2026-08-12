require "rails_helper"

RSpec.describe Tour do
  describe ".current" do
    it "returns the most recently created tour" do
      create(:tour)
      latest = create(:tour)

      expect(Tour.current).to eq(latest)
    end

    it "creates a tour if none exists" do
      expect { Tour.current }.to change(Tour, :count).by(1)
    end
  end

  it "leaves a prior tour's moves intact when a new tour is created" do
    old_tour = create(:tour)
    old_move = create(:move, tour: old_tour)

    create(:tour)

    expect(old_move.reload).to be_persisted
  end
end
