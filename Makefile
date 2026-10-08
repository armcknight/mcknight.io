.DEFAULT_GOAL := help

# SITES
#
# Most actions here apply to one of two sites, so the site is named as a word of
# its own: `make build home`, `make serve travel`, `make deploy home travel`.
#
# make has no arguments, only goals, so `home` and `travel` are real targets
# that do nothing on their own. Each action reads the goal list to see which
# sites were named. Naming both runs the action twice, once for each.
#
# Naming none means `home`, which is what `make build` always did.
SITES := home travel
SELECTED := $(filter $(SITES),$(MAKECMDGOALS))
ifeq ($(SELECTED),)
SELECTED := home
endif

.PHONY: $(SITES)
$(SITES):
	@if [ "$(words $(MAKECMDGOALS))" = "1" ]; then \
		echo "\"$@\" names a site, not an action. Pair it with one:"; \
		echo "    make build $@        make serve $@        make deploy $@"; \
	fi

# What each site is made of. A recipe reads these as $(src_$(s)) for the site it
# is working on, which is why the suffixes must match the names in SITES.
src_home      := .
src_travel    := travel
dest_home     := _site
dest_travel   := travel/_site
port_home     := 4000
port_travel   := 4500
bucket_home   := mcknight.io
bucket_travel := travel.mcknight.io
stamp_home    := DEPLOYED
stamp_travel  := travel/DEPLOYED
log_home      := jekyll_build
log_travel    := travel_build
label_home    := mcknight.io
label_travel  := travel.mcknight.io

# CloudFront distributions.
dist_home     := E3AJVW95W5JFMD
dist_travel   := E2LVEB8WVCV9QY

# Every Ruby command goes through this, never through a bare `rbenv exec`.
#
# tmuxinator's Homebrew wrapper starts with GEM_HOME set to its own Cellar
# directory. When tmuxinator starts the tmux server, that variable lands in the
# server's global environment, and every pane opened afterwards inherits it. So
# bundler looks for this site's gems inside tmuxinator, finds none, and the
# build dies — and a `brew upgrade tmuxinator` moves the path, which breaks it
# again even after a re-install.
#
# Removing the variable for the length of one command fixes it wherever make is
# run. To be rid of it in the shell as well: `tmux set-environment -gu GEM_HOME`
# now, and `set -e GEM_HOME` in config.fish for later shells.
RUBY := env -u GEM_HOME -u GEM_PATH rbenv exec

# Lists every target with a one-line summary. It is the default goal, so a bare
# `make` explains itself instead of doing something.
#
# Help comes in two layers, because a one-liner cannot carry a caveat: the
# summary here comes from the `## ` text on each target's own line, and the long
# form comes from the comment block above it, printed by `make help-<target>`.
# Both live next to the recipe they describe, so neither can drift from it.
.PHONY: help
help: ## Show this help
	@echo "mcknight.io — available make targets:"
	@echo
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(firstword $(MAKEFILE_LIST)) \
		| sort \
		| awk 'BEGIN {FS = ":.*?## "} {printf "  \033[36m%-32s\033[0m %s\n", $$1, $$2}'
	@echo
	@echo "  Targets marked <site> take \033[36mhome\033[0m, \033[36mtravel\033[0m, or both:"
	@echo "    make build travel       make serve home travel      make deploy home"
	@echo "  Naming no site means home."
	@echo
	@echo "  Every target above has a longer explainer. To read one:"
	@echo "    make help-deploy        make help-bust-cache        make help-<target>"

# Prints the comment block sitting above a target — the same text you would read
# in the Makefile, so there is one copy of every explanation rather than a
# summary here and the truth over there.
#
#   make help-deploy
#
# The block is whatever run of consecutive `#` lines immediately precedes the
# target. A blank line ends a block, so a comment separated from its target by
# one is treated as unrelated; `.PHONY:` lines in between are skipped, since they
# belong to the target rather than the prose.
#
# No `## ` summary and no .PHONY here: a pattern rule cannot appear in the index,
# and .PHONY does not accept patterns. Nothing named help-* exists on disk, so the
# rule always runs regardless.
help-%:
	@awk -v t="$*" ' \
		/^[ \t]*#/ { line = $$0; sub(/^[ \t]*#[ ]?/, "", line); block = block line "\n"; next } \
		/^\.PHONY/ { next } \
		index($$0, t ":") == 1 { \
			summary = ""; \
			p = index($$0, "## "); \
			if (p > 0) { summary = substr($$0, p + 3) } \
			print "make " t (summary == "" ? "" : "  —  " summary); \
			print ""; \
			printf "%s", block; \
			found = 1; \
			exit \
		} \
		{ block = "" } \
		END { if (!found) { print "No target named \"" t "\". Try: make help" } } \
	' $(firstword $(MAKEFILE_LIST))

