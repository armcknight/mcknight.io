#!/usr/bin/env ruby
# frozen_string_literal: true

# Writes books/_data/books.yml from a Goodreads library export: My Books →
# Import and export → Export library, which gives goodreads_library_export.csv.
#
#   make books-import CSV=~/Desktop/goodreads_library_export.csv
#
# Goodreads is the record for its books, so they are replaced whole each time:
# a book shelved, moved or removed there is the same here after the next run.
# Authors are looked up separately (find-authors.rb), and kept in their own
# file, so a re-import never costs a lookup again.
#
# A book added by hand is kept. It needs a title, an author, a shelf (read,
# currently-reading or to-read) and `manual: true`:
#
#   - title: The Dispossessed
#     author: Ursula K. Le Guin
#     shelf: read
#     manual: true
#
# Once the same book (by title and author) is in the Goodreads export too, the
# hand-made copy is dropped, and named, so it is not counted twice.
#
# Only what the globe uses is kept. The export also holds reviews, private
# notes and ratings, and none of that is read, let alone committed.

require 'csv'
require 'set'
require 'yaml'

path = File.expand_path(ARGV.first.to_s) if ARGV.first
path or abort 'usage: import-goodreads.rb path/to/goodreads_library_export.csv'
abort "No such file: #{path}" unless File.exist?(path)

# Goodreads pads names with runs of spaces ("Derek   Thompson").
def name(text) = text.to_s.split.join(' ')

# ISBNs come wrapped as spreadsheet formulas, ="9780770436179", so a
# spreadsheet keeps their leading zeros.
def isbn(text) = text.to_s.delete('="').strip.then { |value| value.empty? ? nil : value }

def year(*texts) = texts.map(&:to_s).find { |text| text.match?(/\A-?\d+\z/) }&.to_i

def date(text) = text.to_s.empty? ? nil : text.tr('/', '-')

books = CSV.foreach(path, headers: true, encoding: 'bom|utf-8').map do |row|
  {
    'id' => row['Book Id'],
    'title' => row['Title'].to_s.strip,
    'author' => name(row['Author']),
    # Co-authors and translators alike: the export does not say which is
    # which, so they are kept but not counted.
    'additional_authors' => row['Additional Authors'].to_s.split(',').map { |each| name(each) }.reject(&:empty?),
    'isbn13' => isbn(row['ISBN13']),
    'published' => year(row['Original Publication Year'], row['Year Published']),
    'shelf' => row['Exclusive Shelf'],
    'read' => date(row['Date Read'])
  }.reject { |_, value| value.nil? || value == [] }
end

SHELVES = %w[read currently-reading to-read].freeze

target = File.expand_path('../_data/books.yml', __dir__)
existing = File.exist?(target) ? (YAML.safe_load_file(target) || []) : []

same = ->(book) { [book['title'].to_s.downcase.strip, name(book['author']).downcase] }
imported = books.to_set(&same)
manual, now_imported = existing.select { |book| book['manual'] }.partition { |book| !imported.include?(same.call(book)) }
manual.each do |book|
  warn "  #{book['title'].inspect}: shelf #{book['shelf'].inspect} is not one of #{SHELVES.join(', ')}" unless SHELVES.include?(book['shelf'])
end

File.write(target, (books + manual).to_yaml(line_width: -1))
shelves = (books + manual).map { |book| book['shelf'] }.tally.map { |shelf, count| "#{count} #{shelf}" }.join(', ')
puts "Wrote #{books.size} books from Goodreads and kept #{manual.size} added by hand (#{shelves}) " \
     "to #{target.delete_prefix("#{Dir.pwd}/")}."
unless now_imported.empty?
  puts "Dropped #{now_imported.size} added by hand that Goodreads now has: #{now_imported.map { |book| book['title'] }.join(', ')}"
end
