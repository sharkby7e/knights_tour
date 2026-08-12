require "rails_helper"

RSpec.describe "Tours", type: :request do
  describe "GET /" do
    it "redirects to the current tour, creating one if none exists" do
      expect { get root_path }.to change(Tour, :count).by(1)

      expect(response).to redirect_to(tour_path(Tour.last))
    end

    it "redirects to the existing current tour without creating another" do
      existing = create(:tour)

      expect { get root_path }.not_to change(Tour, :count)

      expect(response).to redirect_to(tour_path(existing))
    end
  end

  describe "GET /tours/:id" do
    it "is successful" do
      tour = create(:tour)

      get tour_path(tour)

      expect(response).to be_successful
    end
  end

  describe "POST /tours" do
    it "creates a new tour and redirects to it" do
      old_tour = create(:tour)
      old_move = create(:move, tour: old_tour)

      expect { post tours_path }.to change(Tour, :count).by(1)

      expect(response).to redirect_to(tour_path(Tour.last))
      expect(old_move.reload).to be_persisted
    end
  end
end
