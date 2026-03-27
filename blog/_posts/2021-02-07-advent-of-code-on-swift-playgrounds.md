---
title: "Advent of Code 2020 on Swift Playgrounds for iPad"
date: 2021-02-07
layout: post
abstract: "I tried using the Swift Playgrounds app on my iPad while solving problems for Advent of Code 2020 this year. Here's my impression of the app as a code editor."
author: Andrew McKnight
author-email: andrew@tworingsoft.com
tags: apple ios ipad swift playgrounds devex tools
---

I tried Advent of Code for the first time this year. Very fun–scratched my itch for the odd programming challenge, comes with a storyline that got me personally, emotionally invested.

I decided that I'd confine myself to using iPad Playgrounds to write my solutions in Swift. I'd used it a few times a couple years ago and liked what I saw, thinking it had great potential. My most memorable session was riding a ski bus to the mountains: I worked out an algorithm for [snapping angles to intervals around a unit circle]({{ site.url }}/blog/2017/03/16/snapping-angles-and-fuzzy-search.html), and enjoyed the visualizations it offered, like graphs of variable values in loops. Those seemed like the perfect tool to attack code challenge problems.

I used an iPad Pro 10.5" with  Smart Keyboard (my second one in as many years, by the way; and my down arrow key is already going in this one!). I did not use a Magic Mouse, although I do from time to time on the iPad; just haven't made it a habit. It probably would have helped with a lot of the minor editing issues, although I wasn't always in a situation that'd allow it. In general, I do prefer key-based control over mousing and clicking, so I always appreciate a robust set of hot key combinations.

As I moved through problems, I started writing down annoyances I encountered. Eventually, I started to dread using the app and felt it was hurting my inaugural AoC experience, and ended the experiment after about 7 days. I don't hate the app; I've previously covered [some things I love about iPad Plagrounds and how it's a glimpse of next-gen IDEs]({{ site.url }}/blog/2018/02/07/programming-20-years-in.html). I just have high expectations of Apple and am disappointed that it hasn't evolved in the intervening years.

After moving to Xcode, I felt like I was moving at warp speed. I now have unit tests that run my solution code against expected answers, and even a command line application target to generate all the boilerplate for next year's competition.

I did not finish the competition, although I may continue to work on problems throughout 2021. I really enjoyed my first AoC and am grateful for the perspective I got taking deep dive in Playgrounds: I _really_ appreciate all the little things a modern IDE provides. All the associated code lives in a [GitHub repository](https://github.com/armcknight/AdventOfCode).

# Pros

- Whole symbols are highlighted when touching them, making for quick replacement by touching and immediately typing or pasting.

- It detects when your program runs too long. In one case, I had accidentally harcoded an infinite loop! I’d be interested to know the heuristics they use, even if it’s a simple timeout on max CPU. Still not perfect: all it says is “there’s a problem with your code.” OK, sure. But also, not always; other times it was just that I wrote terrible, awful, slow solutions (they got better).

# Cons

OK. This is a long list. I split these into small potatoes like simple bugs or oversights, and big fish: things that were probably considered but represent large efforts to complete and so have been put on the back burner.

## Small Potatoes

- No split-screen multitasking on iPad.

- The attempt at maintainingg matching pairs of parens has some bad outcomes: to get just an opening `(`, you have to type `(`, then space in between it and the auto-inserted closing `)`, then arrow past the `)` and backspace twice (once for the closing paren, the other for the space you inserted; if you type `(` which produced `()` with the cursor in the middle, then arrow past the `)` and backspace, both of them are removed.

- Likewise, typing a double quote always puts a closing one even when not appropriate; like when closing a string literal you've already started.

- When I tap on an empty line to type a multiline comment, once I type the `/`, it indents it by a tab width. I then type the `*` and newlines and close it with `*/`, then have to outdent the opening `/*

- It's really difficult to grab the scrollbar and proportionally scroll up and down the source document, oftentimes with the focus going towards placing the cursor wherever I touched. I would love even more for the scrollbar to become a source minimap after pressing and holding to get proportional scrolling as in the rest of iOS.

- There’s no way to escape from documentation popups with an external keyboard. (Also, “Help” should be called “Docs”; it took me a few minutes to figure out how to find the docs for a symbol.) Usually `⌘ .` is the escape key equivalent for iOS.

- Doesn’t have the ⌘ `⌥` `[`/`]` shortcuts to swap lines up/down while maintaining scope indentation, like in Xcode.

- No surrounding of selected text with `(`/`)`, `[`/`]` or `{`/`}` by typing just the opening character.

- No highlighting tokens in camelCased/snake_cased/etc symbol names with `^ ⇧ →`/`←`.

- Each new playground starts with two lines, so tapping in the lower 80% of the screen puts you on the second line, thereby wasting the first line. I want to start on the first line!

- If I leave the cursor and scroll up a bit, then move the cursor or type, the source will jump to center the cursor if it's outside of the middle 30% of the screen. It's jarring and happens way too often.

- The editor window doesn’t remember its scroll position if you leave and come back. I was often jumping between solutions/days to copy something for a new problem.

- No way to select large ranges of text by touching to place the cursor, then holding shift and touching at the other end of the desired span of text to select. Once I'd plopped the huge input strings into my source, that is where they stayed.

- Can’t split between source editor and console any other ratio besides 1:1, even though it appears to have a draggable split bar (the same thing handle as the scrollbar and for the app switcher, or in iPad multitasking panes).

## Big Fish

- No code folding. Originally I was copying in the whole problem story in a comment at the top, then the full input as a string literal (before I discovered the "shared" source tab). This made for a reeeeaaeaeaelly long source file to scroll, which, by the way, the app doesn't handle very well.

- No way to tell the inferred type of a selected variable. In Xcode, I can hit `⎋` (escape) and whatever symbol is under the cursor will get an autocomplete popover showing the symbol's type or signature. I had to do a lot of scrolling up to see the types of my variables. Also no way to see other usages of a highlighted symbol.

- Autocomplete in the predictive text bar instead of directly under the cursor like in Xcode means my eyes have to travel far enough away that the code I'm typing is no longer in my fovea, thus breaking my focus.

- No search/replace. This is huge, I use this constantly as a programmer.

- No SPM support. This would be a huge feature to land in the app and would really open up its real-world use cases. There's already UI for it in Xcode so sure some of that could be reused or easily rebuilt. Code sharing is very difficult/impossible in the app today.

- No source control support. Same comments as for SPM.

# You Must be This Tall to Ride

I've been checking in with Swift Playgrounds since its infancy. I'm hoping that soon we'll see it grow up into a mature code editor, or even a new state-of-the-art IDE by being reincarnated as Xcode on the iPad–one can dream! Whether part of making that dream a reality, or just improving the Playgrounds app, I hope some of the things I listed here are on the roadmap, or find their way there, provided the right people see my feedback. It's undoubtedly a good tool to teach Swift to a new programmer. Could it–_should_ it–become worthy of editing real-life production code?
