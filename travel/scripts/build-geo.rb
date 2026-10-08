#!/usr/bin/env ruby
# frozen_string_literal: true

# Builds the two geometry files the globe draws, from Natural Earth.
#
#   assets/geo/countries.json  every country, each marked visited or not
#   assets/geo/regions.json    only the states/provinces that were visited
#
# Run it with `make travel-geo`. The sources are cached in .geo-cache/, which
# git ignores, so a re-run costs nothing. The admin-1 source is 39 MB; only the
# filtered result is committed and served, which is a few hundred KB.
#
# Natural Earth is public domain (naturalearthdata.com). The page credits it
# anyway, as its authors suggest.
#
# WHY REGIONS ARE FOUND THREE WAYS
#
# A region's ISO 3166-2 code finds it when there is one and when Natural Earth
# agrees about it. Neither is guaranteed. Many regions in travel.yml carry no
# code at all, because a code is tedious to look up and is not what the data is
# for; and Natural Earth's admin-1 layer models some countries at a different
# level than travel.yml does: France as departements rather than regions, Italy
# and the Philippines as provinces, and Czechia under a code of its own
# invention.
#
# So a region is looked for by code, then by name within its country, and only
# then by the places inside it.
#
# That last way uses the places themselves: every polygon containing a visited
# city or point of interest is a polygon to fill. It needs no table of
# exceptions and cannot disagree with the dots, because it is derived from them.
# All matches are kept, not the first, or Tuscany would highlight the province
# holding Pisa and lose the one holding Florence.

require 'json'
require 'net/http'
require 'uri'
require 'yaml'

ROOT = File.expand_path('..', __dir__)
TRAVEL = File.join(ROOT, '_data', 'travel.yml')
CACHE = File.join(ROOT, '.geo-cache')
OUT = File.join(ROOT, 'assets', 'geo')

BASE = 'https://raw.githubusercontent.com/nvkelso/natural-earth-vector/master/geojson'
# 50m rather than 110m for the countries: the focus view magnifies up to forty
# times, and at that distance a 110m coastline is visibly a row of straight
# lines. 50m costs about 150 KB more once filtered and simplified.
SOURCES = {
  'countries' => 'ne_50m_admin_0_countries.geojson',
  'admin1' => 'ne_10m_admin_1_states_provinces.geojson'
}.freeze

# The keys under a region that hold places. A region is located by the places
# inside it when neither its code nor its name finds it, and every kind of
# place counts equally for that.
PLACE_KEYS = %w[cities pois highmark].freeze

# Rounding is the cheapest size win available without a topology tool. Three
# decimals is about 100 m, far finer than a globe can show.
PRECISION = 3

def fetch(name, file)
  path = File.join(CACHE, file)
  return path if File.exist?(path)

  Dir.mkdir(CACHE) unless Dir.exist?(CACHE)
  warn "downloading #{name} (#{file}) ..."
  uri = URI("#{BASE}/#{file}")
  Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) do |http|
    File.open(path, 'wb') do |out|
      http.request(Net::HTTP::Get.new(uri)) { |response| response.read_body { |chunk| out.write(chunk) } }
    end
  end
  path
end

def round_coordinates(node)
  case node
  when Array
    node[0].is_a?(Numeric) ? node.map { |n| n.round(PRECISION) } : node.map { |child| round_coordinates(child) }
  else
    node
  end
end

# Ray casting. Holes are subtracted rather than ignored, because a capital city
# is exactly the case that needs it: Prague is a hole punched in the region that
# surrounds it, so ignoring holes put Prague in Stredocesky.
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

# How far outside a polygon a city may fall and still count as inside it, in
# degrees: about 25 km. A coastal city often geocodes to the water, because that
# is where its centre is — Genoa's point lands in the old port, which Natural
# Earth's coastline excludes, so strict containment put Liguria nowhere.
NEAR_DEGREES = 0.25

# Distance from a point to the closest vertex of a geometry. Vertex distance
# rather than true distance to the edge: a coarse measure is enough to choose
# between provinces tens of kilometres apart, and it cannot pick a far one.
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

# Ramer-Douglas-Peucker. The 10m geometry carries detail no globe can resolve:
# unsimplified it is a megabyte for 45 regions. EPSILON is in degrees, so about
# a kilometre, which is under one screen pixel at any whole-globe zoom.
EPSILON = 0.01

# The country layer is background: at the closest focus it sits behind the
# region being looked at, which is drawn from much finer data. So it is
# simplified harder than the regions are, which is what keeps it from being
# four times their weight.
COUNTRY_EPSILON = 0.03

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

# A ring must stay closed, keep at least three corners, and still describe the
# same patch of ground. The last of those is why the area is checked:
# simplifying hard enough can reverse a ring's winding or flatten it, and d3
# then paints the whole globe in that country's colour instead of the country.
# Antarctica is the usual victim, because its boundary runs along the pole,
# those points are collinear, and dropping them destroys the ring.
#
# Where simplification would do that, the original ring is kept. A few rings
# staying large is a far better outcome than a planet painted beige.
def simplify_ring(ring, epsilon = EPSILON)
  simplified = simplify(ring, epsilon)
  return ring if simplified.length < 4

  simplified[-1] = simplified[0]

  before = signed_area(ring)
  after = signed_area(simplified)
  return ring if before.zero? || after.zero?
  return ring if before.positive? != after.positive?
  return ring if ((after - before).abs / before.abs) > 0.2

  simplified
end

