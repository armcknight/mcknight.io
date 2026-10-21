# frozen_string_literal: true

# Copies everything under shared/assets/ into a site's build, at the same path
# under assets/, as if it were one of the site's own files. This is how
# travel.mcknight.io and books.mcknight.io serve one globe-core.js rather than
# two copies of it.
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
# A shared file and a site file at the same path would collide, so shared files
# take names of their own: globe-core.js, globe-core.css.

module SharedAssets
  ROOT = File.expand_path('..', __dir__)

  class Generator < Jekyll::Generator
    safe true

    def generate(site)
      Dir.glob('assets/**/*', base: ROOT).each do |relative|
        next unless File.file?(File.join(ROOT, relative))

        site.static_files << Jekyll::StaticFile.new(site, ROOT, File.dirname(relative), File.basename(relative))
      end
    end
  end
end
