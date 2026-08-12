class Move < ApplicationRecord
  belongs_to :tour

  validates :square, presence: true, format: { with: /\A[a-h][1-8]\z/ }
  validates :square, uniqueness: { scope: :tour_id }
  validates :position, presence: true, numericality: { only_integer: true, greater_than: 0 },
                        uniqueness: { scope: :tour_id }

  def to_square = Square.from_notation(square)
end
