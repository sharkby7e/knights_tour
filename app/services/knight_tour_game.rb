class KnightTourGame
  class IllegalMoveError < StandardError; end

  attr_reader :tour

  def initialize(tour:)
    @tour = tour
  end

  def current_square
    last = tour.moves.order(:position).last
    last && Square.from_notation(last.square)
  end

  def visited?(square)
    tour.moves.exists?(square: square.notation)
  end

  def legal_moves_from
    return Square.all if tour.moves.none?
    MoveFinder.new(square: current_square).legal_moves.reject { |square| visited?(square) }
  end

  def visit!(square)
    raise IllegalMoveError, "#{square.notation} is not legal" unless legal_moves_from.include?(square)
    tour.moves.create!(square: square.notation, position: next_position)
  end

  def undo!
    tour.moves.order(:position).last&.destroy
  end

  def visited_count
    tour.moves.count
  end

  def won?
    visited_count == 64
  end

  def stuck?
    visited_count.positive? && !won? && legal_moves_from.empty?
  end

  private

  def next_position
    (tour.moves.maximum(:position) || 0) + 1
  end
end
