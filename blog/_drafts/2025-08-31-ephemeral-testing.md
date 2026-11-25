---
title: "Ephemeral Testing"
date: 2025-08-31
author: Andrew McKnight
layout: post
tags: software engineering
abstract: "Ideas on the permanence of tests."
---
Ephemeral Testing

Think about the scientific method. Some chemist, say, has an idea, does a ton of experiments in their lab mixing different chemicals, eventually finds the molecule/property they're after, and writes a report. If they're lucky, they create a new industry and ride off into the sunset with a big ol' bag of FU money.

What they _don't_ have in that bag are all the beakers, intermediate compounds or failed mixtures. Once they have a working process, that stuff isn't as important.

So why do we allow test suites to grow to astronomical proportions?

Imagine a tool that, given a bug, could automatically generate a UI test that reproduces the problem, and, _most importantly_, demonstrates the end user impact. That test runs in CI, where a video recording of the user impact is clear and obvious. Then, something–either you, or an AI–pushes a patch to the branch to fix the bug. The generated test runs again, passes the assertions, and the video recording again captured, so the before and after shots can be compared side-by-side.

Sounds pretty nice! But what do you do with that test afterwards? Do you merge it in? You'll quickly wind up with a test suite that takes longer to run than it does to encounter new bugs that need fixing.

I say that those tests are simply the [scaffolding](https://shermanonsoftware.com/2023/08/28/scaffolding-tests-and-throw-away-work/) that serves as automatic verification of the bug and fix, and can safely be thrown away afterwards.

I like my test suites to do two things: validate the happy paths, and validate graceful handling of the known and expected error conditions. (And also, automatically take screen captures for marketing materials.) Not every single combination of bugs that has ever been encountered needs to be memorialized.

I can imagine some system that automatically intuits what versions of my system are still operating in the wild, and prunes the test suite of scenarios for dead versions–or versions of modules/microservices.

But one thing is for certain, and that is that test suites _must be [pruned](https://osherove.com/blog/2007/9/13/throw-away-tests-vs-tests-that-last.html)_. This is something I've not only observed in my experience in software, but also [gardening](https://hort.extension.wisc.edu/articles/tomato-pruning/#:~:text=Why%20should%20I%20prune%20my,help%20fruits%20mature%20more%20quickly.). The question of how and when is where the art lies, and that indicates to me a market opportunity.

---

I had tried finding a blog post I read long ago along similar lines, but couldn't. However, I just saw https://news.ycombinator.com/item?id=45038074 the other day on HackerNews, which is so close that it might as well be the one I remember.
