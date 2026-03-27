---
title: "Swift Async Operations at Your Command"
date: 2018-11-19
layout: post
abstract: Rewriting an old asynchronous Operation (née NSOperation) subclass in Swift for Pippin, learning new things.
author: Andrew McKnight
author-email: andrew@tworingsoft.com
tags: swift ios objc patterns
---

I recently rewrote [`FABOperation`](https://github.com/google-fabric/faboperation) in Swift for an app that uses [Pippin](https://github.com/tworingsoft/pippin). `FABOperation` was originally a class written by [Matt Massicotte](https://twitter.com/mattie), so credit is due to him for the original, robust solution (explained later in the article). I later picked it up and added the compound operation class, some tests and a demo macOS app. After open-sourcing it while at Twitter/Fabric, I spoke about it at [mDevCon 2016](https://vimeo.com/210042860).

> All references here to Pippin's `AsyncOperation` also apply to `FABOperation`–I'll point out specific differences using the `FAB`-prefixed names.

Let's start with some background info on Apple's `Operation` (`NSOperation` in Objective-C).

# Operation Operation

An [`Operation`](https://developer.apple.com/documentation/foundation/operation) encapsulates a bit of work, as a code application of the [“Command” software pattern](http://wiki.c2.com/?CommandPattern). It's one of many patterns you may already know from using Apple's SDKs: “Delegate” (`UITableViewDataSource`), “Abstract Factory” (`NSString`, `NSNumber`), “Observer” (KVO and `NSNotification`) and “Flyweight” (`UITableViewCell` reuse) among others.

By cordoning off logic and associated state into discrete pieces, you can write flexible, reusable and testable code. Apple's [WWDC 2015 Session 226: Advanced NSOperations](https://developer.apple.com/videos/play/wwdc2015/226) highlights how this architecture benefitted the WWDC iOS app, and my own presentation did the same for some of our tools at Crashlytics.

You can create plain ol' `Operation`s and run them by calling `start()` or by placing them on an `OperationQueue`. Its constructors can accept `NSInvocation`s or closures, and you can add more logic in its `completionBlock` closure. For more customization, you can subclass it and override `main()`, where the business logic resides. You can use one or multiple queues, either serial or concurrent, to architect complex state machines.

The thing is, `Operation` is synchronous... if you want an asynchronous version, you have to build it yourself.

# Why AsyncOperation?

Imagine you want to encapsulate a network request, and you simply subclass `Operation` and initiate the request in its `main()` body. Two problems immediately arise. 

First, if you place the operation on a queue, it won't block subsequent or dependent operations from beginning before your network request completes. Once the request is started, like with `URLSessionDataTask.resume()`, the `main()` function returns, the operation is popped off the queue, and others that were waiting will begin, probably before they should. Dependent operations, possibly in parallel queues, will start too soon, maybe displaying UI for a default success path before an operation fails, or passing empty, stale or corrupt data to subsequent logic.

Second, you have no way to shuttle the network response to consumers of your operation. You could populate some properties on it, but how does your consumer know when to access them? `completionBlock` executes immediately after `main()`; you likely won't have your response data that soon.

`AsyncOperation` solves the first problem by setting the `isConcurrent` and `isAsynchronous` properties to `true`, overriding `start()` and `main()`, and providing a way to manually finish the operation: `finish(withError:)`. As it turns out, though, there's a lot more to the problem. `OperationQueue` uses KVO to start operations and pop them from the queue, depending on changes to its state properties: 

- `isReady`
- `isExecuting`
- `isFinished`
- `isCancelled`

Managing transitions between these states in a concurrent environment presents a formidable challenge. And because `OperationQueue` monitors these changes via KVO, the appropriate KVO events must be dispatched before and after each state change. `AsyncOperation` gates all state changes using a recursive lock, and uses a closure syntax to ensure KVO correctness.

To solve the second problem, we added a new closure, `asyncCompletionBlock`, which passes back any errors encountered. Subclasses may also provide their own custom closures or properties to pass back typed data, but still need to call `finish(withError:)` for correct behavior on queues and in compound operations. For parity with `NSOperation`, `completionBlock` is still the very _last_ thing executed, that is, _after_ `asyncCompletionBlock`.

# Why CompoundOperation?

With `FABOperation`, we started architecting complicated business logic into state machines that could include network requests and interprocess communication, e.g. via `NSTask` and `XPC`. Eventually we found a few subroutines made of multiple operations that we wanted to reuse and manage as a unit.

We created `FABCompoundOperation` to handle executing a set of mixed sync/async operations, aggregate any errors encountered, and propagate cancellation. The set of errors is passed through via its own `asyncCompletionBlock`.

# Rewriting in Swift

I haven't personally needed to use `FABOperation` since Crashlytics, but recently found a need, and wanted to use my own implementation delivered via Pippin. I decided to rewrite the classes in Swift as a way to refresh my memory and see if the design or logic could be improved–this often happens when I write things in a new language. Swift is very safe, so it helps surface plenty of things easy to miss in a dynamic language like ObjC–this time around was no exception. Let's see some of the good and bad...

## Successes

### Swift

Having Swift code is _obviously_ the best part about translating Objective-C into Swift :) But seriously, it substantially reduced the amount of code. It also eliminated some conditionally compiled ObjC code from `FABCompoundOperation` to handle `dispatch_queue_t` as both retain/release or, if building for systems [starting with macOS 10.8 and iOS 6, ARC](https://developer.apple.com/documentation/dispatch/1496328-dispatch_release?language=objc). There's even a bug here surfaced by a newer compiler warning in Xcode: we never called `[super dealloc]`! I found a few other logical errors:


### Compound Completion

Compound operations used to try injecting compound completion attempts into the `asyncCompletionCompletion` _as well as_ `NSOperation`'s stock `completionBlock`. So, every time an async operation would finish, there would be two checks to see if the compound operation was done: in both `competionBlock` and `asyncCompletionBlock`. Because `completionBlock` always executes after its new async counterpart, we can safely use that as the sole check to see if any operation, sync or async, is finished. Aggregating errors from async operations is now its own injected closure, whereas before there was one closure that tried to do both jobs.

### Compound Cancellation

I found an inconsistency in `CompoundOperation`'s completion attempt logic, where if it is cancelled at the time it tries to complete, it will finish with an error and then nil out the reference to `asyncCompletionBlock`. However, it doesn't nil it out in the case where it's not cancelled and all operations have finished. I moved the nil-out of `asyncCompletionBlock` into `AsyncOperation.finish(withError:)`, so compound as well as regular async operations all treat `asyncCompletionBlock` consistently, regardless of the final state.

## Challenges

### Testing

Testing any concurrent code is tricky, and this is no exception. I ran into a few issues validating and fixing the old tests I'd written, and writing a few new ones to verify the behavior of operations in general in service of this post!

#### KVO

I brought over some old ObjC tests that exercised cancellation logic in async and compound operations. After adding some for stock synchronous `NSOperation`s, I straightened out some discrepencies around when and which completions blocks are executed, and also for some KVO events. I also hit a possible known runtime bug w.r.t. which selector names receive KVO events for operation state properties, where `NSOperation` sends updates on keypaths with the ‘is’ prefix, e.g. `isExecuting`, whereas my Swift `AsyncOperation` sends them on the backing property names, e.g. `executing`; this despite explicitly sending it on the prefixed version in `AsyncOperation`'s implementation, and the fact the everything still works on queues in the demo project. Some [filed bugs](https://bugs.swift.org/browse/SR-4397) and [discussions](https://forums.developer.apple.com/thread/87398) were pointed out to me around `Operation` KVO, so it looks like work is still being done here.

#### Concurrency

Originally, my test `AsyncOperation` subclass would use delayed GCD async dispatches to simulate long running tasks. Now, I wanted to add some tests that exercise normal execution of operations, fulfilling expectations in all their completion blocks and for all KVO events. However `waitForExpectations(withTimeout:handler:)` blocks execution to wait for those expectations. I wound up removing the delayed dispatch; the time simulation doesn't matter when verifying all the completion behavior is correct–by definition, an async operation requires _arbitrary_ time to complete, so short==long for our purposes. (To see them work with time delays, check out the demo project mentioned at the end of the post.)

Similarly, I had trouble testing normal behvavior of compound operations. I could not find a way to allow their private operation queues to finish normal execution, that wouldn't deadlock with the test's attempt to wait for expectations. These test cases are currently commented out with a note; the demo operation is currently the best way to verify that multiple compound operations execute correctly on a queue.

### Swift-to-ObjC

At the time we put `FABOperation` together, we chose to keep it Objective-C rather than the hot new language we now know and love: Swift. Matt's original reasoning is still on the README as of this writing, and still holds today:

> There are a huge amount of apps out there that have zero Swift in them. We didn't want to force those apps to include the Swift runtime libs. This is a trade-off, and it's one that we hope will become less and less necessary over time.

While I translated the async operations into Swift for Pippin, I wanted to keep the test and demo sources I had originally written in ObjC. This has the dual benefit of saving time rewriting that part, but more importantly it exercises usage of a now-Swift API back in ObjC land.

One component of the tests and demo is a set of `AsyncOperation` subclasses. However, [ObjC classes cannot inherit from Swift classes](https://developer.apple.com/documentation/swift/migrating_your_objective-c_code_to_swift#//apple_ref/doc/uid/TP40014216-CH12-XID_67)! There's no way around this one: I had to rewrite `TestAsyncOperation` and the demo subclasses in Swift.

### Swift-to-ObjC

Nope, I didn't copypasta that last heading. Nobody ever said it'd be easy using Swift from Objective-C.

This one concerns `Swift.Error` and `NSError`. Originally, if `FABCompoundOperation` had one or more suboperations fail, it would pass an `NSError` back through `asyncCompletionBlock` with a `userInfo` key mapped to an array of those errors. In the Swift version, I'd like to use an `Error` `enum` instead of global error code variables, but then I'd have to attach an associated value to pass that array of errors, which doesn't bridge to ObjC. There were also asserts on the error codes themselves in ObjC test code, which was lost in the translation to a native Swift error. So, while I did switch to an Error enum, I had to include a function to transform them back into `NSError`s anyways :/ Maybe one day, if native Swift errors somehow truly replace NSError, I'll be able to remove the transform.

# Try it out!

The original demo project I wrote is now located in `Examples/OperationDemo.xcodeproj`, so `pod try https://github.com/tworingsoft/pippin` will allow you to check out the demo straightaway! Right now, you can test sync, async and a compound operation composed of a mixture of both, and it will show you when each stage of each operation runs. You can start and stop the queue they're on, switch it between serial and concurrent modes, or cancel the operations.

And of course, contributions are [more than welcome](https://github.com/tworingsoft/pippin), and I'd love to hear if you use `AsyncOperation` or `Pippin` in one of your apps!
