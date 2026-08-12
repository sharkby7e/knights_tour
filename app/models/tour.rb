class Tour < ApplicationRecord
  has_many :moves, -> { order(:position) }, dependent: :destroy, inverse_of: :tour

  def self.current
    order(id: :desc).first || create!
  end
end
