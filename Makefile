init:
	which brew || /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
	brew bundle ||:
	rbenv install --skip-existing
	rbenv exec gem update bundler
	rbenv exec bundle update

_logs-dir:
	mkdir -p logs

.PHONY: resume
resume:
	pushd resume && make build
	cp resume/build/pdfs/cv.pdf assets/pdf/andrew-mcknight-cv.pdf
	cp resume/build/pdfs/ios_resume.pdf assets/pdf/andrew-mcknight-resume-ios.pdf

# Refresh _data/releases.yml with each project's latest release version and date.
# Needs the gh CLI authenticated, since some source repos are private.
.PHONY: releases
releases:
	rbenv exec ruby scripts/fetch-releases.rb

optimize-images:
	@new_images=$$(git status --porcelain | awk '{print $$NF}' | grep -iE '\.(jpg|jpeg|png|gif)$$'); \
	if [ -n "$$new_images" ]; then \
		echo "Stripping EXIF data from new images..."; \
		echo "$$new_images" | xargs exiftool -all= -overwrite_original; \
		echo "Optimizing new images..."; \
		imageoptim $$new_images; \
	fi

build: _logs-dir optimize-images
	rbenv exec bundle exec jekyll build --destination _site 2>&1 | tee logs/jekyll_build.log

# Refuses to deploy from a dirty tree, so the hash in DEPLOYED always describes
# exactly what is live. DEPLOYED itself is excluded from the check: every deploy
# rewrites it, so counting it would block the next deploy over the artifact this
# one just produced.
.PHONY: check-clean
check-clean:
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
# The stamp can never be part of the commit it names, so DEPLOYED trails one
# commit behind: deploy, then commit the stamp.
deploy: _logs-dir check-clean
	@mkdir -p _site
	@sha=$$(git rev-parse HEAD); \
	printf '%s\n%s\n' "$$sha" "$$(date -u +%Y-%m-%dT%H:%M:%SZ)" > _site/DEPLOYED; \
	echo "deploying $$sha"
	set -o pipefail; aws s3 sync _site/ s3://mcknight.io/ --profile armcknight --delete | tee logs/web_deploy.log
	@cp _site/DEPLOYED DEPLOYED
	@echo "stamped DEPLOYED: $$(head -1 DEPLOYED)"

serve:
	pushd _site && python3 -m http.server 4000 --bind localhost &
	open http://localhost:4000

endserve:
	killall Python

# separate multiple paths with a comma and place in a double quoted string, e.g.:
#   make bust-cache PATHS="/experience,/experience/,/experience/index.html"
bust-cache:
	aws --profile armcknight cloudfront create-invalidation --distribution-id E3AJVW95W5JFMD --paths "$(PATHS)"

bust-blog-cache:
	aws --profile armcknight cloudfront create-invalidation --distribution-id E3AJVW95W5JFMD --paths "/blog/" "/blog/index.html"

check-cache-invalidation-status:
	aws --profile armcknight cloudfront list-invalidations --distribution-id E3AJVW95W5JFMD
