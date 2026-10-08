#!/usr/bin/env ruby
# frozen_string_literal: true

# Adds `lat:` and `lon:` to every city in _data/travel.yml that has none, so the
# globe can place a dot for it.
#
# Run it with `make geocode`. It is safe to re-run: a city that already has
# coordinates is left alone, so only new cities cost a lookup.
#
# The file is edited line by line rather than loaded and dumped as YAML, because
# a YAML round trip would throw away every comment in it.
#
# Geocoding uses Nominatim, whose usage policy asks for an identifying
# User-Agent and at most one request per second. Both are honoured below. The
# answers are written into the data file and committed, so the site never
# geocodes anything at build time or in a visitor's browser.
#
# Nominatim answers HTTP 429 when it considers the rate too high, which it will
# do even at one request per second once a few hundred have gone by. Two things
# follow, and both matter more than they sound:
#
#   - A 429 is waited out and retried, with the wait growing each time. Only
#     after several refusals does the run give up.
#   - The file is saved after every single answer, not at the end. A run that
#     dies at the hundredth city used to throw away the ninety-nine before it;
#     now they are already on disk, and re-running simply carries on, because a
#     city that has coordinates is skipped.

require 'json'
require 'net/http'
require 'uri'

# The keys under a region that hold places. All three behave the same.
PLACE_KEYS = %w[cities pois highmark].freeze

ROOT = File.expand_path('..', __dir__)
TRAVEL = File.join(ROOT, '_data', 'travel.yml')

USER_AGENT = 'mcknight.io-travel-map/1.0 (andrew@mcknight.io)'
ENDPOINT = 'https://nominatim.openstreetmap.org/search'

# Terrain elevation for a coordinate, used only when OpenStreetMap has no
# surveyed height for the place itself. It samples a 90 m model, so it reads a
# summit low — Grays Peak comes back 36 m under its true 4352 m. Good enough
# for a trailhead or a recreation area, not for a peak that has a real figure.
TERRAIN = 'https://api.open-meteo.com/v1/elevation'

# A little over the one second the policy asks for, because a request that
# leaves at exactly one per second sometimes arrives faster than that.
PAUSE = 1.2

# How long to wait after each refusal, in seconds. Running out of these ends
# the run rather than hammering a service that has asked us to stop.
BACKOFF = [5, 15, 45, 120].freeze

# Indentation says what a `- name:` line is. See the schema at the top of
# travel.yml: continent 2, country 6, region 10, city 14.
COUNTRY_INDENT = 6
REGION_INDENT = 10
SECTION_INDENT = 12     # the `cities:` / `pois:` / `highmark:` line itself
CITY_INDENT = 14

# Nominatim does better with a plain string than with structured fields for
# mixed international input.
class RateLimited < StandardError; end

def lookup(query, refusals = 0)
  uri = URI(ENDPOINT)
  # extratags brings OpenStreetMap's own `ele` with the answer, so a peak's
  # surveyed height costs no extra request.
  uri.query = URI.encode_www_form(q: query, format: 'json', limit: 1, extratags: 1)
  # An explicit request object, rather than Net::HTTP.get_response with a header
  # hash: that form needs Ruby 3.0, and this must also run under the 2.6 that
  # macOS ships, in case it is invoked without rbenv.
  request = Net::HTTP::Get.new(uri)
  request['User-Agent'] = USER_AGENT
  response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) do |http|
    http.request(request)
  end

  # 429 means we are going too fast, and a 5xx is usually momentary. Both are
  # worth waiting out; anything else is a real error.
  if response.is_a?(Net::HTTPTooManyRequests) || response.is_a?(Net::HTTPServerError)
    raise RateLimited, "gave up after #{refusals} refusals" if refusals >= BACKOFF.length

    wait = BACKOFF[refusals]
    warn "  #{response.code} from Nominatim — waiting #{wait}s before trying again"
    sleep wait
    return lookup(query, refusals + 1)
  end

  raise "HTTP #{response.code} for #{query}" unless response.is_a?(Net::HTTPSuccess)

  result = JSON.parse(response.body).first
  return nil if result.nil?

  elevation = result.dig('extratags', 'ele')
  { 'lat' => result['lat'].to_f.round(5),
    'lon' => result['lon'].to_f.round(5),
    'elevation' => (elevation.to_f.round if elevation && elevation.to_f.positive?) }
