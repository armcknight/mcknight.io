#!/usr/bin/env ruby
# frozen_string_literal: true

# Writes the CV's LaTeX from the same data the experience page is built from,
# so the two never disagree: _data/experience.yaml, _data/education.yaml and
# _data/presentations.yaml, rendered through an ERB template.
#
#   ruby scripts/generate-cv.rb [template] [output]
#
# The defaults are resume/cv.tex.erb and resume/cv.tex. The template lives in
# the resume repo (the resume/ submodule), which is private, so it can hold
# what the public site must not: the postal address and phone number. It holds
# the layout, too; this holds only how each kind of entry is written.
#
# `make resume` runs this before building the PDFs. The output is committed in
# the resume repo, so that repo still builds on its own; edit the data or the
# template, never the output.
#
# What the data may say, beyond what the experience page shows:
#   cv: false            leaves an entry out of the CV (education: out of the
#                        education section; its honors are still listed)
# Text may use `backticks` for code, and "straight quotes", which become TeX's.

require 'erb'
require 'yaml'

ROOT = File.expand_path('..', __dir__)
DATA = File.join(ROOT, '_data')

template = ARGV[0] || File.join(ROOT, 'resume', 'cv.tex.erb')
output = ARGV[1] || File.join(ROOT, 'resume', 'cv.tex')

# What the template can call. Every helper returns LaTeX, escaped and ready to
# insert; data goes in raw.
class CV
  MONTHS = %w[January February March April May June July August September October November December].freeze

  attr_reader :experience, :education, :presentations

  def initialize(data)
    @experience = load(data, 'experience.yaml', 'experience')
    @education = load(data, 'education.yaml', 'education')
    @presentations = load(data, 'presentations.yaml', 'presentations')
  end

  def jobs
    experience.reject { |job| job['cv'] == false }
  end

  def degrees
    education.reject { |degree| degree['cv'] == false }
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
    "\\textcolor{color1}{\\href{#{url.to_s.gsub(/[%#]/) { |c| "\\#{c}" }}}{#{tex(name)}}}"
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
      lines << '\\item \\textbf{Deliverables}:'
      lines.concat(list(deliverables.map { |d| [item(d, :deliverable), d.is_a?(Hash) ? d['details'].to_a.map { |x| tex(x) } : []] }))
    end
    highlights = job['highlights'].to_a.map { |h| item(h, :highlight) }
    if highlights.any?
      # Labelled when the entry says more than its highlights; on their own
      # they are the entry.
      if lines.empty?
        lines.concat(highlights.map { |h| "\\item #{h}" })
      else
        lines << '\\item \\textbf{Highlights}:'
        lines.concat(list(highlights.map { |h| [h, []] }))
      end
    end
    lines
  end

  private

  def load(dir, file, key)
    YAML.load_file(File.join(dir, file))[key].to_a
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

cv = CV.new(DATA)
tex = ERB.new(File.read(template), trim_mode: '-').result(cv.instance_eval { binding })
File.write(output, tex)
puts "Wrote #{output.delete_prefix("#{ROOT}/")} from #{template.delete_prefix("#{ROOT}/")}"
