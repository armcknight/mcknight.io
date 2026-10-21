# frozen_string_literal: true

# A local editor for the travel site's data: list, add, change and delete
# countries, regions, cities, points of interest, high marks and trips, find a
# place's coordinates, see whether it falls inside the regions it is filed
# under, and make trips from a Strava export (import.rb).
#
#   make travel-admin     then open http://localhost:4600
#
# It edits the files in travel/_data/ through Travel::Store, the same as the
# scripts do, so what it saves is committed and deployed the usual way. It is
# for one person on their own machine: it listens on 127.0.0.1 only and has no
# login. Every form carries a token from the session, so another site open in
# the same browser cannot post to it, and Sinatra refuses a request whose Host
# is not this machine, which stops a DNS rebinding page from reading it.

$LOAD_PATH.unshift(File.expand_path('../lib', __dir__))
require 'erb'
require 'securerandom'
require 'sinatra/base'
require 'travel/geocoder'
require 'travel/geometry'
require 'travel/store'
require 'travel/strava'
require 'travel/tracks'

module Travel
  class Admin < Sinatra::Base
    set :root, __dir__
    set :bind, '127.0.0.1'
    set :port, ENV.fetch('PORT', 4600).to_i
    set :sessions, secret: SecureRandom.hex(64), same_site: :strict
    set :host_authorization, permitted_hosts: ['localhost', '127.0.0.1', '.localhost']

    # How each collection is shown and edited. A field's type picks its input;
    # anything not listed here is kept as it is but not shown.
    COLLECTIONS = {
      'countries' => {
        title: 'Countries', one: 'country',
        fields: [
          { name: 'name', label: 'Name' },
          { name: 'code', label: 'ISO 3166-1 code', hint: 'Two letters. Changing it moves its regions with it.' },
          { name: 'continent', label: 'Continent', type: :choice, options: Store::CONTINENTS }
        ]
      },
      'regions' => {
        title: 'States & regions', one: 'region',
        fields: [
          { name: 'name', label: 'Name' },
          { name: 'country', label: 'Country', type: :country },
          { name: 'code', label: 'ISO 3166-2 code',
            hint: 'Optional. Without one the region is known as COUNTRY:Name.' },
          { name: 'kind', label: 'Kind', type: :choice, options: Store::REGION_KINDS },
          { name: 'key', label: 'Key', type: :readonly }
        ]
      },
      'cities' => {
        title: 'Cities', one: 'city',
        fields: [
          { name: 'name', label: 'Name' },
          { name: 'region', label: 'Region', type: :region },
          { name: 'lat', label: 'Latitude', type: :number },
          { name: 'lon', label: 'Longitude', type: :number },
          { name: 'dates', label: 'Dates', type: :dates }
        ]
      },
      'pois' => {
        title: 'Points of interest', one: 'point of interest',
        fields: [
          { name: 'name', label: 'Name' },
          { name: 'regions', label: 'Regions', type: :regions, hint: 'Every region it lies in.' },
          { name: 'lat', label: 'Latitude', type: :number },
          { name: 'lon', label: 'Longitude', type: :number },
          { name: 'dates', label: 'Dates', type: :dates }
        ]
      },
      'high_marks' => {
        title: 'High marks', one: 'high mark',
        fields: [
          { name: 'name', label: 'Name' },
          { name: 'regions', label: 'Regions', type: :regions },
          { name: 'lat', label: 'Latitude', type: :number },
          { name: 'lon', label: 'Longitude', type: :number },
          { name: 'elevation_m', label: 'Elevation (m)', type: :number },
          { name: 'dates', label: 'Dates', type: :dates }
        ]
      },
      'trips' => {
        title: 'Trips', one: 'trip',
        fields: [
          { name: 'name', label: 'Name' },
          { name: 'type', label: 'Type', type: :choice, options: ->(store) { store.trip_types },
            hint: 'Anything: hike, raft, nordic ski. The types already used are suggested.' },
          { name: 'regions', label: 'Regions', type: :regions, hint: 'Every region it passes through.' },
          { name: 'dates', label: 'Dates', type: :dates, hint: 'One per time you did it.' },
          { name: 'activities', label: 'Strava activities', type: :list },
          { name: 'track_activity', label: 'Line drawn from', type: :readonly }
        ]
      }
    }.freeze

    helpers do
      def h(text) = ERB::Util.html_escape(text.to_s)
      def u(text) = ERB::Util.url_encode(text.to_s)
      def csrf_token = (session[:csrf] ||= SecureRandom.hex(32))
      def csrf_field = %(<input type="hidden" name="csrf" value="#{csrf_token}">)
      def place?(collection) = Store::PLACES.include?(collection)
      def id_of(collection, record) = record[Store::COLLECTIONS[collection][:id]]

      # A date in the form's text area: a day or month as written, or a stay as
      # "from to to".
      def date_text(date)
        date.is_a?(Hash) ? "#{date['from']} to #{date['to']}" : date.to_s
      end

      # Whether a place sits in its regions, as a word and a class for the list.
      # A trip passes when some of its line is in one of its regions.
      def check(collection, place)
        return check_trip(place) if collection == 'trips'
        return ['no coordinates', 'warn'] unless place['lat'] && place['lon']

        keys = @store.region_keys(collection, place)
        away = Geometry.degrees_outside(shapes, keys, place['lon'], place['lat'])
        return ['no region shape', 'muted'] if away.nil?
        return ['in region', 'ok'] if away <= Geometry::TOLERANCE

        ["#{(away * 111).round} km outside", 'bad']
      end

      def check_trip(trip)
        line = @store.track(trip['id'])
        return ['no line', 'muted'] unless line

        keys = @store.region_keys('trips', trip)
        away = sample(line).map { |lon, lat| Geometry.degrees_outside(shapes, keys, lon, lat) }.compact.min
        return ['no region shape', 'muted'] if away.nil?
        return ['in region', 'ok'] if away <= Geometry::TOLERANCE

        ["#{(away * 111).round} km outside", 'bad']
      end

      # Up to forty points spread along a line, enough to tell which regions it
      # passes through without testing every one.
      def sample(line, count = 40)
        step = [line.size / count, 1].max
        (0...line.size).step(step).map { |i| line[i] }
      end

      def shapes
        @shapes ||= Geometry.region_shapes
      end

      # A line drawn as SVG, fitted to a box: equirectangular, with longitude
      # narrowed by the cosine of the latitude so a track is not stretched
      # sideways. Every line given is fitted together, so they line up.
      def track_svg(lines, width: 640, height: 360, classes: [])
        points = lines.flatten(1)
        return '' if points.empty?

        squeeze = Math.cos(points.sum { |p| p[1] } / points.size * Math::PI / 180)
        xs = points.map { |p| p[0] * squeeze }
        ys = points.map { |p| -p[1] }
        span = [xs.max - xs.min, ys.max - ys.min, 1e-6].max
        scale = [width, height].min * 0.92 / span
        dx = (width - ((xs.max - xs.min) * scale)) / 2
        dy = (height - ((ys.max - ys.min) * scale)) / 2
        paths = lines.each_with_index.map do |line, i|
          d = line.map { |p| format('%.1f,%.1f', ((p[0] * squeeze) - xs.min) * scale + dx, (-p[1] - ys.min) * scale + dy) }
          %(<polyline class="#{classes[i]}" points="#{d.join(' ')}"/>)
        end
        %(<svg class="track" viewBox="0 0 #{width} #{height}" role="img" aria-label="The line of the track">#{paths.join}</svg>)
      end

      def map_link(lat, lon)
        "https://www.openstreetmap.org/?mlat=#{lat}&mlon=#{lon}#map=12/#{lat}/#{lon}"
      end
    end

    before do
      @store = Store.new
      if request.post? && !Rack::Utils.secure_compare(params['csrf'].to_s, csrf_token)
        halt 403, 'This form is out of date. Go back, reload the page and try again.'
      end
    end

    # Every 404, in the layout. A route that finds nothing halts with its own
    # message, already escaped, which comes here as the body and is shown; an
    # address no route answers has none, and says so.
    not_found do
      @message = Array(response.body).join
      @message = "There is nothing at <code>#{h request.path}</code>." if @message.strip.empty?
      erb '<h1>Not found</h1><p><%= @message %> <a href="/">Back to the start</a>.</p>'
    end

    get '/' do
      @problems = Store::PLACES.flat_map do |collection|
        @store.all(collection).filter_map do |place|
          word, level = check(collection, place)
          [collection, place, word] if %w[warn bad].include?(level)
        end
      end
      @no_shape = @store.all('regions').reject { |region| shapes.key?(region['key']) }
      erb :index
    end

    get '/:collection' do
      collection!
      @records = @store.all(@collection)
      erb :list
    end

    get '/:collection/new' do
      collection!
      @record = params.fetch('record', {}).to_h
      erb :form
    end

    post '/:collection' do
      collection!
      record = @store.create(@collection, attributes)
      session[:notice] = "Added #{record['name']}.#{geometry_reminder}"
      redirect to("/#{@collection}")
    rescue Store::Invalid => e
      @record = attributes
      @errors = e.errors
      status 422
      erb :form
    end

    # Looks a place up and shows the form again with what was found, without
    # saving, so the answer can be read and checked first. Works for a new
    # place and for one being edited alike.
    post '/:collection/locate' do
      collection!
      halt 404, 'Only a place can be looked up.' unless place?(@collection)
      @id = params['id'].to_s.empty? ? nil : params['id']
      @record = attributes
      context = @store.context(@collection, @record)
      begin
        found = Geocoder.locate(@record['name'].to_s, context)
      rescue StandardError => e
        @errors = ["The geocoder did not answer: #{e.message}"]
        return erb :form
      end

      if found.nil?
        @errors = ["Nothing found for #{[@record['name'], *context].join(', ')}. Try a different name, or type the coordinates."]
      else
        @record['lat'] = found['lat']
        @record['lon'] = found['lon']
        if @collection == 'high_marks'
          @record['elevation_m'] = found['elevation'] || Geocoder.terrain_elevation(found['lat'], found['lon'])
        end
        @found = found
      end
      erb :form
    end

    get '/:collection/:id/edit' do
      collection!
      @id = params['id']
      @record = @store.find(@collection, @id) or halt 404, "No #{@spec[:one]} #{h @id}."
      erb :form
    end

    post '/:collection/:id' do
      collection!
      @id = params['id']
      halt 404, "No #{@spec[:one]} #{h @id}." unless @store.find(@collection, @id)
      record = @store.update(@collection, @id, attributes)
      session[:notice] = "Saved #{record['name']}."
      redirect to("/#{@collection}")
    rescue Store::Invalid => e
      @record = attributes
      @errors = e.errors
      status 422
      erb :form
    end

    post '/:collection/:id/delete' do
      collection!
      record = @store.find(@collection, params['id']) or halt 404, "No #{@spec[:one]} #{h params['id']}."
      @store.delete(@collection, params['id'])
      session[:notice] = "Deleted #{record['name']}."
      redirect to("/#{@collection}")
    rescue Store::Invalid => e
      session[:notice] = e.errors.join(' ')
      redirect to("/#{@collection}/#{u params['id']}/edit")
    end

    private

    def collection!
      @collection = params['collection']
      # Not a collection: let a later route, such as /import, have it.
      pass unless COLLECTIONS.key?(@collection)
      @spec = COLLECTIONS[@collection]
    end

    # The submitted record, in the shape the Store expects. Every field the
    # form shows is present, even when empty, so clearing a field clears it.
    def attributes
      submitted = params.fetch('record', {})
      @spec[:fields].each_with_object({}) do |field, record|
        name = field[:name]
        next if field[:type] == :readonly

        value = submitted[name]
        record[name] =
          case field[:type]
          when :regions then Array(value)
          when :dates then parse_dates(value.to_s)
          when :list then value.to_s.split(/[\s,]+/)
          else value.to_s
          end
      end
    end

    def parse_dates(text)
      text.lines.map(&:strip).reject(&:empty?).map do |line|
        from, to = line.split(/\s+to\s+/, 2)
        to ? { 'from' => from, 'to' => to } : from
      end
    end

    def geometry_reminder
      return '' unless %w[countries regions].include?(@collection)

      ' Run make travel-geo to draw it on the globe.'
    end

  end
end

require_relative 'import'
if $PROGRAM_NAME == __FILE__
  # Said again once the server is up, below the server's own start-up lines.
  Travel::Admin.run! do
    puts "\nTravel admin is at http://localhost:#{Travel::Admin.port}\n\n"
    $stdout.flush
  end
end
