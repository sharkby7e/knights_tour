class ToursController < ApplicationController
  def new; end

  def show
    @tour = Tour.find(params[:id])
    @game = KnightTourGame.new(tour: @tour)
  end

  def create
    Tour.create!
    redirect_to root_path
  end
end
