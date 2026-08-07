require 'rails_helper'

RSpec.describe SquaresController, type: :request do
  describe '#index' do
    it 'works' do
      get(squares_path)
      expect(response).to(be_successful)
    end

    it 'assigns the legal squares' do
      located_square = Square.create!(x: 1, y: 1)
      legal_square = Square.create!(x: 2, y: 3)
      another_legal_square = Square.create!(x: 3, y: 2)

      params = { location: { x: 1, y: 1 } }
      get(squares_path(params))

      expect(assigns[:located_square]).to eq located_square
      expect(assigns[:legal_squares]).to eq [ legal_square, another_legal_square ]
    end
  end
end
