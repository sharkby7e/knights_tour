class ToursController < ApplicationController
  before_action :set_tour, only: [ :show ]

  def index
    @pagy, @tours = pagy(Tour.includes(:moves).order(created_at: :desc), limit: 2)
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
