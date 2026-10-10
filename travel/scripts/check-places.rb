#!/usr/bin/env ruby
# frozen_string_literal: true

# Checks every located place against the polygons of the regions it is filed
# under, and reports anything that has no coordinates yet. A city has one
# region; a point of interest or a high mark passes when it sits in any of its
# regions.
#
# Run it with `make travel-check`. It reads only committed files, so it needs no
# network and costs nothing. The admin app shows the same check beside each
# place.
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

$LOAD_PATH.unshift(File.expand_path('../lib', __dir__))
require 'travel/geometry'
require 'travel/store'

store = Travel::Store.new
unless File.exist?(Travel::Geometry::REGIONS)
  warn 'No geometry yet. Run `make travel-geo` first.'
  exit 1
end
shapes = Travel::Geometry.region_shapes

checked = 0
outside = []
unlocated = []
# A place whose region is not in regions.yml. The Store refuses to save one,
# but a file edited by hand can still have it.
unfiled = []
no_geometry = store.all('regions').reject { |region| shapes.key?(region['key']) }
                   .map { |region| "#{region['name']} (#{region['key']})" }

Travel::Store::PLACES.each do |collection|
  store.all(collection).each do |place|
    keys = store.region_keys(collection, place)
    missing = keys.reject { |key| store.region(key) }
    if keys.empty? || missing.any?
      unfiled << "#{place['name']} (#{collection}): " + (keys.empty? ? 'no regions' : "no region #{missing.join(', ')}")
      next
    end

    label = keys.map { |key| store.region(key)['name'] }.join(', ')
    unless place['lat'] && place['lon']
      unlocated << "#{place['name']} (#{label}, #{collection})"
      next
    end

    away = Travel::Geometry.degrees_outside(shapes, keys, place['lon'], place['lat'])
    next if away.nil?

    checked += 1
    next if away <= Travel::Geometry::TOLERANCE

    outside << format('  %-40s %-18s %5.2f deg (%4d km) at %.4f, %.4f',
                      place['name'], label, away, (away * 111).round, place['lat'], place['lon'])
  end
end

puts "checked #{checked} located places against their region"

unless no_geometry.empty?
  puts "no geometry for #{no_geometry.size} region(s) — run `make travel-geo`:"
  no_geometry.each { |line| puts "  #{line}" }
end

unless unfiled.empty?
  puts "#{unfiled.size} place(s) name no region that exists — fix their regions:"
  unfiled.each { |line| puts "  #{line}" }
end

unless unlocated.empty?
  puts "#{unlocated.size} place(s) have no coordinates — run `make travel-geocode`:"
  unlocated.each { |line| puts "  #{line}" }
end

if outside.empty?
  puts "all sit inside, or within #{(Travel::Geometry::TOLERANCE * 111).round} km of, the region they are filed under"
else
  puts "#{outside.size} sit somewhere else:"
  puts outside
end

exit(outside.empty? && unfiled.empty? ? 0 : 1)
