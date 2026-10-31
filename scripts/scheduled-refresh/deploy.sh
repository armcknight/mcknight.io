#!/bin/sh
# Deploys the built main site, clears the projects page from CloudFront and
# pushes the DEPLOYED stamp: run by .github/workflows/scheduled-refresh.yml after
# aws-actions/configure-aws-credentials has put the deploy role's credentials
# in the environment.
#
#   scripts/scheduled-refresh/deploy.sh
#
# The Makefile and scripts/deploy-site.sh name the `armcknight` profile, as
# they do on a laptop, so the role's credentials are given that name first.

set -eu

aws configure set aws_access_key_id "$AWS_ACCESS_KEY_ID" --profile armcknight
aws configure set aws_secret_access_key "$AWS_SECRET_ACCESS_KEY" --profile armcknight
aws configure set aws_session_token "$AWS_SESSION_TOKEN" --profile armcknight
aws configure set region "$AWS_REGION" --profile armcknight

make deploy home
make bust-cache home PATHS="/projects/ /projects/index.html"

# Rebased first, in case something was pushed to main while this ran.
git pull --rebase --quiet origin main
git push origin HEAD:main
