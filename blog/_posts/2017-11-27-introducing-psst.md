---
title: Introducing Psst
date: 2017-11-27
layout: post
abstract: A simple script to perform straigtforward template replacement of credentials in a codebase, to help avoid committing them.
author: Andrew McKnight
author-email: andrew@tworingsoft.com
tags: security products
---

Have you ever committed a secret to a codebase? [You aren't](https://damnhandy.com/2015/09/10/how-putting-credentials-in-git-can-cost-you-at-least-6500-in-just-a-few-hours/comment-page-1/) the [only one.](https://news.ycombinator.com/item?id=13650818) Options exist out there to help you [scan your codebase](https://github.com/anshumanbh/git-all-secrets) for such secrets, [prevent you from committing them in the first place](https://github.com/awslabs/git-secrets) and to [manage secrets](https://github.com/StackExchange/blackbox) from writing code to builds and [deploys](https://docs.chef.io/data_bags.html). A great rundown of those methods can be found [here](https://www.digitalocean.com/community/tutorials/an-introduction-to-managing-secrets-safely-with-version-control-systems).

# KISS committed credentials goodbye

I write mainly for iOS, and I want something as lightweight and simple as possible to simply replace templated strings in my codebase with the appropriate values. I've used [`cocoapods-keys`](https://github.com/orta/cocoapods-keys) for some time, and it fulfills its use case very well, but it only works on secrets that are used in your application's executable code. This means any sort of build environment tools (like Xcode Build Phase scripts) that require secrets, or [things that want to use Plists](https://fabric.io), won't be able to use it.

# SED it and forget it

I wrote a script to do a basic search-and-replace throughout a codebase and swap template values for actual credentials. The template values are enumerated in a file that you commit to your codebase, paired with another file that contains the actual secret values, in `.psst/keys` and `.psst/values` respectively. The separation makes gitignoring the secret values file easy. If no secret values file exists, the script will try to expand environment variables of the same name, a [common workflow for CI setups](https://circleci.com/docs/1.0/environment-variables/#setting-environment-variables-for-all-commands-without-adding-them-to-git). (Optionally, a path to a keychain can be supplied, if you prefer to check in your secrets to the codebase in a securely encrypted file.) It will then iterate through the keys with secrets in hand and perform the replacements.

Check out the [source code](https://github.com/TwoRingSoft/psst) or get it on homebrew:

`brew tap tworingsoft && brew install psst` (in fish, `brew tap tworingsoft; and brew install psst`)

# In case of emergency, don't `break`, `continue`

OK, mistakes happen. This is a software tool, and it's being used by humans. If you find you've still accidentally committed sensitive data to your codebase and pushed, it's out there forever. Don't bother trying to rewrite your git history–immediately rotate that credential!
