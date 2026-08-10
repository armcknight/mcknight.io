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

deploy: _logs-dir
	aws s3 sync _site/ s3://mcknight.io/ --profile armcknight --delete | tee logs/web_deploy.log

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
