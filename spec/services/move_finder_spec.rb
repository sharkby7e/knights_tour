require 'rails_helper'

RSpec.describe MoveFinder do
  let(:square) { create(:square, x: 1, y: 1) }
  let(:finder) { MoveFinder.new(square:) }

  it 'initializes with a square with accessible coordinates' do
    expect(finder.x).to eq 1
  end

  describe '#move_candidates' do
    it 'provides an array of the possible moves given a square' do
      expect(finder.move_candidates).to eq [ [ 2, 3 ], [ 3, 2 ], [ 3, 0 ], [ 2, -1 ], [ 0, -1 ], [ -1, 0 ], [ -1, 2 ], [ 0, 3 ] ]
    end
  end

  describe '#legal_moves' do
    it 'filters out moves that are off the board' do
      expect(finder.legal_moves).to eq [ [ 2, 3 ], [ 3, 2 ] ]
    end

    it 'filters out moves with a coord greater than 8' do
      expect(finder).to receive(:move_candidates).and_return [ [ 2, 8 ], [ 9, 8 ], [ 2, 9 ] ]
      expect(finder.legal_moves).to eq [ [ 2, 8 ] ]
    end

    it 'filters out moves with a coord less than 1' do
      expect(finder).to receive(:move_candidates).and_return [ [ 0, 6 ], [ -1, 3 ], [ 2, -1 ] ]
      expect(finder.legal_moves).to eq []
    end
  end
end
