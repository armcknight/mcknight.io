---
title: Transcending irrational versioning
date: 2024-02-08
layout: post
abstract: Recently learned about my new favorite versioning scheme so far from none other than Donald Knuth.
author: Andrew McKnight
author-email: amcknight2718@gmail.com
tags: funny software engineering
RFC-prompt: Know any other good numbers to use for this? Want to bikeshed over the name "irrationdental"?
---

I've previously [written](https://mcknight.io/blog/2018/10/30/on-a-mission-to-automate-revision.html) blog posts and [some](https://mcknight.io/blog/2018/04/20/automatic-devpod-versioning-and-deployment-with-vrsnr.html) [tools](https://mcknight.io/blog/2017/12/17/easy-versioning-with-vrsnr-and-rake.html) to help practice [Semantic Versioning, aka SemVer](https://github.com/semver/semver), which for the longest time I believed was the best and most logical versioning scheme out there. Better than [CalVer](https://github.com/mahmoud/calver), [RomVer](https://github.com/romversioning/romver), [HashVer](https://github.com/miniscruff/hashver), [ZeroVer](https://github.com/mahmoud/zerover), [Pragmatic](https://github.com/seveibar/pragmaticversioning) or [Sentimental](https://github.com/dominictarr/sentimental-versioning) versioning. At least for APIs, but as this [Stack Overflow](https://softwareengineering.stackexchange.com/a/440907) answer astutely observes, different ones might be the best depending on the use case.

But no more!

I recently stumbled upon the versioning scheme used by Donald Knuth, creator of TeX, [which states](https://texfaq.org/FAQ-TeXfuture):

> at each bug-fix release the version number acquires one more digit, so that it tends to the limit π (at the time of writing, Knuth’s latest release is version 3.1415926). Knuth wants TeX to be frozen at version π when he dies; thereafter, no further changes may be made to Knuth’s source. (A similar rule is applied to MetaFont; its version number tends to the limit 𝑒, and currently stands at 2.718281.)

For your "zeroth" version and any major versions that follow, pick a famous number from mathematics beginning with that integer:

- 0: γ (aka [Euler's constant](https://en.wikipedia.org/wiki/Euler's_constant))

- 1: Φ (aka the [Golden Ratio](https://en.wikipedia.org/wiki/Golden_ratio))

- 2: 𝑒 (aka [Euler's number](https://en.wikipedia.org/wiki/E_(mathematical_constant))... this guy really took a lot of the good numbers)

- 3: π (if you don't know this one, you get pinched on March 14)

- 4: I spent too long already looking for single-character transcendental/irrational numbers, so let's just say if you break your API more than 3 times, you have to rename your product and go back to 0: γ. Rule of three!

Originally I wanted to call this transcendental versioning to signify just how much better it is than all the rest, but Φ is not transcendental, only irrational. γ is not yet proven to be _either_ transcendental or irrational–I think those cancel each other out and it stays here unless it's proven to be _neither_. Both 𝑒 and π are both irrational and transcendental.

Maybe it could just be called your program's Knuth number. 𝕂?
