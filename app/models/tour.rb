class Tour < ApplicationRecord
  has_many :moves, -> { order(:position) }, dependent: :destroy, inverse_of: :tour, autosave: true

  validates :moves, presence: true, on: :save_tour

  FULL_TOUR_LENGTH = 64

  scope :complete, -> {
    where(id: Move.group(:tour_id).having(Move.arel_table[:id].count.eq(FULL_TOUR_LENGTH)).select(:tour_id))
  }
  scope :incomplete, -> { where.not(id: complete) }
end
