# frozen_string_literal: true

# What the sites in this repo share, from shared/: its assets/ copied into a
# site's build, at the same path under assets/, as if they were the site's own
# files; and its _includes/, where a site's include tag looks after the site's
# own _includes/. This is how travel.mcknight.io and books.mcknight.io serve one
# globe-core.js rather than two copies of it, and how all three sites' not-found
# pages share their text (_includes/not-found.html) and script
# (assets/js/not-found.js).
#
# A site loads this from its own _plugins/ with one line:
#
#   require_relative '../../shared/_plugins/shared_assets'
#
# rather than by pointing plugins_dir here, because Jekyll resolves a custom
# plugins_dir from the shell's working directory, not from the site. The path
# to shared/ is worked out from this file instead, so a build works from
# anywhere. Plugins load only outside safe mode, which is Jekyll's default.
#
# A site that needs only some of the assets lists them in its _config.yml, by
# their path under shared/assets/; without the list it gets them all:
#
#   shared_assets: [js/not-found.js]
#
# A shared file and a site file at the same path would collide, so shared files
# take names of their own: globe-core.js, globe-core.css, not-found.html.

module SharedAssets
  ROOT = File.expand_path('..', __dir__)
  INCLUDES = File.join(ROOT, '_includes')

  # Once the site has worked out its include folders, before anything renders
  Jekyll::Hooks.register :site, :after_init do |site|
    site.includes_load_paths << INCLUDES unless site.includes_load_paths.include?(INCLUDES)
  end

  class Generator < Jekyll::Generator
    safe true

    def generate(site)
      wanted = site.config['shared_assets']
      Dir.glob('assets/**/*', base: ROOT).each do |relative|
        next unless File.file?(File.join(ROOT, relative))
        next if wanted && !wanted.include?(relative.delete_prefix('assets/'))

        site.static_files << Jekyll::StaticFile.new(site, ROOT, File.dirname(relative), File.basename(relative))
      end
    end
  end
end
