#!/usr/bin/env ruby
# frozen_string_literal: true

# Finds the authors that today's borders do not fit, records the state each
# was born in when it no longer exists, and lists them:
#
#   _data/authors.yml   each such author gains `then:`, the former states they
#                       were a citizen of in the year they were born
#
#   make books-history
#
# Run after books-geo, which files each author under a country. Both tests come
# from Wikidata: whether a citizenship is a historical country (P31 Q3024240)
# or has a dissolution date (P576), and a country's inception (P571).
#
# Only the first test writes anything. A state counts for `then` only if it
# existed in the birth year, so Kafka, born in Prague in 1883, was born in
# Cisleithania and not in Czechoslovakia, which he was later a citizen of; and
# only if the citizenship had begun by then, where Wikidata says when it did.
# Where Wikidata still has it wrong, write `then:` by hand and add
# `then_by_hand: true`, and it is kept.
#
# The second test is reported but not recorded, because Wikidata dates a
# country from its present form: the United Kingdom from 1921, China from
# 1949. That flags every British author born before 1921, though the map
# hardly changed.

$LOAD_PATH.unshift(File.expand_path('../lib', __dir__))
require 'json'
require 'yaml'
require 'books/wikidata'

ROOT = File.expand_path('..', __dir__)
W = Books::Wikidata

INCEPTION = 'P571'
DISSOLVED = 'P576'
HISTORICAL_COUNTRY = 'Q3024240'

AUTHORS = File.join(ROOT, '_data', 'authors.yml')
everyone = YAML.safe_load_file(AUTHORS) || []
authors = everyone.select { |author| author['country'] && author['qid'] }
books = YAML.safe_load_file(File.join(ROOT, '_data', 'books.yml')) || []
shelves = books.group_by { |book| book['author'] }.transform_values { |list| list.map { |book| book['shelf'] }.uniq }

countries = JSON.parse(File.read(File.join(ROOT, 'assets', 'geo', 'countries.json')))['features']
country_item = countries.to_h { |feature| [feature['properties']['iso'], feature['properties']['wikidata']] }
country_name = countries.to_h { |feature| [feature['properties']['iso'], feature['properties']['name']] }

# A country can have several inceptions — a kingdom, then a republic — and the
# earliest is the fair test: an author born in any form of it was born in it.
items = W.entities(authors.map { |author| country_item[author['country']] }.compact)
began = country_item.transform_values do |id|
  item = id && items[id]
  item && W.values(item, INCEPTION).filter_map { |value| W.year(value['time']) }.min
end

START_TIME = 'P580'

people = W.entities(authors.map { |author| author['qid'] })
citizenships = people.transform_values { |person| W.values(person, W::CITIZENSHIP) }

# The citizenships a person had when born: those whose claim has no start
# time, or one no later than the birth year. Conrad, born a Russian subject in
# 1857, became British in 1886, and his British claim says so.
def citizenships_at_birth(person, year)
  person.dig('claims', W::CITIZENSHIP).to_a.filter_map do |claim|
    id = claim.dig('mainsnak', 'datavalue', 'value', 'id')
    started = claim.dig('qualifiers', START_TIME).to_a.filter_map { |q| W.year(q.dig('datavalue', 'value', 'time')) }.min
    id if id && (year.nil? || started.nil? || started <= year)
  end
end
states = W.entities(citizenships.values.flatten)
former = states.select do |_, state|
  W.values(state, W::INSTANCE_OF).include?(HISTORICAL_COUNTRY) || W.values(state, DISSOLVED).any?
end

# Whether a state existed in a year: no inception after it, no dissolution
# before it. A state with neither date on Wikidata counts.
def existed?(state, year)
  return true unless year

  began = W.values(state, INCEPTION).filter_map { |value| W.year(value['time']) }.min
  ended = W.values(state, DISSOLVED).filter_map { |value| W.year(value['time']) }.max
  (began.nil? || began <= year) && (ended.nil? || year < ended)
end

flagged = authors.filter_map do |author|
  unless author['then_by_hand']
    person = people[author['qid']]
    then_states = (person ? citizenships_at_birth(person, author['born']) : []).filter_map do |id|
      W.label(former[id]) if former[id] && existed?(former[id], author['born'])
    end
    if then_states.any?
      author['then'] = then_states
    else
      author.delete('then')
    end
  end

  reasons = []
  start = began[author['country']]
  if author['born'] && start && author['born'] < start
    reasons << "born before #{country_name[author['country']]} began (#{start})"
  end
  gone = citizenships.fetch(author['qid'], []).filter_map { |id| former[id] && W.label(former[id]) }
  reasons << "citizen of #{gone.join(', ')}" if gone.any?
  next if reasons.empty?

  [author, reasons]
end

order = %w[read currently-reading to-read]
flagged.sort_by! { |author, _| [order.index(shelves[author['name']]&.min_by { |shelf| order.index(shelf) || 9 }) || 9, author['born'] || 0] }

puts "#{flagged.size} of #{authors.size} placed authors do not fit today's borders:"
puts
flagged.each do |author, reasons|
  shelf = shelves[author['name']]&.join('/')
  puts format('  %-28s %6s  %-22s %-3s  [%s]  %s', author['name'][0, 28], author['born'], author['birthplace'].to_s[0, 22],
              author['country'], shelf, reasons.join('; '))
end

states_named = flagged.flat_map { |_, reasons| reasons.grep(/\Acitizen of /).flat_map { |reason| reason.delete_prefix('citizen of ').split(', ') } }
puts
puts 'Former states, by authors:'
states_named.tally.sort_by { |_, count| -count }.each { |name, count| puts format('  %3d  %s', count, name) }

File.write(AUTHORS, everyone.to_yaml(line_width: -1))
recorded = authors.count { |author| author['then'] }
puts
puts "Recorded the former state of #{recorded} authors in #{AUTHORS.delete_prefix("#{Dir.pwd}/")}."
