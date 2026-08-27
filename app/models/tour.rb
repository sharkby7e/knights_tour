class Tour < ApplicationRecord
  has_many :moves, -> { order(:position) }, dependent: :destroy, inverse_of: :tour, autosave: true

  validates :moves, presence: true, on: :save_tour

  FULL_TOUR_LENGTH = 64

  # Total directed Hamiltonian paths (knight's tours) on an 8x8 board — Guenter Stertenbrink, 2005.
  # https://www.mayhematics.com/t/8a.htm
  TOTAL_POSSIBLE_TOURS = 19_591_828_170_979_904

  scope :complete, -> {
    where(id: Move.group(:tour_id).having(Move.arel_table[:id].count.eq(FULL_TOUR_LENGTH)).select(:tour_id))
  }
  scope :incomplete, -> { where.not(id: complete) }

  def self.distinct_complete_count = complete.map { |tour| tour.moves.pluck(:square) }.uniq.size
end
