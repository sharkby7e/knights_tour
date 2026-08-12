require 'rails_helper'

RSpec.describe KnightTourGame do
  let(:tour) { create(:tour) }
  let(:game) { described_class.new(tour:) }

  describe '#current_square' do
    it 'is nil when no moves have been made' do
      expect(game.current_square).to be_nil
    end

    it 'is the most recently visited square' do
      create(:move, tour:, square: 'a1', position: 1)
      create(:move, tour:, square: 'b3', position: 2)

      expect(game.current_square).to eq Square.from_notation('b3')
    end
  end

  describe '#legal_moves_from' do
    it 'allows any square as the first move' do
      expect(game.legal_moves_from).to eq Square.all
    end

    it 'returns the squares reachable by a knight move from the current position' do
      create(:move, tour:, square: 'a1', position: 1)

      expect(game.legal_moves_from).to contain_exactly(Square.from_notation('c2'), Square.from_notation('b3'))
    end

    it 'excludes squares that have already been visited' do
      create(:move, tour:, square: 'c2', position: 1)
      create(:move, tour:, square: 'a1', position: 2)

      expect(game.legal_moves_from).to eq [ Square.from_notation('b3') ]
    end
  end

  describe '#visit!' do
    it 'records a legal move' do
      game.visit!(Square.from_notation('a1'))

      expect(tour.moves.pluck(:square)).to eq [ 'a1' ]
    end

    it 'raises and records nothing for an illegal move' do
      create(:move, tour:, square: 'a1', position: 1)

      expect { game.visit!(Square.from_notation('h8')) }.to raise_error(KnightTourGame::IllegalMoveError)
      expect(tour.moves.count).to eq 1
    end
  end

  describe '#visited_count' do
    it 'counts the moves made in the tour' do
      create(:move, tour:, square: 'a1', position: 1)
      create(:move, tour:, square: 'b3', position: 2)

      expect(game.visited_count).to eq 2
    end
  end

  describe '#won?' do
    it 'is true once every square has been visited' do
      Square.all.each_with_index { |square, i| create(:move, tour:, square: square.notation, position: i + 1) }

      expect(game.won?).to be true
    end

    it 'is false otherwise' do
      create(:move, tour:, square: 'a1', position: 1)

      expect(game.won?).to be false
    end
  end

  describe '#stuck?' do
    it 'is true when every legal move from the current square has already been visited' do
      # A real, legal sequence of knight moves that dead-ends in the a1 corner:
      # c2 -> d4 -> b3 -> a1. a1 only has two legal moves (b3, c2), both already visited.
      create(:move, tour:, square: 'c2', position: 1)
      create(:move, tour:, square: 'd4', position: 2)
      create(:move, tour:, square: 'b3', position: 3)
      create(:move, tour:, square: 'a1', position: 4)

      expect(game.stuck?).to be true
    end

    it 'is false when a legal move remains' do
      create(:move, tour:, square: 'a1', position: 1)

      expect(game.stuck?).to be false
    end

    it 'is false before any move has been made' do
      expect(game.stuck?).to be false
    end
  end

  describe '#undo!' do
    it 'removes the last move' do
      create(:move, tour:, square: 'a1', position: 1)
      create(:move, tour:, square: 'b3', position: 2)

      game.undo!

      expect(tour.moves.pluck(:square)).to eq [ 'a1' ]
    end

    it 'reverts the current square' do
      create(:move, tour:, square: 'a1', position: 1)
      create(:move, tour:, square: 'b3', position: 2)

      game.undo!

      expect(game.current_square).to eq Square.from_notation('a1')
    end

    it 'is a no-op on an empty tour' do
      expect { game.undo! }.not_to raise_error
      expect(tour.moves.count).to eq 0
    end
  end
end
