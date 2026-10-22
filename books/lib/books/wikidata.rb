# frozen_string_literal: true

require 'json'
require 'net/http'
require 'uri'

module Books
  # Who an author is, and where and when they were born, from Wikidata.
  #
  # Wikidata's API asks for an identifying User-Agent and a modest rate; every
  # request here sends one and waits a moment after the last. A refusal (429
  # or a server error) is waited out and retried a few times, then given up.
  module Wikidata
    USER_AGENT = 'mcknight.io-books-map/1.0 (andrew@mcknight.io)'
    API = 'https://www.wikidata.org/w/api.php'
    PAUSE = 0.25
    BACKOFF = [5, 15, 45].freeze

    HUMAN = 'Q5'
    BIRTHPLACE = 'P19'
    BIRTH_DATE = 'P569'
    CITIZENSHIP = 'P27'
    COORDINATES = 'P625'
    INSTANCE_OF = 'P31'
    AUTHOR = 'P50'

    class Refused < StandardError; end

    @last_request = nil

    module_function

    # Items whose label or alias matches the text, best known first.
    def search(text, limit: 10)
      call(action: 'wbsearchentities', search: text, language: 'en', uselang: 'en', type: 'item', limit: limit)
        .fetch('search', []).map { |hit| hit['id'] }
    end

    # Items by id, with their claims, labels and aliases, and how many
    # Wikipedias have a page on them. Fifty at a time, the API's limit.
    #
    # Labels in English and in "mul", the label for every language at once,
    # which is where Wikidata now keeps most people's names: Q42, Douglas
    # Adams, has no English label of his own.
    def entities(ids)
      ids.uniq.each_slice(50).each_with_object({}) do |slice, found|
        answer = call(action: 'wbgetentities', ids: slice.join('|'), props: 'claims|labels|aliases|sitelinks', languages: 'en|mul')
        found.merge!(answer.fetch('entities', {}).reject { |_, entity| entity.key?('missing') })
      end
    end

    LANGUAGES = %w[en mul].freeze

    def label(entity) = LANGUAGES.filter_map { |language| entity.dig('labels', language, 'value') }.first

    def names(entity)
      LANGUAGES.flat_map do |language|
        [entity.dig('labels', language, 'value'), *entity.dig('aliases', language).to_a.map { |alias_| alias_['value'] }]
      end.compact.uniq
    end

    def fame(entity) = entity.fetch('sitelinks', {}).size

    # The values of a property: item ids, or the raw value for anything else.
    def values(entity, property)
      entity.dig('claims', property).to_a.filter_map do |claim|
        value = claim.dig('mainsnak', 'datavalue', 'value')
        value.is_a?(Hash) && value['id'] ? value['id'] : value
      end
    end

    def human?(entity) = values(entity, INSTANCE_OF).include?(HUMAN)

    # A year from a Wikidata time, which reads like "+1953-05-02T00:00:00Z",
    # or "-0121-..." before the common era. Wikidata has no year zero, and
    # neither does this: 1 BC is -1.
    def year(time)
      time.to_s[/\A[+-]?\d+/]&.to_i
    end

    def birth_year(entity)
      values(entity, BIRTH_DATE).filter_map { |value| year(value['time']) }.first
    end

    # How exactly a date is known, by Wikidata's precision numbers. A date
    # known only to the century is stored as a year in it — Kim Zetter's
    # "20th century" is +1901 — so the year alone would claim more than is
    # known. Nil when it is known to the year or better.
    ROUGH = { 6 => 'millennium', 7 => 'century', 8 => 'decade' }.freeze

    def birth_precision(entity)
      ROUGH[values(entity, BIRTH_DATE).first&.dig('precision')]
    end

    def coordinates(entity)
      value = values(entity, COORDINATES).first
      value && [value['latitude'].round(4), value['longitude'].round(4)]
    end

    SPARQL = 'https://query.wikidata.org/sparql'

    # The rows of a SPARQL query, each a hash of variable name to value.
    def sparql(query)
      uri = URI(SPARQL)
      uri.query = URI.encode_www_form(query: query, format: 'json')
      response = get(uri)
      raise "HTTP #{response.code} from the Wikidata query service" unless response.is_a?(Net::HTTPSuccess)

      JSON.parse(response.body).dig('results', 'bindings').map do |row|
        row.transform_values { |cell| cell['value'] }
      end
    end

    def call(params, refusals = 0)
      uri = URI(API)
      uri.query = URI.encode_www_form(params.merge(format: 'json'))
      response = get(uri)
      if response.is_a?(Net::HTTPTooManyRequests) || response.is_a?(Net::HTTPServerError)
        raise Refused, "Wikidata refused #{refusals + 1} times" if refusals >= BACKOFF.length

        warn "  #{response.code} from Wikidata — waiting #{BACKOFF[refusals]}s"
        sleep BACKOFF[refusals]
        return call(params, refusals + 1)
      end
      raise "HTTP #{response.code} from Wikidata" unless response.is_a?(Net::HTTPSuccess)

      JSON.parse(response.body)
    end

    def get(uri)
      if @last_request
        wait = PAUSE - (Time.now - @last_request)
        sleep wait if wait.positive?
      end
      @last_request = Time.now
      Net::HTTP.start(uri.host, uri.port, use_ssl: true, open_timeout: 10, read_timeout: 30) do |http|
        http.request(Net::HTTP::Get.new(uri, 'User-Agent' => USER_AGENT))
      end
    end
  end
end
