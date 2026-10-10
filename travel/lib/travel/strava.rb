# frozen_string_literal: true

require 'csv'
require 'time'
require_relative 'tracks'

module Travel
  # A Strava data export, as Strava sends it: activities.csv, one track file
  # per activity under activities/, and privacy_zones.csv.
  #
  # Only read, never written, and never copied into the repository: an export
  # holds every activity ever recorded, and where its owner lives. What a trip
  # keeps is the simplified line of one activity, with the private parts taken
  # off.
  class Strava
    Activity = Struct.new(:id, :name, :type, :started, :distance, :climb, :file, keyword_init: true) do
      def url = "https://www.strava.com/activities/#{id}"
      def year = started&.year
      def tracked? = !file.to_s.empty? && !file.end_with?('.json')
    end

    attr_reader :dir

    def initialize(dir)
      @dir = File.expand_path(dir)
      raise ArgumentError, "no activities.csv in #{@dir}" unless File.exist?(File.join(@dir, 'activities.csv'))
    end

    # Every activity, newest first. activities.csv has some columns twice —
    # Distance, Elapsed Time — first as shown in the app, in the athlete's
    # units with thousands separators, then again in metres and seconds. The
    # second of each is the one read here.
    def activities
      @activities ||= begin
        rows = CSV.read(File.join(dir, 'activities.csv'), encoding: 'bom|utf-8')
        head = rows.shift
        column = ->(name) { head.rindex(name) }
        id, date, name, type, distance, climb, file =
          ['Activity ID', 'Activity Date', 'Activity Name', 'Activity Type', 'Distance',
           'Elevation Gain', 'Filename'].map(&column)
        rows.filter_map do |row|
          next if row[id].to_s.empty?

          Activity.new(id: row[id], name: row[name].to_s, type: row[type].to_s,
                       started: started(row[date]), distance: row[distance].to_f,
                       climb: row[climb]&.to_f, file: row[file].to_s)
        end.sort_by { |activity| activity.started || Time.at(0) }.reverse
      end
    end

    def activity(id)
      activities.find { |activity| activity.id == id.to_s }
    end

    def points(activity)
      raise ArgumentError, "#{activity.name} has no track in the export" unless activity.tracked?

      Tracks.read(File.join(dir, activity.file))
    end

    # The zones set in Strava to hide the start and end of activities near
    # home, as { lat:, lon:, radius: } with the radius in metres.
    def privacy_zones
      path = File.join(dir, 'privacy_zones.csv')
      return [] unless File.exist?(path)

      CSV.read(path, headers: true, encoding: 'bom|utf-8').filter_map do |row|
        lat, lon = row['Latitude & Longitude'].to_s.split(',').map(&:to_f)
        number, unit = row['Radius'].to_s.split
        next unless lat && lon && number

        metres = number.to_f * { 'mi' => 1609.344, 'km' => 1000.0, 'ft' => 0.3048 }.fetch(unit, 1.0)
        { lat: lat, lon: lon, radius: metres }
      end
    end

    private

    # "Oct 7, 2026, 2:03:20 AM", in UTC.
    def started(text)
      Time.strptime("#{text} UTC", '%b %d, %Y, %I:%M:%S %p %Z')
    rescue ArgumentError, TypeError
      nil
    end
  end
end