end

def terrain_elevation(lat, lon)
  uri = URI(TERRAIN)
  uri.query = URI.encode_www_form(latitude: lat, longitude: lon)
  request = Net::HTTP::Get.new(uri)
  request['User-Agent'] = USER_AGENT
  response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) { |http| http.request(request) }
  return nil unless response.is_a?(Net::HTTPSuccess)

  value = JSON.parse(response.body)['elevation']
  value.is_a?(Array) ? value.first&.round : nil
rescue StandardError
  nil
end

def name_on(line)
  line[/- name:\s*"?([^"\n]+?)"?\s*$/, 1]
end

def indent_of(line)
  line[/\A */].length
end

lines = File.readlines(TRAVEL)

# A place written in shorthand becomes a list of one before anything else runs.
#
#   highmark: Mt. Greylock      ->   highmark:
#                                      - name: Mt. Greylock
#
# The shorthand is the natural thing to type when a region has exactly one of
# something, and it is accepted for that reason. It cannot be kept, though: a
# string has nowhere to put a lat and a lon, and without those there is no dot.
# So it is widened here rather than being rejected, or quietly ignored.
expanded = []
normalised = []
lines.each do |line|
  m = line.match(/\A(\s*)(#{PLACE_KEYS.join('|')}):[ \t]+(\S.*?)\s*\z/)
  if m
    indent, key, value = m[1], m[2], m[3]
    value = value.sub(/\A["']/, '').sub(/["']\z/, '')
    expanded << "#{indent}#{key}:\n"
    expanded << "#{indent}  - name: #{value.match?(/[:#]/) ? value.inspect : value}\n"
    normalised << "#{key}: #{value}"
  else
    expanded << line
  end
end

unless normalised.empty?
  File.write(TRAVEL, expanded.join)
  puts "widened #{normalised.size} shorthand entr#{normalised.size == 1 ? 'y' : 'ies'} into lists:"
  normalised.each { |n| puts "  #{n}" }
  puts
end

lines = expanded
output = []

# Everything decided so far, followed by everything not yet looked at. Called
# after each answer, so the work already done survives whatever happens next.
save = lambda do |index|
  File.write(TRAVEL, (output + lines[(index + 1)..]).join)
end
country = nil
region = nil
geocoded = 0
skipped = 0
elevations = 0
failed = []

section = nil

lines.each_with_index do |line, index|
  output << line

  # Which of the three lists is being read. A high mark gets an elevation; a
  # city and a point of interest do not.
  if (m = line.match(/\A\s{#{SECTION_INDENT}}(#{PLACE_KEYS.join('|')}):\s*\z/))
    section = m[1]
    next
  end

  next unless line.include?('- name:')

  indent = indent_of(line)
  case indent
  when COUNTRY_INDENT then country = name_on(line); region = nil
  when REGION_INDENT  then region = name_on(line)
  when CITY_INDENT
    city = name_on(line)
    # What this entry already has, so nothing is fetched twice.
    attributes = []
    scan = index + 1
    while lines[scan] && lines[scan] =~ /\A\s+([a-z_]+):/
      attributes << Regexp.last_match(1)
      scan += 1
    end
    has_position = attributes.include?('lat')

    # A half-typed entry with no name yet would otherwise be geocoded as
    # ", Region, Country", which Nominatim answers with the region's centre.
    if city.nil? || city.strip.empty?
      warn "  skipping a city with no name under #{region}, #{country}"
      skipped += 1
      next
    end

    # Already positioned on an earlier run. Elevation, if this is a high mark
    # that wants one, is handled by the second pass below.
    if has_position
      skipped += 1
      next
    end

    # Most specific first: a region narrows "Portland" to the right one.
    queries = [[city, region, country].compact.join(', '), [city, country].compact.join(', ')]
    coordinates = nil
    begin
      queries.each do |query|
        coordinates = lookup(query)
        sleep PAUSE
        break if coordinates
      end
    rescue RateLimited => e
      save.call(index)
      warn ''
      warn "Nominatim is refusing requests (#{e.message})."
      warn "#{geocoded} place(s) were saved before stopping. Run this again later"
      warn 'to carry on: everything already found is skipped.'
      exit 1
    end

    if coordinates.nil?
      failed << "#{city}, #{region}, #{country}"
      warn "  no result: #{city}, #{region}, #{country}"
      next
    end

    pad = ' ' * (indent + 2)
    output << "#{pad}lat: #{coordinates['lat']}\n"
    output << "#{pad}lon: #{coordinates['lon']}\n"
    # A peak usually arrives with its surveyed height attached, so a high mark
    # found now needs no second request.
    if section == 'highmark' && coordinates['elevation']
      output << "#{pad}elevation_m: #{coordinates['elevation']}\n"
      elevations += 1
    end
    geocoded += 1
    save.call(index)
    puts format('  %-22s %-22s %10.5f %11.5f', city, region, coordinates['lat'], coordinates['lon'])
  end
end

File.write(TRAVEL, output.join)

# SECOND PASS: heights for high marks that were already positioned.
#
# Kept separate from the pass above rather than folded into it. That pass walks
# the file inserting lines as it goes, and reaching back into lines it has
# already written to add a third one made it hard to follow and easy to break.
# Two simple walks beat one clever one.
lines = File.readlines(TRAVEL)
output = []
section = nil
country = nil
region = nil

lines.each_with_index do |line, index|
  # Lines already copied out by an earlier iteration are blanked, so they are
  # not written twice. They must also not be read again.
  next if line.nil?

  output << line

  if (m = line.match(/\A\s{#{SECTION_INDENT}}(#{PLACE_KEYS.join('|')}):\s*\z/))
    section = m[1]
    next
  end
  next unless line.include?('- name:')

  indent = indent_of(line)
  case indent
  when COUNTRY_INDENT then country = name_on(line); region = nil; section = nil
  when REGION_INDENT then region = name_on(line); section = nil
  when CITY_INDENT
    next unless section == 'highmark'

    name = name_on(line)
    attributes = {}
    scan = index + 1
    while lines[scan] && (m = lines[scan].match(/\A\s+([a-z_]+):\s*(\S+)/))
      attributes[m[1]] = m[2]
      scan += 1
    end
    next unless attributes['lat']
    next if attributes['elevation_m']

    found = lookup([name, region, country].compact.join(', '))
    sleep PAUSE
    metres = found && found['elevation']
    unless metres
      metres = terrain_elevation(attributes['lat'].to_f, attributes['lon'].to_f)
      sleep PAUSE
    end

    unless metres
      warn "  no elevation found for #{name}"
      next
    end

    # Written after the coordinates it belongs with.
    output.concat(lines[(index + 1)...scan])
    output << "#{' ' * (indent + 2)}elevation_m: #{metres}\n"
    lines[(index + 1)...scan] = [nil] * (scan - index - 1)
    elevations += 1
    puts format('  %-34s %-18s %6d m', name, region, metres)
  end
end

File.write(TRAVEL, output.compact.join)

puts
puts "geocoded #{geocoded}, elevations added #{elevations}, already complete #{skipped}"
unless failed.empty?
  puts "no result for #{failed.size} — add lat/lon by hand:"
  failed.each { |place| puts "  #{place}" }
  exit 1
end