def simplify_geometry(geometry, epsilon = EPSILON)
  polygons = geometry['type'] == 'Polygon' ? [geometry['coordinates']] : geometry['coordinates']
  simplified = polygons.map { |rings| rings.map { |ring| simplify_ring(ring, epsilon) }.compact }
                       .reject { |rings| rings.empty? }
  return nil if simplified.empty?

  if geometry['type'] == 'Polygon'
    { 'type' => 'Polygon', 'coordinates' => simplified.first }
  else
    { 'type' => 'MultiPolygon', 'coordinates' => simplified }
  end
end

travel = YAML.load_file(TRAVEL)

visited_countries = {}
wanted_regions = {}
travel['continents'].each do |continent|
  continent['countries'].each do |country|
    visited_countries[country['code']] = country['name']
    (country['regions'] || []).each do |region|
      # A code is optional in the data, so it cannot be the identifier. The
      # country and the name together always exist and are always unique, and
      # the page uses the same key, so the two agree without being told to.
      key = region['code'] || "#{country['code']}:#{region['name']}"
      places = PLACE_KEYS.flat_map { |key| region[key] || [] }.reject { |place| place['lat'].nil? }
      wanted_regions[key] = {
        'name' => region['name'],
        'code' => region['code'],
        'country' => country['code'],
        'places' => places.map { |place| [place['lon'].to_f, place['lat'].to_f] }
      }
    end
  end
end

Dir.mkdir(OUT) unless Dir.exist?(OUT)

# --- countries -------------------------------------------------------------

countries = JSON.parse(File.read(fetch('countries', SOURCES['countries'])))
country_features = countries['features'].map do |feature|
  properties = feature['properties']
  iso = properties['ISO_A2_EH'].to_s
  iso = properties['ISO_A2'].to_s if iso.empty? || iso == '-99'
  {
    'type' => 'Feature',
    'properties' => {
      'iso' => iso,
      'name' => properties['NAME'],
      'visited' => visited_countries.key?(iso)
    },
    'geometry' => simplify_geometry(feature['geometry'], COUNTRY_EPSILON).then { |g| g.merge('coordinates' => round_coordinates(g['coordinates'])) }
  }
end.reject { |f| f['geometry'].nil? }

matched_countries = country_features.count { |f| f['properties']['visited'] }
File.write(File.join(OUT, 'countries.json'),
           JSON.generate({ 'type' => 'FeatureCollection', 'features' => country_features }))

# --- regions ---------------------------------------------------------------

admin1 = JSON.parse(File.read(fetch('admin1', SOURCES['admin1'])))

by_code = {}
admin1['features'].each do |feature|
  code = feature['properties']['iso_3166_2']
  by_code[code] = feature if code && !by_code.key?(code)
end

region_features = []
by_code_count = 0
by_city_count = 0
by_name_count = 0
unresolved = []

wanted_regions.each do |key, want|
  matches =
    if want['code'] && by_code[want['code']]
      [[by_code[want['code']], 'code']]
    elsif (by_name = admin1['features'].find { |f|
             f['properties']['iso_a2'] == want['country'] &&
               f['properties']['name'].to_s.casecmp?(want['name'].to_s)
           })
      # No code, or a code Natural Earth does not use. The name within the
      # right country is unambiguous for a state or a province.
      [[by_name, 'name']]
    else
      # Every polygon of that country holding a visited city, so a region split
      # across several of Natural Earth's units keeps all of them.
      candidates = admin1['features'].select { |f| f['properties']['iso_a2'] == want['country'] }
      inside = candidates.select { |f| want['places'].any? { |lon, lat| geometry_contains?(f['geometry'], lon, lat) } }
      if inside.empty?
        # Nothing contains the city, so take the closest polygon instead, as
        # long as it is genuinely close.
        nearest = candidates.map { |f| [f, want['places'].map { |lon, lat| distance_to(f['geometry'], lon, lat) }.min] }
                            .min_by(&:last)
        nearest && nearest.last <= NEAR_DEGREES ? [[nearest.first, 'near']] : []
      else
        inside.map { |f| [f, 'city'] }
      end
    end

  if matches.empty?
    unresolved << "#{key} #{want['name']} (located places: #{want['places'].size})"
    next
  end

  matches.each do |feature, how|
    geometry = simplify_geometry(feature['geometry'])
    next if geometry.nil?

    case how
    when 'code' then by_code_count += 1
    when 'name' then by_name_count += 1
    else by_city_count += 1
    end
    region_features << {
      'type' => 'Feature',
      'properties' => {
        'key' => key,
        'code' => want['code'],
        'name' => want['name'],
        'source_name' => feature['properties']['name'],
        'country' => want['country'],
        'matched_by' => how
      },
      'geometry' => geometry.merge('coordinates' => round_coordinates(geometry['coordinates']))
    }
  end
  puts format('  %-22s %-26s -> %s (%s)', key, want['name'],
              matches.map { |f, _| f['properties']['name'] }.join(', '), matches.first[1])
end

File.write(File.join(OUT, 'regions.json'),
           JSON.generate({ 'type' => 'FeatureCollection', 'features' => region_features }))

puts
puts "countries: #{country_features.size} written, #{matched_countries} of #{visited_countries.size} marked visited"
puts "regions:   #{region_features.size} of #{wanted_regions.size} written " \
     "(#{by_code_count} by code, #{by_name_count} by name, #{by_city_count} by place)"
%w[countries.json regions.json].each do |file|
  puts format('  %-16s %6d KB', file, File.size(File.join(OUT, file)) / 1024)
end

unless unresolved.empty?
  puts "could not locate #{unresolved.size}:"
  unresolved.each { |line| puts "  #{line}" }
  exit 1
end
