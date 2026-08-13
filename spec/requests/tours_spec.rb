require "rails_helper"

RSpec.describe "Tours", type: :request do
  describe "GET /" do
    it "does not create a tour" do
      expect { get root_path }.not_to change(Tour, :count)
    end

    it "renders the board skeleton with a Stimulus-controlled play area" do
      get root_path

      expect(response).to be_successful
      doc = Nokogiri::HTML5.fragment(response.body)
      expect(doc.at_css("[data-controller='tour']")).to be_present
      expect(doc.css("[data-square-notation]").count).to eq(64)
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
    it "creates a new tour and redirects to root, leaving the old tour's moves intact" do
      old_tour = create(:tour)
      old_move = create(:move, tour: old_tour)

      expect { post tours_path }.to change(Tour, :count).by(1)

      expect(response).to redirect_to(root_path)
      expect(old_move.reload).to be_persisted
    end
  end
end
