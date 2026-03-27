---
title: The Programmer Political Compass
date: 2024-03-13
layout: post
abstract: Visualizing our tendencies as programmers.
author: Andrew McKnight
author-email: amcknight2718@gmail.com
tags: funny mgmt software
---

I frequently find myself thinking back to an old article I read when conflicts arise between programmers, Steve Yegge's "Notes from the Mystery Machine Bus", in which he proposes a framework for describing different programmer's value systems on a spectrum of conservatism, with "conservative" and "liberal" at the extreme ends.

I don't love all of how he tries to relate this back to actual political conservatism and liberalism, but I do think there're some gems hidden in the article. It was originally published on Google+, and I had trouble even loading it in the [WayBack machine archive](https://web.archive.org/web/20120701000000*/https://plus.google.com/u/0/110981030061712822816/posts/KaSKeg4vQtz) (I assume the archives are so old that someone had to run a tape drive between buildings and tripped on a curb en route). Luckily someone copied it to a gist long ago, which I [forked](https://gist.github.com/armcknight/360f1d3457c333efff89a9585d5176aa) but keep forgetting about and have repeated this attempt-wayback-machine-rediscover-gist scenario countless times by now. Some quotes:

> the adjective "conservative" is more or less synonymous with caution and risk aversion

> Liberalism [can be then thought of] as a belief system that is motivated by the desire above all else to effect change...changing the world...to maximize the speed of feature development, while simultaneously maximizing the flexibility of the systems being built, so that feature development never needs to slow down or be compromised.

> To be sure, conservatives think that's what they're maximizing too...Flexibility and productivity are still motivators, but they are not the primary motivators. Safety always trumps other considerations, and performance also tends to rank very highly in the software-conservative's value system.

> The crux of the disagreement between liberals and conservatives in the software world is this: how much focus should you put on safety? Not just compile-time type-safety, but also broader kinds of "idiot-proofing" for systems spanning more than one machine.

> I do think that mutual understanding of the underlying value systems may help the camps compromise

That last point to me is how you can really excel in software engineering. So much of it involves _people problems_, not technical ones. One of the thorniest challenges I see in collaboration is in getting a room full of programmers to agree on a mental model of the problem and possible solutions.

I think it's a helpful framework to check yourself, but I don't think it's the end-all-be-all. It's not quite a false dichotomy because you should view it as a spectrum, not a binary. But it is one-dimensional and disregards other possible factors than just risk aversion. So then I started wondering what would be a good orthogonal factor I could use to create a quadrant system: economic incentives ([as this Slashdot user points out](https://developers.slashdot.org/comments.pl?sid=3040083&cid=40945183)). And thusly you have the parallel to the [political compass](https://www.politicalcompass.org). Again, not an end-all-be-all, but an interesting conceptual framework.

I googled to see if someone had already done this. [Of course they have.](https://www.reddit.com/r/ProgrammerHumor/comments/wi0o4c/36_different_kinds_of_programmers/) You also have to go hunting for the actual image in the WayBack Machine; I already did the legwork:

{% include blog-post-image.html source="programmer-political-compass-meme.jpg" alt="The Programmer Political Compass (meme)" %}

Of course, a lot of it is irreverantly tongue-in-cheek. But it does capture some of what I had in mind. Free software, developer salaries, government/defense contracting.

Can we improve on it?

> Everything has already been done, every story has been told, every scene has been shot. It’s our job to do it one better.

- Stanley Kubrick

People's politics can change depending on life circumstances. So under what conditions does someone move from one area in the compass to another? Here's a tongue-in-cheek answer to that question:

[update 10 June 2024]
...I wanted to see a "me, normally -> me, when X" style overlay on this. I think I started one while trying to finish this post, but got distracted and shipped without it 😅 Maybe one day I'll finish it.
