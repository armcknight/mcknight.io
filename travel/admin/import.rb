# frozen_string_literal: true

require 'fileutils'
require 'json'
require 'tmpdir'

module Travel
  # Making trips from a Strava export.
  #
  # An export is dropped onto the import page each time the server runs, and
  # only the parts read here are kept, in a temporary folder that is deleted
  # when the server stops. Its list of activities is
  # filtered to the few worth keeping; an activity is looked at on its own
  # page, with its line drawn and the private ends shown; and then it becomes a
  # new trip, or another time an existing trip was done.
  #
  # A trip keeps the line of one activity, simplified and with the private ends
  # removed, and the ids and dates of every activity that was that trip. So a
  # route done five times is one line on the globe with five dates.
  class Admin
    # The exports dropped onto the import page, by id, for as long as the
    # server runs: the folder each is unpacked into, its name, and once it is
    # read, the Strava export itself. Nothing is remembered between runs, and
    # nothing is put in the repository. Which one the list shows is kept in
    # the session.
    EXPORTS = {}
    at_exit { EXPORTS.each_value { |export| FileUtils.rm_rf(export['dir']) } }

    # How a zip from Strava is unpacked: without the photos and videos, which
    # are most of it and never read.
    UNZIP_LEAVING_OUT = ['media/*', '*/media/*'].freeze

    # How much of each end of a track is removed by default, in metres. Most
    # activities start and end at home, and a privacy zone covers only the
    # home it was set for.
    TRIM_ENDS = 500

    # The columns the import list sorts by, and the value each sorts on. An
    # activity without one, such as a climb Strava did not record, goes last
    # either way.
    SORTS = {
      'date' => :started.to_proc,
      'distance' => :distance.to_proc,
      'climb' => :climb.to_proc
    }.freeze

    helpers do
      # The export chosen on the import page. Nil until one is dropped there.
      def strava = EXPORTS.dig(session[:export], 'strava')

      # Strava activity id -> the trip it is part of.
      def imported
        @imported ||= @store.all('trips').each_with_object({}) do |trip, found|
          Array(trip['activities']).each { |id| found[id] = trip }
        end
      end

      def km(metres) = format('%.1f km', metres.to_f / 1000)

      # A column heading that sorts the list by that column, keeping the
      # filters. The first click puts the newest or largest first; a click on
      # the column already sorted turns it around.
      def sort_link(label, column)
        current = @filters['sort'] == column
        dir = current && @filters['dir'] == 'desc' ? 'asc' : 'desc'
        query = @filters.merge('sort' => column, 'dir' => dir).reject { |_, v| v.empty? }
        arrow = { 'asc' => ' ▲', 'desc' => ' ▼' }[@filters['dir']] if current
        %(<a href="/import?#{h Rack::Utils.build_query(query)}">#{h label}#{arrow}</a>)
      end

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
        'min_km' => params['min_km'].to_s, 'show' => params['show'].to_s,
        'sort' => SORTS.key?(params['sort']) ? params['sort'] : 'date',
        'dir' => params['dir'] == 'asc' ? 'asc' : 'desc'
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
        value = SORTS[@filters['sort']]
        known, unknown = @activities.partition(&value)
        known.sort_by!(&value)
        known.reverse! if @filters['dir'] == 'desc'
        @activities = known + unknown
      end
      erb :import
    end

    # An export comes in three steps, so that a folder of a thousand tracks
    # can be sent a hundred files at a time: make a place for it, send its
    # files, then open it. A zip is sent the same way, as one file.
    post '/import/exports' do
      id = SecureRandom.hex(8)
      EXPORTS[id] = { 'dir' => Dir.mktmpdir('travel-strava-'), 'name' => params['name'].to_s }
      content_type :json
      { id: id }.to_json
    end

    # Each file comes with the path it had in the export, which says where it
    # goes in the export's folder. A zip is unpacked where it lands.
    post '/import/exports/:id/files' do
      export = export!
      Array(params['files']).zip(Array(params['paths'])).each do |file, path|
        parts = path.to_s.split('/').reject { |part| part.empty? || part == '.' || part == '..' }
        halt 400, 'A file came without its path.' if parts.empty? || !file.is_a?(Hash)

        target = File.join(export['dir'], *parts)
        FileUtils.mkdir_p(File.dirname(target))
        FileUtils.cp(file[:tempfile].path, target)
        next unless target.end_with?('.zip')

        unzipped = system('unzip', '-qo', target, '-x', *UNZIP_LEAVING_OUT, '-d', export['dir'])
        FileUtils.rm_f(target)
        halt 422, "#{export['name']} could not be unzipped." unless unzipped
      end
      204
    end

    # Reads what was sent, and shows it. The export may sit at the top of its
    # folder, as a zip unpacks, or one folder down, as a dropped folder does.
    post '/import/exports/:id/open' do
      export = export!
      csv = Dir.glob(File.join(export['dir'], '{,*/}activities.csv')).first
      begin
        raise ArgumentError, 'it has no activities.csv' unless csv

        export['strava'] = Strava.new(File.dirname(csv))
        count = export['strava'].activities.size
      rescue StandardError => e
        forget(params['id'])
        halt 422, "#{export['name']} is not a Strava export that can be read: #{e.message}."
      end
      session[:export] = params['id']
      session[:notice] = "Opened #{export['name']}, with #{count} activities."
      204
    end

    post '/import/exports/:id/use' do
      export!
      session[:export] = params['id']
      redirect to('/import')
    end

    post '/import/exports/:id/delete' do
      export = export!
      forget(params['id'])
      session[:notice] = "Closed #{export['name']}, and deleted its copy."
      redirect to('/import')
    end

    # A trip from each chosen activity, with the defaults the activity's own
    # page would offer: its name, Strava's type, the regions along its line,
    # and the same trimming. One that cannot become a trip is skipped and
    # named, with why, and the rest are made; there is nothing half made to
    # clean up, since a trip is saved only when it is complete.
    post '/import/bulk' do
      halt 404, 'Drop an export on the import page first.' unless strava
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
      halt 404, 'Drop an export on the import page first.' unless strava
      @activity = strava.activity(params['id']) or halt 404, "No activity #{h params['id']} in the export."
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
      @activity = strava&.activity(params['id']) or halt 404, "No activity #{h params['id']} in the export."
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
      @activity = strava&.activity(params['id']) or halt 404, "No activity #{h params['id']} in the export."
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

    private

    def export!
      EXPORTS[params['id']] or halt 404, 'That export is not open. Drop it again.'
    end

    def forget(id)
      export = EXPORTS.delete(id) or return
      FileUtils.rm_rf(export['dir'])
      session.delete(:export) if session[:export] == id
    end
  end
end
