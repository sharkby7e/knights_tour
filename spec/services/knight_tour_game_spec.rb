require 'rails_helper'

RSpec.describe KnightTourGame do
  let(:game) { described_class.new }

  describe '#visit!' do
    it 'marks the square as carrying the knight and visited' do
      square = create(:square, x: 1, y: 1)

      visited = game.visit!(x: 1, y: 1)

      expect(visited).to eq square
      expect(square.reload.has_knight).to be true
      expect(square.reload.has_been_visited).to be true
    end

    it 'clears the knight from every other square' do
      previous = create(:square, x: 1, y: 1, has_knight: true)
      next_square = create(:square, x: 2, y: 3)

      game.visit!(x: 2, y: 3)

      expect(previous.reload.has_knight).to be false
      expect(next_square.reload.has_knight).to be true
    end
  end

  describe '#legal_moves_from' do
    it 'returns the squares reachable by a knight move' do
      square = create(:square, x: 1, y: 1)
      legal_square = create(:square, x: 2, y: 3)
      another_legal_square = create(:square, x: 3, y: 2)

      expect(game.legal_moves_from(square)).to eq [ legal_square, another_legal_square ]
    end

    it 'excludes squares that have already been visited' do
      square = create(:square, x: 1, y: 1)
      create(:square, x: 2, y: 3, has_been_visited: true)
      unvisited = create(:square, x: 3, y: 2)

      expect(game.legal_moves_from(square)).to eq [ unvisited ]
    end
  end

  describe '#visited_count' do
    it 'counts the squares marked as visited' do
      create(:square, x: 1, y: 1, has_been_visited: true)
      create(:square, x: 2, y: 2, has_been_visited: false)

      expect(game.visited_count).to eq 1
    end
  end

  describe '#won?' do
    it 'is true once every square has been visited' do
      64.times { |n| create(:square, x: (n % 8) + 1, y: (n / 8) + 1, has_been_visited: true) }

      expect(game.won?).to be true
    end

    it 'is false otherwise' do
      create(:square, x: 1, y: 1, has_been_visited: true)

      expect(game.won?).to be false
    end
  end

  describe '#stuck?' do
    it 'is true when every legal move has already been visited' do
      square = create(:square, x: 1, y: 1)
      create(:square, x: 2, y: 3, has_been_visited: true)
      create(:square, x: 3, y: 2, has_been_visited: true)

      expect(game.stuck?(square)).to be true
    end

    it 'is false when a legal move remains' do
      square = create(:square, x: 1, y: 1)
      create(:square, x: 2, y: 3)

      expect(game.stuck?(square)).to be false
    end
  end

  describe '#reset!' do
    it 'clears the visited and knight flags on every square' do
      create(:square, x: 1, y: 1, has_been_visited: true, has_knight: true)

      game.reset!

      expect(Square.pluck(:has_been_visited, :has_knight)).to eq [ [ false, false ] ]
    end
  end
end
