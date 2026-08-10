---
title: Claude Workflow pt. 2
date: 2026-08-10
author: Andrew McKnight
layout: post
tags: ai, tech, software
abstract: Updates on how I automate my Claude usage.
---

Following my previous post on [my LLM workflow](/blog/2026/01/07/my-current-llm-assisted-workflow.html), updates on how my workflow has evolved.

# Herding Kittens

After making it so easy to spin up parallel local agents, my problem then became wrangling them all and even knowing what was what, with so many mental context switches to perform. So I built a macOS app to serve as a dashboard for which sessions were running, what they were up to, and most importantly, which ones were _not_ running, so I could attend to them first and keep my throughput as high as possible.

There are a couple other apps out there that do similar things, like [Conductor](https://www.conductor.build) and even Cursor itself, but the most important difference for me here is that I _don't_ want an app that controls the workflow. I just wanted a read-only view into what was going on. I prefer to manage my worktrees myself. I guess I just like a bit more granularity in my tools, à la the Unix philosophy.

I call it [Claude Squad](https://github.com/armcknight/claude-squad).

{% include blog-post-image.html source="claude-squad.png" alt="Claude Squad macOS app serving as a dashboard for all my local Claude sessions." %}

# Haystack Needles

My other problem was switching to the terminal window I wanted to do something with next. I went from ⌘-tabbing through windows to  entering exposé and squinting at the grid of tiny preview windows trying to find the right one. But this really doesn't scale well.

So, I had Claude tweak my `work` utility to name the terminal window according to the filesystem path and git branch for the session, and then build a Hammerspoon hotkey and picker window I could type to filter through those names, for true random access to exactly the thing I wanted.

I've extracted this and my earlier Spoon to a new [hammerspoons](https://github.com/armcknight/hammerspoons) repo.

{% include blog-post-image.html source="hammerspoon-terminal-switcher.png" alt="Random access to all my terminal windows via Hammerspoon." %}

# Claude in the Cloud

Local worktrees for parallel Claude sessions are great for my personal projects, but not so much for my current dayjob, which has a multirepo setup that makes assumptions about locations on disk. Sure, I could maybe copy or symlink all the repos' worktrees I need to put together for a given task to a dedicated folder so they all are side by side. And maybe I could make the changes to the repos so all the venv stuff can coexist with multiple parallel copies.

But there was a better option available: remote dev boxes. Our dev infra team already had an offering via one provider, and is currently test-driving a new one. Both offer a cloud container with all the necessary repos in their required filesystem relationship, a Claude install I can prompt and tail, and then I can spin up the devserver and forward a port back to my local machine to visit in the browser and test what I need (which is great because the devserver crushes my laptop battery in short order).

So, it's as simple as:

- `work start remote andrewmcknight/proj-123-my-task` which does all the same stuff as `work start` from my previous blog post: pull linear ticket info, craft a prompt, and carry all the way through to opening a draft PR
- `work remote status` gives me a listing of all my current containers, status info, URLs to their web dashboards, and URLs to the associated GitHub PRs
- `work remote log [-f]` to see what Claude's up to
- `work remote test $instance-slug` to open the  URL to the devserver running on that instance in my browser

Example `work remote status` output:
```
  ~/D/project ❯❯❯ work remote status
  WORKSPACE                           CODER      AGENT         LAST ACTIVITY         PR                                                                DASHBOARD
  proj-101-debounce-the-idempotenc    stopped    -             -                     https://github.com/example-org/example-repo/pull/1001  merged, passing  https://coder.example.com/@username/proj-101-debounce-the-idempotenc
  proj-102-shard-the-widget-cache-    stopped    -             -                     https://github.com/example-org/example-repo/pull/1002  closed, passing  https://coder.example.com/@username/proj-102-shard-the-widget-cache-
  proj-103-backfill-the-telemetry-    stopped    -             -                     https://github.com/example-org/example-repo/pull/1003  closed, passing  https://coder.example.com/@username/proj-103-backfill-the-telemetry-
  proj-104-migrate-the-blob-store-    stopped    -             -                     https://github.com/example-org/example-repo/pull/1004  closed, passing  https://coder.example.com/@username/proj-104-migrate-the-blob-store-
  proj-105-throttle-the-webhook-fa    stopped    -             -                     https://github.com/example-org/example-repo/pull/1005  draft, passing  https://coder.example.com/@username/proj-105-throttle-the-webhook-fa
  proj-106-memoize-the-graph-resol    stopped    -             -                     https://github.com/example-org/example-repo/pull/1006  draft, passing  https://coder.example.com/@username/proj-106-memoize-the-graph-resol
  proj-107-rotate                     stopped    -             -                     https://github.com/example-org/example-repo/pull/1007  needs review, passing  https://coder.example.com/@username/proj-107-rotate
```

I can provide multiple `remote` configurations so that i can override any of those invocations with `work remote --provider $providerName`, and define a default remote so I don't have to specify the provider in every invocation.

Oh, and I had Claude reimplement the `work` utility in Swift, and I now deliver it as a standalone Homebrew cask (it was previously a collection of Fish functions deployed via my private dotfiles repo). I architected remote providers as a plugin system with a Swift protocol that can be satisfied by separate packages providing conforming implementations, so I can hide all the details of our providers in private repos.

Source in my [workr repo](https://github.com/armcknight/workr).

# Just Do It

So, I have a way to pull Linear task info to start a task and take it all the way through drafting a PR. But ugh, all that typing to do it! Yuck! Why not automate it?

So, I wrote a daemon that polls my Linear boards, and just automatically calls `work start` for each task. Now, It's even simpler than the above list of commands. All I have to do is open a Linear task, and then check out the PR later. This runs on a Mac Mini M1 at my house, so I can always dive into the worktrees created by the `work` commands it executes to do the work.

One future idea I have for Claude Squad is to be able to monitor remote sessions, which would get me access to info for the remote containerized Claude stuff like for my job, plus monitoring the build machine's sessions from a different location. Maybe even an iOS port so I can run it on my iPhone/iPad, and accessing my build machine via my Tailnet.

But I digress; check out my [superlinear repo](https://github.com/armcknight/superlinear) to see more on the orchestrator.

# Adhoc Tuah

It's pretty straightforward to drop a link to a containerized devserver instance in a PR. But you can't do that for a mobile app. Unless, that is, I have a GitHub Action that builds and signs an IPA I can host on S3, that could be downloaded to a test device from a signed link in the PR! It's one of my growing [collection of GitHub Action workflows](https://github.com/armcknight/workflows).

# Voilà

So there you have it. A fully automated pipeline from Linear task to a reviewable draft PR with a test instance I can access right on my mobile device. I can pump out features without ever opening the laptop.

# Nota Bene

You might get the impression that I'm all in on AI. Well, almost. It's a great tool. I just want to state here that all my blog posts are 100% AI-free. I like writing, and I want to keep that activity for myself, in a ["AI was supposed to free us from laundry and dishes so we could make art, but instead it is making our art so we can do laundry and dishes" sorta way](https://x.com/AuthorJMac/status/1773679197631701238).

I do need to circle back to the readmes and project descriptions on my website, because I just pushed a big update blitz to get these all visible for this blog post. I would also like those to remain human-crafted with my personal touches. OK.
