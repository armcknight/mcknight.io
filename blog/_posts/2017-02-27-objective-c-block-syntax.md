---
title: Objective-C Block Syntax
date: 2017-02-27
layout: post
abstract: Some ways to make writing Objective-C blocks in Xcode a little easier.
thumbnail: inlineblock-example.png
author: Andrew McKnight
author-email: andrew@tworingsoft.com
tags: ios objc
---

One of the things Objective-C developers love to hate about the language is the [fucking block syntax](https://fuckingblocksyntax.com) (disclaimer: I used this website to write the block syntax in some examples!). I certainly understand the sentiment: they are very clumsy to write and get right the first time. If you use Xcode, however, there are some strategies and helpful autocompletion flows that will make your life easier without having to fire up a new browser window.

# A little abstraction goes a long way

I never write a method that contains all the clumsy mechanics of a block directly in a parameter type.

Bad:
{% include gist-embed.html url="https://gist.github.com/armcknight/58de74211062f1784b1cb3410f5a07b9" %}

Instead, Xcode provides an autocompletion for the string `typedefBlock`; start typing that outside of an `@interface`/`@implementation` scope, and you can accept an automatic expansion to the following:

{% include 
	blog-post-image.html 
	source="typedefblock-autocompletion.png" 
	alt="Autocompletion for typedefBlock." 
	caption="Autocompletion for `typedefBlock`." 
	dimensions="width=\"75%\"" %}

Good:
{% include gist-embed.html url="https://gist.github.com/armcknight/26662cb58286db2d0c3e1f5aefe69b71" %}

This adheres to DRY principles and makes the code more self-documentingly readable. So many times, I've seen method after method clumsily spell out the same block signature for passing networking completion blocks down the call stack with the familiar triad of `NSData`, `NSURLResponse` and `NSError`, when it should have been wrapped up in a `typedefBlock`. Removing the actual signature from 20 places to just one would have avoided many permutations of nullability specifiers, types and parameter names between all the instances of the completion signature. you can change it much easier in the future and even add documentation comments!

# Placeholder expansion

OK, we've now `typedef`'d all of our block declarations, and now we want to call a method containing a completion block. If you have autocompleted a method call that accepts a block as a parameter, you can tab over to that placeholder and hit Return, expanding the full block syntax needed to satisfy the parameter. This really helps me to write blocks that have return values, because for some reason I can never remember that particular piece of [gosh darn block syntax](http://goshdarnblocksyntax.com).

{% include 
	blog-post-image.html 
	source="block-placeholder-expansion-before.png" 
	alt="The autocompletion for the method call contains a placeholder for the block parameter." %}

<br />
<br />
<br />

{% include 
	blog-post-image.html 
	source="block-placeholder-expansion-after.png" 
	alt="After tabbing to the block placeholder and expanding with the Return key." %}

# Inline blocks

Xcode has one other helpful snippet to write Objective-C blocks: `inlineBlock`. This helps you to declare a block and store it in a variable in local scope. This makes method calls that accept multiple blocks, like `+[UIView animateWithDuration:animations:completion:]`, more readable at the call site. I prefer this over chaining multiple blocks directly in the parameter positions, which ends up looking awkward in Objective-C syntax and even worse when you're reading code or diffs in viewers that wrap text.

{% include 
	blog-post-image.html 
	source="inlineblock-example.png" 
	alt="The good and bad of Objective-C method calls with multiple block parameters." %}

In general, I don't fully care for this approach, as you then have to read code upwards. It also annoyingly makes you repeat the parameter list. Most preferable to me is to still declare the blocks as local variables, but extract all the logic you would have written in the block to a method. This approach makes your code more readable, and your logic more testable and refactorable later.

## What about Swift?

Writing closures in Swift is much easier for me, but I'd still encourage you to `typealias` complicated closure types, and you can always visit [fucking swift block syntax](http://fuckingswiftblocksyntax.com), [fucking closure syntax](http://fuckingclosuresyntax.com) and of course [gosh darn closure syntax](http://goshdarnclosuresyntax.com), for those of you who've already maxed out your cursing jar allowance for the month performing Swift 3 migrations.
