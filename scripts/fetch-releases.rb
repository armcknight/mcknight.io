#!/usr/bin/env ruby
# frozen_string_literal: true

# Writes _data/releases.yml: the latest release version and date for each app and
# devtool in _data/projects.yml, for display on the projects page. And writes
# _data/activity.yml: each devtool's commits and lines added and deleted over
# the last year, month and week, which the page shows beside it as a small bar
# chart of commits and a count of lines, for the period its switch chooses.
#
# Run it with `make releases`. The result is committed, so builds and deploys
# never need the network or a GitHub token, and the page keeps showing the last
# known version if this ever fails.
#
# Per-project keys in _data/projects.yml, all optional:
#   release-repo:        owner/name to query. Defaults to the `website` repo.
#   release-tag-prefix:  only consider tags starting with this, and strip it from
#                        the displayed version. Needed for the tools whose
#                        releases live in the homebrew-tools tap under tags like
#                        `work-1.0.1`.

require 'date'
require 'json'
require 'yaml'
require 'open3'
require 'net/http'
require 'uri'

ROOT = File.expand_path('..', __dir__)
PROJECTS = File.join(ROOT, '_data', 'projects.yml')
RELEASES = File.join(ROOT, '_data', 'releases.yml')
ACTIVITY = File.join(ROOT, '_data', 'activity.yml')

