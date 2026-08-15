class Tour < ApplicationRecord
  has_many :moves, -> { order(:position) }, dependent: :destroy, inverse_of: :tour, autosave: true

  validates :moves, presence: true, on: :save_tour
end
