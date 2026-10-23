#!/usr/bin/env ruby
# frozen_string_literal: true

# Checks _data/projects.yml before the main site is built: every developer
# tool needs an `impact`, a whole number from 1, closest to an end user, and no
# two tools may share one, since the projects page sorts by it.
#
# Run by `make build home` (and `make build`, which means home); it fails the
# build, naming each problem, so a deploy never ships a page that cannot sort.

require 'yaml'

tools = YAML.load_file(File.expand_path('../_data/projects.yml', __dir__)).fetch('devtools', [])
problems = []

tools.each do |tool|
  impact = tool['impact']
  if impact.nil?
    problems << "#{tool['name']} has no impact"
  elsif !impact.is_a?(Integer) || impact < 1
    problems << "#{tool['name']} has impact #{impact.inspect}, which is not a whole number from 1"
  end
end

tools.select { |tool| tool['impact'].is_a?(Integer) }.group_by { |tool| tool['impact'] }.each do |impact, same|
  problems << "impact #{impact} is shared by #{same.map { |tool| tool['name'] }.join(', ')}" if same.size > 1
end

if problems.empty?
  puts "projects.yml: #{tools.size} developer tools, each with its own impact"
else
  warn 'projects.yml: the developer tools need an impact each, from 1 (closest to an end user), with no two the same:'
  problems.each { |problem| warn "  #{problem}" }
  exit 1
end
