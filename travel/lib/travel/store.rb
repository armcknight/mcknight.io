# frozen_string_literal: true

require 'date'
require 'fileutils'
require 'json'
require 'yaml'

module Travel
  # Every record the travel site is built from, kept as one YAML file per
  # collection in travel/_data/, the way a database keeps one table per kind.
  #
  #   countries.yml    code, name, continent
  #   regions.yml      key, code, name, country, kind
  #   cities.yml       id, name, region, lat, lon, dates
  #   pois.yml         id, name, regions, lat, lon, dates
  #   high_marks.yml   id, name, regions, lat, lon, elevation_m, dates
  #   trips.yml        id, name, type, regions, dates, activities, track_activity
  #
  # A trip's line is not in trips.yml but in assets/geo/trips.json, as GeoJSON
  # the globe loads directly: one feature per trip, with the trip's id. A line
  # is hundreds of points, which would bury the rest of the record.
  #
  # A record points at another by its id, never by nesting, so each file is a
  # flat list and the shape is the one a database would want. The admin app and
  # the scripts read and write through this class alone, which is what keeps a
  # later move to a database to one file.
  #
  # The files are written by this class, not by hand, so they carry no comments:
  # a YAML round trip would lose them. What used to be explained in comments is
  # in the README.
  class Store
    # TRAVEL_DATA points everything at another folder, to try a change on a
    # copy of the data first.
    DATA = ENV.fetch('TRAVEL_DATA') { File.expand_path('../../_data', __dir__) }

    # What each collection holds, in the order its fields are written. Fields
    # not listed here are kept, after these, so nothing typed by hand is lost.
    COLLECTIONS = {
      'countries' => { id: 'code', fields: %w[code name continent] },
      'regions' => { id: 'key', fields: %w[key code name country kind] },
      'cities' => { id: 'id', fields: %w[id name region lat lon dates] },
      'pois' => { id: 'id', fields: %w[id name regions lat lon dates] },
      'high_marks' => { id: 'id', fields: %w[id name regions lat lon elevation_m dates] },
      'trips' => { id: 'id', fields: %w[id name type regions dates activities track_activity] }
    }.freeze

    # The collections whose records name any number of regions.
    MULTI_REGION = %w[pois high_marks trips].freeze

    # The collections whose records are dots on the globe.
    PLACES = %w[cities pois high_marks].freeze

    CONTINENTS = ['North America', 'South America', 'Europe', 'Asia', 'Africa', 'Oceania', 'Antarctica'].freeze
    REGION_KINDS = ['state', 'province', 'territory', 'region', 'prefecture', 'county',
                    'federal district', 'capital city'].freeze

    class Invalid < StandardError
      attr_reader :errors

      def initialize(errors)
        @errors = errors
        super(errors.join('; '))
      end
    end

    attr_reader :dir, :tracks_path

    # The trips' lines live with the page's other geometry. For a copy of the
    # data elsewhere they live beside it, so trying something on a copy never
    # touches the real lines.
    def initialize(dir = DATA, tracks_path: nil)
      @dir = dir
      @tracks_path = tracks_path ||
                     if File.expand_path(dir) == File.expand_path('../../_data', __dir__)
                       File.expand_path('../../assets/geo/trips.json', __dir__)
                     else
                       File.join(dir, 'trips.json')
                     end
      reload
    end

    # Reads every file again, so a change made by a script or by hand while the
    # admin app is running is what the next page shows.
    def reload
      @data = COLLECTIONS.keys.to_h { |name| [name, read(name)] }
      @tracks = read_tracks
      self
    end

    def all(collection)
      @data.fetch(collection)
    end

    def find(collection, id)
      key = COLLECTIONS.fetch(collection)[:id]
      all(collection).find { |record| record[key] == id }
    end

    def country(code) = find('countries', code)
    def region(key) = find('regions', key)

    # The regions a place is in: one for a city, any number for the rest.
    def region_keys(collection, place)
      collection == 'cities' ? [place['region']].compact : Array(place['regions'])
    end

    # Every trip type in use, most used first. A type is whatever was typed —
    # there is no fixed list — so this is the list to suggest from.
    def trip_types
      all('trips').filter_map { |trip| trip['type'] }.tally.sort_by { |type, count| [-count, type] }.map(&:first)
    end

    # A trip's line, as [[lon, lat, elevation], ...], or nil when it has none.
    def track(id)
      @tracks[id]
    end

    # Gives a trip a line, or with nil takes it away. Saved with the trips.
    def set_track(id, line)
      line.nil? || line.empty? ? @tracks.delete(id) : @tracks[id] = line
    end

    # Words that narrow a geocoder's search for a place: its first region and
    # that region's country.
    def context(collection, place)
      region = region(region_keys(collection, place).first.to_s)
      return [] unless region

      [region['name'], country(region['country'])&.fetch('name')].compact
    end

    # How many records point at this one. A record still pointed at cannot be
    # deleted, or the pointers would lead nowhere.
    def references(collection, id)
      case collection
      when 'countries'
        { 'regions' => all('regions').count { |region| region['country'] == id } }
      when 'regions'
        (PLACES + ['trips']).to_h { |name| [name, all(name).count { |place| region_keys(name, place).include?(id) }] }
      else
        {}
      end.reject { |_, count| count.zero? }
    end

    def create(collection, attributes)
      record = normalise(collection, attributes)
      id_field = COLLECTIONS[collection][:id]
      record[id_field] = new_id(collection, record) if record[id_field].to_s.empty?
      validate!(collection, record, nil)
      all(collection) << record
      save(collection)
      record
    end

    def update(collection, id, attributes)
      record = find(collection, id) or raise Invalid, ["no #{collection} record #{id}"]
      id_field = COLLECTIONS[collection][:id]
      changed = normalise(collection, record.merge(attributes))
      # A region's key and a country's code are what other records point at,
      # so they follow the record's code; an id for anything else never moves.
      changed['key'] = region_key(changed) if collection == 'regions'
      changed[id_field] = id unless %w[countries regions].include?(collection)
      validate!(collection, changed, id)

      record.replace(changed)
      new_id = record[id_field]
      cascade(collection, id, new_id) if new_id != id
      save
      record
    end

    def delete(collection, id)
      used = references(collection, id)
      unless used.empty?
        raise Invalid, ["#{id} is still used by " + used.map { |name, count| "#{count} #{name}" }.join(', ')]
      end

      all(collection).reject! { |record| record[COLLECTIONS[collection][:id]] == id }
      @tracks.delete(id) if collection == 'trips'
      save(collection)
    end

    # Writes one collection, or all of them. Each file is written whole to a
    # temporary name and then moved over the old one, so a run that dies
    # halfway leaves the old file rather than half of a new one.
    def save(collection = nil)
      (collection ? [collection] : COLLECTIONS.keys).each do |name|
        path = path(name)
        records = all(name).map { |record| ordered(name, record) }
        FileUtils.mkdir_p(dir)
        File.write("#{path}.tmp", YAML.dump(records).sub(/\A---\s/, ''))
        File.rename("#{path}.tmp", path)
      end
      save_tracks if collection.nil? || collection == 'trips'
    end

    def path(collection)
      File.join(dir, "#{collection}.yml")
    end

    # The key a region is known by: its ISO 3166-2 code, or for a region with
    # none, its country and name, as in "IT:Tuscany".
    def region_key(region)
      region['code'].to_s.empty? ? "#{region['country']}:#{region['name']}" : region['code']
    end

    private

    def read_tracks
      return {} unless File.exist?(tracks_path)

      JSON.parse(File.read(tracks_path))['features'].to_h do |feature|
        [feature['properties']['id'], feature['geometry']['coordinates']]
      end
    end

    # One feature per trip that has a line, in the order of trips.yml, with
    # what the globe needs to draw and label it. One line per feature, so a
    # change to one trip is a change to one line of the diff.
    def save_tracks
      features = all('trips').filter_map do |trip|
        line = @tracks[trip['id']] or next
        JSON.generate({ 'type' => 'Feature',
                        'properties' => { 'id' => trip['id'], 'name' => trip['name'], 'type' => trip['type'],
                                          'regions' => trip['regions'] },
                        'geometry' => { 'type' => 'LineString', 'coordinates' => line } })
      end
      FileUtils.mkdir_p(File.dirname(tracks_path))
      File.write("#{tracks_path}.tmp", %({"type":"FeatureCollection","features":[\n#{features.join(",\n")}\n]}\n))
      File.rename("#{tracks_path}.tmp", tracks_path)
    end

    def read(collection)
      path = path(collection)
      return [] unless File.exist?(path)

      records = YAML.safe_load(File.read(path), permitted_classes: [Date]) || []
      records.map { |record| normalise(collection, record) }
    end

    # Trims text, turns numbers that arrived as text into numbers, drops empty
    # fields, and keeps dates as text, so `2024-03` and `2024-03-05` are the same
    # kind of thing and a date never changes shape between a read and a write.
    def normalise(collection, attributes)
      record = {}
      attributes.each do |field, value|
        field = field.to_s
        value = value.strip if value.is_a?(String)
        value = case field
                when 'lat', 'lon' then number(value)
                when 'elevation_m' then number(value)&.round
                when 'regions', 'activities' then Array(value).map(&:to_s).map(&:strip).reject(&:empty?).uniq
                when 'track_activity' then value.to_s
                # One spelling per type, so "Hike" and "hike " are one type.
                when 'type' then value.to_s.downcase.squeeze(' ')
                when 'dates' then Array(value).map { |date| date_value(date) }.compact
                when 'code' then collection == 'countries' ? value.to_s.upcase : value
                else value
                end
        next if value.nil? || value == '' || value == []

        record[field] = value
      end
      record['key'] = region_key(record) if collection == 'regions' && record['key'].to_s.empty?
      record
    end

    def number(value)
      return value if value.is_a?(Numeric)
      return nil if value.to_s.strip.empty?

      Float(value.to_s)
    rescue ArgumentError
      value.to_s
    end

    def date_value(date)
      case date
      when Date then date.iso8601
      when Hash then date.transform_keys(&:to_s).transform_values { |v| date_value(v) }
      when nil then nil
      else date.to_s.strip.then { |text| text.empty? ? nil : text }
      end
    end

    def ordered(collection, record)
      known = COLLECTIONS[collection][:fields]
      known.filter_map { |field| [field, record[field]] if record.key?(field) }.to_h
           .merge(record.reject { |field, _| known.include?(field) })
    end

    # A readable id made from the name, and for a city its region too, since
    # two regions can each have a Portland. A number is added only if needed.
    def new_id(collection, record)
      words = collection == 'cities' ? [record['region'], record['name']] : [record['name']]
      base = words.compact.join(' ').unicode_normalize(:nfkd).downcase
                  .gsub(/[^a-z0-9]+/, '-').gsub(/\A-|-\z/, '')
      base = collection.chomp('s') if base.empty?
      taken = all(collection).map { |r| r['id'] }
      candidate = base
      n = 1
      candidate = "#{base}-#{n += 1}" while taken.include?(candidate)
      candidate
    end

    def validate!(collection, record, old_id)
      errors = []
      id_field = COLLECTIONS[collection][:id]
      errors << 'name is required' if record['name'].to_s.empty?
      if all(collection).any? { |other| other[id_field] == record[id_field] && other[id_field] != old_id }
        errors << "#{id_field} #{record[id_field]} is already used"
      end

      case collection
      when 'countries'
        errors << 'code must be two letters (ISO 3166-1)' unless record['code'].to_s.match?(/\A[A-Z]{2}\z/)
        errors << 'continent is required' if record['continent'].to_s.empty?
      when 'regions'
        errors << "no country #{record['country']}" unless country(record['country'].to_s)
      when 'cities'
        errors << "no region #{record['region']}" unless region(record['region'].to_s)
      when 'trips'
        errors << 'type is required' if record['type'].to_s.empty?
        errors << 'at least one region is required' if Array(record['regions']).empty?
        Array(record['regions']).each { |key| errors << "no region #{key}" unless region(key) }
      else
        errors << 'at least one region is required' if Array(record['regions']).empty?
        Array(record['regions']).each { |key| errors << "no region #{key}" unless region(key) }
      end

      if PLACES.include?(collection)
        lat = record['lat']
        lon = record['lon']
        errors << 'latitude and longitude go together' if lat.nil? != lon.nil?
        errors << 'latitude must be a number from -90 to 90' if lat && !(lat.is_a?(Numeric) && lat.between?(-90, 90))
        errors << 'longitude must be a number from -180 to 180' if lon && !(lon.is_a?(Numeric) && lon.between?(-180, 180))
        if record.key?('elevation_m') && !record['elevation_m'].is_a?(Numeric)
          errors << 'elevation must be a number of metres'
        end
      end

      raise Invalid, errors unless errors.empty?
    end

    # Points everything that referred to an old id at the new one.
    def cascade(collection, old_id, new_id)
      case collection
      when 'countries'
        all('regions').each do |region|
          next unless region['country'] == old_id

          old_key = region['key']
          region['country'] = new_id
          region['key'] = region_key(region)
          cascade('regions', old_key, region['key']) if region['key'] != old_key
        end
      when 'regions'
        all('cities').each { |city| city['region'] = new_id if city['region'] == old_id }
        MULTI_REGION.each do |name|
          all(name).each do |place|
            place['regions'] = place['regions'].map { |key| key == old_id ? new_id : key } if place['regions']
          end
        end
      end
    end
  end
end
