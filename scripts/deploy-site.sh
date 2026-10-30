#!/bin/sh
# Deploys one site: upload, stamp what is live, commit the stamp.
#
#   deploy-site.sh <site> <label> <dest> <bucket> <stamp>
#
#     site    the site's name in the Makefile, e.g. travel: the commit that
#             records the deploy is "deploy(<site>): <commit>"
#     label   what to call the site in messages, e.g. travel.mcknight.io
#     dest    the built directory to upload, e.g. travel/_site
#     bucket  the S3 bucket name
#     stamp   path of the DEPLOYED file for this site, e.g. travel/DEPLOYED
#
# This lives in a script rather than in the Makefile because it is a sequence
# with conditions in it, and a sequence like that becomes unreadable once a
# `foreach` has folded it onto one line for each site.
#
# The caller has already checked that the working tree is clean. See the
# Makefile's check-clean, and `make help-deploy`.

set -eu

site=$1
label=$2
dest=$3
bucket=$4
stamp=$5

if [ ! -d "$dest" ]; then
    echo "Nothing to deploy for $label: $dest does not exist. Build it first."
    exit 1
fi

sha=$(git rev-parse HEAD)

# The stamp goes into the upload as well as the repo, so the live site can say
# which commit it is without anyone holding a checkout.
printf '%s\n%s\n' "$sha" "$(date -u +%Y-%m-%dT%H:%M:%SZ)" > "$dest/DEPLOYED"
echo "deploying $label at $sha"

# pipefail, or a failed upload would be hidden by tee's exit status. Tried in
# a subshell first: a shell without it, like the dash that is /bin/sh on
# Ubuntu, exits on an unknown `set -o` rather than failing the command, so
# `|| true` alone cannot catch it.
if (set -o pipefail) 2>/dev/null; then
    set -o pipefail
fi
aws s3 sync "$dest/" "s3://$bucket/" --profile armcknight --delete | tee "logs/$(basename "$bucket")_deploy.log"

# Only now that the upload succeeded does the repo claim this is live.
cp "$dest/DEPLOYED" "$stamp"
echo "stamped $stamp: $(head -1 "$stamp")"

# The tree was clean before the upload, so a stamp is the only thing that may
# differ. Anything else means something moved underneath the deploy, and that
# is for a person to look at rather than for this to commit.
changes=$(git status --porcelain)
unexpected=$(printf '%s\n' "$changes" | grep -v '^..[ ]DEPLOYED$' | grep -v '^..[ ].*/DEPLOYED$' | grep -v '^$' || true)
if [ -n "$unexpected" ]; then
    echo
    echo "Deploy finished, but something other than a DEPLOYED stamp changed, so"
    echo "the stamp was NOT committed. Look at these, then commit it yourself:"
    printf '%s\n' "$unexpected"
    exit 1
fi

if git diff --quiet -- "$stamp" && [ -z "$(git status --porcelain -- "$stamp")" ]; then
    echo "$stamp unchanged; nothing to commit."
else
    git add -- "$stamp"
    git commit --quiet --only -m "deploy($site): $(head -1 "$stamp" | cut -c1-12)" -- "$stamp"
    echo "committed $stamp as $(git rev-parse --short HEAD)"
fi
