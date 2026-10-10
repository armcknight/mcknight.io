#!/usr/bin/env ruby
# frozen_string_literal: true

# Adds `lat:` and `lon:` to every place in travel/_data/ that has none, so the
# globe can place a dot for it, and `elevation_m:` to every high mark.
#
# Run it with `make travel-geocode`. It is safe to re-run: a place that already
# has coordinates is left alone, so only new places cost a lookup. The admin app
# (`make travel-admin`) can do the same for one place at a time.
#
# Geocoding uses Nominatim; see lib/travel/geocoder.rb for how its usage policy
# is honoured. The answers are written into the data and committed, so the site
# never geocodes anything at build time or in a visitor's browser.
#
# The data is saved after every single answer, not at the end. A run that dies
# at the hundredth place used to throw away the ninety-nine before it; now they
# are already on disk, and re-running simply carries on.

$LOAD_PATH.unshift(File.expand_path('../lib', __dir__))
require 'travel/geocoder'
require 'travel/store'

store = Travel::Store.new
geocoded = 0
skipped = 0
elevations = 0
failed = []

Travel::Store::PLACES.each do |collection|
  store.all(collection).each do |place|
    if place['lat']
      skipped += 1
      next
    end

    context = store.context(collection, place)
    label = [place['name'], *context].join(', ')
    begin
      found = Travel::Geocoder.locate(place['name'], context)
    rescue Travel::Geocoder::RateLimited => e
      warn ''
      warn "Nominatim is refusing requests (#{e.message})."
      warn "#{geocoded} place(s) were saved before stopping. Run this again later"
      warn 'to carry on: everything already found is skipped.'
      exit 1
    end

    if found.nil?
      failed << label
      warn "  no result: #{label}"
      next
    end

    place['lat'] = found['lat']
    place['lon'] = found['lon']
    # A peak usually arrives with its surveyed height attached, so a high mark
    # found now needs no second request.
    if collection == 'high_marks' && found['elevation']
      place['elevation_m'] = found['elevation']
      elevations += 1
    end
    store.save(collection)
    geocoded += 1
    puts format('  %-34s %-22s %10.5f %11.5f', place['name'], context.first, place['lat'], place['lon'])
  end
end

# Heights for high marks that were positioned without one: by hand, on an
# earlier run, or by an answer that carried no `ele`.
store.all('high_marks').each do |place|
  next unless place['lat'] && !place['elevation_m']

  context = store.context('high_marks', place)
  metres = Travel::Geocoder.elevation(place['name'], context, place['lat'], place['lon'])
  unless metres
    warn "  no elevation found for #{place['name']}"
    next
  end

  place['elevation_m'] = metres
  store.save('high_marks')
  elevations += 1
  puts format('  %-34s %-18s %6d m', place['name'], context.first, metres)
end

puts
puts "geocoded #{geocoded}, elevations added #{elevations}, already complete #{skipped}"
unless failed.empty?
  puts "no result for #{failed.size} — add lat/lon by hand, or in make travel-admin:"
  failed.each { |place| puts "  #{place}" }
  exit 1
end
