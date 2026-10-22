=---
title: Skill Issue
date: 2026-06-24
author: Andrew McKnight
layout: post
tags: ai software tech
abstract: "How I approach automation of AI tooling."
---
Slash commands. Skills. MCPs.

The ecosystem is frothy with such things these days.

These are the tools of last resort for me. I use them as sparingly as possible. I will reach for a CLI/API before using them. Sometimes I wind up promoting skill/MCP usage to CLI/API, once I've solidified the use case and have a good idea of the implementation.

I prefer determinism, as well as the Unix philosophy of things doing their jobs and no more. Keeping responsibilities separated allows for better workflow combination.

Sure, tokens are cheap. For now. But also, I find the AI first approach much slower in terms of wall clock time. There's no need to introduce an extra network round trip to statistically generate a result that could be deterministically computed locally, right now.

I prefer Claude working as a tool, not the foreman. I'm still the foreman, even if I have built several layers of abstraction that almost completely automate vibecoding by now. I can still dip into any level of that abstraction to work manually if need be.
