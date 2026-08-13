# Hardcoded knight paths for the tours index prototype: each inner array is a
# legal knight's-tour move sequence (consecutive squares are a knight's move
# apart, no repeats). Three finish all 64 squares; two dead-end partway,
# giving the index a realistic complete/incomplete mix to render against.
SEED_TOURS = [
  %w[a1 b3 c1 a2 b4 a6 b8 d7 f8 h7 g5 h3 g1 e2 g3 h1 f2 d1 b2 a4 b6 a8 c7 e8
     g7 h5 f6 g8 h6 g4 h2 f1 d2 b1 c3 e4 c5 e6 d8 b7 a5 c6 a7 c8 e7 d5 f4 d3
     e1 g2 h4 f3 d4 f5 e3 c2 a3 b5 d6 c4 e5 f7 h8 g6],
  %w[h8 g6 h4 g2 e1 c2 a1 b3 c1 a2 b4 a6 b8 d7 f8 h7 g5 h3 g1 e2 f4 h5 g7 e8
     f6 g8 h6 f7 d8 e6 c7 a8 b6 c8 a7 c6 e7 d5 e3 f5 d4 f3 h2 f1 g3 h1 f2 g4
     e5 d3 b2 d1 c3 a4 c5 e4 d2 b1 a3 b5 d6 c4 a5 b7],
  %w[d4 e2 g1 h3 f2 h1 g3 h5 g7 e8 c7 a8 b6 c8 a7 b5 a3 b1 c3 d1 b2 a4 c5 a6
     b8 d7 f8 h7 g5 e6 d8 b7 a5 c6 e7 g8 h6 f5 h4 g2 e1 f3 h2 f1 d2 e4 f6 g4
     e3 c2 a1 b3 c1 a2 b4 d5 f4 d3 e5 g6 h8 f7 d6 c4],
  %w[a1 b3 c5 d7 f8 h7 g5 h3 g1 e2 f4 g6 h8 f7 h6 g4 h2 f1 g3 h5 f6 g8 e7 f5
     g7 e6 d4 f3 h4 g2 e1 c2 e3 d1 f2 h1],
  %w[h1 f2 g4 h6 f5 g7 h5 g3 f1 h2 f3 g5 h7 f6 g8 e7 g6 h8 f7 e5 d3 f4 h3 g1
     e2 c1 a2 b4 c6 d8 e6 f8 d7 c5 e4 d2 b1 c3 d5 e3 g2 h4]
].freeze

Tour.destroy_all

SEED_TOURS.each do |squares|
  tour = Tour.create!
  squares.each_with_index do |square, i|
    tour.moves.create!(square:, position: i + 1)
  end
end

puts "Seeded #{Tour.count} tours (#{Tour.joins(:moves).group(:tour_id).count.count { |_, n| n == 64 }} complete)."
