# frozen_string_literal: true

# Makes the travel data readable from the main site, as `site.data.travel`.
#
# The data belongs to the site that owns it, travel/_data/travel.yml, and this
# site excludes that whole directory so the two never build into each other.
# That exclusion also hides the file from Jekyll's own data loading, which is
# why this exists: the home page counts states and countries from the same file
# the globe is drawn from, rather than from a copy that would quietly go stale
# the first time a place is added.
#
# Read after Jekyll's own pass, so nothing it loaded is overwritten, and guarded
# so the site still builds if the travel directory is ever absent.

require 'yaml'

Jekyll::Hooks.register :site, :post_read do |site|
  path = File.join(site.source, 'travel', '_data', 'travel.yml')
  next unless File.exist?(path)

  begin
    site.data['travel'] = YAML.load_file(path)
  rescue StandardError => e
    # A broken travel file must not stop the main site from building.
    Jekyll.logger.warn 'Travel data:', "could not read #{path}: #{e.message}"
  end
end
