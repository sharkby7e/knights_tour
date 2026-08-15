class Tour < ApplicationRecord
  has_many :moves, -> { order(:position) }, dependent: :destroy, inverse_of: :tour

  validates :moves, presence: true, on: :save_tour
end
