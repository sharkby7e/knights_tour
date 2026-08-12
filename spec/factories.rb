# frozen_string_literal: true

FactoryBot.define do
  factory :tour

  factory :move do
    tour
    sequence(:position) { |n| n }
    square { "e4" }
  end
end
