# frozen_string_literal: true

require 'json'
require 'net/http'
require 'uri'

module Travel
  # Coordinates and heights for a place name, from OpenStreetMap's Nominatim,
  # and from a terrain model when OpenStreetMap has no surveyed height.
  #
  # Nominatim's usage policy asks for an identifying User-Agent and at most one
  # request per second. Both are honoured here: every request waits until a
  # little over a second has passed since the one before it. It answers HTTP 429
  # when it considers the rate too high anyway, which it does once a few hundred
  # requests have gone by; that is waited out and retried, with the wait growing
  # each time, and only after several refusals does a lookup give up.
  module Geocoder
    USER_AGENT = 'mcknight.io-travel-map/1.0 (andrew@mcknight.io)'
    ENDPOINT = 'https://nominatim.openstreetmap.org/search'

    # Terrain elevation for a coordinate. It samples a 90 m model, so it reads a
    # summit low — Grays Peak comes back 36 m under its true 4352 m. Good enough
    # for a trailhead or a recreation area, not for a peak that has a real figure.
    TERRAIN = 'https://api.open-meteo.com/v1/elevation'

    # A little over the one second the policy asks for, because a request that
    # leaves at exactly one per second sometimes arrives faster than that.
    PAUSE = 1.2

    # How long to wait after each refusal, in seconds. Running out of these ends
    # the lookup rather than hammering a service that has asked us to stop.
    BACKOFF = [5, 15, 45, 120].freeze

    class RateLimited < StandardError; end

    @last_request = nil

    module_function

    # The first answer for a place, tried with its context and then without the
    # most specific part of it: a region narrows "Portland" to the right one,
    # but a park that OpenStreetMap files under no region needs the looser
    # query. Returns { 'lat', 'lon', 'elevation' } or nil.
    def locate(name, context = [])
      queries = [[name, *context], [name, context.last]].map { |words| words.compact.join(', ') }.uniq
      queries.each do |query|
        found = lookup(query)
        return found if found
      end
      nil
    end

    def lookup(query, refusals = 0)
      uri = URI(ENDPOINT)
      # extratags brings OpenStreetMap's own `ele` with the answer, so a peak's
      # surveyed height costs no extra request.
      uri.query = URI.encode_www_form(q: query, format: 'json', limit: 1, extratags: 1)
      response = get(uri)

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
      response = get(uri)
      return nil unless response.is_a?(Net::HTTPSuccess)

      value = JSON.parse(response.body)['elevation']
      value.is_a?(Array) ? value.first&.round : nil
    rescue StandardError
      nil
    end

    # The height of a place: OpenStreetMap's surveyed figure where it has one,
    # the terrain under the coordinates otherwise.
    def elevation(name, context, lat, lon)
      found = lookup([name, *context].compact.join(', '))
      (found && found['elevation']) || terrain_elevation(lat, lon)
    end

    # An explicit request object, rather than Net::HTTP.get_response with a
    # header hash, and the pause is kept here so every caller gets it.
    def get(uri)
      wait = @last_request && (PAUSE - (Process.clock_gettime(Process::CLOCK_MONOTONIC) - @last_request))
      sleep wait if wait&.positive?
      request = Net::HTTP::Get.new(uri)
      request['User-Agent'] = USER_AGENT
      Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) { |http| http.request(request) }
    ensure
      @last_request = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    end
  end
end
