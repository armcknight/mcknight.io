---
title: Me and My Claude Squad
date: 2026-05-21
author: Andrew McKnight
layout: post
tags: tech softwaer ai
abstract: "A new macOS app I built to help wrangle all my Claude kitties."
---

I've been riding the cusp between [Yegge stage 6 and 7](https://steve-yegge.medium.com/welcome-to-gas-town-4f25ee16dd04#:~:text=Stage%206:%20CLI%2C%20multi%2Dagent%2C%20YOLO.%20You%20regularly%20use%203%20to%205%20parallel%20instances.%20You%20are%20very%20fast.) (please, [don't](https://www.youtube.com/watch?v=XEFZ30Cvdnc)) for about 6 months now. I basically do a continuous round robin of:

- thinking of new things to do, which go onto a linear board
- kicking off new claude sessions in worktrees to do the things
- checking in to make sure claude isn't blocked
- reviewing finalized work
- merging

But it gets unwieldy quickly. So I wanted a way to centralize monitoring all these sessions.

I looked at a few options like [Conductor](https://www.conductor.build), [Claude Control](https://github.com/sverrirsig/claude-control) and [Claudy](https://claudy.markg.app/apps/claudy). They're all nice apps and have a lot to offer. Almost _too_ much for what I really wanted though.

I don't want to really _control_ any aspects of my sessions. I just want to see what's going on at a quick glance. I don't want _all_ the information there, like git status. I want to keep that in my [tmux session](https://mcknight.io/blog/2026/01/07/my-current-llm-assisted-workflow.html) wrapping that claude session. I don't want to have a meta-project file, or have to connect my Anthropic account.

I just wanted something minimal and focused to help me know what are the most important claude sessions to go look at next. Usually, that means the ones that are waiting for confirmation to do something. Followed by idle sessions. And then finally I can see the ones that are actively running or that I interrupted for some reason.

It should automatically discover them just by looking at the files claude code creates on disk. No networking, no interventions on my part. It should Just Work.

So I've been building my own thing. Introducing [Claude Squad](https://github.com/armcknight/claude-squad). Hope you enjoy!
