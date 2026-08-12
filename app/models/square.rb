class Square < Data.define(:x, :y)
  FILES = ("a".."h").to_a.freeze

  def self.from_notation(notation)
    match = notation.to_s.match(/\A([a-h])([1-8])\z/)
    raise ArgumentError, "invalid square: #{notation.inspect}" unless match
    new(x: FILES.index(match[1]) + 1, y: match[2].to_i)
  end

  def self.all
    @all ||= 8.downto(1).flat_map { |y| (1..8).map { |x| new(x:, y:) } }.freeze
  end

  def initialize(x:, y:)
    raise ArgumentError, "x out of bounds" unless (1..8).cover?(x)
    raise ArgumentError, "y out of bounds" unless (1..8).cover?(y)
    super
  end

  def notation = "#{FILES[x - 1]}#{y}"
  def dom_id = "square_#{notation}"
end
