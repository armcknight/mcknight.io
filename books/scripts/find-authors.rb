#!/usr/bin/env ruby
# frozen_string_literal: true

# Finds where and when each author in books/_data/books.yml was born, from
# Wikidata, and keeps it in books/_data/authors.yml:
#
#   - name: Marcus Aurelius
#     qid: Q1430           the Wikidata item, to check or correct by hand
#     born: 121            the year; negative before the common era
#     birthplace: Rome
#     lat: 41.8933
#     lon: 12.4831
#     check: why a person should look at this one, when it is not certain
#     problem: why there is no place, when there is none
#
# Run it with `make books-authors`. It is safe to re-run: an author with a
# place is left alone, so only new authors cost a lookup. To correct one, set
# its qid by hand and delete its other fields but the name; the next run
# fills them in from that item. An author marked `skip: true` is never looked
# up, for a name that is not a person.
#
# A name is matched to people only, by their label or an alias, ignoring
# punctuation and case, so "J.R.R. Tolkien" finds "J. R. R. Tolkien"; with no
# such match, the search's first person stands in, marked to check. When
# several people share the name, the one Wikidata records as the author of
# one of the books wins; failing that, the best known one does, and is
# marked to check. Without a birthplace, the country of citizenship stands
# in, and is marked too.
#
# The file is saved after every author, so a run that stops loses nothing.

$LOAD_PATH.unshift(File.expand_path('../lib', __dir__))
require 'yaml'
require 'books/wikidata'

DATA = File.expand_path('../_data', __dir__)
BOOKS = File.join(DATA, 'books.yml')
AUTHORS = File.join(DATA, 'authors.yml')

W = Books::Wikidata

def key(name) = name.to_s.downcase.gsub(/[^\p{L}\p{N}]/, '')

# A title as a search would know it: no subtitle, no series in brackets.
def short_title(title) = title.sub(/\s*\(.*\)\s*\z/, '').split(':').first.strip

def save(authors)
  File.write(AUTHORS, authors.to_yaml(line_width: -1))
end

# The person, among people sharing the name, whom Wikidata records as the
# author of one of their books here.
def author_of(people, titles)
  ids = people.map { |person| person['id'] }
  titles.first(3).each do |title|
    W.entities(W.search(short_title(title), limit: 5)).each_value do |work|
      found = (W.values(work, W::AUTHOR) & ids).first
      return people.find { |person| person['id'] == found } if found
    end
  end
  nil
end

def resolve(name, titles)
  ids = W.search(name)
  found = W.entities(ids)
  humans = ids.filter_map { |id| found[id] }.select { |entity| W.human?(entity) }
  people = humans.select { |entity| W.names(entity).any? { |each| key(each) == key(name) } }

  # Goodreads and Wikidata do not always name a person alike: "Dalai Lama
  # XIV" is "14th Dalai Lama". The search still finds them, so its first
  # person stands in, to be checked.
  if people.empty?
    first = humans.first
    return [nil, nil] unless first

    return [first, "named #{W.label(first).inspect} on Wikidata, not this; the search's first person"]
  end
  return [people.first, nil] if people.size == 1

  by_book = author_of(people, titles)
  return [by_book, nil] if by_book

  best = people.max_by { |person| W.fame(person) }
  [best, "#{people.size} people are called this; chose the best known, #{best['id']}"]
end

# Fills an author's fields from their Wikidata item.
def describe(author, person)
  author['qid'] = person['id']
  born = W.birth_year(person)
  author['born'] = born if born

  place_id = W.values(person, W::BIRTHPLACE).first
  if place_id
    place = W.entities([place_id])[place_id]
    where = place && W.coordinates(place)
    if where
      author['birthplace'] = W.label(place)
      author['lat'], author['lon'] = where
      return
    end
  end

  country_id = W.values(person, W::CITIZENSHIP).first
  country = country_id && W.entities([country_id])[country_id]
  where = country && W.coordinates(country)
  if where
    author['birthplace'] = W.label(country)
    author['lat'], author['lon'] = where
    author['check'] = [author['check'], 'no birthplace on Wikidata; placed in the country of citizenship'].compact.join('; ')
  else
    author['problem'] = 'no birthplace or citizenship on Wikidata'
  end
end

books = YAML.safe_load_file(BOOKS) || []
authors = File.exist?(AUTHORS) ? (YAML.safe_load_file(AUTHORS) || []) : []
known = authors.to_h { |author| [author['name'], author] }

# Books read first, so a stopped run has already done the authors that show.
order = %w[read currently-reading to-read]
titles = Hash.new { |hash, name| hash[name] = [] }
books.sort_by { |book| order.index(book['shelf']) || order.size }.each { |book| titles[book['author']] << book['title'] }

found = 0
uncertain = []
missing = []
titles.each_with_index do |(name, their_titles), i|
  author = known[name]
  next if author && (author['lat'] || author['skip'] || author['problem'])

  unless author
    author = { 'name' => name }
    authors << author
    known[name] = author
  end

  print "[#{i + 1}/#{titles.size}] #{name} … "
  begin
    if author['qid']
      person = W.entities([author['qid']])[author['qid']]
      note = nil
    else
      person, note = resolve(name, their_titles)
    end
  rescue W::Refused, StandardError => e
    puts "stopped: #{e.message}. Re-run to carry on."
    break
  end

  if person
    author['check'] = note if note
    describe(author, person)
  else
    author['problem'] = 'no person by this name on Wikidata'
  end
  save(authors)

  if author['lat']
    found += 1
    puts [author['birthplace'], author['born'], author['check'] && "(check: #{author['check']})"].compact.join(', ')
    uncertain << name if author['check']
  else
    puts author['problem']
    missing << name
  end
end

puts
puts "Placed #{found} new authors; #{uncertain.size} to check, #{missing.size} not found."
puts "Not found: #{missing.join(', ')}" if missing.any?