# One-time setup for a fresh machine, and safe to re-run on an existing one.
#
# Installs Homebrew if it is missing, then everything in the Brewfile (awscli,
# exiftool, imageoptim, the TeX bits the resume needs), then the pinned Ruby
# through rbenv and the gems through bundler. Both sites share these gems.
#
# Run this before anything else, and again after the Gemfile or Brewfile changes.
.PHONY: init
init: ## Install Homebrew, the Brewfile, the pinned Ruby, and the gems
	which brew || /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
	brew bundle ||:
	rbenv install --skip-existing
	$(RUBY) gem update bundler
	$(RUBY) bundle update

# Internal. `build` and `deploy` tee their output into logs/, which git ignores,
# and neither would survive the directory being absent.
_logs-dir:
	mkdir -p logs

# Builds a site into its own output directory, with the full Jekyll output kept
# in logs/ rather than scrolling past.
#
#   make build            the main site, into _site/
#   make build travel     the travel site, into travel/_site/
#   make build home travel   both
#
# `--source travel` makes Jekyll read travel/_config.yml, so the subdomain keeps
# its own title, url and excludes. The parent config excludes travel/, so the
# two builds never reach into each other.
#
# optimize-images runs once first, whichever sites are named, since it works
# from what git reports rather than from a directory.
#
# This only builds. Nothing reaches the internet until `deploy`, and `deploy`
# uploads whatever is in the output directory without building it.
.PHONY: build
build: _logs-dir optimize-images ## <site> Build a site into its output directory
	$(foreach s,$(SELECTED),echo "building $(label_$(s))"; set -o pipefail; $(RUBY) bundle exec jekyll build --source $(src_$(s)) --destination $(dest_$(s)) 2>&1 | tee logs/$(log_$(s)).log;)

