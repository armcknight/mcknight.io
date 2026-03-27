---
title: "Claude Willing"
date: 2025-08-26
author: Andrew McKnight
layout: post
tags: tech
abstract: "Things I've learned after ramping up intensity with Claude Code."
---

Last week was Hackweek at my company, and I used that week to keep pushing through a new project I recently started. I've been Claude-first from the beginning of the project, and was already familiar with it (see my previous post about it: [Claude Damn](/blog/2025/07/15/claude-damn.html)). In the rush to make it to our deadline of Thursday evening to record our video presentation, I put the process in overdrive.

Here's an explanation of some of the habits I've formed:

# Strategic Compaction

I started manually running `/compact` before a big or intensive task I thought might use up the context window, to avoid it happening in flight, potentially losing some context.

# Plan Mode

So far, all my usage has just been in the default mode, using the magic "[ultra]think [hard(er)]" keywords if I want a better outcome. But last Wednesday or so, I got a tip to hit shift+tab to enter plan mode. This lets you ask questions, point out pieces of code and iterate on a plan, that is then fed into the normal mode _as the prompt_. Prompt engineering prompts provides a much more refined and rich prompts to get a better outcome!

# Writing Good Bug Reports

Just telling Claude what is wrong and what you expected to happen can get you pretty far, as long as you provide a good amount of detail. I like using voice dictation to just stream-of-consciousness all my thoughts into the prompt. It does a good job of figuring it out.

# Debug Logging

Sometimes, when it can't just figure it out, it will add logs and ask you to run the app again and give it the console output. I started asking it to do this other times when it felt like I'd gone through several cycles without the results I was looking for. And then you get to keep those logs for later!

# Git Gud

Commit often to avoid unrelated changes from mixing together, or to lose progress you were happy with, in case Claude changes something for the worse, or removes something you want to keep. Committing often when using LLMs is like hitting ctrl-s every 20 seconds while editing a Word doc circa 1998.

# An IDE's Place

I find myself using my IDE (Xcode) more to inspect changes and less to write actual code (much less~almost none). Or, to jump around in call hierarchies and find a piece of code to feed back to Claude as a clue for the next task. I usually have the File Navigator (⌘ 1) set to "show only files with source control" (that little box in the far right of the filter bar on the bottom of the pane with the + and -), and my editor is usually in Version Editor mode (⌘ ⌥ ⇧ ⏎), where I can quickly move from one change to the next with ^ \.

---

OK, some takeaways, and thoughts for next steps:

- AI is still not a panacea. True one-shotting is rare, if you care about code quality and architectural organization (more on this in a minute). Sometimes it just can't figure it out period, although I've only hit this maybe once or twice.

- You must be able to quickly and effectively dive into what is essentially a brand new or foreign codebase and debug issues. You'll constantly see things you didn't pay enough attention to or forgot, plus all the new stuff that just came in. Grokking the firehose of output is not the grokking you do when you've written everything by hand.

- You need good intuitions for architecture and organization of code to keep that firehose of code wrangled. It can get out of hand quickly. If you factor things well, it becomes easier to run multiple agents simultaneously. At one point last week I had four sessions going in different areas of the app and tests.

    - This also leads to a point about humans' working memory and your ability to manage tasks and a tidy queue of upcoming work.

    - One thing I want to try next is having multiple local clones of my repo, one per agent session, to avoid them conflicting writing code or trying to build/run the app, since sometimes one will cause breakages for others.

    - I just saw [this show HN](https://news.ycombinator.com/item?id=45013572) that looks like another thing I wanted: something that would pull tasks off of a Linear project and implement them for me, since I can think of things to do much faster than Claude can get through them.

- LLMs are great at "chores" like generating mock data and in-app development/debug tools.

- If you want something done right, DIY. Sometimes you still just have to roll up your sleeves and do something yourself.

---

If you liked this post, you might also enjoy this one written several weeks back: [https://www.indragie.com/blog/i-shipped-a-macos-app-built-entirely-by-claude-code](https://www.indragie.com/blog/i-shipped-a-macos-app-built-entirely-by-claude-code).
