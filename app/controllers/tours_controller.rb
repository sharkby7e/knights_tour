class ToursController < ApplicationController
  def current
    @tour = Tour.current
    @game = KnightTourGame.new(tour: @tour)
    render :show
  end

  def show
    @tour = Tour.find(params[:id])
    @game = KnightTourGame.new(tour: @tour)
  end

  def create
    Tour.create!
    redirect_to root_path
  end
end
