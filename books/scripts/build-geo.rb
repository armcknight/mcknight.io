#!/usr/bin/env ruby
# frozen_string_literal: true

# Builds the country borders the books globe draws, from Natural Earth, and
# files each author under the country their birthplace is in today:
#
#   assets/geo/countries.json   every country, simplified for a globe
#   _data/authors.yml           each placed author gains `country:`, its ISO code,
#                               and `state:`, the one of the 195 states in
#                               _data/states.yml it is counted under
#   _data/countries.yml         the name of each country an author is from, for
#                               the page's list
#
# Run it with `make books-geo`, after `make books-authors`. The source is cached
# in .cache/, which git ignores. Natural Earth is public domain; the page
# credits it anyway.
#
# Today's borders only, for now. An author born where those borders did not
# yet apply is listed by `make books-history`.

require 'json'
require 'net/http'
require 'uri'
require 'set'
require 'yaml'

$LOAD_PATH.unshift(File.expand_path('../../travel/lib', __dir__))
require 'travel/geometry'
require 'travel/simplify'

ROOT = File.expand_path('..', __dir__)
CACHE = File.join(ROOT, '.cache')
OUT = File.join(ROOT, 'assets', 'geo')
AUTHORS = File.join(ROOT, '_data', 'authors.yml')

# The same source as travel's countries, for the same reasons: 50m, so a close
# look is not a row of straight lines, and the lakes cut out.
SOURCE = 'https://raw.githubusercontent.com/nvkelso/natural-earth-vector/master/geojson/ne_50m_admin_0_countries_lakes.geojson'

# Simplified as hard as travel's country layer, and drawn the same way, on the
# same globe core: every one is a path redrawn on each frame of a drag.
EPSILON = 0.03

# How far outside every country a birthplace may fall and still belong to the
# nearest, in degrees: about 25 km. A coastal city's point often lands in its
# harbour, which the coastline leaves out.
NEAR_DEGREES = 0.25

def fetch(url)
  path = File.join(CACHE, File.basename(url))
  return path if File.exist?(path)

  Dir.mkdir(CACHE) unless Dir.exist?(CACHE)
  warn "downloading #{File.basename(url)} ..."
  uri = URI(url)
  Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) do |http|
    File.open(path, 'wb') do |out|
      http.request(Net::HTTP::Get.new(uri)) { |response| response.read_body { |chunk| out.write(chunk) } }
    end
  end
  path
end

source = JSON.parse(File.read(fetch(SOURCE)))
countries = source['features'].filter_map do |feature|
  properties = feature['properties']
  iso = properties['ISO_A2_EH'].to_s
  iso = properties['ISO_A2'].to_s if iso.empty? || iso == '-99'
  geometry = Travel::Simplify.simplify_geometry(feature['geometry'], EPSILON)
  next unless geometry

  {
    'type' => 'Feature',
    'properties' => { 'iso' => iso, 'name' => properties['NAME'], 'wikidata' => properties['WIKIDATAID'] },
    'geometry' => geometry
  }
end

Dir.mkdir(OUT) unless Dir.exist?(OUT)
File.write(File.join(OUT, 'countries.json'), JSON.generate({ 'type' => 'FeatureCollection', 'features' => countries }))

# Tested against the unsimplified shapes, so a birthplace near a border is not
# moved across it by the simplification.
shapes = source['features'].map do |feature|
  iso = feature['properties']['ISO_A2_EH'].to_s
  iso = feature['properties']['ISO_A2'].to_s if iso.empty? || iso == '-99'
  [iso, feature['geometry']]
end

authors = YAML.safe_load_file(AUTHORS) || []
filed = 0
nowhere = []
authors.each do |author|
  next unless author['lat']

  lon = author['lon']
  lat = author['lat']
  iso, = shapes.find { |_, geometry| Travel::Geometry.contains?(geometry, lon, lat) }
  unless iso
    nearest_iso, distance = shapes.map { |code, geometry| [code, Travel::Geometry.distance_to(geometry, lon, lat)] }.min_by(&:last)
    iso = nearest_iso if distance <= NEAR_DEGREES
  end

  if iso && iso != '-99'
    author['country'] = iso
    filed += 1
  else
    author.delete('country')
    nowhere << "#{author['name']} (#{author['birthplace']}, #{lat}, #{lon})"
  end
end
# The state each author is counted under: their country, when it is one of
# the 195 (make books-states); otherwise the state that governs it, found by
# Natural Earth's sovereign code, which a territory shares with its state —
# Puerto Rico with the United States, Greenland with Denmark. A place no state
# governs, by that list, is counted under none and reported.
states = (YAML.safe_load_file(File.join(ROOT, '_data', 'states.yml')) || []).to_set { |state| state['iso'] }
code_of = lambda do |properties|
  iso = properties['ISO_A2_EH'].to_s
  iso.empty? || iso == '-99' ? properties['ISO_A2'].to_s : iso
end
sovereign = source['features'].to_h { |feature| [code_of.call(feature['properties']), feature['properties']['SOV_A3']] }
state_of_sovereign = source['features'].each_with_object({}) do |feature, found|
  iso = code_of.call(feature['properties'])
  found[feature['properties']['SOV_A3']] ||= iso if states.include?(iso)
end
stateless = []
authors.each do |author|
  next author.delete('state') unless author['country']

  state = states.include?(author['country']) ? author['country'] : state_of_sovereign[sovereign[author['country']]]
  if state
    author['state'] = state
  else
    author.delete('state')
    stateless << "#{author['name']} (#{author['country']})"
  end
end

File.write(AUTHORS, authors.to_yaml(line_width: -1))

# A code can name several features — Natural Earth files the Ashmore and
# Cartier Islands under AU — so a code is named after its largest.
def area(geometry)
  polygons = geometry['type'] == 'Polygon' ? [geometry['coordinates']] : geometry['coordinates']
  polygons.sum { |rings| Travel::Simplify.signed_area(rings.first).abs }
end
names = countries.group_by { |feature| feature['properties']['iso'] }
                 .transform_values { |features| features.max_by { |feature| area(feature['geometry']) }['properties']['name'] }
used = authors.filter_map { |author| author['country'] }.uniq.sort_by { |iso| names[iso].to_s }
File.write(File.join(ROOT, '_data', 'countries.yml'), used.map { |iso| { 'iso' => iso, 'name' => names[iso] } }.to_yaml(line_width: -1))

puts "countries: #{countries.size} written, #{File.size(File.join(OUT, 'countries.json')) / 1024} KB"
puts "authors:   #{filed} filed under a country"
by_country = authors.filter_map { |author| author['country'] }.tally.sort_by { |_, count| -count }
puts "           #{by_country.first(12).map { |iso, count| "#{iso} #{count}" }.join(', ')}#{' …' if by_country.size > 12}"
puts "states:    #{authors.filter_map { |author| author['state'] }.uniq.size} of #{states.size} have an author"
puts "counted under no state (#{stateless.size}): #{stateless.join(', ')}" unless stateless.empty?
unless nowhere.empty?
  puts "in no country (#{nowhere.size}):"
  nowhere.each { |line| puts "  #{line}" }
end
