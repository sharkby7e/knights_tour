class MovesController < ApplicationController
  before_action :set_game

  def create
    @game.visit!(Square.from_notation(params[:square]))
    redirect_to root_path
  rescue ArgumentError, KnightTourGame::IllegalMoveError
    head :unprocessable_content
  end

  def destroy
    @game.undo!
    redirect_to root_path
  end

  private

  def set_game
    @tour = Tour.find(params[:tour_id])
    @game = KnightTourGame.new(tour: @tour)
  end
end
