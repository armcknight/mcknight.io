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
# agrees about it. Neither is guaranteed. Many regions in regions.yml carry no
# code at all, because a code is tedious to look up and is not what the data is
# for; and Natural Earth's admin-1 layer models some countries at a different
# level than regions.yml does: France as departements rather than regions, Italy
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

$LOAD_PATH.unshift(File.expand_path('../lib', __dir__))
require 'travel/geometry'
require 'travel/simplify'
require 'travel/store'

ROOT = File.expand_path('..', __dir__)
CACHE = File.join(ROOT, '.geo-cache')
OUT = File.join(ROOT, 'assets', 'geo')

BASE = 'https://raw.githubusercontent.com/nvkelso/natural-earth-vector/master/geojson'
# 50m rather than 110m for the countries: the focus view magnifies up to forty
# times, and at that distance a 110m coastline is visibly a row of straight
# lines. 50m costs about 150 KB more once filtered and simplified.
#
# The `_lakes` variants, because a state's legal boundary runs out into the
# water: in the plain files Michigan is one polygon that swallows Lake Michigan,
# rather than the two peninsulas either side of it. The `_lakes` files cut the
# major lakes back out, which is what a map should show.
SOURCES = {
  'countries' => 'ne_50m_admin_0_countries_lakes.geojson',
  'admin1' => 'ne_10m_admin_1_states_provinces_lakes.geojson'
}.freeze

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

# How far outside a polygon a city may fall and still count as inside it, in
# degrees: about 25 km. A coastal city often geocodes to the water, because that
# is where its centre is — Genoa's point lands in the old port, which Natural
# Earth's coastline excludes, so strict containment put Liguria nowhere.
NEAR_DEGREES = 0.25

# The country layer is background: at the closest focus it sits behind the
# region being looked at, which is drawn from much finer data. So it is
# simplified harder than the regions are, which is what keeps it from being
# four times their weight.
COUNTRY_EPSILON = 0.03

# Every region in the data, with the coordinates of the places in it. A region
# is located by those places when neither its code nor its name finds it, and a
# city, a point of interest and a high mark all count equally for that.
store = Travel::Store.new
visited_countries = store.all('countries').to_h { |country| [country['code'], country['name']] }
wanted_regions = store.all('regions').to_h do |region|
  [region['key'], { 'name' => region['name'], 'code' => region['code'], 'country' => region['country'], 'places' => [] }]
end
Travel::Store::PLACES.each do |collection|
  store.all(collection).each do |place|
    next if place['lat'].nil?

    store.region_keys(collection, place).each do |key|
      wanted_regions[key]['places'] << [place['lon'], place['lat']] if wanted_regions.key?(key)
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
    'geometry' => Travel::Simplify.simplify_geometry(feature['geometry'], COUNTRY_EPSILON)
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
      inside = candidates.select { |f| want['places'].any? { |lon, lat| Travel::Geometry.contains?(f['geometry'], lon, lat) } }
      if inside.empty?
        # Nothing contains the city, so take the closest polygon instead, as
        # long as it is genuinely close.
        nearest = candidates.map { |f| [f, want['places'].map { |lon, lat| Travel::Geometry.distance_to(f['geometry'], lon, lat) }.min] }
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
    geometry = Travel::Simplify.simplify_geometry(feature['geometry'])
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
      'geometry' => geometry
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
