# frozen_string_literal: true

require 'yaml'

module Travel
  # Making trips from a Strava export.
  #
  # The export is read where it lies, never copied. Its list of activities is
  # filtered to the few worth keeping; an activity is looked at on its own
  # page, with its line drawn and the private ends shown; and then it becomes a
  # new trip, or another time an existing trip was done.
  #
  # A trip keeps the line of one activity, simplified and with the private ends
  # removed, and the ids and dates of every activity that was that trip. So a
  # route done five times is one line on the globe with five dates.
  class Admin
    SETTINGS = File.join(__dir__, 'settings.yml')

    # How much of each end of a track is removed by default, in metres. Most
    # activities start and end at home, and a privacy zone covers only the
    # home it was set for.
    TRIM_ENDS = 500

    helpers do
      def settings_file
        File.exist?(SETTINGS) ? (YAML.safe_load(File.read(SETTINGS)) || {}) : {}
      end

      # The export, from STRAVA_EXPORT or from the path saved on the import
      # page. Nil when neither is set or the folder holds no export.
      def strava
        return @strava if defined?(@strava)

        dir = ENV['STRAVA_EXPORT'] || settings_file['strava_export']
        @strava = dir && Strava.new(dir)
      rescue ArgumentError => e
        @strava_error = e.message
        @strava = nil
      end

      # Strava activity id -> the trip it is part of.
      def imported
        @imported ||= @store.all('trips').each_with_object({}) do |trip, found|
          Array(trip['activities']).each { |id| found[id] = trip }
        end
      end

      def km(metres) = format('%.1f km', metres.to_f / 1000)

      # The track an activity becomes: GPS errors, privacy zones and the ends
      # removed, then simplified. Returns the line and what was removed, to
      # draw both.
      #
      # GPS errors are removed first, so a bad fix at the start does not decide
      # where the trimmed ends are measured from. `errors` is how many went.
      def prepared(activity, ends)
        points = strava.points(activity)
        clean = Tracks.despike(points)
        kept = Tracks.trim(clean, ends: ends, zones: strava.privacy_zones)
        { all: points, kept: kept, errors: points.size - clean.size, line: Tracks.line(Tracks.simplify(kept)) }
      end

      # The day an activity happened, where it started.
      def start_date(activity, track)
        start = track[:kept].first || track[:all].first
        Tracks.local_date(start&.at(3) || activity.started, start&.at(0))
      end

      # A new trip from an activity and its prepared track, with `attributes`
      # (name, type, regions) as chosen. Raises Store::Invalid if they are not
      # enough for a trip; nothing is saved then.
      def make_trip(activity, track, attributes)
        trip = @store.create('trips', attributes.merge(
          'dates' => [start_date(activity, track).iso8601],
          'activities' => [activity.id],
          'track_activity' => activity.id
        ))
        @store.set_track(trip['id'], track[:line])
        @store.save('trips')
        trip
      end

      # The regions a line passes through, most of the line first, from the
      # region shapes already drawn on the globe. A region not visited yet has
      # no shape, so it cannot be suggested; it is added first, then the trip.
      def regions_along(line)
        counts = Hash.new(0)
        sample(line, 60).each do |lon, lat|
          shapes.each do |key, geometries|
            counts[key] += 1 if geometries.any? { |geometry| Geometry.contains?(geometry, lon, lat) }
          end
        end
        counts.sort_by { |_, count| -count }.map(&:first)
      end
    end

    before '/import*' do
      @importing = true
    end

    get '/import' do
      @filters = {
        'q' => params['q'].to_s, 'type' => params['type'].to_s, 'year' => params['year'].to_s,
        'min_km' => params['min_km'].to_s, 'show' => params['show'].to_s
      }
      if strava
        @types = strava.activities.map(&:type).tally.sort_by { |_, count| -count }
        @years = strava.activities.filter_map(&:year).uniq.sort.reverse
        @activities = strava.activities.select do |activity|
          next false unless activity.tracked?
          next false if @filters['show'] == 'new' && imported[activity.id]
          next false if @filters['show'] == 'imported' && !imported[activity.id]
          next false unless @filters['type'].empty? || activity.type == @filters['type']
          next false unless @filters['year'].empty? || activity.year.to_s == @filters['year']
          next false unless @filters['min_km'].empty? || activity.distance >= @filters['min_km'].to_f * 1000

          @filters['q'].empty? || activity.name.downcase.include?(@filters['q'].downcase)
        end
      end
      erb :import
    end

    post '/import/settings' do
      dir = File.expand_path(params['strava_export'].to_s.strip.gsub('\\ ', ' '))
      begin
        Strava.new(dir)
      rescue ArgumentError => e
        session[:notice] = e.message
        redirect to('/import')
      end
      File.write(SETTINGS, YAML.dump('strava_export' => dir))
      session[:notice] = 'Export found.'
      redirect to('/import')
    end

    # A trip from each chosen activity, with the defaults the activity's own
    # page would offer: its name, Strava's type, the regions along its line,
    # and the same trimming. One that cannot become a trip is skipped and
    # named, with why, and the rest are made; there is nothing half made to
    # clean up, since a trip is saved only when it is complete.
    post '/import/bulk' do
      halt 404, 'Set the export folder first.' unless strava
      ends = (params['ends'] || TRIM_ENDS).to_i
      made = []
      skipped = Hash.new { |hash, why| hash[why] = [] }
      Array(params['ids']).uniq.each do |id|
        activity = strava.activity(id)
        next skipped['not in the export'] << id unless activity
        next skipped['already a trip'] << activity.name if imported[activity.id]

        begin
          track = prepared(activity, ends)
        rescue StandardError
          next skipped['track could not be read'] << activity.name
        end
        next skipped['no GPS track'] << activity.name if track[:all].size < 2
        next skipped['too short once its ends are removed'] << activity.name if track[:line].size < 2

        regions = regions_along(track[:line])
        next skipped['in no region on the globe yet'] << activity.name if regions.empty?

        begin
          made << make_trip(activity, track, 'name' => activity.name, 'type' => activity.type, 'regions' => regions)
          imported[activity.id] = made.last
        rescue Store::Invalid => e
          skipped[e.errors.join('; ')] << activity.name
        end
      end

      notice = made.empty? ? 'Made no trips.' : "Made #{made.size} trip#{'s' unless made.size == 1}."
      skipped.each { |why, names| notice += " Skipped #{names.size} (#{why}): #{names.first(5).join(', ')}#{', ...' if names.size > 5}." }
      session[:notice] = notice
      redirect to("/import?#{params['filters']}")
    end

    get '/import/:id' do
      halt 404, 'Set the export folder first.' unless strava
      @activity = strava.activity(params['id']) or halt 404
      @ends = (params['ends'] || TRIM_ENDS).to_i
      begin
        @track = prepared(@activity, @ends)
      rescue StandardError => e
        @problem = "Could not read #{File.basename(@activity.file)}: #{e.message}"
        return erb :import_activity
      end
      @suggested = regions_along(@track[:line])
      @date = start_date(@activity, @track)
      @high = Tracks.high_point(@track[:kept])
      @trip = imported[@activity.id]
      erb :import_activity
    end

    # A new trip from this activity.
    post '/import/:id' do
      @activity = strava&.activity(params['id']) or halt 404
      ends = params['ends'].to_i
      track = prepared(@activity, ends)
      record = params.fetch('record', {}).to_h.merge('regions' => Array(params.dig('record', 'regions')))
      begin
        trip = make_trip(@activity, track, record)
      rescue Store::Invalid => e
        session[:notice] = "Not imported: #{e.errors.join('; ')}"
        redirect to("/import/#{u @activity.id}?ends=#{ends}")
      end
      session[:notice] = "Made the trip #{trip['name']}. Commit travel/_data/trips.yml and travel/assets/geo/trips.json to publish it."
      redirect to("/import/#{u @activity.id}?ends=#{ends}")
    end

    # Another time an existing trip was done: its date and id are added, and
    # its line replaces the trip's if asked.
    post '/import/:id/attach' do
      @activity = strava&.activity(params['id']) or halt 404
      trip = @store.find('trips', params['trip'].to_s) or halt 404, 'No such trip.'
      ends = params['ends'].to_i
      track = prepared(@activity, ends)
      date = start_date(@activity, track).iso8601
      changes = {
        'activities' => (Array(trip['activities']) + [@activity.id]).uniq,
        'dates' => (Array(trip['dates']) + [date]).uniq
      }
      if params['use_line'] == '1'
        changes['track_activity'] = @activity.id
        @store.set_track(trip['id'], track[:line])
      end
      @store.update('trips', trip['id'], changes)
      session[:notice] = "Added #{date} to #{trip['name']}#{', and drew it with this line' if params['use_line'] == '1'}."
      redirect to("/import/#{u @activity.id}?ends=#{ends}")
    end
  end
end
