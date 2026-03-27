---
title: "do try Antitypical's Result to catch Async Errors in Swift"
date: 2018-09-04
layout: post
abstract: Reviewing my foray into using Result for error handling in Swift, and my realization of a particular use case it solves well.
author: Andrew McKnight
author-email: andrew@tworingsoft.com
tags: swift
---

I've previously written about using [swift errors vs optionals](http://tworingsoft.com/blog/2017/05/18/returning-optionals-versus-throwing-errors-in-swift.html) to indicate errors while fetching results (e.g. no file descriptors available to open a file to read its contents) vs absence of results (e.g. the file was read but it was empty). After publishing, a friend asked if I had heard of the [Result](https://github.com/antitypical/Result) library, and if I'd considered using that instead of Swift errors. Indeed, I had used it due to its inclusion in [ReactiveSwift](https://github.com/ReactiveCocoa/ReactiveSwift)/[ReactiveCocoa](https://github.com/ReactiveCocoa/ReactiveCocoa), but had never in my own code or libraries' API.

# What I tried

I took a generic function from my model layer, which inserts a Core Data entity and returns the instance as its own type instead of `NSManagedObject`, or `throw`s an error if the cast fails. I changed it from `throws -> T` to `-> Result<T, CoreDataError>` (typed error semantics is a nice plus for `Result`). This small change at such a fundamental level precipitated many code changes, and because it’s a function in a framework used by several of my apps, more work lay ahead if I committed to the change. I wound up concluding that I didn’t care to replace all error handling with `Result` in my own API, but I found it very helpful resolving a particular situation: combinatorial optionality in nonrethrowing function closures.

## Combinatorial optionality

Lots of APIs return an optional result and optional error, like [`NSURLSession.dataTask(with:completionHandler:)`](https://developer.apple.com/documentation/foundation/urlsession/1407613-datatask), whose completion block provides parameters `(Data?, URLResponse?, Error?)`. Because optionals are a compiler feature, you're forced to deal with scenarios like getting `nil` for all three parameters. According to [`NSURLSession`'s docs](https://developer.apple.com/documentation/foundation/nsurlsession/1410330-datataskwithurl?language=objc#discussion), this can't happen: 

<blockquote>
	If the request completes successfully, the data parameter of the completion handler block contains the resource data, and the error parameter is nil. If the request fails, the data parameter is nil and the error parameter contain information about the failure. If a response from the server is received, regardless of whether the request completes successfully or fails, the response parameter contains that information.
</blockquote>

Nonetheless, you must conceptually handle each case in code:

<table class="alternating-table bordered-table">
	<tr><th>Data?</th><th>URLResponse?</th><th>Error?</th><th>Behavior</th></tr>
	<tr><td>nil</td><td>nil</td><td>nil</td><td><b>impossible</b>; should always have a URLResponse</td></tr>
	<tr><td>nil</td><td>nil</td><td>present</td><td><b>impossible</b>; should always have a URLResponse</td></tr>
	<tr><td>nil</td><td>present</td><td>nil</td><td><b>impossible</b>; should always have only one of either a Data or an Error</td></tr>
	<tr><td>nil</td><td>present</td><td>present</td><td>handle the Error (including passing it back to callers)</td></tr>
	<tr><td>present</td><td>nil</td><td>nil</td><td><b>impossible</b>; should always have a URLResponse</td></tr>
	<tr><td>present</td><td>nil</td><td>present</td><td><b>impossible</b>; should always have a URLResponse</td></tr>
	<tr><td>present</td><td>present</td><td>nil</td><td>pass the Data or a deserialized object or data structure back to callers</td></tr>
	<tr><td>present</td><td>present</td><td>present</td><td><b>impossible</b>; should always have only one of either a Data or an Error</td></tr>
</table>

Only two of the eight combinations even make sense. I really want [union](https://en.wikipedia.org/wiki/Tagged_union) semantics: a way to tell the compiler that a reference can point to either one thing/type or another at a time. `Result` achieves the same expressibility using Swift’s error throwing itself, along with enums and generics in a sort of Swift hat-trick. Funny enough, it's the solution I found myself building towards when I sat down to implement my own union-y type specific to my app's domain, instead of the general-purpose `Result` (starting from the Swift Language Guide's recommendation to use [enums with associated values](https://docs.swift.org/swift-book/LanguageGuide/Enumerations.html#ID148). There's also [Either](https://github.com/robrix/Either), which generalizes the concept further, but its `.left` and `.right` names seemed too generic to me, whereas `Result` has more specific terminology for the current domain: `.success’ and `.failure`.

`(URLResponse, Result<Data, Error>)` exactly transcribes what the docs say into code that's enforceable by the compiler. Of course, it'd be even easier to have an invariant return type on a function that `throws` and error. Even then, combinatorial optionality is easier to deal with, via a few early exits from `guard let`s, and you only have to do it once. The problem lies in functions that don't rethrow errors thrown in their closure parameters...

## Nonrethrowing function closures

If you've ever [`map`](https://developer.apple.com/documentation/swift/array/3017522-map)ped over a Swift `Array`, you've used a function that `rethrows` Swift errors thrown from its closure parameter's scope. It's as simple as declaring a function as `rethrows` and the closure parameter it accepts as `throws`. Otherwise, any thrown errors must be handled inside that closure's scope, and this is enforced by the compiler. (To see more, check out “Rethrowing Functions and Methods” under “Functions” in the [Swift language reference's “Declarations” section](https://docs.swift.org/swift-book/ReferenceManual/Declarations.html#ID362).) 

Any calls to nonrethrowing functions in a call hierarchy stop thrown error propagation at that point. For instance, imagine a user action results in saving some data to your local cache and then uploading the data over the network, with any errors presented back to the user. A simplified description of the flow of execution through different application layers might look like so: `UI -> model -> network`, with errors propagating backwards. If all layers had functions declared with `throws`/`rethrows`, then we could just `throw` an error all the way back to the UI layer, where a `catch` block would handle it and present a dialog to the user. However, because `NSURLSession.dataTask` accepts a closure and is not declared `rethrows`, you cannot `throw` any error in the first place for failures. You must design your call hierarchy to use async patterns (closures, delegates, notifications etc) and pass errors as optional parameters.

## My app: CLGeocoder and Core Data

At some point in my app, Core Data entities (returned from the same function I mentioned earlier) are populated with data returned from [`CLGeocoder.reverseGeocodeLocation(_:completionHandler:)`](https://developer.apple.com/documentation/corelocation/clgeocoder/1423621-reversegeocodelocation). Like `NSURLSession`, the `completionHandler` closure passes back multiple optional parameters, in this case [`([CLPlacemark]?, Error?)`](https://developer.apple.com/documentation/corelocation/clgeocodecompletionhandler). Whereas with plain functions I'd `throw` an error all the way back from my model/network layers to the UI, now they all call closures passing something like `Result<CLLocation, Error>`. `Result` has mostly reduced the difference between propagating errors synchronously and async to one of syntax.

# Conclusion

From a reading of [Swift](https://github.com/apple/swift/blob/master/docs/ErrorHandling.rst#manual-propagation-and-manipulation-of-errors) [docs](https://github.com/apple/swift/blob/master/docs/ErrorHandlingRationale.rst) and [evolution](https://lists.swift.org/pipermail/swift-evolution/Week-of-Mon-20160314/012545.html) and [forum](https://forums.swift.org/t/throws-as-returning-a-result/1799) [posts](https://forums.swift.org/t/adding-result-to-the-standard-library/6932), it seems that the most likely thing we'll see is an `async/await` mechanism that works with `throw`, and we can break out of the restrictive closures I mentioned (hopefully). Until then, I'll keep using `Result` as a way to maintain clean call/error hierarchies that, from time to time, must include that tough breed of closures.

If you're weighing whether to use `Result` in your own API, here are the other pros and cons I came up with while experimenting with it:

---

# Pros 

## Typed Errors 

A Swift function may declare that it `throws` an error, but not which subtypes of `Error` they may be. You may attempt conditional casts in `catch` declarations, but you must always fall back to the "default" case of the `Error` root type as well. `Result` allows you to specify a particular subtype, such as `Result<String, MySwiftErrorSubtype>`. 

## No Combinatorial Optionality

See: this blog post

# Cons

## Structural Code Changes

Unless you decide at some point to convert the result's error field to a thrown error, the change from `do-try-catch` to `switch-success-failure` permeates throughout your codebase. At first, there was no clear answer on where to make the switch for me, so I just passed the `Result` all the way to my presentation layer. This changed a lot of code everywhere in my app, although in the end I found it comprehensible and concise.

Changing from a `do-try-catch` to `switch-failure-success` has its own tradeoffs:

### Pros

- Clearer separation of happy path and failure modes: they're literally labeled by the `success/failure` case names in each `switch`.
- I find `switch` boilerplate easier to cognitively filter out than `do-try-catch` boilerplate.

### Cons

- Code ordering: `do-try-catch` imposes a specific order on your code statements and blocks. You must write the statements that depend on the result of the throwing call after that call, and the error handling must follow that in a catch block. You can't write a catch block anywhere else. With `switch-failure-success`, you can write the `failure` case first, similar to an early exit with a `guard` (my preference), but you can also put the `success` case first. `switch` imposes no ordering on its case labels, so even though this is a small, pedantic nitpick, you must expend a little cognitive overhead each time to decide which case to write first. And if you have anything less than perfect memory and willpower, you will eventually swap the ordering in your code, introducing inconsistency.
- Nesting: you may have a `do` block that calls multiple `throw`ing functions at the same scope level. If each of those instead returned a `Result`, they must be nested inside each other's `switch` blocks, or use higher-order functions like `map` to recompose the results (further overloading the meaning of those function names, and requiring you to remember to use `flatMap` with `Result` as with `Optional`, and not `compactMap` as with `Sequence`).

## Dependency

Inserting a dependency requiring pervasive changes, that I don't maintain, and that changes the way I express code execution, is risky. Changes in anything from Swift `Error`s, stdlib protocols, generics or closures could affect how Result operates, and maybe even necessitate code changes to fix API breakage. However small, there is a nonzero probability that I may one day have to rewrite the code that used `Result`.