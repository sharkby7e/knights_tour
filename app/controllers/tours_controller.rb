class ToursController < ApplicationController
  before_action :set_tour, only: [ :show ]

  def index
    @pagy, @tours = pagy(Tour.includes(:moves).order(created_at: :desc), limit: 2)
  end

  def new; end

  def show; end

  def create
    tour = Tour.new
    create_params.each_with_index { |square, i| tour.moves.build(square:, position: i + 1) }

    if tour.save(context: :save_tour)
      render json: { redirect_url: tour_path(tour) }
    else
      render json: tour.errors, status: :unprocessable_entity
    end
  end

  private

  def set_tour
    @tour = Tour.find(params[:id])
  end

  def create_params
    params.permit(moves: []).fetch(:moves, [])
  end
end
