.DEFAULT_GOAL := help

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
# through rbenv and the gems through bundler.
#
# Run this before anything else, and again after the Gemfile or Brewfile changes.
.PHONY: init
init: ## Install Homebrew, the Brewfile, the pinned Ruby, and the gems
	which brew || /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
	brew bundle ||:
	rbenv install --skip-existing
	rbenv exec gem update bundler
	rbenv exec bundle update

# Internal. `build` and `deploy` tee their output into logs/, which git ignores,
# and neither would survive the directory being absent.
_logs-dir:
	mkdir -p logs

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
# app and devtool on the projects page.
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
	rbenv exec ruby scripts/fetch-releases.rb

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

# Builds the site into _site/, with the full Jekyll output kept in
# logs/jekyll_build.log rather than scrolling past.
#
# Runs optimize-images first, so a new image is stripped and compressed before it
# is ever copied into the output.
#
# This only builds. Nothing reaches the internet until `deploy`, and `deploy`
# uploads whatever is in _site/ without building it — so build, then deploy.
.PHONY: build
build: _logs-dir optimize-images ## Build the site into _site/
	rbenv exec bundle exec jekyll build --destination _site 2>&1 | tee logs/jekyll_build.log

# Refuses to deploy from a dirty tree, so the hash in DEPLOYED always describes
# exactly what is live. DEPLOYED itself is excluded from the check: every deploy
# rewrites it, so counting it would block the next deploy over the artifact this
# one just produced.
.PHONY: check-clean
check-clean: ## Fail unless the working tree is clean (a deploy prerequisite)
	@changes=$$(git status --porcelain -- . ':!DEPLOYED'); \
	if [ -n "$$changes" ]; then \
		echo "Refusing to deploy: the working tree has uncommitted changes."; \
		echo "$$changes"; \
		echo; \
		echo "Commit or stash them, rebuild, then deploy — otherwise DEPLOYED would"; \
		echo "record a commit that does not match what was uploaded."; \
		exit 1; \
	fi

# Records what is live. The stamp goes into the synced output as well as the
# repo, so https://mcknight.io/DEPLOYED answers "which commit is serving right
# now?" without a checkout, and the tracked file answers it from the repo.
#
# Line 1 is the commit hash, line 2 the UTC deploy time — `head -1 DEPLOYED` is
# the hash on its own.
#
# The repo copy is written only after the sync succeeds, so a failed deploy never
# claims to be live. `deploy` syncs whatever `build` last produced; it does not
# build for you.
#
# The stamp can never be part of the commit it names, so it is committed on its
# own straight afterwards — leaving the tree clean, and leaving DEPLOYED naming
# the commit just before the one that records it. Since the tree was verified
# clean before the sync, DEPLOYED must be the only thing that changed; anything
# else means something moved underneath the deploy, so the stamp is left
# uncommitted for a human to look at rather than swept into a commit.
#
# The commit is local. Push it yourself.
#
# CloudFront still holds the old objects afterwards — follow with `bust-cache`.
.PHONY: deploy
deploy: _logs-dir check-clean ## Sync _site/ to S3, then stamp and commit DEPLOYED
	@mkdir -p _site
	@sha=$$(git rev-parse HEAD); \
	printf '%s\n%s\n' "$$sha" "$$(date -u +%Y-%m-%dT%H:%M:%SZ)" > _site/DEPLOYED; \
	echo "deploying $$sha"
	set -o pipefail; aws s3 sync _site/ s3://mcknight.io/ --profile armcknight --delete | tee logs/web_deploy.log
	@cp _site/DEPLOYED DEPLOYED
	@echo "stamped DEPLOYED: $$(head -1 DEPLOYED)"
	@changes=$$(git status --porcelain); \
	unexpected=$$(printf '%s\n' "$$changes" | grep -v '^..[ ]DEPLOYED$$' | grep -v '^$$' || true); \
	if [ -n "$$unexpected" ]; then \
		echo; \
		echo "Deploy finished, but something other than DEPLOYED changed, so the"; \
		echo "stamp was NOT committed. Look at these, then commit it yourself:"; \
		printf '%s\n' "$$unexpected"; \
		exit 1; \
	fi; \
	if [ -z "$$changes" ]; then \
		echo "DEPLOYED unchanged; nothing to commit."; \
	else \
		git add -- DEPLOYED && \
		git commit --quiet --only -m "record $$(head -1 DEPLOYED | cut -c1-12) as deployed" -- DEPLOYED && \
		echo "committed DEPLOYED as $$(git rev-parse --short HEAD)"; \
	fi

# Serves the built site at http://localhost:4000 and opens it.
#
# It serves _site/, not the sources, so there is no watching and no live reload:
# every change needs another `build` before it shows up. The server is
# backgrounded and outlives this command — `endserve` stops it.
.PHONY: serve
serve: ## Serve _site/ at localhost:4000 in the background and open it
	pushd _site && python3 -m http.server 4000 --bind localhost &
	open http://localhost:4000

# Stops the backgrounded `serve`.
#
# Blunt instrument: it kills every Python process you own, not only this server.
# If something else of yours is running under Python, stop the server by hand
# instead — `lsof -ti :4000 | xargs kill`.
.PHONY: endserve
endserve: ## Stop the backgrounded serve (kills all your Python processes)
	killall Python

# Invalidate CloudFront, so a fresh deploy is actually what gets served.
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
# One section and its index:
#
#   make bust-cache PATHS="/experience/ /experience/index.html"
#
# $(PATHS) is deliberately unquoted so the shell splits it into separate
# arguments. `set -f` turns globbing off first, so a wildcard like `/*` reaches
# CloudFront instead of expanding against the local filesystem.
#
# Invalidation is asynchronous — `check-cache-invalidation-status` says whether it
# has finished.
.PHONY: bust-cache
bust-cache: ## Invalidate CloudFront paths, e.g. PATHS="/ /index.html"
	@test -n "$(PATHS)" || { echo 'usage: make bust-cache PATHS="/ /index.html"'; exit 1; }
	set -f; aws --profile armcknight cloudfront create-invalidation --distribution-id E3AJVW95W5JFMD --paths $(PATHS)

# Shorthand for the blog index's two cache keys, the pair that goes stale on every
# new post. Identical to:
#
#   make bust-cache PATHS="/blog/ /blog/index.html"
#
# It does not touch the post itself, or the tag pages and feeds that also list it.
.PHONY: bust-blog-cache
bust-blog-cache: ## Invalidate the blog index (/blog/ and /blog/index.html)
	aws --profile armcknight cloudfront create-invalidation --distribution-id E3AJVW95W5JFMD --paths "/blog/" "/blog/index.html"

# Lists recent invalidations newest first, with the status of each: InProgress
# while CloudFront is still working through the edge locations, Completed once a
# request will fetch from the origin again.
#
# A bust that reports Completed but still serves the old page is a browser cache,
# not this one.
.PHONY: check-cache-invalidation-status
check-cache-invalidation-status: ## List recent CloudFront invalidations and their status
	aws --profile armcknight cloudfront list-invalidations --distribution-id E3AJVW95W5JFMD
