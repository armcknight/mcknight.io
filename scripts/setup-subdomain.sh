#!/bin/sh
# Sets up the AWS side of a new subdomain the way travel.mcknight.io is: an S3
# website bucket, a certificate, a CloudFront distribution, and the DNS.
#
#   scripts/setup-subdomain.sh books.mcknight.io
#
# The five steps of the README's "Adding another subdomain", with the settings
# read from travel's live configuration:
#
#   1. the bucket, named for the site, in us-east-1: a website endpoint with
#      index.html as its index document, the public access block off, and a
#      public-read policy
#   2. a certificate for the name, in us-east-1 (CloudFront requires it there),
#      validated by a CNAME in the zone, which stays there for renewal
#   3. a distribution aliased to the name, reaching the bucket's website
#      endpoint over plain HTTP: redirect-to-https, compression, the managed
#      CachingOptimized policy, index.html as the root object, all edge
#      locations, HTTP/2, IPv6, TLS 1.2
#   4. A and AAAA alias records for the name, to the distribution
#   5. what to add to the Makefile and the README
#
# EVERY AWS COMMAND IS SHOWN AND ASKED ABOUT
#
# Each one is printed exactly as it will run, with its profile and region as
# flags so it can be copied and run by hand, and runs only after a "y". Any
# other answer stops the whole script. What it returns is printed after it.
# Read-only lookups ask too, so a run never touches the account unseen.
#
# It can be run again. Each step looks for what it would make before making
# it, so a run that stopped part way — most often while the certificate waits
# for validation — carries on where it stopped, and one that finished changes
# nothing. The bucket's settings are written every time, which also puts back
# any that were changed by hand.
#
# PROFILE picks the AWS profile, armcknight by default.

set -eu

name=${1:-}
if [ -z "$name" ]; then
    echo "usage: $0 <name>, e.g. $0 books.mcknight.io"
    exit 1
fi

profile=${PROFILE:-armcknight}
region=us-east-1
parent=${name#*.}
short=${name%%.*}

# CloudFront's own hosted zone, the same for every distribution, which an
# alias record to one must name.
CLOUDFRONT_ZONE=Z2FDTNDATAQYW2
# The managed CachingOptimized cache policy.
CACHING_OPTIMIZED=658327ea-f89d-4fab-a63d-7e88639e58f6

step() { printf '\n== %s\n' "$1" >&2; }

# One argument as the shell would need it typed: bare when it is plain, in
# single quotes otherwise, so the printed command can be pasted and run.
quote() {
    case $1 in
        *[!A-Za-z0-9_./:=@,-]*|'') printf "'%s'" "$(printf '%s' "$1" | sed "s/'/'\\\\''/g")" ;;
        *) printf '%s' "$1" ;;
    esac
}

# Runs one aws command: prints it, asks, runs it, and prints what it returned.
#
# Everything shown goes to stderr and the answer is read from the terminal, so
# this works inside $( ), where stdout is the result being captured. A "no"
# stops the whole script, not only the $( ) it was asked in: $$ is the
# script's own process, even there.
#
# A command that fails returns its exit code, with its error printed, for the
# caller to decide on: a missing bucket is how the first step learns to make
# one.
aws_run() {
    {
        printf '\n$ aws'
        for arg in "$@" --profile "$profile" --region "$region" --no-cli-pager; do
            printf ' %s' "$(quote "$arg")"
        done
        printf '\nRun it? [y/N] '
    } >&2
    read -r answer </dev/tty
    case $answer in
        y|Y|yes) ;;
        *) echo "Stopped; nothing more was run." >&2; kill "$$"; exit 1 ;;
    esac

    if output=$(aws "$@" --profile "$profile" --region "$region" --no-cli-pager 2>&1); then
        if [ -n "$output" ]; then printf '%s\n' "$output" | sed 's/^/  -> /' >&2; else echo "  -> done" >&2; fi
        printf '%s' "$output"
    else
        code=$?
        printf '%s\n' "$output" | sed 's/^/  !! /' >&2
        echo "  !! exit code $code" >&2
        return $code
    fi
}

# Upserts one record set into the zone, from its JSON, and prints Route 53's
# status for the change: PENDING, and INSYNC once every server has it.
upsert() {
    aws_run route53 change-resource-record-sets --hosted-zone-id "$zone" \
        --change-batch "{\"Changes\":[{\"Action\":\"UPSERT\",\"ResourceRecordSet\":$1}]}" \
        --query ChangeInfo.Status --output text
}

echo "Setting up $name in profile $profile. Each AWS command is shown before it runs." >&2

step "0/5 the zone for $parent"
zone=$(aws_run route53 list-hosted-zones-by-name --dns-name "$parent." --max-items 1 \
    --query "HostedZones[?Name=='$parent.'].Id | [0]" --output text)
if [ "$zone" = None ] || [ -z "$zone" ]; then
    echo "No Route 53 hosted zone for $parent in profile $profile." >&2
    exit 1
