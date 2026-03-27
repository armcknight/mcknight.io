---
title: "The Art of Source Control, Part 2: Clean Git History"
date: 2017-01-19
layout: post
abstract: Outlining some best practices concerning git history tidiness.
author: Andrew McKnight
author-email: andrew@tworingsoft.com
tags: git
---

Just like [organizing a codebase](/blog/2017/01/14/art-of-source-control-part-1-organizing-codebases.html), git makes no prescription about how you organize the changes you make to that code. Hence, we find ourselves in another area where the practice depends on the person. The science of coding is in the compilation, type theory, runtime characteristics; how human readable languages are translated all the way down to binary that dictates physical changes in the hardware of the machine. The art I'm talking about today lies in curating the record of how the human readable code evolves via git commits. Each person's idea of the ideal commit history lies in the balance between the qualitative judgement of which changes should be preserved due to their relevance, and practical considerations for the tools used to inspect that history. 

# Relevance: Signal to Noise Ratio

Some people argue that every change should be recorded in a commit. What constitutes a change? Surely you wouldn't record a commit for each character you type, if you are adding an entirely new function to a class. What if you write the function, commit it, and then run your test suite only to discover a bug in the function? Should the fix for that bug be recorded as a separate commit in perpetuity?

I used to think that commits should be as granular as possible, something like the create-commit-fix-commit example above. This attempts to record the _thought process_ by which the final code came into being. I still work this way locally, because it provides better ability to isolate small iterative experiments. It's also much easier to reason about a very small git diff than a huge set of changes at any time, something I frequently look at to stay on track while working.

After some time working this way, I realized that it doesn't help people trying to come to grips with my code and how it evolved. If you leave commits that contained bugs fixed in later commits, you're actually leaving dead ends in a maze for later maintainers to navigate, instead of a clean, linear evolution. Moreover, I really never even needed to retrace my steps in that way. I frequently use Xcode's blame view, for instance, and I'd rather not see a 50 line function have a separate commit blamed for each line of code.

# Tooling: Practicality

Before merging my branch upstream, I now edit my commit history to squash many of the tinkering commits into a cohesive whole with an interactive git rebase. I make heavy usage of `git commit --fixup` and `git rebase --autosquash` to automatically reorder and squash those experimental/iterative commits. This helps if I can't `git commit --amend` because I've already committed some other changes after the commit I want to amend. I used to frequently `--amend` to `HEAD`, but I've been burned a few times after getting too eager to do so and have had to spelunk through the reflog. Now I'm more likely to `--fixup HEAD` and just to do the big `--autosquash`ed rebase right at the end.

Recording cohesive commits allows for easy reverting later. My concept of "cohesive" is this: if, when you ship your next release, you disover a problem with the new code, you should be able to reverse the change with a single `git revert` (of course, this is an ideal to strive for, not necessarily always practical in the real world). You should not have to perform as much work to surgically remove the logic as went into writing it in the first place, and you really don't want to have to do that after getting woken up at 3 AM.

Git bisect can help you find out which commit to revert. What if a bug is found in a release that went out some time ago? Maybe you're new to a project, with no knowledge of the history of the code's evolution. `git bisect` is a very helpful tool in these situations, performing a binary search between the last "good" commit and the first "bad" commit, to pinpoint the commit that introduced the bug. If the code change that introduced the bug is spread out over multiple commits, understanding the context of the changes in the commit that bisection ultimately blames may be very difficult–you may not even know how many commits are related. It's worth noting also that git bisect works best when each commit contains a code change that compiles and contains and passes all relevant tests.

Squashing also provides an opportunity to review all the previous messages, gather your thoughts, and write a good summary of what changed. For my first few years using git, I only ever used the short commit message or "subject". Now, my subject lines typically only contain 70 characters (enough to avoid truncation on GitHub, in Git clients like Tower, SourceTree or GitX, or when running `git log --oneline --decorate --graph`). The description contains a summary and usually bullet points gleaned from all the individual commits I squashed. Github will even pull all that useful information into a PR's description field!

> Updated 3/20/19 for minor typos.
