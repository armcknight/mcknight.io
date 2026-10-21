#!/usr/bin/env ruby
# frozen_string_literal: true

# Writes books/_data/states.yml: the 195 countries the page counts against —
# the 193 members of the United Nations and its two observer states, Vatican
# City and Palestine — each by its ISO 3166-1 code and name, from Wikidata.
#
#   make books-states
#
# The list hardly ever changes, so it is fetched on demand and committed, not
# on every build. It fails rather than write a list of the wrong length.

$LOAD_PATH.unshift(File.expand_path('../lib', __dir__))
require 'yaml'
require 'books/wikidata'

TARGET = File.expand_path('../_data/states.yml', __dir__)

# Current members: a membership (P463) of the United Nations (Q1065) with no
# end time, held by an item with an ISO code (P297).
MEMBERS = <<~SPARQL
  SELECT ?item ?iso ?name WHERE {
    ?item p:P463 ?membership .
    ?membership ps:P463 wd:Q1065 .
    FILTER NOT EXISTS { ?membership pq:P582 ?end }
    OPTIONAL { ?item wdt:P297 ?iso }
    ?item rdfs:label ?name FILTER(LANG(?name) = "en")
  }
SPARQL

# Members whose membership Wikidata records on an item with no ISO code. The
# Kingdom of Denmark (Q756617), the whole realm with Greenland and the Faroes,
# is the member; Denmark itself (Q35) holds the code.
CODE_OF = { 'Q756617' => %w[DK Denmark] }.freeze

# The two observer states, which are counted as countries though not members.
OBSERVERS = [%w[VA Vatican\ City], %w[PS Palestine]].freeze

rows = Books::Wikidata.sparql(MEMBERS)
states = rows.filter_map do |row|
  id = row['item'].split('/').last
  if row['iso']
    [row['iso'], row['name']]
  elsif CODE_OF[id]
    CODE_OF[id]
  end
end
# A member with no code and no entry above is a state that no longer exists,
# with a stale membership: the Soviet Union, Czechoslovakia.
states = (states + OBSERVERS).uniq(&:first).sort_by(&:last)

abort "Expected 195 states, got #{states.size}; not writing #{TARGET}." unless states.size == 195

File.write(TARGET, states.map { |iso, name| { 'iso' => iso, 'name' => name } }.to_yaml(line_width: -1))
puts "Wrote #{states.size} states to #{TARGET.delete_prefix("#{Dir.pwd}/")}."
