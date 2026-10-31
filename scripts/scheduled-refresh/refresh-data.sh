#!/bin/sh
# Refreshes the projects page's data with `make releases`, and says whether
# the page would change: run by .github/workflows/scheduled-refresh.yml.
#
#   scripts/scheduled-refresh/refresh-data.sh
#
# releases.yml is committed, so git says whether it changed. activity.yml is
# ignored by git, so it is compared with the copy the workflow restored from
# the Actions cache, which is the one last deployed. Only its data lines are
# compared: its comment header holds the date it was made.
#
# Writes releases=true|false and changed=true|false to $GITHUB_OUTPUT, or to
# standard output when run outside of Actions.

set -eu

out=${GITHUB_OUTPUT:-/dev/stdout}
previous=$(mktemp)
trap 'rm -f "$previous" "$previous.old" "$previous.new"' EXIT

have_previous=false
if [ -f _data/activity.yml ]; then
    cp _data/activity.yml "$previous"
    have_previous=true
fi

make releases

releases=false
activity=false
if ! git diff --quiet -- _data/releases.yml; then
    git diff -- _data/releases.yml
    releases=true
fi
if [ "$have_previous" = false ]; then
    echo "No activity in the cache to compare with."
    activity=true
else
    grep -v '^#' "$previous" > "$previous.old"
    grep -v '^#' _data/activity.yml > "$previous.new"
    if ! diff "$previous.old" "$previous.new"; then
        activity=true
    fi
fi

echo "releases=$releases" >> "$out"
if [ "$releases" = true ] || [ "$activity" = true ]; then
    echo "changed=true" >> "$out"
else
    echo "No release or activity changed."
    echo "changed=false" >> "$out"
fi
