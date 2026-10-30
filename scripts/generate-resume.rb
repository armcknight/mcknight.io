#!/usr/bin/env ruby
# frozen_string_literal: true

# Writes a resume's LaTeX from the same data the experience page is built
# from, so the two never disagree: _data/experience.yaml, education.yaml,
# presentations.yaml and mentorship.yaml, rendered through an ERB template.
# Which entries go in, under which sections, in which order, the resume's
# entry in selections.yml says. And writes the cover letter of the same name,
# from its entry in letters.yml, through letter.tex.erb.
#
#   ruby scripts/generate-resume.rb reddit
#
# writes resume/.build/reddit.tex from the `reddit` entry in
# resume/selections.yml, and resume/.build/reddit-letter.tex from the one in
# resume/letters.yml: either, or both, as each has an entry by that name. The
# selections, the letters, the templates (resume.tex.erb unless a selection
# names another) and the output all live in the resume repo (the resume/
# submodule), which is private, so they can hold what the public site must
# not: the address and phone number, and which resume went where. The
# templates hold the layout; this holds only how each kind of entry is
# written. The comments at the top of selections.yml and letters.yml describe
# an entry.
#
# Sections: experience, education, presentations and mentorship, whose entries
# are named by the `id` each has in the data; and publications and honors,
# which come from the degrees and are all or nothing. Each has its one title.
# A name, section or id that does not exist stops the run, with the ones that
# do.
#
# `make resume-<name>` runs this and builds the PDFs. The output is generated
# and ignored by git: edit the data, the selection, the letter or the
# templates.
#
# Text may use `backticks` for code, and "straight quotes", which become TeX's.

require 'erb'
require 'fileutils'
require 'yaml'

ROOT = File.expand_path('..', __dir__)
DATA = File.join(ROOT, '_data')
RESUME = File.join(ROOT, 'resume')
BUILD = File.join(RESUME, '.build')

USAGE = 'usage: ruby scripts/generate-resume.rb <name> [--private], for an entry in resume/selections.yml or letters.yml'
name = ARGV.reject { |arg| arg.start_with?('--') }.first or abort USAGE
unknown = ARGV.select { |arg| arg.start_with?('--') } - ['--private']
abort "#{USAGE}; not #{unknown.join(', ')}" if unknown.any?
# The copy for the web, without the address and phone number, unless asked for
# the private one, which also gets names of its own, <name>-private.tex, so it
# can never be mistaken for, or overwrite, the copy for the web.
WEB = !ARGV.include?('--private')
SUFFIX = WEB ? '' : '-private'
selections = YAML.load_file(File.join(RESUME, 'selections.yml'))
letters = YAML.load_file(File.join(RESUME, 'letters.yml'))
# Whether a copy is for the web is the run's to say, not an entry's: a `web`
# key left in one would be ignored, so it stops the run instead.
{ 'selections.yml' => selections, 'letters.yml' => letters }.each do |file, entries|
  stale = entries.select { |_, entry| entry.is_a?(Hash) && entry.key?('web') }.keys
  next if stale.empty?

  abort "resume/#{file}: #{stale.join(', ')} still say web:, which no entry sets now; " \
        'build the private copy with `make resume-<name> WEB=false` instead'
end
unless selections.key?(name) || letters.key?(name)
  abort "No resume or letter #{name} in resume/selections.yml or letters.yml; " \
        "there are #{(selections.keys | letters.keys).join(', ')}"
end

