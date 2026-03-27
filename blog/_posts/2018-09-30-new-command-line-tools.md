---
title: "New command line tools"
date: 2018-09-30
layout: post
abstract: Announcing some new CLI tools available, and plans on how to consolidate others like psst, xcbs and vrsn.
author: Andrew McKnight
author-email: andrew@tworingsoft.com
tags: ruby tools
---

Over the last few weeks I've written two new tools for the command line: `rebuild-sims` and `sync-forks`. They join a small but growing family of tools to help with software development. Here's a bit about the newcomers and how I see that collection growing and staying organized.

# rebuild-sims

At some point a few weeks ago I found I'd corrupted my installs of iOS simulators. I tried fixing it myself to no avail, partly because I was trying to wrap up a release for an app update (of course, with yhr timing). I looked around for a drop in solution online and found this gist: [simulator populator xcode](https://gist.github.com/cabeca/3ff77007204e5479f7af), but I had some issues with it:

- it tried to build _every_ combination of device and platform, for things like watch + iOS
- it has to be copied and pasted from a Gist, and then I have to manage it from there

So, I took the opportunity to rewrite it a bit to improve performance, and serve it in a Gem for ease of distribution and use.

# sync-forks

I find a lot of useful code on GitHub, and when I want to use something in a project I try to [safely isolate the dependency](http://tworingsoft.com/blog/2018/01/09/dependency-management-best-practices.html), part of which involves forking it. 

[Forking a repository](https://help.github.com/articles/fork-a-repo/) in a DVCS really just means creating a new mirror, a new node in the graph of “remotes” (even your local clones of repositories are really remotes: try cloning from a local repository on your machine, and then look at that clone's git remotes–they'll be local paths), to which GitHub adds some helpful UX: if you fork a repo via the GitHub UI, your repository is tagged with information about the original one. Hence, the little "forked from original-owner/repository-name" link under a fork's name on its GitHub page.

I currently have around 80 forks. I've tried keeping them up to date locally to maintain as much control as possible over my fate as a dependee, but that's a lot of work. For a while I've wanted a way to automatically ensure I have a local copy of each fork.

`sync-forks` uses the GitHub API via the [`github_api`](https://github.com/piotrmurach/github) Gem to get a list of all your repositories and clone those that are forks. In each local repo, the git remote `origin` will point to your fork, and `sync-forks` will add a new remote named `upstream` that points to the original.

Eventually, I'd like a way to automatically fetch new commits from `upstream`s and apply them (using `--ff-only` for safety) to the local default branch, and then push to `origin`. Maybe later a more sophisticated approach using `git pull --rebase` and a stored `rerere` strategy could be used for customized forks. 

Here's another pie-in-the-sky idea: automate _forking_ for all your dependencies. I'm not perfect about going around and forking all the repos for dependencies I use in my apps, or even in these Gems. While it is true that package managers may leave caches or checkouts of dependencies in various places, it might be nice to archive them all on a personal server, perhaps. If `sync-forks` could crawl all of my Gem or CocoaPod dependencies, fork them on their respective platforms (if possible–GitHub would work, but a privately hosted Git repo probably won't) and do the usual sync work, then you'd have a total mirror of all the software your apps need to work!

# tworingtools

These are distributed in a Ruby Gem named `tworingtools`, which provided a nice little learning opportunity to me, since this is the first Gem I've created. I also have a set of tools distibuted via `Homebrew` in [tworingsoft/homebrew-formulae](https://github.com/TwoRingSoft/homebrew-formulae), but I've found that approach tougher. Going forward, I'd like to merge these collections. 

[`tworingtools`](https://github.com/tworingsoft/tools) is currently all housed in a single repository, including specs, which I like. I currently have the Homebrew specs stored in a separate repo from the tools, introducing more complexity. Ultimately I'd like to combine those source repositories into `tworingtools`, and add them appropriately to the gemspec. All the better if I can also host the Homebrew specs in that same repository, and target both package managers.
