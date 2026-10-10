# frozen_string_literal: true

require 'json'

module Travel
  # Point-in-region tests against the committed region polygons, shared by the
  # region check, the geometry build and the admin app.
  module Geometry
    REGIONS = File.expand_path('../../assets/geo/regions.json', __dir__)

    # How far outside its region a place may sit before it counts as outside,
    # in degrees: about 25 km. A coastal place often geocodes to the water,
    # which the region polygon excludes — Genoa's point lands in its old port.
    TOLERANCE = 0.25

    module_function

    # Ray casting. Holes are subtracted rather than ignored, because a capital
    # city is exactly the case that needs it: Prague is a hole punched in the
    # region that surrounds it, so ignoring holes put Prague in Stredocesky.
    def ring_contains?(ring, lon, lat)
      inside = false
      j = ring.length - 1
      ring.each_index do |i|
        xi, yi = ring[i]
        xj, yj = ring[j]
        if (yi > lat) != (yj > lat) && lon < ((xj - xi) * (lat - yi) / (yj - yi)) + xi
          inside = !inside
        end
        j = i
      end
      inside
    end

    def contains?(geometry, lon, lat)
      polygons = geometry['type'] == 'Polygon' ? [geometry['coordinates']] : geometry['coordinates']
      polygons.any? do |rings|
        outer, *holes = rings
        ring_contains?(outer, lon, lat) && holes.none? { |hole| ring_contains?(hole, lon, lat) }
      end
    end

    # Distance from a point to the closest vertex of a geometry, in degrees.
    # Vertex distance rather than true distance to the edge: a coarse measure is
    # enough to tell a coastal near miss from a place in the wrong state.
    def distance_to(geometry, lon, lat)
      best = Float::INFINITY
      stack = [geometry['coordinates']]
      until stack.empty?
        node = stack.pop
        if node[0].is_a?(Numeric)
          d = Math.sqrt(((node[0] - lon)**2) + ((node[1] - lat)**2))
          best = d if d < best
        else
          node.each { |child| stack << child }
        end
      end
      best
    end

    # Region key -> its polygons, from the committed geometry. Empty when the
    # geometry has not been built yet.
    def region_shapes(path = REGIONS)
      shapes = Hash.new { |hash, key| hash[key] = [] }
      return shapes unless File.exist?(path)

      JSON.parse(File.read(path))['features'].each do |feature|
        shapes[feature['properties']['key']] << feature['geometry']
      end
      shapes
    end

    # How far a point is outside the nearest of some regions, in degrees: zero
    # when it is inside one, nil when none of them has a shape to test against.
    def degrees_outside(shapes, keys, lon, lat)
      geometries = keys.flat_map { |key| shapes.key?(key) ? shapes[key] : [] }
      return nil if geometries.empty?
      return 0.0 if geometries.any? { |geometry| contains?(geometry, lon, lat) }

      geometries.map { |geometry| distance_to(geometry, lon, lat) }.min
    end
  end
end
