# get title from command line argument
if [ -z "$1" ]; then
  echo "Usage: new-post.sh <title>"
  exit 1
fi
title="${1}"

#slugify title
slug=$(echo $title | tr '[:upper:]' '[:lower:]' | tr ' ' '-' | tr -cd '[:alnum:]-')

# get today's date in the form YYYY-MM-DD
today=$(date +%F)

# heredoc of blog post template
template=$(cat << EOF
---
title: "$title"
date: $today
layout: post
abstract: "<short summary>"
author: Andrew McKnight
tags: <space-separated list of tags>
---

<content>
EOF
)

echo "$template" > blog/_drafts/$today-$slug.md
