class StatsController < ApplicationController
  def show
    @tour_count = Tour.count
    @complete_count = Tour.complete.count
    @incomplete_count = Tour.incomplete.count
    @total_moves = Move.count
    @average_moves = @tour_count.zero? ? nil : (@total_moves.to_f / @tour_count).round(1)
    @distinct_tour_count = Tour.distinct_complete_count
    @discovery_percent = (BigDecimal(@distinct_tour_count).div(BigDecimal(Tour::TOTAL_POSSIBLE_TOURS), 30) * 100).round(20)
    @discovery_bar_percent = [ @discovery_percent, BigDecimal(1) ].max
    @visit_counts = Move.visit_counts
    @max_visit_count = @visit_counts.values.max || 0
    @min_visit_count = @visit_counts.values.min || 0
  end
end
