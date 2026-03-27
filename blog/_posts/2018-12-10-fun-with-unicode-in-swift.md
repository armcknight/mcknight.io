---
title: "Fun with Unicode in Swift"
date: 2018-12-10
layout: post
abstract: Looking at some ways to write tricky Swift code using Unicode.
author: Andrew McKnight
author-email: andrew@tworingsoft.com
tags: swift
---

I recently saw an [article mentioning Unicode identifiers in Go](https://blog.golang.org/go2-here-we-come) ([discussion on GitHub](https://github.com/golang/go/issues/20706)). Now, I don't use golang, but another language I do know and love also supports Unicode identifiers.

# Unicode in Swift

Swift can include Unicode in identifier names, like variables, functions or enum/protocol/value/class definitions (but importantly, not in operators). This gives developers the ability to write code that is internationalized, appears more mathematical or just looks like [Glitchr_'s Twitter feed]( https://twitter.com/glitchr_). In the spirit of the exquisite [how to write unmaintainable code](https://github.com/armcknight/unmaintainable-code), let's look at a few fun things that could be done to write unmaintainable Swift code!

> I use the awesome [FiraCode](https://github.com/tonsky/FiraCode) font face in Xcode (and everything else!), hence in all these screenshots. Unicode characters will render differently for different fonts. For many of these tricks, it's obvious where the differences lie, but that may not be as true for all typefaces.

## Lookalikes

Unicode has lots of alternative codepoints for the same character. Put them to work to help store more data, seemingly without the need to create more variables!

You can replace combinations of letters with ligatured versions...

{% include blog-post-image.html source="unicode-swift-letter-combinations.png" narrow="true" mobile_fullwidth="true" %}

...or hide operator-like glyphs to fake expressions.

{% include blog-post-image.html source="unicode-swift-operators.png" narrow="true" mobile_fullwidth="true"%}

When in Rome...

{% include blog-post-image.html source="unicode-swift-roman-numerals.png" narrow="true" mobile_fullwidth="true"%}

...it's all Greek to me!

{% include blog-post-image.html source="unicode-swift-greek-letters.png" narrow="true" mobile_fullwidth="true"%}

Full-width characters can fake a function...

{% include blog-post-image.html source="unicode-swift-full-width.png" narrow="true" mobile_fullwidth="true" alt="Oh no he didn't use an empty catch block as an example!" %}

...and you can always use the Socratic method!

{% include blog-post-image.html source="unicode-swift-greek-question-mark.png" narrow="true" mobile_fullwidth="true"%}

## Noseeums

The original inspiration for this post was a zero width space in some text I copied from a JIRA ticket right to code. It took me a bit to figure out what'd happened, and with any luck, equally so for each your colleagues! That's what we call network effect.

{% include blog-post-image.html source="unicode-swift-invisible-spaces.png" narrow="true" mobile_fullwidth="true"%}

## Emoji

They're much slower to type, and many are nearly indistiguishable from one another, but [emoji use in Swift](https://ericasadun.com/2016/11/08/swift-by-emoji-a-considered-approach/) sure is fun 🎉! 

{% include blog-post-image.html source="unicode-swift-emoji.png" narrow="true" mobile_fullwidth="true"%}

## Zalgo

The `mutating` keyword just doesn't drive the point home enough. You need to make those functions strike fear into the hearts of those who would invoke such dangerous spells!

{% include blog-post-image.html source="unicode-swift-zalgo.png" narrow="true" mobile_fullwidth="true"%}

> If you need to curse your own code, the [Zalgo Text Generator](https://zalgo.org) can help you find the right invocation!

# Dark Ages of Code? 🌚

This is all fun and games, but what if we were to [use Unicode in earnest](http://www.bbc.com/future/story/20151012-will-emoji-become-a-new-language) and then [things change](https://openspace.sfmoma.org/2018/07/the-absolute-denial-of-💩/), like [Apple changing a deadly revolver to a harmless and fun watergun](https://blog.emojipedia.org/apple-and-the-gun-emoji/)? Given enough time, could entire code sectors and execution paths become unreadable, their [intent lost](https://grouplens.org/blog/investigating-the-potential-for-miscommunication-using-emoji/) along with the sensibilities of a previous programmer, design team, society, or civilization?

# Look on the Bright Side! 🌞

I don't think we're at a point where we use enough Unicode in code to worry about any significant meaning to be lost in translation or redesigns. Tricks like identifiers containing alternate semicolons, parens or curlies would probably stand out using something as simple as syntax coloring. The sneakier lookalikes can be caught using automation like [SwiftLint](https://github.com/realm/SwiftLint) or [Danger](https://danger.systems). The most I've been harmed thus far is a 5 minute head-scratcher... I'm not too worried about the future 😎

Toy with some head-scratchers of your own with the [Xcode Playground containing these Swift Unicode examples](https://github.com/armcknight/swift-unicode-playground), and if you figure out something interesting, submit a PR!
