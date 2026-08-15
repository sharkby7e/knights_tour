# frozen_string_literal: true

COMPLETE_TOUR_SQUARES = %w[
  a1 b3 a5 b7 d8 f7 h8 g6 f8 h7 g5 h3 g1 e2 c1 a2 b4 a6 b8 c6 a7 c8 e7 g8
  h6 g4 h2 f1 g3 h1 f2 d1 b2 a4 b6 a8 c7 e8 g7 h5 f6 d7 e5 d3 c5 e6 f4 d5
  c3 e4 d6 b5 d4 f5 h4 g2 e3 c4 d2 f3 e1 c2 a3 b1
].freeze

FactoryBot.define do
  factory :tour do
    trait :complete do
      after(:create) do |tour|
        COMPLETE_TOUR_SQUARES.each_with_index { |square, i| create(:move, tour:, square:, position: i + 1) }
      end
    end
  end

  factory :move do
    tour
    sequence(:position) { |n| n }
    square { "e4" }
  end
end
