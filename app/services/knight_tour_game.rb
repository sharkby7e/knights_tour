class KnightTourGame
  def visit!(x:, y:)
    Square.update_all(has_knight: false)
    square = Square.find_by!(x: x, y: y)
    square.update!(has_knight: true, has_been_visited: true)
    square
  end

  def legal_moves_from(square)
    MoveFinder.new(square: square).legal_moves
      .filter_map { |x, y| Square.find_by(x: x, y: y) }
      .reject(&:has_been_visited?)
  end

  def visited_count
    Square.where(has_been_visited: true).count
  end

  def won?
    visited_count == 64
  end

  def stuck?(square)
    legal_moves_from(square).empty?
  end

  def reset!
    Square.update_all(has_knight: false, has_been_visited: false)
  end
end
