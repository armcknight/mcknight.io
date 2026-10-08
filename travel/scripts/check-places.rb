#!/usr/bin/env ruby
# frozen_string_literal: true

# Checks every located place against the polygon of the region it is filed
# under, and reports anything that has no coordinates yet.
#
# Run it with `make travel-check`. It reads only committed files, so it needs no
# network and costs nothing.
#
# WHY THIS EXISTS
#
# A geocoder is confidently wrong often enough to matter. Over one afternoon it
# put Gray's Peak in Oklahoma, the Painted Desert in Anaheim, and Skyline Drive
# on a residential street in Norfolk. Each was a plausible-looking answer to a
# slightly ambiguous name, and each would have sat on the map unnoticed.
#
# WHAT IT CANNOT DO
#
# It only knows whether a place is in the right region. A wrong answer inside
# the right region looks right to it: Ka Lae was on Kauai and Kapa'au on
# Molokai, both hundreds of kilometres out and both still in Hawaii. Read new
# coordinates; this is a safety net, not a substitute.

require 'json'
require 'yaml'

ROOT = File.expand_path('..', __dir__)
PLACE_KEYS = %w[cities pois highmark].freeze

# How far outside its region a place may sit before it is reported, in degrees:
# about 25 km. A coastal place often geocodes to the water, which the region
# polygon excludes.
TOLERANCE = 0.25

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

def geometry_contains?(geometry, lon, lat)
  polygons = geometry['type'] == 'Polygon' ? [geometry['coordinates']] : geometry['coordinates']
  polygons.any? do |rings|
    outer, *holes = rings
    ring_contains?(outer, lon, lat) && holes.none? { |hole| ring_contains?(hole, lon, lat) }
  end
end

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

travel = YAML.load_file(File.join(ROOT, '_data', 'travel.yml'))
regions_path = File.join(ROOT, 'assets', 'geo', 'regions.json')
unless File.exist?(regions_path)
  warn 'No geometry yet. Run `make travel-geo` first.'
  exit 1
end

shapes = Hash.new { |hash, key| hash[key] = [] }
JSON.parse(File.read(regions_path))['features'].each do |feature|
  shapes[feature['properties']['key']] << feature['geometry']
end

checked = 0
outside = []
unlocated = []
no_geometry = []

travel['continents'].each do |continent|
  continent['countries'].each do |country|
    (country['regions'] || []).each do |region|
      key = region['code'] || "#{country['code']}:#{region['name']}"
      region_shapes = shapes[key]
      no_geometry << "#{region['name']} (#{key})" if region_shapes.empty?

      PLACE_KEYS.each do |kind|
        places = region[kind]
        next if places.nil?

        # A place still written in shorthand is a string, not a place yet.
        places = [places] if places.is_a?(String)
        places.each do |place|
          name = place.is_a?(Hash) ? place['name'] : place
          unless place.is_a?(Hash) && place['lat'] && place['lon']
            unlocated << "#{name} (#{region['name']}, #{kind})"
            next
          end
          next if region_shapes.empty?

          checked += 1
          lon = place['lon'].to_f
          lat = place['lat'].to_f
          next if region_shapes.any? { |geometry| geometry_contains?(geometry, lon, lat) }

          away = region_shapes.map { |geometry| distance_to(geometry, lon, lat) }.min
          next if away <= TOLERANCE

          outside << format('  %-40s %-18s %5.2f deg (%4d km) at %.4f, %.4f',
                            name, region['name'], away, (away * 111).round, lat, lon)
        end
      end
    end
  end
end

puts "checked #{checked} located places against their region"

unless no_geometry.empty?
  puts "no geometry for #{no_geometry.size} region(s) — run `make travel-geo`:"
  no_geometry.each { |line| puts "  #{line}" }
end

unless unlocated.empty?
  puts "#{unlocated.size} place(s) have no coordinates — run `make travel-geocode`:"
  unlocated.each { |line| puts "  #{line}" }
end

if outside.empty?
  puts "all sit inside, or within #{(TOLERANCE * 111).round} km of, the region they are filed under"
else
  puts "#{outside.size} sit somewhere else:"
  puts outside
end

exit(outside.empty? ? 0 : 1)
