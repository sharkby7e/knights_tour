class ToursController < ApplicationController
  def current
    redirect_to tour_path(Tour.current)
  end

  def show
    @tour = Tour.find(params[:id])
    @game = KnightTourGame.new(tour: @tour)
  end

  def create
    @tour = Tour.create!
    redirect_to tour_path(@tour)
  end
end
