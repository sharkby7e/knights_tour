# frozen_string_literal: true

FactoryBot.define do
  factory :tour do
    trait :complete do
      after(:create) do |tour|
        Square.all.each_with_index { |square, i| create(:move, tour:, square: square.notation, position: i + 1) }
      end
    end
  end

  factory :move do
    tour
    sequence(:position) { |n| n }
    square { "e4" }
  end
end
