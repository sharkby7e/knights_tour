class Move < ApplicationRecord
  SQUARE_FORMAT = /\A[a-h][1-8]\z/

  belongs_to :tour

  validates :square, presence: true, format: { with: SQUARE_FORMAT }
  validates :square, uniqueness: { scope: :tour_id }
  validates :position, presence: true, numericality: { only_integer: true, greater_than: 0 },
                        uniqueness: { scope: :tour_id }
  validate :legal_knight_move_from_previous

  def self.visit_counts = group(:square).count

  def to_square = Square.from_notation(square)

  private

  def legal_knight_move_from_previous
    return unless square&.match?(SQUARE_FORMAT) && position && position > 1

    previous_move = tour&.moves&.to_a&.find { |m| m.position == position - 1 }
    return unless previous_move

    dx = (to_square.x - previous_move.to_square.x).abs
    dy = (to_square.y - previous_move.to_square.y).abs
    errors.add(:square, "is not a legal knight's-move from the previous move") unless [ dx, dy ].sort == [ 1, 2 ]
  end
end
