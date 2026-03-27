---
title: "Laws We Never Voted In"
date: 2024-04-10
layout: post
abstract: "Axioms, maxims, truisms, heuristics, theorems, paradoxes, thought experiments, sayings, razors, and maybe some clichés."
author: Andrew McKnight
tags: philosophy statistics logic
---

_Update April 12, 2024: how could I forget Chesterton's fence?_
_Update June 17, 2024: Segal's law_

I've kept a list of these in my notes app for the longest time, recording names I knew and more as I read about them, often as mentioned in comments on Hacker News, or on Wikipedia rabbit hole dives resulting from them. I can't remember where I heard about some of them anymore. I'll update this list as I discover more.

I saw a reddit post the other day quoting Dietrich Bonhoeffer, which reminded me of Hanlon's razor, and finally decided that I needed to get this list tidied up a bit and shipped. Here's the full quote, expanded from what I saw on Reddit, from [GoodReads](https://www.goodreads.com/quotes/8616320-stupidity-is-a-more-dangerous-enemy-of-the-good-than):

> Stupidity is a more dangerous enemy of the good than malice. One may protest against evil; it can be exposed and, if need be, prevented by use of force. Evil always carries within itself the germ of its own subversion in that it leaves behind in human beings at least a sense of unease. Against stupidity we are defenseless. Neither protests nor the use of force accomplish anything here; reasons fall on deaf ears; facts that contradict one’s prejudgment simply need not be believed – in such moments the stupid person even becomes critical – and when facts are irrefutable they are just pushed aside as inconsequential, as incidental. In all this the stupid person, in contrast to the malicious one, is utterly self satisfied and, being easily irritated, becomes dangerous by going on the attack. For that reason, greater caution is called for when dealing with a stupid person than with a malicious one. Never again will we try to persuade the stupid person with reasons, for it is senseless and dangerous.

# Logical

- Occam's Razor: given competing explanations for a given phenomenon, the one that makes the least assumptions is the likeliest to be true
- Hanlon's Razor: never attribute to malice that which can be adequately explained by ignorance
  - Bonhoeffer's corrolary: Stupidity is a more dangerous enemy of the good than malice
- Sagan standard: extraordinary claims require extraordinary evidence
- Chesterton's fence: reforms should not be made until the reasoning behind the existing state of affairs is understood
- Segal's law: a person with a watch knows what time it is. Someone with two can never be sure.

# Economic

- Shirky Principle: Institutions will try to preserve the problem to which they are the solution.
- Yule’s Law of Complementarity: if the price of one complement is reduced, the demand for the other will increase (from [_4 New Laws of Computing_](https://spectrum.ieee.org/on-beyond-moores-law-4-new-laws-of-computing))
  - The [Gwern corollary](https://www.gwern.net/Complement): Smart companies try to commoditize their products’ complements
- Jevon's paradox: increased efficiency in usage of a resource can lead to induced demand leading to an increased, instead of decreased, overall need for that resource
- Hotelling's law: competitors differentiate their goods and services as little as possible in order to maximize demand from the public

# Geographical

- Naiman's rule: allow one hour for every 3 miles hiking forwards, plus an additional hour for every 2,000 ft of climbing
- Arbia's law of geography: everything is related to everything else, but the closer you look at different things, the more different they appear
- Tobler's first law of geography: everything is related to everything else, but near things are more related than distant things
- Tobler's second law of geography: the phenomenon external to a geographic area of interest affects what goes on inside

# Managerial

- Augustine's laws
  - Most projects start out slowly, and then sort of taper off.
  - Hiring consultants to conduct studies can be an excellent means of turning problems into gold: your problems into their gold.
- Goodhart's law: When a measure becomes a target, it ceases to be a good measure.
  - Scrum burndown charts: "This is how fast you went last sprint. Now do that or better." Leads to political estimations and commitments.
- Parkinson’s Law: work expands to fill the time allotted
- Conway’s Law: an organization will tend to produce systems representative of its own communication structure
- Peter principle: people in a hierarchy tend to rise to a level of respective incompetence

# Technological

- Fundamental theorem of software engineering: all problems in computer science can be solved by another level of indirection (attribted to David Wheeler)
- Also from [_4 New Laws of Computing_](https://spectrum.ieee.org/on-beyond-moores-law-4-new-laws-of-computing):
  - Hoff’s Law of Scalability: a technology's potential to scale is inversely related to its customizability, and directly related to its degree of standardization
  - Evans’s Law of Modularity: modularization reduces incompatibilities and complexities
  - There is a fourth law in that article, which it calls "The Law of Digitiplication," but I disagree with it. It states:
> if a paper is copied four times, one can now share the resource with five people. But digitize the document and the value-creation opportunities are multiplicative rather than additive.

    But fundamentally, multiplication is just iterated addition. To that end, the comparison between sharing paper and digital documents is a difference of degree, not kind. Those people you share a paper document with can also go on to make their own copies, and those copies can be copied, etc. That's just as multiplicative. The difference between sharing paper and digital documents is simply the _effort required to share copies_.
- Brewer's Theorem (aka CAP Theorem): a distributed data store can only guarantee two of the following three things: *C*onsistency, *A*vailability and *P*artition tolerance:
- Wirth's Law: software is getting slower more rapidly than hardware is becoming faster
- Moore’s Law: the number of transistors in an integrated circuit doubles roughly every two years
- Ahmdahl’s Law: the overall performance improvement gained by optimizing a single part of a system is limited by the fraction of time that the improved part is actually used. Often applied to parallel computing, where a given task only has a subset of its work that is actually parallelizable, with some fixed portion of work that is necessarily serializable, which will dominate the overall time needed to complete the task even with infite parallelization.
  - Gustafson’s*: addresses an assumption of Ahmdahl's law of a fixed problem size: what about the speedup as the improvement is applied to larger and larger problems?
- Fitt's law‡: the time necessary to move to a target area is a function of the ratio between the distance from the starting location and the width of the target
- Atwood’s Law: Any application that can be written in JavaScript, will eventually be written in JavaScript
- Brooks’ Law: Adding [human resources] to a late software project makes it later
- Zawinski’s Law†: every program attempts to expand until it can read mail
  - Mallett's: Every program attempts to expand until it can render HTML. This usually results in it being able to read email.
- Hyrum's rule: if you expose any API, someone will use it and any current behavior will become a contract, whether used by external consumers or internal maintainers
- Reed’s (related: Sarnoff’s)
- Schneier’s*
- Putt’s*
- Liebniz’
- Linus’
- Maes-Garreau*
- Metcalfe’s
- Hofstadter’s
- Koomey’s*
- Kryder’s*
- Finagle’s*
- Gall’s\*: A complex system that works is invariably found to have evolved from a simple system that worked. A complex system designed from scratch never works and cannot be patched up to make it work. You have to start over with a working simple system.
- Grosch’s*
- Sturgeon’s (funny)
- Andy and Bill’s*
- Ashby’s*
- Cheops’*
- Claasen’s*
- Dollo’s* (related to rollbacks/reverts?)
- Dawson’s\*: O(n^2) is the sweet spot of badly scaling algorithms: fast enough to make it into production, but slow enough to make things fall down once it gets there.
- Greenspun's tenth rule\*: Any sufficiently complicated C or Fortran program contains an ad hoc, informally-specified, bug-ridden, slow implementation of half of Common Lisp
- Roko's Basilisk‡: an otherwise benevolent artificial superintelligence (AI) in the future would be incentivized to create a virtual reality simulation to torture anyone who knew of its potential existence but did not directly contribute to its advancement or development, in order to incentivize said advancement

# Sociological

- Godwin’s Law‡: As an online discussion grows longer, the probability of a comparison involving Nazis or Hitler approaches 1
- Brandolini’s Law (aka the bullshit asymmetry law)†: The amount of energy needed to refute bullshit is an order of magnitude larger than is needed to produce it.
- Betteridge's law\*: Any headline that ends in a question mark can be answered by the word "no"
- Poe’s Law‡: without a clear indicator of the author's intent, any parodic or sarcastic expression of extreme views can be mistaken by some readers for a sincere expression of those views

# Linguistic

- Weise's law (note: the vocabulary of linguistics is essentially an alien language to me, but I find it fascinating to read about; maybe one day I'll understand what this law means-for now, you should look it up yourself!)

# Politics

- Cube root law\*: the optimal number of democratic representatives is the cube root of the population (from https://en.wikipedia.org/wiki/Cube_root_law)

# By the Numbers

- Simpson's paradox: when a trend appears in several groups of data but disappears or reverses when the groups are combined
- 68–95–99.7 rule (the empirical rule)\*: the percentage of values that lie within increasing standard deviations from the mean in a normal distribution
- 80-20 rule: 80% of outcomes come from 20% of causes
- 64-4 rule: 64% of revenue comes from 4% of customers, 64% of accidents are caused by 4% of hazards, 64% of software errors can be traced to 4% of bugs, and so on
- 75-25 rule: the investor should never have less than 25% or more than 75% of his funds in common stocks (from https://www.bogleheads.org/wiki/Graham_75-25_rule)
- 4% rule: you should be able to comfortably live off of 4% of your money in investments in your first year of retirement, then slightly increase or decrease that amount to account for inflation each subsequent year
- 3-6-3 rule: describes how bankers would supposedly give 3% interest on their depositors' accounts, lend the depositors money at 6% interest, and then be playing golf by 3 p.m
- rule 72 (aka rule 69): to estimate the time needed for an investment to double if you know the interest rate and if the interest is compound. For example, if a real estate investor can earn twenty percent on an investment, they divide 69 by the 20 percent return and add 0.35 to the result
- rule 110: to figure out how much of your portfolio should be in stocks, subtract your age from 110
- 25x rule: an estimate of how much you'll need to have saved for retirement. You take the amount you want to spend each year in retirement and multiply it by 25
- rule of 16: if the VIX is trading at 16, then the SPX is estimated to see average daily moves up or down of 1%

\* a law I discovered while researching laws I already knew about on https://en.m.wikipedia.org/wiki/List_of_eponymous_laws, https://www.laws-of-software.com or another page if mentioned
† a law I knew but didn't know the name for until I learned it from that wikipedia article or another page if mentioned
‡ a law I knew about previously but went to Wikipedia to get a good wording on the definition