def github_repo(project)
  return project['release-repo'] if project['release-repo']

  website = project['website'].to_s
  match = website.match(%r{github\.com/([^/]+/[^/#?]+)})
  match && match[1].sub(/\.git\z/, '')
end

# Newest published, non-draft, non-prerelease release whose tag matches the
# prefix. Sorted by date rather than by version, so a patch to an older line
# can't look like the latest release.
def latest_release(repo, prefix)
  out, err, status = Open3.capture3(
    'gh', 'api', '--paginate', "repos/#{repo}/releases?per_page=100"
  )
  raise "gh api failed for #{repo}: #{err.strip}" unless status.success?

  # --paginate concatenates one JSON array per page.
  releases = out.scan(/(?<=\A|\])\s*\[.*?\](?=\s*\[|\s*\z)/m).flat_map { |page| JSON.parse(page) }
  releases = JSON.parse(out) if releases.empty? && !out.strip.empty?

  candidates = releases.reject { |r| r['draft'] || r['prerelease'] }
                       .select { |r| r['published_at'] }
                       .select { |r| prefix.nil? || r['tag_name'].to_s.start_with?(prefix) }

  candidates.max_by { |r| r['published_at'] }
end

# App Store apps have no GitHub release to read, so take the shipping version
# from the public iTunes lookup API instead.
def app_store_release(app_store_url)
  id = app_store_url.to_s[%r{/id(\d+)}, 1]
  return nil if id.nil?

  response = Net::HTTP.get_response(URI("https://itunes.apple.com/lookup?id=#{id}"))
  return nil unless response.is_a?(Net::HTTPSuccess)

  result = JSON.parse(response.body).dig('results', 0)
  return nil if result.nil?

  {
    'version' => result['version'],
    'date' => result['currentVersionReleaseDate'][0, 10],
    'url' => app_store_url
  }
end

# The repository a project's code lives in, which is where its commits are:
# its website, even when its releases are published from another repository
# (the homebrew-tools tap).
def code_repo(project)
  match = project['website'].to_s.match(%r{github\.com/([^/]+/[^/#?]+)})
  match && match[1].sub(/\.git\z/, '')
end

# A year of a repository's activity, from its commits on the default branch:
# how many commits, and how many lines added and deleted, on each of the last
# 365 days, oldest first and ending today.
#
# From the commits themselves rather than GitHub's statistics endpoints:
# those count lines only by week, and work their numbers out when first asked,
# answering 202 with nothing for minutes on end. Each commit's lines come
# from its own page, which never changes once written, so they are kept in
# .cache/commit-stats.json (git ignores it) and only new commits cost a call.
#
# A merge commit counts as a commit but not for lines: its changes are the
# merged commits', already counted.
COMMIT_STATS = File.join(ROOT, '.cache', 'commit-stats.json')
DAYS = 365

def commit_stats_cache
  @commit_stats_cache ||= File.exist?(COMMIT_STATS) ? JSON.parse(File.read(COMMIT_STATS)) : {}
end

def save_commit_stats_cache
  Dir.mkdir(File.dirname(COMMIT_STATS)) unless Dir.exist?(File.dirname(COMMIT_STATS))
  File.write(COMMIT_STATS, JSON.generate(commit_stats_cache))
end

def gh_json(path)
  out, err, status = Open3.capture3('gh', 'api', path)
  raise "gh api failed for #{path}: #{err.strip}" unless status.success?

  JSON.parse(out)
end

# Every commit on the default branch since a date, as { sha, date, parents }.
# Paged through by gh, which prints each commit as a line of its own, so no
# page has to be cut out of the joined output by matching brackets — which a
# commit message holding "][" broke.
def commits_since(repo, since)
  out, err, status = Open3.capture3(
    'gh', 'api', '--paginate', "repos/#{repo}/commits?since=#{since}&per_page=100",
    '--jq', '.[] | {sha, date: .commit.author.date, parents: (.parents | length)}'
  )
  raise "gh api failed for #{repo}'s commits: #{err.strip}" unless status.success?

  out.lines.map { |line| JSON.parse(line) }
end

def daily_activity(repo)
  today = Time.now.utc.to_date
  first = today - (DAYS - 1)
  commits = commits_since(repo, "#{first.iso8601}T00:00:00Z")

  counts = Array.new(DAYS, 0)
  added = Array.new(DAYS, 0)
  deleted = Array.new(DAYS, 0)
  commits.each do |commit|
    day = (Date.parse(commit['date']) - first).to_i
    next unless day.between?(0, DAYS - 1)

    counts[day] += 1
    next if commit['parents'] > 1

    stats = commit_stats_cache[commit['sha']] ||=
      gh_json("repos/#{repo}/commits/#{commit['sha']}")['stats'].slice('additions', 'deletions')
    added[day] += stats['additions']
    deleted[day] += stats['deletions']
  end
  save_commit_stats_cache
  { counts: counts, added: added, deleted: deleted }
end

def version_from(tag, prefix)
  version = tag.to_s
  version = version.sub(/\A#{Regexp.escape(prefix)}/, '') if prefix
  version.sub(/\Av/, '')
end

projects = YAML.load_file(PROJECTS)
releases = {}
skipped = []

(projects['apps'].to_a + projects['devtools'].to_a).each do |project|
  name = project['name']

  if project['app-store-url']
    release = app_store_release(project['app-store-url'])
    if release.nil?
      skipped << "#{name}: no version from the App Store"
    else
      releases[name] = release
      puts format('%-22s %-10s %s', name, release['version'], release['date'])
    end
    next
  end

  repo = github_repo(project)
  if repo.nil?
    skipped << "#{name}: no GitHub repo and no App Store listing"
    next
  end

  prefix = project['release-tag-prefix']
  release = latest_release(repo, prefix)

  if release.nil?
    skipped << "#{name}: no published release in #{repo}#{prefix ? " matching #{prefix}*" : ''}"
    next
  end

  version = version_from(release['tag_name'], prefix)
  releases[name] = {
    'version' => version,
    'date' => release['published_at'][0, 10],
    'url' => release['html_url'],
    'tag' => release['tag_name']
  }
  puts format('%-22s %-10s %s', name, version, release['published_at'][0, 10])
end

header = <<~YAML
  # Generated by scripts/fetch-releases.rb — run `make releases` to refresh.
  # Keyed by the project name in projects.yml.
YAML

File.write(RELEASES, header + releases.to_yaml.sub(/\A---\n/, ''))

puts
puts "Wrote #{releases.size} releases to _data/releases.yml"
skipped.each { |line| puts "  skipped #{line}" }

# --- commit activity -------------------------------------------------------
#
# For each devtool, over the last year, month (30 days) and week (7 days),
# each ending today: commits and lines added and deleted; with the commits
# also by week over the year and by day over the month, for the page's charts.
# The year's weeks are 52 runs of 7 days ending today, so the last is the week.

puts
activity = {}
missing = []
projects['devtools'].to_a.each do |project|
  repo = code_repo(project)
  if repo.nil?
    missing << project['name']
    next
  end

  daily = daily_activity(repo)
  span = ->(series, days) { series.last(days).sum }
  entry = { 'weeks' => daily[:counts].last(52 * 7).each_slice(7).map(&:sum), 'days' => daily[:counts].last(30) }
  { 'year' => DAYS, 'month' => 30, 'week' => 7 }.each do |period, days|
    entry[period] = { 'commits' => span.call(daily[:counts], days),
                      'added' => span.call(daily[:added], days), 'deleted' => span.call(daily[:deleted], days) }
  end
  activity[project['name']] = entry
  puts format('%-20s year %3d commits +%-6d -%-6d  month %3d +%-6d -%-6d  week %3d +%-5d -%d', project['name'],
              *%w[year month week].flat_map { |period| entry[period].values_at('commits', 'added', 'deleted') })
end

# Each list on one line, rather than YAML's one line per number.
lines = activity.map do |name, data|
  periods = %w[year month week].map do |period|
    counts = data[period]
    "  #{period}: { commits: #{counts['commits']}, added: #{counts['added']}, deleted: #{counts['deleted']} }\n"
  end
  "#{name.to_yaml.sub(/\A--- /, '').strip}:\n#{periods.join}" \
    "  weeks: [#{data['weeks'].join(', ')}]\n  days: [#{data['days'].join(', ')}]\n"
end
File.write(ACTIVITY, <<~YAML + lines.join)
  # Generated by scripts/fetch-releases.rb — run `make releases` to refresh.
  # Each devtool's activity on its default branch, from its commits, as of
  # #{Time.now.utc.strftime('%Y-%m-%d')}: commits and lines added and deleted over the last 365,
  # 30 and 7 days (year, month, week; merges count as commits but not lines);
  # then commits by week over the year (weeks, 52 runs of 7 days) and by day
  # over the month (days), each oldest first and ending today.
YAML

puts
puts "Wrote the activity of #{activity.size} devtools to _data/activity.yml"
puts "  no GitHub repository for #{missing.join(', ')}" unless missing.empty?
