#!/bin/sh
# Checks that a subdomain's AWS setup is what setup-subdomain.sh makes, and
# that the site answers. Read-only: it gets, lists and describes, and changes
# nothing, so it does not ask before each command, though it prints each one.
#
#   scripts/audit-subdomain.sh travel.mcknight.io
#
# Each setting is printed as ok, or WRONG with what was found and what was
# expected. It exits 0 when every check is ok, 1 otherwise, so it can gate a
# deploy. PROFILE picks the AWS profile, armcknight by default.
#
# The expected values are setup-subdomain.sh's; a change to one belongs in both.

set -u

name=${1:-}
if [ -z "$name" ]; then
    echo "usage: $0 <name>, e.g. $0 travel.mcknight.io"
    exit 1
fi

profile=${PROFILE:-armcknight}
region=us-east-1
parent=${name#*.}
short=${name%%.*}

CLOUDFRONT_ZONE=Z2FDTNDATAQYW2
CACHING_OPTIMIZED=658327ea-f89d-4fab-a63d-7e88639e58f6

wrong=0

section() { printf '\n== %s\n' "$1"; }

# Runs one read-only aws command, printing it first. Prints the result on
# stdout, or "(error)" if the command failed, with the error shown.
aws_get() {
    printf '  $ aws %s\n' "$*" >&2
    if ! out=$(aws "$@" --profile "$profile" --region "$region" --no-cli-pager 2>&1); then
        printf '%s\n' "$out" | sed 's/^/    !! /' >&2
        echo "(error)"
        return
    fi
    printf '%s' "$out"
}

# One setting: ok when it is what was expected, WRONG with both otherwise.
check() {
    label=$1
    expected=$2
    actual=$3
    if [ "$actual" = "$expected" ]; then
        printf '  ok     %s: %s\n' "$label" "$actual"
    else
        printf '  WRONG  %s: found %s, expected %s\n' "$label" "${actual:-(nothing)}" "$expected"
        wrong=$((wrong + 1))
    fi
}

echo "Auditing $name in profile $profile."

section "zone for $parent"
zone=$(aws_get route53 list-hosted-zones-by-name --dns-name "$parent." --max-items 1 \
    --query "HostedZones[?Name=='$parent.'].Id | [0]" --output text)
zone=${zone##*/}
if [ "$zone" = None ] || [ "$zone" = "(error)" ]; then
    check "hosted zone" "a zone named $parent." "none"
    echo; echo "No zone, so nothing else can be checked."; exit 1
fi
check "hosted zone" "$zone" "$zone"

section "bucket"
exists=$(aws_get s3api head-bucket --bucket "$name")
if [ "$exists" = "(error)" ]; then
    check "bucket $name" "exists, and is this account's" "missing or not ours"
else
    check "bucket $name" "exists" "exists"
    check "region" "None" "$(aws_get s3api get-bucket-location --bucket "$name" --query LocationConstraint --output text)"
    check "website index document" "index.html" \
        "$(aws_get s3api get-bucket-website --bucket "$name" --query IndexDocument.Suffix --output text)"
    check "public access block" "False False False False" \
        "$(aws_get s3api get-public-access-block --bucket "$name" \
            --query 'PublicAccessBlockConfiguration.[BlockPublicAcls,IgnorePublicAcls,BlockPublicPolicy,RestrictPublicBuckets]' \
            --output text | tr '\t' ' ')"
    check "object ownership" "BucketOwnerEnforced" \
        "$(aws_get s3api get-bucket-ownership-controls --bucket "$name" --query 'OwnershipControls.Rules[0].ObjectOwnership' --output text)"
    # The policy is compared as JSON text, after the one form the setup writes.
    check "policy" \
        "{\"Version\":\"2012-10-17\",\"Statement\":[{\"Effect\":\"Allow\",\"Principal\":\"*\",\"Action\":\"s3:GetObject\",\"Resource\":\"arn:aws:s3:::$name/*\"}]}" \
        "$(aws_get s3api get-bucket-policy --bucket "$name" --query Policy --output text)"
fi

section "certificate"
cert=$(aws_get acm list-certificates \
    --query "CertificateSummaryList[?DomainName=='$name'].CertificateArn | [0]" --output text)
if [ "$cert" = None ] || [ "$cert" = "(error)" ]; then
    check "certificate for $name" "one, in $region" "none"
else
    check "certificate" "$cert" "$cert"
    check "status" "ISSUED" "$(aws_get acm describe-certificate --certificate-arn "$cert" --query Certificate.Status --output text)"
    check "validation" "DNS" \
        "$(aws_get acm describe-certificate --certificate-arn "$cert" --query 'Certificate.DomainValidationOptions[0].ValidationMethod' --output text)"
    check "renewal eligibility" "ELIGIBLE" \
        "$(aws_get acm describe-certificate --certificate-arn "$cert" --query Certificate.RenewalEligibility --output text)"
    expires=$(aws_get acm describe-certificate --certificate-arn "$cert" --query Certificate.NotAfter --output text)
    printf '  info   expires %s; ACM renews it while the validation record stays\n' "$expires"

    # The record that proves the name must stay in the zone, or renewal fails.
    record=$(aws_get acm describe-certificate --certificate-arn "$cert" \
        --query 'Certificate.DomainValidationOptions[0].ResourceRecord.[Name,Value] | join(`" "`, @)' --output text)
    record_name=${record% *}
    record_value=${record#* }
    check "validation CNAME in the zone" "$record_value" \
        "$(aws_get route53 list-resource-record-sets --hosted-zone-id "$zone" \
            --query "ResourceRecordSets[?Name=='$record_name' && Type=='CNAME'].ResourceRecords[0].Value | [0]" --output text)"
fi

section "distribution"
distribution=$(aws_get cloudfront list-distributions \
    --query "DistributionList.Items[?Aliases.Items && contains(Aliases.Items, '$name')].Id | [0]" --output text)
if [ "$distribution" = None ] || [ "$distribution" = "(error)" ]; then
    check "distribution for $name" "one, aliased to $name" "none"
    distribution=""
    domain=""
else
    check "distribution" "$distribution" "$distribution"
    # Every field in one call, tab-separated, in this order.
    fields=$(aws_get cloudfront get-distribution --id "$distribution" --output text --query '[
        Distribution.Status,
        Distribution.DomainName,
        Distribution.DistributionConfig.Enabled,
        join(`,`, Distribution.DistributionConfig.Aliases.Items),
        Distribution.DistributionConfig.DefaultRootObject,
        Distribution.DistributionConfig.Origins.Quantity,
        Distribution.DistributionConfig.Origins.Items[0].DomainName,
        Distribution.DistributionConfig.Origins.Items[0].CustomOriginConfig.OriginProtocolPolicy,
        Distribution.DistributionConfig.DefaultCacheBehavior.ViewerProtocolPolicy,
        Distribution.DistributionConfig.DefaultCacheBehavior.Compress,
        Distribution.DistributionConfig.DefaultCacheBehavior.CachePolicyId,
        join(`,`, sort(Distribution.DistributionConfig.DefaultCacheBehavior.AllowedMethods.Items)),
        Distribution.DistributionConfig.PriceClass,
        Distribution.DistributionConfig.HttpVersion,
        Distribution.DistributionConfig.IsIPV6Enabled,
        Distribution.DistributionConfig.ViewerCertificate.ACMCertificateArn,
        Distribution.DistributionConfig.ViewerCertificate.SSLSupportMethod,
        Distribution.DistributionConfig.ViewerCertificate.MinimumProtocolVersion
    ]')
    # Reads the tab-separated fields into their names.
    IFS='	' read -r status domain enabled aliases root origins origin origin_protocol viewer_protocol \
        compress cache_policy methods price_class http_version ipv6 cert_arn ssl_method tls <<EOF
$fields
EOF
    check "status" "Deployed" "$status"
    check "enabled" "True" "$enabled"
    check "aliases" "$name" "$aliases"
    check "default root object" "index.html" "$root"
    check "origins" "1" "$origins"
    check "origin" "$name.s3-website-$region.amazonaws.com" "$origin"
    check "origin protocol" "http-only" "$origin_protocol"
    check "viewer protocol" "redirect-to-https" "$viewer_protocol"
    check "compression" "True" "$compress"
    check "cache policy (CachingOptimized)" "$CACHING_OPTIMIZED" "$cache_policy"
    check "allowed methods" "GET,HEAD" "$methods"
    check "price class" "PriceClass_All" "$price_class"
    check "HTTP version" "http2" "$http_version"
    check "IPv6" "True" "$ipv6"
    check "certificate" "${cert:-the certificate above}" "$cert_arn"
    check "SSL support" "sni-only" "$ssl_method"
    check "minimum TLS" "TLSv1.2_2021" "$tls"
fi

section "DNS"
for type in A AAAA; do
    target=$(aws_get route53 list-resource-record-sets --hosted-zone-id "$zone" \
        --query "ResourceRecordSets[?Name=='$name.' && Type=='$type'] | [0].AliasTarget.[HostedZoneId,DNSName]" \
        --output text | tr '\t' ' ')
    [ "$target" = None ] && target=""
    check "$type alias" "$CLOUDFRONT_ZONE ${domain:-<the distribution>}." "$target"
done

section "the site"
printf '  $ curl -sI https://%s/\n' "$name"
check "https://$name/" "200" "$(curl -s -o /dev/null -w '%{http_code}' --max-time 15 "https://$name/")"
printf '  $ curl -sI http://%s/\n' "$name"
check "http://$name/ redirects" "301 https://$name/" \
    "$(curl -s -o /dev/null -w '%{http_code} %{redirect_url}' --max-time 15 "http://$name/")"

section "Makefile"
check "bucket_$short" "$name" "$(sed -n "s/^bucket_$short *:= *//p" Makefile)"
check "dist_$short" "${distribution:-the distribution above}" "$(sed -n "s/^dist_$short *:= *//p" Makefile)"

echo
if [ "$wrong" -eq 0 ]; then
    echo "All ok."
else
    echo "$wrong wrong."
    exit 1
fi
