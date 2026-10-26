---
title: Code Review on the cusp of the Anthropocene and Anthropic Eras
date: 2026-10-26
author: Andrew McKnight
layout: post
tags: software engineering ai tech
abstract: "Code review is about as bad a process as tech interviewing and peer performance review. But it's the best choice of the three to be revolutionized by AI."
---

_Note: I wrote this draft yesterday, before Anthropic submitted their official S-1 filing which many of you have no doubt seen by now. HN discussion at https://news.ycombinator.com/item?id=50242939. It does color some of this post, but I haven't fully integrated it into my thinking yet; I present this as I thought of it as of yesterday._

---

Last week Anthropic published a provocative article on their source control and review processes: [https://www.anthropic.com/research/redesigning-source-control](https://www.anthropic.com/research/redesigning-source-control)..

A few days later there was a proposal for how to improve code review generally in the industry [https://just-be.dev/blog/code-review-sucks-now/](https://just-be.dev/blog/code-review-sucks-now/).

And for the past long while there's been an ongoing debate over where the optimal threshold lies on the spectrum between writing all code by hand and having LLMs do it all. A crystallizing moment in this debate was [_Don't be a meat proxy_](https://gruhn.me/blog/2026-08-03/). Which I totally get behind when it comes to human communication; nobody should be talking to coworkers over slack via LLM, or writing newsletters via LLM, or generating restaurant menus and images of dishes via LLM. [Or using it to generate their feelings and opinion about loved ones](https://www.nytimes.com/2026/10/25/style/marissa-mayer-ai-assistants-women.html).

I just think that AI is the beginning of the end of programming languages being a medium of communication between humans. I think the common thread running through all these articles and debates is an unwillingness to accept that.

Personally, I think this desire to maintain an absolute grip on source code is a control fantasy. Any individual's control over a millions-of-LoC repo was always tenuous at best, and mostly imagined. I fall more on the side of Anthropic. But let me back up to why even before AI came along, code review sucked.

# Code review in the age of human-authored code

There are multiple perspectives on why code review should be done when humans are the only actors reading and writing code:

1. Share understanding on how a given commit will change the codebase.
2. Identify defects the author missed in the changes.

These are the ostensible ones, at least, in a professional setting, but there is plenty of hazing involved as well. The problem is that everyone has a unique opinion on how something should be implemented, everyone has an ego drive, and there are multiple valid isomorphisms that satisfy any set of objective constraints.

Assume you practice perfect TDD, and write an exhaustive set of tests that validate the spec, every edge case, every performance concern (so you don't accidentally use bozo sort instead of a a radix or quicksort), and have linters for every cross-cutting architectural (like no singletons) and stylistic concern (like line length or tabs vs spaces), and to catch obvious sources of bugs and faults (like IUOs or unchecked direct array accesses). Basically, you have automated everything away except matters of taste, like naming things or how functions are organized in files.

People will still fight over those matters of taste. They hide behind things like prefixing such comments as "nits" or with [logaf](/blog/2025/01/06/logaf-v.-lem.html). Usually it comes down to speculation over future maintainability. This insecurity is unbecoming of engineers, we should be confident in our ability to change something later, we have incredible tools to assist us. We need to learn how to better use them.

Much time has been wasted due to such debates.

I also just want to take a moment to expound on a pet theory of mine. Code and architecture are extensions of an individual's unique brain structure. As we author a given bit of code, we are both expressing the preexisting structures in our brain, and also altering them to fit our understanding of the emerging structure we're creating.

It's no wonder that there is such ego involved in code review. But to become better engineers, we need to shed our attachment to code we've written. It's most likely going to be rewritten or discarded over time. When you revisit something you built, you might have to figure out someone else's reimplementation.

Reading code feels harder than writing it to many. I think the people who can quickly figure out alien code are going to thrive in the LLM age.

And aside from the nitpicky part of code review, people fail even at the two "real reasons" all the time. Or at least deploy them unwisely.

All of our worst bugs to hit production probably went through code review. And usually that's followed by lengthy process generating lengthy todo lists that will take forever to get done (read: never fully happen) because of the onerous process required to do it.

# Code review in the age of LLM-authored code

I think we should be moving reviews further away from being code nitpicking, and more into planning, user discussions, and measuring outcomes: does it work correctly? is it performant? Is it secure?

Organizations that haven't invested in the automation to avoid all the BS involved with code review are going to fall farther behind in this respect.

Anthropic is committing code at mind-boggling rates today. It was already true that for large codebases, there'd never be any one person that understands it all. They're accelerating that reality towards warp factor five.

Some people's reaction to this is to add more process, like Justin's blog post. Review all the code LLMs are outputting, but now also attach all the LLM sessions to the commits, so we can review those too.

This is like proposing building bigger battleships and aircraft carriers in the drone warfare age. It’s the classic trope of generals preparing to fight the last war.

Anthropic may ship bugs, as we all occasionally do, and their IPO may bust, but IMO they're still incredibly successful. Here's why: I'm very picky with what software I'll pay for, and even more so in the subscription age. I still keep a Kaleidoscope 3 license and binary from five years ago around, because even though I find it immensely useful, and understand the need to make money as a developer, there's nothing new coming out in it that's moving me to giving their new maintainers money every month. I need diffing and merging with keyboard shortcuts, that's it.

Claude Code is so valuable to me right now that I don't even blink at paying $100 month for it. That is 5x the amount I pay each to Netflix and Spotify every month, which I still reevaluate from time to time despite such a large part of my identity being an interest in film and music. I sometimes think I can work around those. Claude Code is essential, there is no working around it for me right now.

But I digress.

What should code review look like in the LLM age? It has almost nothing to do with the code at all.

The humans involved should be heavily collaborating with themselves and their users on how to meet those users' needs. The engineers should be engineeering automation to automatically verify that specs are met (tests), that the product is secure (tests) and performs well (tests). They should then peform continuous manual QA and iterate on it with each other and, again, and most importantly, _with their users_.

It's a huge waste of time to require people to maintain mental models of expansive codebases. They should instead be able to find target areas as needed, and be able to make the changes necessary. Agents can at least help with this, if not still doing all the work, as in initial implementation. More likely, all the time committed to memorizing code from diffs will be wasted because of the rate of churn. This is why I say reason #1 above is deployed unwisely.

It's a huge waste of time to write code by hand. And as the still very resonating article on how much [programming sucks](https://www.stilldrinking.org/programming-sucks) tells us: humans did not evolve to think in code. It's a crude, albeit extremely powerful and successful tool. I don't believe that today's high-level languages are the end state; they're a step towards something better, just as punch cards and assembly language were. And before you say anything, no, I do not compare LLMs to compilers. I think there are opportunities for new generations of programming languages to be designed for LLMs to use, that can structurally represent more classes of concerns, as we've recently seen with memory management, NPEs and concurrency, to name a few.

# All the world's a _stage_

I first heard of the _stage_ working in restaurants: you work in the kitchen for a day or week to see how you meld with the staff and prove you actually have the chops. I've also done one of these in a tech hiring process.

It's just the idea that the proof is in the pudding. It's easier to talk a good game in an interview, or even cheat, than it is to not sound like an idiot in a meeting, or present a competently and tastefully completed end-user-facing feature.

For me this extends to every changeset now. When my orchestrated agents send me PRs, they're accompanied with screenshots and staging builds for me to try it out. This is the manual QA that I mentioned. If it works closely enough to how I envisioned it, doesn't crash the app (it's also accompanied by exhaustive tests of all edge cases, including rigorous typing, which is essentially having the compiler test certain classes of bugs, like providing the string literal `'e'` to something that expects an integer, or a negative number to something that expects an unsigned integer), and doesn't have obvious performance issues.

That is where I think code review should be headed. Away from code, and towards what it's doing. We should be reviewing it in the domain that requires code to be written at all—the applications—and not as an end goal in and of itself.
