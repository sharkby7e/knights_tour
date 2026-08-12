class MoveFinder
  MOVE_SET = [ [ 1, 2 ], [ 2, 1 ], [ 2, -1 ], [ 1, -2 ], [ -1, -2 ], [ -2, -1 ], [ -2, 1 ], [ -1, 2 ] ].freeze

  attr_accessor :x, :y

  def initialize(square:)
    @x = square.x
    @y = square.y
  end

  def legal_moves
    move_candidates
      .select { |x, y| (1..8).cover?(x) && (1..8).cover?(y) }
      .map { |x, y| Square.new(x:, y:) }
  end

  def move_candidates
    MOVE_SET.map { |move| move(move) }
  end

  def move(move)
    [ x + move[0], y + move[1] ]
  end
end
