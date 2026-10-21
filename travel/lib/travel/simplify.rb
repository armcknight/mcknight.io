# frozen_string_literal: true

module Travel
  # Simplifying Natural Earth polygons for a globe, without breaking them:
  # Ramer-Douglas-Peucker, rounding to a grid, and dropping any ring that the
  # two together would turn inside out. Shared by travel's geometry build and
  # the books site's (books/scripts/build-geo.rb).
  module Simplify
    # Rounding is the cheapest size win available without a topology tool. Three
    # decimals is about 100 m, far finer than a globe can show.
    PRECISION = 3

    # Ramer-Douglas-Peucker. The 10m geometry carries detail no globe can resolve:
    # unsimplified it is a megabyte for 45 regions. EPSILON is in degrees, so about
    # a kilometre, which is under one screen pixel at any whole-globe zoom.
    EPSILON = 0.01

    module_function

    def perpendicular_distance(point, line_start, line_end)
      x, y = point
      x1, y1 = line_start
      x2, y2 = line_end
      dx = x2 - x1
      dy = y2 - y1
      return Math.sqrt(((x - x1)**2) + ((y - y1)**2)) if dx.zero? && dy.zero?

      ((dy * x) - (dx * y) + (x2 * y1) - (y2 * x1)).abs / Math.sqrt((dx**2) + (dy**2))
    end

    def simplify(points, epsilon = EPSILON)
      return points if points.length < 3

      furthest = 0
      distance = 0.0
      (1...(points.length - 1)).each do |i|
        d = perpendicular_distance(points[i], points.first, points.last)
        if d > distance
          distance = d
          furthest = i
        end
      end

      if distance > epsilon
        left = simplify(points[0..furthest], epsilon)
        right = simplify(points[furthest..], epsilon)
        left[0..-2] + right
      else
        [points.first, points.last]
      end
    end

    # Signed area by the shoelace formula, in square degrees. The sign is the ring's
    # winding, which matters more here than the size: a sphere has no outside, so a
    # ring wound the wrong way no longer describes a country, it describes
    # everything except that country.
    def signed_area(ring)
      total = 0.0
      j = ring.length - 1
      ring.each_index do |i|
        total += (ring[j][0] + ring[i][0]) * (ring[j][1] - ring[i][1])
        j = i
      end
      total / 2.0
    end

    # The smallest area a ring may enclose and still be worth drawing, in square
    # degrees. Roughly a tenth of a square kilometre: far below one screen pixel.
    #
    # Size is measured by area rather than by width, because the dangerous shapes
    # are slivers — long, thin and enclosing almost nothing. Malawi gains one in the
    # lakes variant: five points enclosing two millionths of a square degree. Round
    # its corners to the grid and its winding reverses, and a reversed ring does not
    # describe a sliver, it describes everything except that sliver. d3 duly painted
    # the whole planet in Malawi's colour.
    SMALLEST_AREA = 1e-5

    # Rounding belongs here, with the checks, rather than afterwards: a ring that
    # survives simplification can still be ruined by being snapped to the grid, and
    # only a check applied to the final coordinates can see that.
    def round_ring(ring, precision)
      rounded = ring.map { |x, y| [x.round(precision), y.round(precision)] }
      deduped = rounded.chunk_while { |a, b| a == b }.map(&:first)
      deduped << deduped.first unless deduped.first == deduped.last
      deduped
    end

    # A ring must stay closed, keep at least three corners, enclose enough ground to
    # see, and still be wound the way it started. Anything that fails is dropped
    # rather than repaired: the obvious repair, falling back to the original ring, is
    # no repair at all when rounding is what broke it, since the original rounds the
    # same way.
    def simplify_ring(ring, epsilon = EPSILON, precision = PRECISION)
      before = signed_area(ring)
      return nil if before.abs < SMALLEST_AREA

      simplified = simplify(ring, epsilon)
      simplified = ring if simplified.length < 4
      simplified[-1] = simplified[0]

      final = round_ring(simplified, precision)
      return nil if final.length < 4

      after = signed_area(final)
      return nil if after.zero?
      return nil if before.positive? != after.positive?

      return final if ((after - before).abs / before.abs) <= 0.2

      # Simplified too far. The unsimplified ring, rounded, is the only other
      # candidate, and it is used only if it survives the same tests.
      fallback = round_ring(ring, precision)
      fallback_area = signed_area(fallback)
      return nil if fallback.length < 4 || fallback_area.zero?
      return nil if before.positive? != fallback_area.positive?

      fallback
    end

    def simplify_geometry(geometry, epsilon = EPSILON, precision = PRECISION)
      polygons = geometry['type'] == 'Polygon' ? [geometry['coordinates']] : geometry['coordinates']
      simplified = polygons.map do |rings|
        outer, *holes = rings
        kept_outer = simplify_ring(outer, epsilon, precision)
        # The whole polygon goes when its outer ring does. Compacting the list
        # instead would promote a hole to be the outline, which is worse than
        # losing the shape: the hole would be drawn as land.
        next nil if kept_outer.nil?

        [kept_outer] + holes.map { |hole| simplify_ring(hole, epsilon, precision) }.compact
      end.compact
      return nil if simplified.empty?

      if geometry['type'] == 'Polygon'
        { 'type' => 'Polygon', 'coordinates' => simplified.first }
      else
        { 'type' => 'MultiPolygon', 'coordinates' => simplified }
      end
    end
  end
end
