class SquaresController < ApplicationController
  def index
    @game = KnightTourGame.new
    @squares = Square.order(y: :desc, x: :asc)

    if params[:location].blank?
      @game.reset!
      @new_game = true
      return
    end

    @located_square = @game.visit!(x: params[:location][:x], y: params[:location][:y])
    @legal_squares = @game.legal_moves_from(@located_square)
    @visited_squares = @game.visited_count
    @fail_state = @game.stuck?(@located_square)
  end
end