# What the template can call. Every helper returns LaTeX, escaped and ready to
# insert; data goes in raw.
class Resume
  MONTHS = %w[January February March April May June July August September October November December].freeze

  # Each kind of section: its title, and whether its entries have ids to pick
  # them by.
  KINDS = {
    'education' => ['Education', true],
    'publications' => ['Publications', false],
    'experience' => ['Experience', true],
    'honors' => ['Honors & Awards', false],
    'presentations' => ['Presentations', true],
    'mentorship' => ['Mentorship', true]
  }.freeze

  Section = Struct.new(:kind, :title, :items)

  attr_reader :experience, :education, :presentations, :mentorship

  # A resume's selection, or a cover letter's entry in letters.yml; source
  # names it in messages and in the output's header.
  def initialize(data, source, selection: {}, letter: {})
    @experience = load(data, 'experience.yaml', 'experience')
    @education = load(data, 'education.yaml', 'education')
    @presentations = load(data, 'presentations.yaml', 'presentations')
    @mentorship = load(data, 'mentorship.yaml', 'mentorship')
    @selection = selection
    @letter = letter
    @source = source
  end

  # Whether this is the copy for the web, without the address and phone
  # number: as the run was asked, never as an entry says.
  def web?
    WEB
  end

  # The selection's sections, in its order, each with its entries.
  def sections
    @selection.fetch('sections').map do |section|
      kind, spec = section.first
      title, by_id = KINDS.fetch(kind) { abort "#{@source}: no section called #{kind}; there are #{KINDS.keys.join(', ')}" }
      spec = { 'only' => spec } if spec.is_a?(Array)
      spec = {} if spec == 'all'
      extra = spec.keys - %w[only except]
      abort "#{@source}: #{kind} takes all, a list of ids, only or except, not #{extra.join(', ')}" if extra.any?
      Section.new(kind, title, pick(kind, all_of(kind), spec, by_id))
    end
  end

  def publications
    education.flat_map { |degree| degree['publications'].to_a }
  end

  # Every degree's honors, newest first, in data order within a year.
  def honors
    all = education.flat_map { |degree| degree['honors'].to_a }
    all.each_with_index.sort_by { |honor, index| [-honor['year'].to_s[/\d{4}/].to_i, index] }.map(&:first)
  end

  # Text for LaTeX: special characters escaped, `code` in typewriter type,
  # "quotes" as TeX's curly ones.
  def tex(text)
    text.to_s.split(/(`[^`]*`)/).map do |part|
      if part.start_with?('`') && part.end_with?('`') && part.size > 1
        "\\texttt{#{escape(part[1..-2])}}"
      else
        escape(part).gsub(/"([^"]*)"/) { "``#{Regexp.last_match(1)}''" }
      end
    end.join
  end

  def link(name, url)
    "\\href{#{url.to_s.gsub(/[%#]/) { |c| "\\#{c}" }}}{#{tex(name)}}"
  end

  # "Jan 2021 – Current", or "Jan – Apr 2018" within one year.
  def dates(item)
    start = short_date(item['start'])
    finish = short_date(item['end'])
    return start if finish.empty?

    start_month, start_year = start.split
    _, finish_year = finish.split
    return "#{start_month} – #{finish}" if start_year && start_year == finish_year

    "#{start} – #{finish}"
  end

  def year(text)
    text.to_s[/\d{4}/]
  end

  # A job's stack, every category in its order, on one line.
  def stack(job)
    items = job['stack'].to_a.flat_map { |category| category.is_a?(Hash) ? category.values.flatten : [] }
    items.empty? ? nil : items.map { |item| tex(item) }.join(', ')
  end

  # A deliverable or highlight: a plain string, or a name with a url and a
  # description. A deliverable is written as its name, then what it is; a
  # highlight is its description, the name in it linked, as the experience
  # page writes them.
  def item(entry, kind)
    return tex(entry) unless entry.is_a?(Hash)

    name = entry['url'] ? link(entry['name'], entry['url']) : tex(entry['name'])
    return tex(entry['description']).sub(tex(entry['name'])) { name } if kind == :highlight

    entry['description'] ? "#{name}: #{tex(entry['description'])}" : name
  end

  # The \item lines of one job's entry, indented for the template.
  def job_items(job)
    lines = []
    lines << "\\item \\textbf{Stack}: #{stack(job)}" if stack(job)
    deliverables = job['deliverables'].to_a
    if deliverables.size == 1 && deliverables.first.is_a?(String)
      lines << "\\item \\textbf{Deliverables}: #{tex(deliverables.first)}"
    elsif deliverables.any?
      # \cvlistlabel, from the template, keeps it on the page with the list.
      lines << '\\item \\cvlistlabel{Deliverables}'
      lines.concat(list(deliverables.map { |d| [item(d, :deliverable), d.is_a?(Hash) ? d['details'].to_a.map { |x| tex(x) } : []] }))
    end
    highlights = job['highlights'].to_a.map { |h| item(h, :highlight) }
    if highlights.any?
      # Labelled when the entry says more than its highlights; on their own
      # they are the entry.
      if lines.empty?
        lines.concat(highlights.map { |h| "\\item #{h}" })
      else
        lines << '\\item \\cvlistlabel{Highlights}'
        lines.concat(list(highlights.map { |h| [h, []] }))
      end
    end
    lines
  end

  private

  def load(dir, file, key)
    YAML.load_file(File.join(dir, file))[key].to_a
  end

  def all_of(kind)
    { 'education' => education, 'publications' => publications, 'experience' => experience,
      'honors' => honors, 'presentations' => presentations, 'mentorship' => mentorship }.fetch(kind)
  end

  # A section's entries: those `only` names, in its order; or all but those
  # `except` names, in data order; or all.
  def pick(kind, entries, spec, by_id)
    names = spec['only'] || spec['except']
    return entries unless names
    abort "#{@source}: #{kind} cannot be picked by id, only all of it" unless by_id

    known = entries.map { |entry| entry['id'] }
    unknown = names - known
    abort "#{@source}: no #{kind} with id #{unknown.join(', ')}; there are #{known.join(', ')}" if unknown.any?
    if spec['only']
      names.map { |id| entries.find { |entry| entry['id'] == id } }
    else
      entries.reject { |entry| names.include?(entry['id']) }
    end
  end

  def escape(text)
    text.gsub(/[\\&%$#_{}~^]/) do |c|
      case c
      when '\\' then '\\textbackslash{}'
      when '~' then '\\textasciitilde{}'
      when '^' then '\\textasciicircum{}'
      else "\\#{c}"
      end
    end
  end

  def short_date(text)
    text.to_s.split.map { |word| MONTHS.include?(word) ? word[0, 3] : word }.join(' ')
  end

  # A nested itemize of [line, sub-lines] pairs.
  def list(entries)
    lines = ['\\begin{itemize}']
    entries.each do |line, subs|
      lines << "    \\item #{line}"
      next if subs.empty?

      lines << '    \\begin{itemize}'
      lines.concat(subs.map { |sub| "        \\item #{sub}" })
      lines << '    \\end{itemize}'
    end
    lines << '\\end{itemize}'
  end
end

# Writes one .tex into .build/ from a template; or, with no entry for it,
# removes what an earlier run left there, so make does not build that.
def render(template, output, context)
  if context.nil?
    FileUtils.rm_f(output)
    return
  end
  tex = ERB.new(File.read(template), trim_mode: '-').result(context.instance_eval { binding })
  FileUtils.mkdir_p(File.dirname(output))
  File.write(output, tex)
  puts "Wrote #{output.delete_prefix("#{ROOT}/")} from #{template.delete_prefix("#{ROOT}/")}"
end

# The resume, from its selection, and the cover letter, from letters.yml:
# whichever of the two has an entry under the name.
selection = selections[name]
render(File.join(RESUME, selection ? selection['template'] || 'resume.tex.erb' : 'resume.tex.erb'),
       File.join(BUILD, "#{name}#{SUFFIX}.tex"),
       selection && Resume.new(DATA, "selections.yml, #{name}", selection: selection))
render(File.join(RESUME, 'letter.tex.erb'),
       File.join(BUILD, "#{name}-letter#{SUFFIX}.tex"),
       letters[name] && Resume.new(DATA, "letters.yml, #{name}", letter: letters[name]))