fi
zone=${zone##*/}

step "1/5 bucket"
if aws_run s3api head-bucket --bucket "$name" >/dev/null; then
    echo "$name exists; its settings are written again below." >&2
else
    # us-east-1 takes no location constraint; any other region would need one.
    aws_run s3api create-bucket --bucket "$name" >/dev/null
fi
aws_run s3api put-public-access-block --bucket "$name" --public-access-block-configuration \
    BlockPublicAcls=false,IgnorePublicAcls=false,BlockPublicPolicy=false,RestrictPublicBuckets=false >/dev/null
aws_run s3api put-bucket-website --bucket "$name" \
    --website-configuration '{"IndexDocument":{"Suffix":"index.html"}}' >/dev/null
aws_run s3api put-bucket-policy --bucket "$name" --policy \
    "{\"Version\":\"2012-10-17\",\"Statement\":[{\"Effect\":\"Allow\",\"Principal\":\"*\",\"Action\":\"s3:GetObject\",\"Resource\":\"arn:aws:s3:::$name/*\"}]}" >/dev/null

step "2/5 certificate"
cert=$(aws_run acm list-certificates --certificate-statuses ISSUED PENDING_VALIDATION \
    --query "CertificateSummaryList[?DomainName=='$name'].CertificateArn | [0]" --output text)
if [ "$cert" = None ] || [ -z "$cert" ]; then
    # The token makes a repeated request within the hour return the same
    # certificate rather than a second one.
    cert=$(aws_run acm request-certificate --domain-name "$name" --validation-method DNS \
        --idempotency-token "$(printf '%s' "$short" | tr -cd 'a-zA-Z0-9' | cut -c1-32)" \
        --query CertificateArn --output text)
    # ACM takes a few seconds to say what record will prove the name.
    echo "waiting 15 seconds for ACM to give the validation record ..." >&2
    sleep 15
fi

status=$(aws_run acm describe-certificate --certificate-arn "$cert" --query Certificate.Status --output text)
if [ "$status" != ISSUED ]; then
    record=$(aws_run acm describe-certificate --certificate-arn "$cert" \
        --query 'Certificate.DomainValidationOptions[0].ResourceRecord.[Name,Value] | join(`" "`, @)' \
        --output text) || record=None
    if [ "$record" = None ] || [ -z "$record" ]; then
        echo "ACM has not given the validation record yet. Run this again in a minute; it carries on from here." >&2
        exit 1
    fi
    record_name=${record% *}
    record_value=${record#* }
    upsert "{\"Name\":\"$record_name\",\"Type\":\"CNAME\",\"TTL\":300,\"ResourceRecords\":[{\"Value\":\"$record_value\"}]}" >/dev/null
    echo "waiting for the certificate to be issued; usually a few minutes ..." >&2
    aws_run acm wait certificate-validated --certificate-arn "$cert" >/dev/null
fi

step "3/5 distribution"
distribution=$(aws_run cloudfront list-distributions \
    --query "DistributionList.Items[?Aliases.Items && contains(Aliases.Items, '$name')].Id | [0]" --output text)
if [ "$distribution" = None ] || [ -z "$distribution" ]; then
    origin="$short-s3-website"
    config=$(cat <<EOF
{
  "CallerReference": "$name-$(date +%s)",
  "Comment": "$name",
  "Aliases": { "Quantity": 1, "Items": ["$name"] },
  "DefaultRootObject": "index.html",
  "Origins": { "Quantity": 1, "Items": [{
    "Id": "$origin",
    "DomainName": "$name.s3-website-us-east-1.amazonaws.com",
    "CustomOriginConfig": {
      "HTTPPort": 80, "HTTPSPort": 443, "OriginProtocolPolicy": "http-only",
      "OriginSslProtocols": { "Quantity": 1, "Items": ["TLSv1.2"] },
      "OriginReadTimeout": 30, "OriginKeepaliveTimeout": 5
    }
  }]},
  "DefaultCacheBehavior": {
    "TargetOriginId": "$origin",
    "ViewerProtocolPolicy": "redirect-to-https",
    "AllowedMethods": { "Quantity": 2, "Items": ["HEAD", "GET"],
      "CachedMethods": { "Quantity": 2, "Items": ["HEAD", "GET"] } },
    "Compress": true,
    "CachePolicyId": "$CACHING_OPTIMIZED"
  },
  "PriceClass": "PriceClass_All",
  "Enabled": true,
  "ViewerCertificate": {
    "ACMCertificateArn": "$cert",
    "SSLSupportMethod": "sni-only",
    "MinimumProtocolVersion": "TLSv1.2_2021"
  },
  "HttpVersion": "http2",
  "IsIPV6Enabled": true
}
EOF
)
    distribution=$(aws_run cloudfront create-distribution --distribution-config "$config" \
        --query Distribution.Id --output text)
fi
domain=$(aws_run cloudfront get-distribution --id "$distribution" --query Distribution.DomainName --output text)

step "4/5 DNS"
for type in A AAAA; do
    upsert "{\"Name\":\"$name\",\"Type\":\"$type\",\"AliasTarget\":{\"HostedZoneId\":\"$CLOUDFRONT_ZONE\",\"DNSName\":\"$domain\",\"EvaluateTargetHealth\":false}}" >/dev/null
done

step "5/5 what to record"
cat >&2 <<EOF
In the Makefile, beside the other sites' entries:

  bucket_$short := $name
  dist_$short   := $distribution

and in the README's Hosting table:

  | S3 bucket | \`$name\` |
  | CloudFront | \`$distribution\` |
  | Distribution domain | \`$domain\` |
  | ACM certificate (us-east-1) | \`$(printf '%s' "${cert##*/}" | cut -c1-8)…\` |

A new distribution takes several minutes to reach every edge location. Until
then https://$name may not answer; this waits for it:

  aws cloudfront wait distribution-deployed --id $distribution --profile $profile

Then build and deploy as usual.
EOF
