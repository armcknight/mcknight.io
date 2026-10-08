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

ROOT = File.expand_path('..', __dir__)
TRAVEL = File.join(ROOT, '_data', 'travel.yml')

USER_AGENT = 'mcknight.io-travel-map/1.0 (andrew@mcknight.io)'
ENDPOINT = 'https://nominatim.openstreetmap.org/search'

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
CITY_INDENT = 14

# Nominatim does better with a plain string than with structured fields for
# mixed international input.
class RateLimited < StandardError; end

def lookup(query, refusals = 0)
  uri = URI(ENDPOINT)
  uri.query = URI.encode_www_form(q: query, format: 'json', limit: 1)
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

  [result['lat'].to_f.round(5), result['lon'].to_f.round(5)]
end

def name_on(line)
  line[/- name:\s*"?([^"\n]+?)"?\s*$/, 1]
end

def indent_of(line)
  line[/\A */].length
end

lines = File.readlines(TRAVEL)
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
failed = []

lines.each_with_index do |line, index|
  output << line

  next unless line.include?('- name:')

  indent = indent_of(line)
  case indent
  when COUNTRY_INDENT then country = name_on(line); region = nil
  when REGION_INDENT  then region = name_on(line)
  when CITY_INDENT
    city = name_on(line)

    # A half-typed entry with no name yet would otherwise be geocoded as
    # ", Region, Country", which Nominatim answers with the region's centre.
    if city.nil? || city.strip.empty?
      warn "  skipping a city with no name under #{region}, #{country}"
      skipped += 1
      next
    end

    # Already done on an earlier run?
    if lines[index + 1].to_s.include?('lat:')
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
    output << "#{pad}lat: #{coordinates[0]}\n"
    output << "#{pad}lon: #{coordinates[1]}\n"
    geocoded += 1
    save.call(index)
    puts format('  %-22s %-22s %10.5f %11.5f', city, region, coordinates[0], coordinates[1])
  end
end

File.write(TRAVEL, output.join)

puts
puts "geocoded #{geocoded}, already had coordinates #{skipped}"
unless failed.empty?
  puts "no result for #{failed.size} — add lat/lon by hand:"
  failed.each { |place| puts "  #{place}" }
  exit 1
end
