class MovesController < ApplicationController
  before_action :set_game

  def create
    previous_square = @game.current_square
    previous_legal_squares = @game.legal_moves_from
    square = Square.from_notation(params[:square])

    @game.visit!(square)

    @squares_to_refresh = ([ previous_square, square ] + previous_legal_squares + @game.legal_moves_from).compact.uniq

    respond_to do |format|
      format.turbo_stream
      format.html { redirect_to tour_path(@tour) }
    end
  rescue ArgumentError, KnightTourGame::IllegalMoveError
    head :unprocessable_content
  end

  def destroy
    undone_square = @game.current_square
    previous_legal_squares = @game.legal_moves_from
    @was_stuck = @game.stuck?

    @game.undo!

    @squares_to_refresh = ([ undone_square, @game.current_square ] + previous_legal_squares + @game.legal_moves_from).compact.uniq

    respond_to do |format|
      format.turbo_stream
      format.html { redirect_to tour_path(@tour) }
    end
  end

  private

  def set_game
    @tour = Tour.find(params[:tour_id])
    @game = KnightTourGame.new(tour: @tour)
  end
end
