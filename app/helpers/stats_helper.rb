module StatsHelper
  HEAT_DOT_RADIUS = 5.5

  # Viridis - perceptually uniform and colorblind-safe.
  HEAT_COLOR_STOPS = [
    [ 0.0, [ 0x44, 0x01, 0x54 ] ], # purple - fewest visits
    [ 0.5, [ 0x21, 0x90, 0x8c ] ], # teal - middle
    [ 1.0, [ 0xfd, 0xe7, 0x25 ] ]  # yellow - most visits
  ].freeze

  # Scales against the observed range of visited squares (min_count..max_count), not
  # an absolute 0, so the least-visited square always reads as the coldest color and
  # the spectrum isn't compressed toward one end when counts cluster together.
  def heat_color(count, min_count, max_count)
    return nil if count.zero? || max_count.zero?

    intensity = min_count == max_count ? 1.0 : (count - min_count).to_f / (max_count - min_count)
    (lo_t, lo_rgb), (hi_t, hi_rgb) = HEAT_COLOR_STOPS.each_cons(2).find { |(a, _), (b, _)| intensity.between?(a, b) }
    ratio = (intensity - lo_t) / (hi_t - lo_t)
    rgb = lo_rgb.zip(hi_rgb).map { |lo, hi| (lo + (hi - lo) * ratio).round }
    format("#%02x%02x%02x", *rgb)
  end

  def heat_gradient_css
    "linear-gradient(to right, #{HEAT_COLOR_STOPS.map { |_, rgb| format('#%02x%02x%02x', *rgb) }.join(', ')})"
  end
end
