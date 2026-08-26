class ToursController < ApplicationController
  before_action :set_tour, only: [ :show ]

  def index
    @status = (params[:status] in "complete" | "incomplete") ? params[:status] : nil
    scope = Tour.includes(:moves).order(created_at: :desc)
    scope = scope.complete if @status == "complete"
    scope = scope.incomplete if @status == "incomplete"
    @pagy, @tours = pagy(scope, limit: 6)
  end

  def new
    @squares = Square.all
  end

  def show; end

  def create
    tour = Tour.new(name: create_params[:name])
    create_params.fetch(:moves, []).each.with_index(1) { |square, position| tour.moves.build(square:, position:) }

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
    params.permit(:name, moves: [])
  end
end
