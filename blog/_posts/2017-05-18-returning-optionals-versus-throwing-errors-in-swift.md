---
title: Returning Optionals Versus Throwing Errors in Swift
date: 2017-05-18
layout: post
abstract: Deciding between flow control and data model concepts in your app's business logic.
author: Andrew McKnight
author-email: andrew@tworingsoft.com
tags: ios swift
---

One of Swift's most notable, fundamental and pervasive constructs is the Optional, to help deal with the `null` problem faced by any language with pointers. This is a great way to represent the absence of an object, and denote anything that is not required and can be absent as such. Then, you get some great ways to validate you have everything you need before working with variables to perform a task.

Swift, like Objective-C and many other languages before it, also has a way to divert the normal flow of execution in exceptional circumstances. So, if your validation routine decides it has hit a situation where it can no longer proceed, it can `throw` an error and bail out early.

As you shuttle data between disks, servers, and capture it from and present it to your users, you probably have many functions to perform specific transformations or I/O tasks. You have been writing more functional code since moving to Swift, haven't you? Well, let's talk about return types and describing function failures!

# Failure mode code

Consider how many C or Objective-C APIs work: return an integer or boolean result that represents the status, -1 often representing an error in the integer case. It's tempting in Swift to use the return value of a function to signify something went wrong, by making it optional and returning `nil`.

{% include gist-embed.html url="https://gist.github.com/armcknight/73f54da770d415545e38e30961a49488" %}

In Objective-C, the inout error parameter was the pattern to communicate errors, with a special return value to signal the error occurred. Swift  encourages the use of `do`/`try`/`catch` to divert execution using `throw`, where Objective-C discouraged using exceptions for all but actual programmer error. 

{% include gist-embed.html url="https://gist.github.com/armcknight/81cc09a5185b35f2c52c2d3fa48b5ee8" %}

In both of these examples, assume:

- the class definition and function represents your model layer
- the middle function definition represents your middle business logic 
- and the statements at the bottom represents your presentation layer. 

I like several things about the second approach. It saves me from a clunky `guard` statement in the middle layer; using `try` clears away edge cases and the code more clearly describes intention. All error handling logic that involves user notification cohesively resides in the presentation layer, whereas in the first example there can be many places that could plausibly handle the error, forcing you to expend more cognitive process to make those decisions.

# Optional requirements

So then what should an optional be used for? To represent the absence of something. Not the absense of something *because an error occurred.* Just absence. 

The difference becomes a bit more clear when you consider collections. What is the difference between an empty collection and a collection that is not there? In both cases, you have zero things that would be found in such a collection. The difference is in how all the code involved in shuffling the container from A to B must handle all possible combinations.

{% include gist-embed.html url="https://gist.github.com/armcknight/91004385bbd1a79eebe5ed9cd7bab310" %}

If you need to do some validation etc. at multiple stages along the way, you'll need to work around the optionality of the collection. Whereas, if you always have a container, your logic can be more streamlined. The same loops and function calls work the same way whether there are 0 or 100 elements in an array.

{% include gist-embed.html url="https://gist.github.com/armcknight/df1a304f22b03958d4ca2802523e9baf" %}

And again, by using Swift's error system, you're much more expressively describing possible failures.

# If it walks like an error...

Think about what you'll need to do with an error. In truly exceptional scenarios, the app is not going to function the way the user expects, so you're probably going to need to show them an alert. This is a great use case for `throw`ing errors. You can bubble up errors from any application layer all the way to the UI, even transforming errors at the boundaries between layers. (You may want to log an error received from your server, then repackage it with a user-friendly message and propogate it through your controller logic until it reaches the presentation layer.)

All the intervening code paths that return things to other things might then not need to worry about optionals. That means many less `guards`, `if lets`, optional chaining and `nil` coalescing along the way. Instead, you can just prefix other function calls with `try` (and sometimes perhaps `try?`). Using these constructs to communicate errors is an abuse of the optional system and hides information about the errors that would help the compiler and other developers.

Swift's error type system has recently seen improvements and I'm sure as time goes on we'll see more improvements to the overall propogation mechanisms. They provide a great way to describe the failure modes of your routines, so always consider if what you're really trying to communicate is best handled with Swift's errors. I default to the strategy described here, deviating only if the model really calls for it.