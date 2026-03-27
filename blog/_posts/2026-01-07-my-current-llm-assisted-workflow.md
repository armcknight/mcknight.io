---
title: My Current LLM-Assisted Workflow
date: 2026-01-07
author: Andrew McKnight
layout: post
tags: software engineering tech
abstract: "How I've been using Claude Code to build iOS/macOS apps."
---
My last few blog posts have been snapshots of my ramp up to full blown LLM-first software development. I've been at a steady state in my workflow lately, here's what I've currently settled on.

I use claude purely in the terminal with `tmux` (via `tmuxinator`) splitting the window into 3 panes:
- entire right side is cc
- top left is emacs launched directly into magit for quick diff viewing
- bottom left is a bare shell.

The tmuxinator config:

{% include gist-embed.html url="https://gist.github.com/armcknight/5957c1723bfe08d11fedf66fdb953cea" %}

I have anywhere from 2 to 6 or 7 of these going at any given time.

To start a new task, I navigate a new terminal window to the root of my repo and enter `work start <branch name copied from linear task>` (we use Linear at work for task management; I try to add all the context I'd want Claude to have to take an initial swing at the problem there, which helpfully doubles as context for any other humans looking at it, including my future self; for a similar concept, see <a href="https://build.ms/2025/12/15/building-software-from-blog-posts/">Building Software From Blog Posts</a>). Here's what that does:

- creates a new git worktree, copying my .env files from the repo root
- spins up the tmux session for it.

My Fish shell `work` function:

{% include gist-embed.html url="https://gist.github.com/armcknight/8588a00d6d5524c24bb8b64a4ed9dc3e" %}

That also has subcommands for `term` which I can use to spin up a tmux session in any repo/worktree as needed.

In the Claude pane there, I issue a `/start` command, which does the following:

- fetch all the Linear task info using their API (I used to use their MCP, but it's way slower and doesn't offer me anything over the API; I landed on [`linctl`](https://github.com/dorkitude/linctl) instead)
- mark the issue as "In Progress"
- prepare an implementation plan for my approval.

My `/start` command:

{% include gist-embed.html url="https://gist.github.com/armcknight/69e15018de5ea6a1bb187983f9f2ca0c" %}

Once Claude has taken its swing at solving the problem, I can come back to the session and in the tmux shell pane, run `make xcode` to run XcodeGen and open the generated Xcode project, where I still work largely as described earlier in [Claude Willing](/blog/2025/08/26/claude-willing.html#:~:text=An%20IDE’s%20Place). My latest addition there is a little piece of Hammerspoon automation to toggle the File Navigator's "Show only files with source-control status" filter, since no standard keyboard shortcut exists for it, nor even a menu item I could use to create one in macOS Keyboard settings.

The Hammerspoon script:

{% include gist-embed.html url="https://gist.github.com/armcknight/fe01a3469da1c59bc83ce5b482fccc34" %}

I create simple commits in the magit pane of the tmux session at regular intervals, so I can keep track of changes, and throw out new stuff Claude has done if I don't like it, or want to avoid my own hand edits from being overwritten, which Claude will happily do.

I have another tmux session always running in the repo root always on `main`, where I can issue a `/merge <branch name>` command which:

- updates CHANGELOG.md
- prepares a commit description
- waits for my approval on those, and then
- creates a merge commit (with conflict resolution if necessary)
- marks the Linear task as "In Review".

My `/merge` command:

{% include gist-embed.html url="https://gist.github.com/armcknight/63e8bd2ede562ec70053f991715ec75c" %}

I also use this one for housekeeping tasks not necessary to capture in a Linear task.

All the automation here is kept in my private dotfiles repo, where, you guessed it, I also have the same tmux session running, to iterate on the automation itself. I can then update my machine's configuration with `make deploy` from that repo to make it available to all my other projects.
