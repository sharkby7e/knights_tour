class ToursController < ApplicationController
  before_action :set_tour, only: [ :show ]

  def index
    @tours = Tour.includes(:moves).order(created_at: :desc)
  end

  def new; end

  def show; end

  def create
    Tour.create!
    redirect_to root_path
  end

  private

  def set_tour
    @tour = Tour.find(params[:id])
  end
end