# Serves a built site and opens it.
#
#   make serve                 mcknight.io  at localhost:4000
#   make serve travel          travel       at localhost:4500
#   make serve home travel     both at once
#
# They are separate servers because they are separate sites: _site/ excludes
# travel/ exactly as the real mcknight.io does, so one server cannot answer for
# both. Two ports stand in for two hostnames.
#
# Browsers resolve any *.localhost name to 127.0.0.1 with no /etc/hosts entry,
# so http://travel.localhost:4500 works too and reads more like production.
#
# It serves the build, not the sources: there is no watch and no live reload, so
# each change needs another build.
.PHONY: serve
serve: ## <site> Serve a built site and open it
	$(foreach s,$(SELECTED),(cd $(dest_$(s)) && nohup python3 -m http.server $(port_$(s)) --bind localhost >/dev/null 2>&1 &); echo "serving $(label_$(s)) at http://localhost:$(port_$(s))"; open http://localhost:$(port_$(s));)

# Stops a served site, by the port it is on rather than by killing every Python
# process on the machine, which is what this used to do.
#
#   make endserve              stops the main site
#   make endserve home travel  stops both
.PHONY: endserve
endserve: ## <site> Stop a served site
	@$(foreach s,$(SELECTED),pids=$$(lsof -ti :$(port_$(s)) 2>/dev/null); if [ -n "$$pids" ]; then echo "$$pids" | xargs kill && echo "stopped $(label_$(s)) on port $(port_$(s))"; else echo "nothing was serving $(label_$(s)) on port $(port_$(s))"; fi;)

# Rebuilds the LaTeX resume and CV, then copies the two PDFs the site links to
# into assets/pdf/.
#
# resume/build/ is scratch space that git ignores — the tracked artifacts are the
# two copies under assets/pdf/, which is why the copy step exists. Editing
# resume/*.tex changes nothing a visitor sees until this runs, so run it in the
# same commit as the .tex change.
#
# Needs a TeX distribution: the resume's own Makefile drives pdflatex directly.
.PHONY: resume
resume: ## Rebuild the resume and CV PDFs from LaTeX and copy them into assets/pdf
	pushd resume && make build
	cp resume/build/pdfs/cv.pdf assets/pdf/andrew-mcknight-cv.pdf
	cp resume/build/pdfs/ios_resume.pdf assets/pdf/andrew-mcknight-resume-ios.pdf

# Refreshes _data/releases.yml with the latest release version and date for every
# app and devtool on the projects page of the main site.
#
# Deliberately not part of `build`: some source repos are private, so the lookup
# needs an authenticated gh, and the result is committed. That keeps builds and
# deploys offline, immune to API rate limits, and able to keep showing the last
# known version if a fetch ever fails.
#
# GitHub releases come from `gh`; the two App Store apps have no release to read,
# so their shipping version comes from the public iTunes lookup API instead. A
# project whose releases live in the homebrew-tools tap under a prefixed tag
# declares that in _data/projects.yml — see scripts/fetch-releases.rb.
#
# The versions on the site are only as fresh as the last run.
.PHONY: releases
releases: ## Refresh _data/releases.yml with each project's latest release
	$(RUBY) ruby scripts/fetch-releases.rb

# Strips EXIF metadata and losslessly compresses images, in place.
#
# It only touches images git reports as changed, so it stays cheap enough to hang
# off `build` — but that also means it does nothing for an image already
# committed. Optimise before committing, not after.
#
# In place is the point: the smaller file is what gets committed and served.
# Needs exiftool and imageoptim from the Brewfile.
.PHONY: optimize-images
optimize-images: ## Strip EXIF from and compress any images git sees as changed
	@new_images=$$(git status --porcelain | awk '{print $$NF}' | grep -iE '\.(jpg|jpeg|png|gif)$$'); \
	if [ -n "$$new_images" ]; then \
		echo "Stripping EXIF data from new images..."; \
		echo "$$new_images" | xargs exiftool -all= -overwrite_original; \
		echo "Optimizing new images..."; \
		imageoptim $$new_images; \
	fi

# MARK: - travel.mcknight.io data
#
# These two produce the committed files the globe reads. They belong to the
# travel site's content rather than to a site operation, so they are not
# <site> targets.

# Fills in `lat:` and `lon:` for any city in travel/_data/travel.yml that lacks
# them, using the Nominatim geocoder of OpenStreetMap.
#
# Only new cities cost anything: a city that already has coordinates is skipped,
# so a re-run with nothing to do finishes in well under a second. A first run
# over every city takes about a second per city, because Nominatim's usage
# policy permits one request per second and the script obeys it.
#
# A city with no name yet is skipped and reported, rather than geocoded as
# ", Region, Country", which would answer with the middle of the region.
#
# The answers are committed, so neither the build nor a visitor's browser ever
# contacts the geocoder. A city listed without coordinates appears in the page's
# outline but has no dot, until this is run.
.PHONY: travel-geocode
travel-geocode: ## Add missing city coordinates to travel/_data/travel.yml
	$(RUBY) ruby travel/scripts/geocode-travel.rb

# Rebuilds the two map files the globe draws, from Natural Earth.
#
# Run it after adding a country or a region to travel.yml. Adding only a city
# needs travel-geocode instead, unless that city is in a region not drawn yet.
#
# The sources are cached in travel/.geo-cache/, which git ignores. The first run
# downloads about 42 MB; later runs read the cache. Only the filtered result is
# committed, which is about a megabyte, or 350 KB as a visitor receives it.
.PHONY: travel-geo
travel-geo: ## Rebuild the globe geometry from Natural Earth
	$(RUBY) ruby travel/scripts/build-geo.rb

# Checks every located place against the polygon of the region it is filed
# under, and lists anything still waiting for coordinates. Reads only committed
# files, so it needs no network.
#
# It exists because a geocoder is confidently wrong often enough to matter: it
# has put Gray's Peak in Oklahoma, the Painted Desert in Anaheim, and Skyline
# Drive on a street in Norfolk, each a plausible answer to a slightly ambiguous
# name.
#
# It cannot catch a wrong answer that lands inside the right region — Ka Lae on
# Kauai and Kapa'au on Molokai were both hundreds of kilometres out and both
# still in Hawaii. Read new coordinates; this is a safety net, not a substitute.
.PHONY: travel-check
travel-check: ## Check every travel place sits inside the region it is filed under
	$(RUBY) ruby travel/scripts/check-places.rb

# MARK: - Publishing

# Refuses to deploy from a dirty tree, so the hash in a DEPLOYED stamp always
# describes exactly what is live. The stamps themselves are excluded: every
# deploy rewrites one, so counting them would block the next deploy over the
# artifact the last one produced.
.PHONY: check-clean
check-clean: ## Fail unless the working tree is clean (a deploy prerequisite)
	@changes=$$(git status --porcelain -- . ':!DEPLOYED' ':!travel/DEPLOYED'); \
	if [ -n "$$changes" ]; then \
		echo "Refusing to deploy: the working tree has uncommitted changes."; \
		echo "$$changes"; \
		echo; \
		echo "Commit or stash them, rebuild, then deploy — otherwise a DEPLOYED stamp"; \
		echo "would record a commit that does not match what was uploaded."; \
		exit 1; \
	fi

# Uploads a built site and records what is live.
#
#   make deploy              mcknight.io, from _site/
#   make deploy travel       travel.mcknight.io, from travel/_site/
#   make deploy home travel  both
#
# Each site has its own stamp: DEPLOYED for the main site, travel/DEPLOYED for
# the subdomain. The stamp goes into the upload as well as the repo, so
# https://mcknight.io/DEPLOYED answers "which commit is serving right now?"
# without a checkout. Line 1 is the commit hash and line 2 the UTC deploy time,
# so `head -1` is the hash on its own.
#
# The repo copy is written only after the upload succeeds, so a failed deploy
# never claims to be live, and it is committed straight afterwards, which leaves
# the tree clean for the next deploy. A stamp can never be inside the commit it
# names, so it names the commit just before the one that records it.
#
# `deploy` uploads whatever `build` last produced; it does not build for you.
# The commit it makes is local — push it yourself.
#
# CloudFront still holds the old objects afterwards — follow with `bust-cache`.
#
# The sequence lives in scripts/deploy-site.sh, because it is a sequence with
# conditions in it and would be unreadable folded onto one line per site.
.PHONY: deploy
deploy: _logs-dir check-clean ## <site> Upload a built site, then stamp and commit what is live
	$(foreach s,$(SELECTED),scripts/deploy-site.sh "$(label_$(s))" "$(dest_$(s))" "$(bucket_$(s))" "$(stamp_$(s))";)

# Invalidate CloudFront, so a fresh deploy is actually what gets served.
#
#   make bust-cache PATHS="/ /index.html"
#   make bust-cache travel PATHS="/*"
#
# PATHS is a SPACE-separated list, each entry starting with `/`. That is what
# `create-invalidation --paths` wants — one argument per path. Commas do not
# separate anything: "/a,/b" is a single path named `/a,/b`, which matches no
# object and quietly invalidates nothing.
#
# A directory URL and its index object are cached under separate keys, so busting
# a page usually means busting both forms — `/blog/` is not `/blog/index.html`.
#
# The site root, the blog index, and one post:
#
#   make bust-cache PATHS="/ /index.html /blog/ /blog/index.html /blog/2026/08/10/claude-workflow-pt.-2.html"
#
# Everything, which counts as a single path for billing and is usually the better
# deal than listing more than a handful:
#
#   make bust-cache PATHS="/*"
#
# $(PATHS) is deliberately unquoted so the shell splits it into separate
# arguments. `set -f` turns globbing off first, so a wildcard like `/*` reaches
# CloudFront instead of expanding against the local filesystem.
#
# Invalidation is asynchronous — `check-cache-invalidation-status` says whether
# it has finished.
.PHONY: bust-cache
bust-cache: ## <site> Invalidate CloudFront paths, e.g. PATHS="/ /index.html"
	@test -n "$(PATHS)" || { echo 'usage: make bust-cache [site] PATHS="/ /index.html"'; exit 1; }
	@$(foreach s,$(SELECTED),test -n "$(dist_$(s))" || { echo "No CloudFront distribution is recorded for $(label_$(s)). Set dist_$(s) in the Makefile once it exists."; exit 1; };)
	$(foreach s,$(SELECTED),set -f; aws --profile armcknight cloudfront create-invalidation --distribution-id $(dist_$(s)) --paths $(PATHS);)

# Shorthand for the blog index's two cache keys, the pair that goes stale on every
# new post. Identical to:
#
#   make bust-cache PATHS="/blog/ /blog/index.html"
#
# The main site only: the subdomain has no blog. It does not touch the post
# itself, or the tag pages and feeds that also list it.
.PHONY: bust-blog-cache
bust-blog-cache: ## Invalidate the blog index (/blog/ and /blog/index.html)
	aws --profile armcknight cloudfront create-invalidation --distribution-id $(dist_home) --paths "/blog/" "/blog/index.html"

# Lists recent invalidations newest first, with the status of each: InProgress
# while CloudFront is still working through the edge locations, Completed once a
# request will fetch from the origin again.
#
# A bust that reports Completed but still serves the old page is a browser cache,
# not this one.
.PHONY: check-cache-invalidation-status
check-cache-invalidation-status: ## <site> List recent CloudFront invalidations and their status
	@$(foreach s,$(SELECTED),test -n "$(dist_$(s))" || { echo "No CloudFront distribution is recorded for $(label_$(s))."; exit 1; };)
	$(foreach s,$(SELECTED),echo "== $(label_$(s))"; aws --profile armcknight cloudfront list-invalidations --distribution-id $(dist_$(s));)
