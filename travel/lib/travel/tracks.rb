# frozen_string_literal: true

require 'date'
require 'time'
require 'zlib'

module Travel
  # Reads a recorded track — GPX, TCX or FIT, each possibly gzipped, as a
  # Strava export holds them — into a list of points, and turns that into the
  # line a trip is drawn with: the private ends taken off, and simplified.
  #
  # A point is [lon, lat, elevation in metres or nil, time or nil]: longitude
  # first, as GeoJSON has it.
  module Tracks
    EARTH_RADIUS = 6_371_000.0

    module_function

    def read(path)
      bytes = File.binread(path)
      bytes = Zlib.gunzip(bytes) if path.end_with?('.gz')
      case path.sub(/\.gz\z/, '')
      when /\.gpx\z/i then gpx(bytes.force_encoding('UTF-8'))
      when /\.tcx\z/i then tcx(bytes.force_encoding('UTF-8'))
      when /\.fit\z/i then fit(bytes)
      else raise ArgumentError, "cannot read #{File.basename(path)}: not GPX, TCX or FIT"
      end
    end

    # GPX: <trkpt lat= lon=> with an optional <ele> and <time> inside. Read with
    # a pattern rather than an XML parser: these files are machine-written and
    # regular, and a parser takes seconds on a long ride.
    def gpx(text)
      text.scan(%r{<trkpt\b([^>]*?)(?:/>|>(.*?)</trkpt>)}m).filter_map do |attributes, body|
        lat = attributes[/\blat="([^"]+)"/, 1]
        lon = attributes[/\blon="([^"]+)"/, 1]
        next unless lat && lon

        [lon.to_f, lat.to_f, body.to_s[%r{<ele>([^<]+)</ele>}, 1]&.to_f, time(body.to_s[%r{<time>([^<]+)</time>}, 1])]
      end
    end

    # TCX: <Trackpoint> with <Position> holding the degrees. A point recorded
    # without a position (indoors, or before a fix) is skipped.
    def tcx(text)
      text.scan(%r{<Trackpoint>(.*?)</Trackpoint>}m).filter_map do |(body)|
        lat = body[%r{<LatitudeDegrees>([^<]+)</LatitudeDegrees>}, 1]
        lon = body[%r{<LongitudeDegrees>([^<]+)</LongitudeDegrees>}, 1]
        next unless lat && lon

        [lon.to_f, lat.to_f, body[%r{<AltitudeMeters>([^<]+)</AltitudeMeters>}, 1]&.to_f,
         time(body[%r{<Time>([^<]+)</Time>}, 1])]
      end
    end

    def time(text)
      text && Time.iso8601(text.strip)
    rescue ArgumentError
      nil
    end

    # FIT, Garmin's binary format. Only what a track needs is decoded: the
    # `record` messages (global number 20), and in them the position, the
    # altitude and the time. Everything else is read past by its size, which
    # the definition messages give, so nothing has to be understood to be
    # skipped.
    #
    #   position_lat, position_long   fields 0, 1     sint32 semicircles
    #   altitude                      field 2         uint16, metres * 5 + 500
    #   enhanced_altitude             field 78        uint32, the same scale
    #   timestamp                     field 253       uint32, seconds since 1989-12-31
    FIT_EPOCH = Time.utc(1989, 12, 31).to_i
    SEMICIRCLES = 180.0 / (2**31)

    def fit(bytes)
      points = []
      offset = 0
      # A file can hold several FIT files end to end; each has its own header.
      while offset + 12 <= bytes.bytesize && bytes.byteslice(offset + 8, 4) == '.FIT'
        header_size = bytes.getbyte(offset)
        data_size = bytes.byteslice(offset + 4, 4).unpack1('V')
        fit_records(bytes, offset + header_size, offset + header_size + data_size, points)
        offset += header_size + data_size + 2 # the two-byte CRC that ends each file
      end
      points
    end

    def fit_records(bytes, position, finish, points)
      definitions = {}
      last_timestamp = nil
      while position < finish
        header = bytes.getbyte(position)
        position += 1

        if header & 0x80 != 0
          # A compressed-timestamp header: a data message whose time is an
          # offset from the last full timestamp, in its low five bits.
          local = (header >> 5) & 0x03
          offset = header & 0x1F
          if last_timestamp
            last_timestamp += (offset - (last_timestamp & 0x1F)) & 0x1F
          end
          compressed_time = last_timestamp
        elsif header & 0x40 != 0
          # A definition: what the data messages of this local type hold.
          local = header & 0x0F
          big = bytes.getbyte(position + 1) == 1
          global = bytes.byteslice(position + 2, 2).unpack1(big ? 'n' : 'v')
          count = bytes.getbyte(position + 4)
          position += 5
          fields = Array.new(count) do |i|
            base = position + (i * 3)
            [bytes.getbyte(base), bytes.getbyte(base + 1)]
          end
          position += count * 3
          developer_size = 0
          if header & 0x20 != 0
            developer_count = bytes.getbyte(position)
            position += 1
            developer_size = Array.new(developer_count) { |i| bytes.getbyte(position + (i * 3) + 1) }.sum
            position += developer_count * 3
          end
          definitions[local] = { global: global, big: big, fields: fields, developer_size: developer_size }
          next
        else
          local = header & 0x0F
          compressed_time = nil
        end

        definition = definitions[local] or raise ArgumentError, 'FIT data before its definition'
        values = {}
        definition[:fields].each do |number, size|
          if definition[:global] == 20 && [0, 1, 2, 78, 253].include?(number)
            values[number] = fit_value(bytes.byteslice(position, size), size, definition[:big], signed: number < 2)
          elsif definition[:global] != 20 && number == 253
            values[253] = fit_value(bytes.byteslice(position, size), size, definition[:big], signed: false)
          end
          position += size
        end
        position += definition[:developer_size]

        last_timestamp = values[253] if values[253]
        next unless definition[:global] == 20

        lat = values[0]
        lon = values[1]
        next if lat.nil? || lon.nil?

        metres = values[78] || values[2]
        stamp = values[253] || compressed_time
        points << [lon * SEMICIRCLES, lat * SEMICIRCLES, metres && ((metres / 5.0) - 500),
                   stamp && Time.at(FIT_EPOCH + stamp).utc]
      end
    end

    # A number from a field, or nil when it holds the "invalid" value FIT uses
    # for a field with nothing in it.
    def fit_value(raw, size, big, signed:)
      case size
      when 1 then value = raw.unpack1('C')
                  value == 0xFF ? nil : value
      when 2 then value = raw.unpack1(big ? 'n' : 'v')
                  value == 0xFFFF ? nil : value
      when 4
        value = raw.unpack1(big ? 'N' : 'V')
        return nil if value == (signed ? 0x7FFFFFFF : 0xFFFFFFFF)

        signed && value >= 2**31 ? value - 2**32 : value
      end
    end

    def distance(a, b)
      lat1 = a[1] * Math::PI / 180
      lat2 = b[1] * Math::PI / 180
      dlat = lat2 - lat1
      dlon = (b[0] - a[0]) * Math::PI / 180
      h = (Math.sin(dlat / 2)**2) + (Math.cos(lat1) * Math.cos(lat2) * (Math.sin(dlon / 2)**2))
      2 * EARTH_RADIUS * Math.asin(Math.sqrt(h))
    end

    def length(points)
      points.each_cons(2).sum { |a, b| distance(a, b) }
    end

    # Faster than anything in a Strava activity goes, in metres per second:
    # 300 km/h. A point reached faster than this is a GPS error.
    MAX_SPEED = 300 / 3.6

    # Without times, how far apart two points one step apart may be, in metres.
    # Devices record every few seconds, so a kilometre in one step is an error.
    MAX_STEP = 1000

    # A jump this far after a pause this long is not travel either, however
    # slow it was: it is a fix left over from before, such as one taken in the
    # car on the way to the start. Two rides in the export begin with a point
    # 22 and 27 km from the rest, recorded about half an hour earlier.
    STALE_DISTANCE = 2000
    STALE_PAUSE = 300

    # A piece of track with fewer points than this, cut off from the rest by
    # jumps, is an error rather than somewhere the activity went.
    MIN_PIECE = 5

    # The track without its GPS errors.
    #
    # The track is cut wherever one point cannot follow from the one before:
    # reached faster than MAX_SPEED, or far away after a long pause. A bad fix
    # is then a short piece on its own — one point for a spike, two or three
    # for a cluster, one at the start for a stale fix — and every piece shorter
    # than MIN_PIECE is dropped. A real jump, such as a track that carries on
    # after a ride in a car, leaves long pieces on both sides, and both stay.
    # If every piece is short, the longest is kept rather than nothing.
    def despike(points)
      return points.dup if points.size < 2

      pieces = points.slice_when { |a, b| jump?(a, b) }.to_a
      kept = pieces.select { |piece| piece.size >= MIN_PIECE }
      kept = [pieces.max_by(&:size)] if kept.empty?
      kept.flatten(1)
    end

    def jump?(a, b)
      metres = distance(a, b)
      seconds = a[3] && b[3] ? (b[3] - a[3]).abs : nil
      return metres > MAX_STEP if seconds.nil?

      metres > MAX_SPEED * [seconds, 1].max || (metres > STALE_DISTANCE && seconds > STALE_PAUSE)
    end

    # The track with its private parts taken off: every point inside a privacy
    # zone, and a stretch at each end, since most activities start and stop at
    # home. A zone is { lat:, lon:, radius: } in metres.
    def trim(points, ends: 0, zones: [])
      kept = points.reject do |point|
        zones.any? { |zone| distance(point, [zone[:lon], zone[:lat]]) <= zone[:radius] }
      end
      return kept if ends <= 0 || kept.size < 2

      # Each end starts at the first point at least `ends` along the track, so
      # a long first step is trimmed too rather than counted as nothing.
      first = 0
      travelled = 0.0
      while first < kept.size - 1 && travelled < ends
        travelled += distance(kept[first], kept[first + 1])
        first += 1
      end
      last = kept.size - 1
      travelled = 0.0
      while last > first && travelled < ends
        travelled += distance(kept[last - 1], kept[last])
        last -= 1
      end
      last > first ? kept[first..last] : []
    end

    # Ramer-Douglas-Peucker on longitude and latitude, iteratively so a long
    # ride cannot overflow the stack. TOLERANCE is in degrees, about 15 m: finer
    # than the globe can show at its closest, and a tenth of the points or less.
    TOLERANCE = 0.00015

    def simplify(points, tolerance = TOLERANCE)
      return points if points.size < 3

      keep = Array.new(points.size, false)
      keep[0] = keep[-1] = true
      stack = [[0, points.size - 1]]
      until stack.empty?
        first, last = stack.pop
        a = points[first]
        b = points[last]
        furthest = nil
        widest = tolerance
        ((first + 1)...last).each do |i|
          d = offset(points[i], a, b)
          if d > widest
            widest = d
            furthest = i
          end
        end
        next unless furthest

        keep[furthest] = true
        stack << [first, furthest] << [furthest, last]
      end
      points.each_index.select { |i| keep[i] }.map { |i| points[i] }
    end

    def offset(point, a, b)
      dx = b[0] - a[0]
      dy = b[1] - a[1]
      return Math.hypot(point[0] - a[0], point[1] - a[1]) if dx.zero? && dy.zero?

      ((dy * point[0]) - (dx * point[1]) + (b[0] * a[1]) - (b[1] * a[0])).abs / Math.hypot(dx, dy)
    end

    # The line a trip stores: [lon, lat, elevation] with the time dropped,
    # rounded to about a metre and to whole metres of height.
    def line(points)
      points.map { |lon, lat, ele, _| [lon.round(5), lat.round(5), ele&.round].compact }
    end

    # The highest point of a track, or nil when it carries no heights.
    def high_point(points)
      points.select { |point| point[2] }.max_by { |point| point[2] }
    end

    # The day an activity happened where it happened. Strava's dates and the
    # tracks' times are UTC, which puts an evening run in the eastern states on
    # the next day. The hour offset from the longitude is close enough to get
    # the day right.
    def local_date(time, lon)
      return time&.to_date unless time && lon

      (time + ((lon / 15.0).round * 3600)).to_date
    end
  end
end
