class KnightTourGame
  class IllegalMoveError < StandardError; end

  attr_reader :tour

  def initialize(tour:)
    @tour = tour
  end

  def current_square
    last_move && Square.from_notation(last_move.square)
  end

  def last_move
    moves.last
  end

  def visited?(square)
    visited_notations.include?(square.notation)
  end

  def legal_moves_from
    @legal_moves_from ||= if moves.none?
      Square.all
    else
      MoveFinder.new(square: current_square).legal_moves.reject { |square| visited?(square) }
    end
  end

  def visit!(square)
    raise IllegalMoveError, "#{square.notation} is not legal" unless legal_moves_from.include?(square)
    move = tour.moves.create!(square: square.notation, position: next_position)
    reset!
    move
  end

  def undo!
    last_move&.destroy
    reset!
  end

  def visited_count
    moves.size
  end

  def won?
    visited_count == 64
  end

  def stuck?
    visited_count.positive? && !won? && legal_moves_from.empty?
  end

  private

  # Loaded once per instance; visit!/undo! call reset! so a single
  # KnightTourGame stays consistent across a mutation + subsequent reads.
  def moves
    @moves ||= tour.moves.order(:position).to_a
  end

  def visited_notations
    @visited_notations ||= moves.map(&:square).to_set
  end

  def next_position
    (moves.map(&:position).max || 0) + 1
  end

  def reset!
    @moves = nil
    @legal_moves_from = nil
    @visited_notations = nil
  end
end
