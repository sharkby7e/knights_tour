require "rails_helper"

RSpec.describe Square do
  describe ".from_notation" do
    it "parses algebraic notation into x/y coordinates" do
      square = Square.from_notation("e4")

      expect(square.x).to eq 5
      expect(square.y).to eq 4
    end

    it "raises for malformed notation" do
      expect { Square.from_notation("z9") }.to raise_error(ArgumentError)
    end
  end

  describe "#notation" do
    it "round-trips back to the original algebraic notation" do
      expect(Square.from_notation("e4").notation).to eq "e4"
    end

    it "renders the a1 corner correctly" do
      expect(Square.new(x: 1, y: 1).notation).to eq "a1"
    end

    it "renders the h8 corner correctly" do
      expect(Square.new(x: 8, y: 8).notation).to eq "h8"
    end
  end

  describe "#dom_id" do
    it "is derived from notation" do
      expect(Square.from_notation("e4").dom_id).to eq "square_e4"
    end
  end

  describe "#initialize" do
    it "raises when x is out of bounds" do
      expect { Square.new(x: 9, y: 1) }.to raise_error(ArgumentError)
      expect { Square.new(x: 0, y: 1) }.to raise_error(ArgumentError)
    end

    it "raises when y is out of bounds" do
      expect { Square.new(x: 1, y: 9) }.to raise_error(ArgumentError)
      expect { Square.new(x: 1, y: 0) }.to raise_error(ArgumentError)
    end
  end

  describe "equality" do
    it "considers two squares with the same coordinates equal" do
      expect(Square.new(x: 3, y: 3)).to eq Square.new(x: 3, y: 3)
    end

    it "is usable with Array#include? and #uniq" do
      squares = [ Square.new(x: 1, y: 1), Square.new(x: 1, y: 1), Square.new(x: 2, y: 2) ]

      expect(squares.uniq.size).to eq 2
      expect(squares).to include(Square.new(x: 2, y: 2))
    end
  end

  describe ".all" do
    it "returns all 64 unique squares" do
      expect(Square.all.size).to eq 64
      expect(Square.all.uniq.size).to eq 64
    end

    it "orders rank 8 down to rank 1, file a to h within each rank (matches the board's visual row-major layout)" do
      expect(Square.all.first).to eq Square.new(x: 1, y: 8)
      expect(Square.all[7]).to eq Square.new(x: 8, y: 8)
      expect(Square.all[8]).to eq Square.new(x: 1, y: 7)
      expect(Square.all.last).to eq Square.new(x: 8, y: 1)
    end
  end
end
