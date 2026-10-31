#!/bin/sh
# Commits the refreshed _data/releases.yml as the Actions bot and pushes it to
# main: run by .github/workflows/scheduled-refresh.yml when it changed.
#
#   scripts/scheduled-refresh/commit-releases.sh
#
# Pushed before the build, so the DEPLOYED stamp names a commit that is already
# on main. Rebasing it later would change its hash and leave the stamp pointing
# at nothing.

set -eu

git config user.name 'github-actions[bot]'
git config user.email '41898282+github-actions[bot]@users.noreply.github.com'
git commit --quiet -m 'update project release data' -- _data/releases.yml
git pull --rebase --quiet origin main
git push origin HEAD:main
