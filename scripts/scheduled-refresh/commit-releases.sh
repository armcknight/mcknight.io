#!/bin/sh
# Commits the refreshed _data/releases.yml as the Actions bot (whom the
# workflow names for the job) and pushes it to main: run by
# .github/workflows/scheduled-refresh.yml when it changed.
#
#   scripts/scheduled-refresh/commit-releases.sh
#
# Pushed before the build, so the DEPLOYED stamp names a commit that is already
# on main. Rebasing it later would change its hash and leave the stamp pointing
# at nothing.

set -eu

git commit --quiet -m 'update project release data' -- _data/releases.yml
git pull --rebase --quiet origin main
git push origin HEAD:main
